//
//  Route.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum      NIOHTTP1.HTTPMethod
import class     http.IncomingMessage
import class     http.ServerResponse
import typealias connect.Next

private let patternMarker : UInt8 = 58 // ':'
private let debugMatcher  = false

public typealias ErrorMiddleware =
                   ( Swift.Error,
                     IncomingMessage, ServerResponse, @escaping Next ) -> Void

public struct Route: MiddlewareObject {
  
  public enum Pattern {
    case root
    case text    (String)
    case variable(String)
    case wildcard
    case prefix  (String)
    case suffix  (String)
    case contains(String)
    
    @inlinable
    public func match<S: StringProtocol>(string s: S) -> Bool {
      switch self {
        case .root:            return s == ""
        case .text(let v):     return s == v
        case .wildcard:        return true
        case .variable:        return true // allow anything, like .Wildcard
        case .prefix(let v):   return s.hasPrefix(v)
        case .suffix(let v):   return s.hasSuffix(v)
        case .contains(let v): return s.contains(v)
      }
    }
  }
  
  let middleware      : ContiguousArray<Middleware>
  let errorMiddleware : ContiguousArray<ErrorMiddleware>
  
  let methods         : ContiguousArray<HTTPMethod>?
  
  let urlPattern      : [ Pattern ]?
    // FIXME: all this works a little different in Express.js. Exact matches,
    //        non-path-component matches, regex support etc.
  
  init(pattern         : String?,
       method          : HTTPMethod?,
       middleware      : ContiguousArray<Middleware>,
       errorMiddleware : ContiguousArray<ErrorMiddleware>)
  {
    // FIXME: urlPrefix should be url or sth
    
    if let m = method { self.methods = [ m ] }
    else { self.methods = nil }
    
    self.middleware      = middleware
    self.errorMiddleware = errorMiddleware

    self.urlPattern = pattern != nil ? parseURLPattern(url: pattern!) : nil
  }
  
  
  // MARK: MiddlewareObject
  
  public func handle(request  req       : IncomingMessage,
                     response res       : ServerResponse,
                     next     upperNext : @escaping Next)
  {
    guard matches(request: req)    else { return upperNext() }
    guard !self.middleware.isEmpty else { return upperNext() }
    
    final class State {
      var stack      : ArraySlice<Middleware>
      var errorStack : ArraySlice<Middleware>
      let request    : IncomingMessage
      let response   : ServerResponse
      var endNext    : Next?
      var error      : Swift.Error?
      
      init(_ stack      : ArraySlice<Middleware>,
           _ errorStack : ArraySlice<Middleware>,
           _ request    : IncomingMessage,
           _ response   : ServerResponse,
           _ endNext    : @escaping Next)
      {
        self.stack      = stack
        self.errorStack = errorStack
        self.request    = request
        self.response   = response
        self.endNext    = endNext
      }
      
      func step(_ args: Any...) {
        if args.first == "route" || args.first == "router" {
          endNext?(); endNext = nil
          return
        }
        
        if let error = (args.first as? Error) ?? self.error {
          self.error = error
          if let middleware = errorStack.popFirst() {
            middleware(error, request, response, self.step)
          }
          else {
            endNext?(error); endNext = nil
          }
          return
        }
        
        if let middleware = stack.popFirst() {
          middleware(request, response, self.step)
        }
        else {
          assert(error == nil)
          endNext?(); endNext = nil
        }
      }
    }
    
    // push route state
    let oldParams = req.params
    let oldRoute  = req.route
    req.params = extractPatternVariables(request: req)
    req.route  = self
    
    let state = State(middleware[...], errorMiddleware[...],
                      req, res)
    {
      // restore route state (only if none matched, i.e. did not call next)
      req.params = oldParams
      req.route  = oldRoute
      if let arg = args.first { // lame 1-object spread
        upperNext(arg)
      }
      else {
        upperNext()
      }
    }
    state.step()
  }
  
  
  // MARK: - Matching
  
