//
//  Route.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2026 ZeeZide GmbH. All rights reserved.
//

import Logging
import Foundation // URL
import NIOHTTP1   // HTTPMethod
import MacroCore  // process
import http       // IncomingMessage, ServerResponse
import connect

private let patternMarker : UInt8 = 58 // ':'

// TODO: use loggers for that
private let debug         = process.getenvflag("macro.router.debug")
private let debugMatcher  = process.getenvflag("macro.router.matcher.debug")
private let debugWalker   = process.getenvflag("macro.router.walker.debug")

/**
 * A ``Route`` is a middleware which wraps another middleware and guards it by a
 * condition. For example:
 * ```swift
 * app.get("/index") { req, res, next in ... }
 * ```
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
 * - the `*` string is considered a match-all.
 * - otherwise the string is split into path components (on `/`)
 * - if it starts with a `/`, the pattern will start with a Root symbol
 * - `*` (like in `/users/ * / view`) matches any component (spaces added)
 * - if the component starts with `:`, it is considered a variable.
 *   Example: `/users/:id/view`
 * - `text*`, `*text*`, `*text` creates hasPrefix/hasSuffix/contains patterns
 * - otherwise the text is matched AS IS
 *
 * Variables can be extracted using:
 * ```swift
 * app.get("/user/:id/view") { req, res in
 *   guard let id = req.params[int: "id"] else {
 *     return res.sendStatus(404) // TBD: or 400?
 *   }
 *   ...
 * }
 * ```
 *
 * and companions.
 */
