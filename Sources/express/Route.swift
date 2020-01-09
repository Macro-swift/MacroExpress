//
//  Route.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum      NIOHTTP1.HTTPMethod
import enum      MacroCore.console
import class     http.IncomingMessage
import class     http.ServerResponse
import typealias connect.Next
import struct    Foundation.URL

private let patternMarker : UInt8 = 58 // ':'
private let debugMatcher  = false
private let debug         = false

public typealias ErrorMiddleware =
                   ( Swift.Error,
                     IncomingMessage, ServerResponse, @escaping Next ) -> Void

/**
 * A Route is a middleware which wraps another middleware and guards it by a
 * condition. For example:
 *
 *     app.get("/index") { req, res, next in ... }
 *
 * This creates a Route wrapping the closure given. It only runs the
 * embedded closure if:
 * - the method of the request is 'GET'
 * - the request path is equal to "/index"
 * In all other cases it immediately calls the `next` handler.
 *
 * ## Path Patterns
 *
 * The Route accepts a pattern for the path:
 * - the "*" string is considered a match-all.
 * - otherwise the string is split into path components (on '/')
 * - if it starts with a "/", the pattern will start with a Root symbol
 * - "*" (like in `/users/ * / view`) matches any component (spaces added)
 * - if the component starts with `:`, it is considered a variable.
 *   Example: `/users/:id/view`
 * - "text*", "*text*", "*text" creates hasPrefix/hasSuffix/contains patterns
 * - otherwise the text is matched AS IS
 *
 * Variables can be extracted using:
 *
 *     req.params[int: "id"]
 *
 * and companions.
 */
open class Route: MiddlewareObject, RouteKeeper {
  
  public var middleware      : ContiguousArray<Middleware>
  public var errorMiddleware : ContiguousArray<ErrorMiddleware>
  
  var id             : String?
  let methods        : ContiguousArray<HTTPMethod>?

  @inlinable
  public var isEmpty : Bool {
    return middleware.isEmpty && errorMiddleware.isEmpty
  }
  @inlinable
  public var count   : Int  { return middleware.count + errorMiddleware.count }

  let urlPattern      : [ RoutePattern ]?
    // FIXME: all this works a little different in Express.js. Exact matches,
    //        non-path-component matches, regex support etc.
  
  init(id              : String? = nil,
       pattern         : String?,
       method          : HTTPMethod?,
       middleware      : ContiguousArray<Middleware>,
       errorMiddleware : ContiguousArray<ErrorMiddleware> = [])
  {
    self.id = id
    
    if let m = method { self.methods = [ m ] }
    else { self.methods = nil }
    
    self.middleware      = middleware
    self.errorMiddleware = errorMiddleware

    self.urlPattern = pattern != nil ? RoutePattern.parse(pattern!) : nil
      
    if debug {
      if isEmpty {
        console.log("\(logPrefix) setup route w/o middleware: \(self)")
      }
      else {
        console.log("\(logPrefix) setup route: \(self)")
      }
    }
  }
  
  public func add(route: Route) {
    self.middleware.append(route.middleware)
  }

  // MARK: MiddlewareObject
  
  public func handle(request  req       : IncomingMessage,
                     response res       : ServerResponse,
                     next     upperNext : @escaping Next)
  {
    // FIXME: this needs to be adjusted for the ExExpress variant
    guard matches(request: req)    else { return upperNext() }
    guard !self.middleware.isEmpty else { return upperNext() }
    
    // push route state
    let oldParams = req.params
    let oldRoute  = req.route
    req.params = extractPatternVariables(request: req)
    req.route  = self
    
    let state = MiddlewareWalker(middleware[...], errorMiddleware[...],
                                 req, res)
    { args in
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
      guard case .request(let head) = req.head else { return false }
      guard methods.contains(head.method) else { return false }
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
        if case .wildcard = pattern.last! {
          let endIdx = pattern.count - 1
          pattern = Array<RoutePattern>(pattern[0..<endIdx])
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
        if case .wildcard = patternComponent {
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
  
  private func split(urlPath: String) -> [ String ] {
    guard !urlPath.isEmpty else { return [] }
    
    let isAbsolute = urlPath.hasPrefix("/")
    let pathComps  = urlPath.split(separator: "/",
                                   omittingEmptySubsequences: false)
                            .map(String.init)
    /* Note: we cannot just return a leading slash for absolute pathes as we
     *       wouldn't be able to distinguish between an absolute path and a
     *       relative path starting with an escaped slash.
     *   So: Absolute pathes instead start with an empty string.
     */
    var gotAbsolute = isAbsolute ? false : true
    return pathComps.filter {
      if $0 != "" || !gotAbsolute {
        if !gotAbsolute { gotAbsolute = true }
        return true
      }
      else {
        return false
      }
    }
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
        case .variable(let s): vars[s] = matchComponent
        default:               continue
      }
    }
    
    return vars
  }
  
}

extension Route: CustomStringConvertible {
  
  // MARK: - Description
  
  private var logPrefix : String = {
    let logPrefixPad = 20
    let id = self.id ?? ObjectIdentifier(self).debugDescription
    let p  = id
    let ids = p.count < logPrefixPad
      ? p + String(repeating: " ", count: logPrefixPad - p.count)
      : p
    return "[\(ids)]:"
  }()
  
  public var description : String {
    var ms = "<Route:"
    
    if let id = id {
      ms += " [\(id)]"
    }
    
    var hadLimit = false
    if let methods = methods, !methods.isEmpty {
      ms += " "
      ms += methods.map({ $0.rawValue }).joined(separator: ",")
      hadLimit = true
    }
    if let pattern = urlPattern {
      ms += " "
      ms += pattern.map({$0.description}).joined(separator: "/")
      hadLimit = true
    }
    if !hadLimit { ms += " *" }
    
    if isEmpty {
      ms += " NO-middleware"
    }
    else if count > 1 {
      ms += " #middleware=\(middleware.count)"
    }
    else {
      ms += " 1-middleware"
    }
    
    ms += ">"
    return ms
  }
}

private let routeKey = "macro.express.route"

public extension IncomingMessage {
  
  var route : Route? {
    set { extra[routeKey] = newValue }
    get { return extra[routeKey] as? Route }
  }
}
