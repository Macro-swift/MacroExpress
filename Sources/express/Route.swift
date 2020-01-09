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

  let urlPattern      : [ RoutePattern ]?
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
      
    if debug {
      if isEmpty {
        console.log("\(logPrefix) setup route w/o middleware: \(self)")
      }
      else {
        console.log("\(logPrefix) setup route: \(self)")
      }
    }
  }
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
  
  public func add(route: Route) {
    self.middleware.append(route.middleware)
  }

  // MARK: MiddlewareObject
  
  public func handle(request  req       : IncomingMessage,
                     response res       : ServerResponse,
                     next     upperNext : @escaping Next)
  {
    let ids = debug ? logPrefix : ""
    if debug { console.log("\(ids) > enter route:", self) }
    
    if let methods = self.methods, !methods.isEmpty {
      guard case .request(let head) = req.head,
            methods.contains(head.method) else {
        if debug {
          console.log("\(ids) route method does not match, next:", self)
        }
        return upperNext()
      }
    }

    // FIXME: Could also be a full URL! (CONNECT)
    let reqPath = req.url.isEmpty ? "/" : req.url
    
    let params    : [ String : String ]
    let matchPath : String?
    if let pattern = urlPattern {
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

    // TBD: error middleware?
    guard !self.middleware.isEmpty else { return upperNext() }
    
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
      
      var stack      : ArraySlice<Middleware>
      var errorStack : ArraySlice<ErrorMiddleware>
      let request    : IncomingMessage
      let response   : ServerResponse
      var endNext    : Next?
      var error      : Swift.Error?
      
      init(_ stack      : ArraySlice<Middleware>,
           _ errorStack : ArraySlice<ErrorMiddleware>,
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
        if let s = args.first as? String, s == "route" || s == "router" {
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

    let state = MiddlewareWalker(middleware[...], errorMiddleware[...],
                                 req, res)
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
  
}

extension Route: CustomStringConvertible {
  
  // MARK: - Description
  
  private var logPrefix : String {
    let logPrefixPad = 20
    let id = self.id ?? ObjectIdentifier(self).debugDescription
    let p  = id
    let ids = p.count < logPrefixPad
      ? p + String(repeating: " ", count: logPrefixPad - p.count)
      : p
    return "[\(ids)]:"
  }
  
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