open class Route: MiddlewareObject, ErrorMiddlewareObject, RouteKeeper,
                  CustomStringConvertible, @unchecked Sendable
{
  
  public var middleware      : [ Middleware ]
  public var routeObjects    : [ Route?     ] // if ^^ is a route
  public var errorMiddleware : [ ErrorMiddleware ]

  var id         : String?
  let methods    : ContiguousArray<HTTPMethod>?
  let exact      : Bool
  let urlPattern : [ RoutePattern ]?
    // FIXME: all this works a little different in Express.js. Exact matches,
    //        non-path-component matches, regex support etc.
  public let log : Logger
  
  public init(id              : String?             = nil,
              pattern         : String?             = nil,
              method          : HTTPMethod?         = nil,
              exact           : Bool?               = nil,
              middleware      : [ Middleware      ] = [],
              errorMiddleware : [ ErrorMiddleware ] = [],
              logger          : Logger? = nil)
  {
    self.log = logger ?? Logger(label: "μ.router")
    self.id  = id
    
    if let m = method { self.methods = [ m ] } else { self.methods = nil }

    // Unless the user explicitly set `exact`, we are exact if a method is
    // specified, otherwise not.
    self.exact = exact ?? (method != nil)

    self.middleware      = middleware
    self.routeObjects    = [ Route? ](repeating: nil, count: middleware.count)
    self.errorMiddleware = errorMiddleware

    self.urlPattern = pattern != nil ? RoutePattern.parse(pattern!) : nil
      
    if debug { // isEmpty is true when the router is initially setup by express
      log.log(logPrefix,
              isEmpty ? "setup route w/o middleware:" : "setup route:",
              descriptionContent)
    }
  }
  
  @inlinable
  public convenience init(id         : String?     = nil,
                          pattern    : String?     = nil,
                          method     : HTTPMethod? = nil,
                          exact      : Bool?       = nil,
                          middleware : [ MiddlewareObject ])
  {
    // In ExExpress we use an enum to hold the different variants, which might
    // be a little more efficient
    self.init(id: id, pattern: pattern, method: method, exact: exact,
              middleware: middleware.map { $0.middleware })
  }
  
  @inlinable
  public func add(route: Route) {
    // Note: We cannot skip empty routes (or append the contents), because
    //       Route's are objects and can be filled later.
    self.middleware     .append(route.middleware)
    self.routeObjects   .append(route)
    self.errorMiddleware.append(route.errorMiddleware)
  }
  
  // MARK: - State

  @inlinable
  public var isEmpty : Bool {
    return middleware.isEmpty && errorMiddleware.isEmpty
  }
  @inlinable
  public var count   : Int  { return middleware.count + errorMiddleware.count }


  // MARK: - MiddlewareObject
  
  @inlinable
  public func handle(request: IncomingMessage, response: ServerResponse,
                     next: @escaping Next) throws
  {
    try handle(request: request, response: response, error: nil, next: next)
  }

  @inlinable
  public func handle(error: Swift.Error,
                     request: IncomingMessage, response: ServerResponse,
                     next: @escaping Next) throws
  {
    try handle(request: request, response: response, error: error, next: next)
  }

  
  // MARK: - Mounted Routing

  /**
   * Match the request against this route's method and URL pattern. If it 
   * matches, dispatch to the middleware stack. If not, call `upperNext`.
   */
  @usableFromInline
  internal func handle(request: IncomingMessage, response: ServerResponse,
                       error: Swift.Error?, next upperNext : @escaping Next)
                  throws
  {
    let ids = debug ? logPrefix : ""
    if debug { log.log("\(ids) > enter route:", self) }

    if request.environment[IncomingMessage.OriginalURLKey.self] == nil {
      request.originalURL = request.url
    }

    if let methods = self.methods, !methods.isEmpty {
      guard case .request(let head) = request.head, 
            methods.contains(head.method) else 
      {
        if debug { log.log("\(ids) method mismatch, next:", self) }
        if let error = error { throw error }
        return upperNext()
      }
    }

    let reqPath   = extractRequestPath(request.url)
    let params    : IncomingMessage.Params
    let matchPath : String?
    if let pattern = urlPattern {
      var newParams = request.params
      let comps = split(urlPath: reqPath)
      
      guard let mp = RoutePattern
        .match(pattern: pattern, against: comps,
               exact: exact, variables: &newParams) else 
      {
        if debug { log.log("\(ids) path mismatch, next:", self) }
        if let error = error { throw error }
        return upperNext()
      }
      
      matchPath = mp
      params    = newParams
    }
    else {
      matchPath = nil
      params    = request.params
    }

    // -- Empty check --
    if let error = error {
      guard !self.errorMiddleware.isEmpty
      else { throw error }
    }
    else {
      guard !self.middleware.isEmpty
      else { return upperNext() }
    }

    // Matched -- hand off to dispatch (separate
    // frame, keeps this function's frame small).
    try dispatchMiddleware(request: request, response: response, error: error,
                           upperNext: upperNext, matchPath: matchPath, 
                           params: params, ids: ids)
  }

  private func extractRequestPath(_ url: String) -> String {
    if url.isEmpty { return "/" }
    if let idx = url.firstIndex(where: { $0 == "#" || $0 == "?" }) {
      return String(url[..<idx])
    }
    return url
  }

  /**
   * Push route state, create the middleware walker, and run the middleware 
   * stack.
   */
  @inline(never)
  private func dispatchMiddleware(request: IncomingMessage, 
                                  response: ServerResponse,
                                  error: Swift.Error?, upperNext: @escaping Next,
                                  matchPath: String?,
                                  params: IncomingMessage.Params, ids: String)
    throws 
  {
    // Push route state
    let oldParams = request.params
    let oldRoute  = request.route
    let oldBase   = request.baseURL
    let oldUrl    = request.url
    request.params = params
    request.route  = self
    if let mp = matchPath {
      request.baseURL = (oldBase ?? "") + mp
      if !exact {
        var newUrl = String(request.url.dropFirst(mp.count))
        if newUrl.isEmpty { newUrl = "/" }
        else if newUrl.first == "?" || newUrl.first == "#" {
          newUrl = "/" + newUrl
        }
        request.url = newUrl
      }
      if debug {
        log.log("\(ids)   baseURL:", request.baseURL, "url:", request.url)
      }
    }

    let state = MiddlewareWalker(ids, middleware[...], routeObjects[...],
                                 errorMiddleware[...], request, response, error,
                                 log)
    { ( args : Any...) in
      // pop route state
      request.params  = oldParams
      request.route   = oldRoute
      request.baseURL = oldBase
      request.url     = oldUrl
      if let arg = args.first { upperNext(arg) }
      else                    { upperNext() }
    }
    state.step()
  }
  
  
  // MARK: - Middleware Walker

  /**
   * Walks the middleware stack for a matched route.
   *
   * Calls `Route.handle()` directly for known Route entries.
   */
  final class MiddlewareWalker: @unchecked Sendable {

    let ids          : String
    var stack        : ArraySlice<Middleware>
    var routeObjects : ArraySlice<Route?>
    var errorStack   : ArraySlice<ErrorMiddleware>
    let request      : IncomingMessage
    let response     : ServerResponse
    var endNext      : Next?
    var error        : Swift.Error?
    let log          : Logger

    init(_ ids          : String,
         _ stack        : ArraySlice<Middleware>,
         _ routeObjects : ArraySlice<Route?>,
         _ errorStack   : ArraySlice<ErrorMiddleware>,
         _ request      : IncomingMessage,
         _ response     : ServerResponse,
         _ error        : Swift.Error?,
         _ log          : Logger,
         _ endNext      : @escaping Next)
    {
      self.ids          = ids
      self.stack        = stack
      self.routeObjects = routeObjects
      self.errorStack   = errorStack
      self.request      = request
      self.response     = response
      self.error        = error
      self.endNext      = endNext
      self.log          = log
    }

    /// Trampoline state: when a middleware calls
    /// `next()` synchronously while `step` is
    /// already on the call stack, we record the
    /// args and loop instead of recursing.
    var stepping     = false
    var continueArgs : [ Any ]?

    func step(_ args: Any...) {
      if stepping {
        continueArgs = args
        return
      }
      stepping = true
      defer { stepping = false }

      var curArgs = args
      trampolineLoop: while true {
        if debugWalker {
          if curArgs.isEmpty { log.log("\(ids)   step") }
          else { log.log("\(ids)   step:", curArgs) }
        }
        if let s = curArgs.first as? String, s == "route" || s == "router" {
          endNext?(); endNext = nil
          return
        }

        if let error = (curArgs.first as? Swift.Error) ?? self.error {
          self.error = error

          guard let mw = errorStack.popFirst() else {
            endNext?(error); endNext = nil
            return
          }

          continueArgs = nil
          do {
            try mw(error, request, response, self.step)
          }
          catch {
            self.error = error
            continueArgs = [ error ]
          }
        }
        else {
          // Skip child routes that won't match.
          while let entry = routeObjects.first, let route = entry,
                !route.couldMatch(request: request)
          {
            _ = stack.popFirst()
            _ = routeObjects.popFirst()
          }

          // Pop next middleware + route pair.
          guard let mw = stack.popFirst() else {
            assert(error == nil)
            endNext?(); endNext = nil
            return
          }
          let routeObj = routeObjects.popFirst() ?? nil

          continueArgs = nil

          // If entry is a known Route, call handle
          // directly -- skips ~6 closure/thunk frames
          // vs going through the opaque Middleware.
          if let route = routeObj {
            do {
              try route.handle(request: request, response: response,
                               error: self.error, next: self.step)
            }
            catch {
              self.error = error
              continueArgs = [ error ]
            }
          }
          else {
            do {
              try mw(request, response, self.step)
            }
            catch {
              self.error = error
              continueArgs = [ error ]
            }
          }
        }

        guard let nextArgs = continueArgs else { break trampolineLoop }
        continueArgs = nil
        curArgs = nextArgs
      }
    }
  }

  // MARK: - Matching

  /**
   * Quick check whether a request could match this route.
   *
   * Used by the `MiddlewareWalker` to skip non-matching
   * child routes without recursing into `handle()`,
   * avoiding stack overflow with many registered routes.
   *
   * Returns false if the route definitely won't match
   * (wrong method or pattern mismatch). Returns true if
   * it might match (caller should call `handle()`).
   */
  func couldMatch(request req: IncomingMessage) -> Bool {
    if let methods = self.methods, !methods.isEmpty {
      guard case .request(let head) = req.head, 
              methods.contains(head.method) else { return false }
    }

    if let pattern = urlPattern {
      let reqPath = req.url.isEmpty ? "/" : {
        let s = req.url
        if let idx = s.firstIndex(where: { $0 == "#" || $0 == "?" }) {
          return String(s[..<idx])
        }
        else { return s }
      }()
      let comps = split(urlPath: reqPath)
      var dummyParams = req.params
      guard RoutePattern.match(pattern: pattern, against: comps, exact: exact, 
                               variables: &dummyParams) != nil else 
      {
        return false 
      }
    }
    return true
  }

  private func split(urlPath: String) -> [ String ] {
    return extractEscapedURLPathComponents(for: urlPath)
  }

  // MARK: - CustomStringConvertible
  
  private var logPrefix : String {
    let logPrefixPad = 20
    let id = self.id ?? (
      "0x" + String(Int(bitPattern: ObjectIdentifier(self)), radix: 16)
    )
    let p  = id
    let ids = p.count < logPrefixPad
      ? p + String(repeating: " ", count: logPrefixPad - p.count)
      : p
    return "[\(ids)]:"
  }

  open var description : String {
    var ms = "<Route:"
    if let id = id { ms += " [\(id)]" }
    ms += " \(descriptionContent)>"
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
