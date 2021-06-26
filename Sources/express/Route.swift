//
//  Route.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum      NIOHTTP1.HTTPMethod
import let       MacroCore.console
import enum      MacroCore.process
import class     http.IncomingMessage
import class     http.ServerResponse
import typealias connect.Next
import struct    Foundation.URL

private let patternMarker : UInt8 = 58 // ':'

private let debug        = process.getenvflag("macro.router.debug")
private let debugMatcher = process.getenvflag("macro.router.matcher.debug")
private let debugWalker  = process.getenvflag("macro.router.walker.debug")

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
open class Route: MiddlewareObject, ErrorMiddlewareObject, RouteKeeper,
                  CustomStringConvertible
{
  
  public var middleware      : [ Middleware ]
  public var errorMiddleware : [ ErrorMiddleware ]
  
  var id             : String?
  let methods        : ContiguousArray<HTTPMethod>?

  @inlinable
  public var isEmpty : Bool {
    return middleware.isEmpty && errorMiddleware.isEmpty
  }
  @inlinable
  public var count   : Int  { return middleware.count + errorMiddleware.count }

  let urlPattern     : [ RoutePattern ]?
    // FIXME: all this works a little different in Express.js. Exact matches,
    //        non-path-component matches, regex support etc.
  
  public init(id              : String?             = nil,
              pattern         : String?             = nil,
              method          : HTTPMethod?         = nil,
              middleware      : [ Middleware      ] = [],
              errorMiddleware : [ ErrorMiddleware ] = [])
  {
    self.id = id
    
    if let m = method { self.methods = [ m ] }
    else { self.methods = nil }
    
    self.middleware      = middleware
    self.errorMiddleware = errorMiddleware

    self.urlPattern = pattern != nil ? RoutePattern.parse(pattern!) : nil
      
    if debug { // isEmpty is true when the router is initially setup by express
      console.log(logPrefix,
                  isEmpty ? "setup route w/o middleware:" : "setup route:",
                  descriptionContent)
    }
  }
  
  @inlinable
  public convenience init(id              : String?             = nil,
                          pattern         : String?             = nil,
                          method          : HTTPMethod?         = nil,
                          middleware      : [ MiddlewareObject ])
  {
    // In ExExpress we use an enum to hold the different variants, which might
    // be a little more efficient
    self.init(id: id, pattern: pattern, method: method,
              middleware: middleware.map { $0.middleware })
  }
  
  @inlinable
  public func add(route: Route) {
    // Note: We cannot skip empty routes (or append the contents), because
    //       Route's are objects and can be filled later.
    self.middleware     .append(route.middleware)
    self.errorMiddleware.append(route.errorMiddleware)
  }

  // MARK: - MiddlewareObject
  
  @inlinable
  public func handle(request  : IncomingMessage,
                     response : ServerResponse,
                     next     : @escaping Next) throws
  {
    try handle(request: request, response: response, error: nil, next: next)
  }

  @inlinable
  public func handle(error    : Swift.Error,
                     request  : IncomingMessage,
                     response : ServerResponse,
                     next     : @escaping Next) throws
  {
    try handle(request: request, response: response, error: error, next: next)
  }

  
  // MARK: - Mounted Routing
  
  @usableFromInline
  internal func handle(request    req : IncomingMessage,
                       response   res : ServerResponse,
                       error          : Swift.Error?,
                       next upperNext : @escaping Next) throws
  {
    let ids = debug ? logPrefix : ""
    if debug { console.log("\(ids) > enter route:", self) }
    
    if let methods = self.methods, !methods.isEmpty {
      guard case .request(let head) = req.head,
            methods.contains(head.method) else {
        if debug {
          console.log("\(ids) route method does not match, next:", self)
        }
        if let error = error { throw error }
        return upperNext()
      }
    }

    // FIXME: Could also be a full URL! (CONNECT)
    let reqPath = req.url.isEmpty ? "/" : {
      // Strip of query parameters and such. This is the raw URL,
      // but we need to match just the path.
      let s = req.url
      if let idx = s.firstIndex(where: { $0 == "#" || $0 == "?" }) {
        return String(s[..<idx])
      }
      else {
        return s
      }
    }()
    
    let params    : [ String : String ]
    let matchPath : String?
    if let pattern = urlPattern { // this route has a path pattern assigned
      var newParams = req.params // TBD
      
      if let base = req.baseURL {
        let mountPath = String(reqPath[base.endIndex..<reqPath.endIndex])
        let comps     = split(urlPath: mountPath)

        let mountMatchPath = RoutePattern.match(pattern   : pattern,
                                                against   : comps,
                                                variables : &newParams)
        guard let match = mountMatchPath else {
          if debug {
            console.log("\(ids) mount route path does not match, next:", self)
          }
          if let error = error { throw error }
          return upperNext()
        }
        
        matchPath = base + match
      }
      else {
        let comps = split(urlPath: reqPath)
        
        guard let mp = RoutePattern.match(pattern   : pattern,
                                          against   : comps,
                                          variables : &newParams)
         else {
          if debug {
            console.log("\(ids) route path does not match, next:",
              self)
          }
          if let error = error { throw error }
          return upperNext()
         }
        matchPath = mp
      }
      
      if debug { console.log("\(ids)     path match:", matchPath) }
      
      params = newParams
    }
    else {
      matchPath = nil
      params    = req.params
    }

    if let error = error {
      guard !self.errorMiddleware.isEmpty else { throw error }
    }
    else {
      guard !self.middleware     .isEmpty else { return upperNext() }
    }
    
    // push route state
    let oldParams = req.params
    let oldRoute  = req.route
    let oldBase   = req.baseURL
    req.params  = params
    req.route   = self
    if let mp = matchPath {
      req.baseURL = mp
      if debug { console.log("\(ids)   push baseURL:", req.baseURL) }
    }

    final class MiddlewareWalker {
      
      let ids        : String
      var stack      : ArraySlice<Middleware>
      var errorStack : ArraySlice<ErrorMiddleware>
      let request    : IncomingMessage
      let response   : ServerResponse
      var endNext    : Next?
      var error      : Swift.Error?
      
      init(_ ids        : String,
           _ stack      : ArraySlice<Middleware>,
           _ errorStack : ArraySlice<ErrorMiddleware>,
           _ request    : IncomingMessage,
           _ response   : ServerResponse,
           _ error      : Swift.Error?,
           _ endNext    : @escaping Next)
      {
        self.ids        = ids
        self.stack      = stack
        self.errorStack = errorStack
        self.request    = request
        self.response   = response
        self.error      = error
        self.endNext    = endNext
      }
      
      func step(_ args: Any...) {
        if debugWalker {
          if args.isEmpty { console.log("\(ids)   push step")        }
          else            { console.log("\(ids)   push step:", args) }
        }
        if let s = args.first as? String, s == "route" || s == "router" {
          if debugWalker { console.log("\(ids)   end-step via route:", args) }
          endNext?(); endNext = nil
          return
        }
        
        if let error = (args.first as? Swift.Error) ?? self.error {
          if debugWalker { console.log("\(ids)     step error:", error) }
          self.error = error
          
          guard let middleware = errorStack.popFirst() else {
            if debugWalker { console.log("\(ids)   end-error next:", error) }
            endNext?(error); endNext = nil
            return
          }
          
          do {
            try middleware(error, request, response, self.step)
          }
          catch {
            // the error which is thrown by the error middleware itself
            if debugWalker {
              console.log("\(ids)     step error-middleware threw:", error)
            }
            self.error = error
            self.step(error)
          }
        }
        else {
          guard let middleware = stack.popFirst() else {
            if debugWalker { console.log("\(ids)   end-step next") }
            assert(error == nil)
            endNext?(); endNext = nil
            return
          }
          
          if debugWalker { console.log("\(ids)     step middleware") }
          do {
            try middleware(request, response, self.step)
          }
          catch {
            if debugWalker {
              console.log("\(ids)     step middleware threw:", error)
            }
            self.error = error
            self.step(error)
          }
        }
      }
    }

    let state = MiddlewareWalker(ids,
                                 middleware[...], errorMiddleware[...],
                                 req, res, error)
    { ( args : Any...) in
      // restore route state (only if none matched, i.e. all called next)
      req.params  = oldParams
      req.route   = oldRoute
      req.baseURL = oldBase
      
      if let arg = args.first { // lame 1-object spread to pass on errors
        upperNext(arg)
      }
      else {
        upperNext()
      }
    }
    state.step()
  }
  
  
  // MARK: - Matching
  
  private func split(urlPath: String) -> [ String ] {
    return extractEscapedURLPathComponents(for: urlPath)
  }

  // MARK: - CustomStringConvertible
  
  private var logPrefix : String {
    let logPrefixPad = 20
    let id = self.id ?? {
      let oids = ObjectIdentifier(self).debugDescription
      // ObjectIdentifier(0x000000010388a610)
      let dropPrefix = "ObjectIdentifier(0x000000"
      guard oids.hasPrefix(dropPrefix) else { return oids }
      return "0x" + oids.dropFirst(dropPrefix.count).dropLast()
    }()
    let p  = id
    let ids = p.count < logPrefixPad
      ? p + String(repeating: " ", count: logPrefixPad - p.count)
      : p
    return "[\(ids)]:"
  }

  open var description : String {
    var ms = "<Route:"
    
    if let id = id {
      ms += " [\(id)]"
    }
    ms += " "
    ms += descriptionContent
    ms += ">"
    return ms
  }
  
  open var descriptionContent : String {
    var ms = ""
    
    var hadLimit = false
    if let methods = methods, !methods.isEmpty {
      ms += methods.map({ $0.rawValue }).joined(separator: ",")
      hadLimit = true
    }
    if let pattern = urlPattern {
      if !ms.isEmpty { ms += " " }
      if pattern.isEmpty {
        ms += "empty-pattern?"
      }
      else if pattern.first == .root {
        ms += "/"
        ms += pattern.dropFirst().map({ $0.description }).joined(separator: "/")
      }
      else {
        ms += pattern.map({ $0.description }).joined(separator: "/")
      }
      hadLimit = true
    }
    if !hadLimit { ms += "*" }
    
    if isEmpty {
      ms += " NO-middleware"
    }
    else if count > 1 {
      ms += " #middleware=\(middleware.count)"
      if !errorMiddleware.isEmpty {
        ms += "(#error=\(errorMiddleware.count))"
      }
    }
    else {
      if errorMiddleware.isEmpty { ms += " 1-middleware"       }
      else                       { ms += " 1-error-middleware" }
    }
    
    return ms
  }
}