  func matches(request req: IncomingMessage) -> Bool {
    
    // match methods
    
    if let methods = self.methods {
      let reqMethod = HTTPMethod(string: req.method)!
      guard methods.contains(reqMethod) else { return false }
    }
    
    // match URLs
    
    if var pattern = urlPattern {
      // TODO: consider mounting!
      
      let escapedPathComponents = split(urlPath: req.url)
      if debugMatcher {
        print("MATCH: \(req.url)\n  components: \(escapedPathComponents)\n" +
              "  against: \(pattern)")
      }
      
      // this is to support matching "/" against the "/*" ("", "*") pattern
      if escapedPathComponents.count + 1 == pattern.count {
        if case .Wildcard = pattern.last! {
          let endIdx = pattern.count - 1
          pattern = Array<Pattern>(pattern[0..<endIdx])
        }
      }
      
      guard escapedPathComponents.count >= pattern.count else { return false }
      
      var lastWasWildcard = false
      for i in pattern.indices {
        let patternComponent = pattern[i]
        let matchComponent   = escapedPathComponents[i]
        
        guard patternComponent.match(string: matchComponent) else {
          return false
        }
        
        if debugMatcher {
          print("  MATCHED[\(i)]: \(patternComponent) \(matchComponent)")
        }
        
        // Special case, last component is a wildcard. Like /* or /todos/*. In
        // this case we ignore extra URL path stuff.
        if case .Wildcard = patternComponent {
          let isLast = i + 1 == pattern.count
          if isLast { lastWasWildcard = true }
        }
      }
      
      if escapedPathComponents.count > pattern.count {
        if !lastWasWildcard { return false }
      }
    }
    
    return true
  }
  
  private func split(urlPath s: String) -> [ String ] {
    var url  = URL()
    url.path = s
    return url.escapedPathComponents!
  }
  
  func extractPatternVariables(request rq: IncomingMessage)
       -> [ String : String ]
  {
    guard let pat = urlPattern else { return [:] }
    
    // TODO: consider mounting!
    let matchPrefix = rq.url
    
    var url = URL()
    url.path = matchPrefix
    let matchComponents = url.escapedPathComponents!
    
    var vars = [ String : String ]()
    
    for i in pat.indices {
      guard i < matchComponents.count else { break }
      
      let patternComponent = pat[i]
      let matchComponent   = matchComponents[i]
      
      switch patternComponent {
        case .Variable(let s): vars[s] = matchComponent
        default:               continue
      }
    }
    
    return vars
  }
  
}

func parseURLPattern(url s: String) -> [ Route.Pattern ]? {
  if s == "*" { return nil } // match-all
  
  var url = URL()
  url.path = s
  let comps = url.escapedPathComponents!
  
  var isFirst = false
  
  var pattern : [ Route.Pattern ] = []
  for c in comps {
    if isFirst {
      isFirst = false
      if c == "" { // root
        pattern.append(.Root)
        continue
      }
    }
    
    if c == "*" {
      pattern.append(.Wildcard)
      continue
    }
    
    if c.hasPrefix(":") {
      let vIdx = c.index(after: c.startIndex)
      pattern.append(.Variable(String(c[vIdx..<c.endIndex])))
      continue
    }
    
    if c.hasPrefix("*") {
      let vIdx = c.index(after: c.startIndex)
      let characters = c
      if c == "**" {
        pattern.append(.Wildcard)
      }
      else if c.hasSuffix("*") && characters.count > 1 {
        let eIdx = c.index(before: c.endIndex)
        pattern.append(.Contains(String(c[vIdx..<eIdx])))
      }
      else {
        pattern.append(.Prefix(String(c[vIdx..<c.endIndex])))
      }
      continue
    }
    if c.hasSuffix("*") {
      let eIdx = c.index(before: c.endIndex)
      pattern.append(.Suffix(String(c[c.startIndex..<eIdx])))
      continue
    }

    pattern.append(.Text(c))
  }
  
  return pattern
}

private let routeKey = "macro.express.route"

public extension IncomingMessage {
  
  var route : Route? {
    set { extra[routeKey] = newValue }
    get { return extra[routeKey] as? Route }
  }
  
}
