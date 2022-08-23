//
//  Express.swift
//  Noze.io / ExExpress / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2022 ZeeZide GmbH. All rights reserved.
//

import struct   Logging.Logger
import enum     MacroCore.process
import enum     MacroCore.EventListenerSet
import protocol MacroCore.EnvironmentKey
import class    http.IncomingMessage
import class    http.ServerResponse

/**
 * # The Express application object
 *
 * An instance of this object represents an Express application. An Express
 * application is essentially as set of routes, configuration, and templates.
 * Applications are 'mountable' and can be added to other applications.
 *
 * In ApacheExpress you need to use the `ApacheExpress` subclass as the main
 * entry point, but you can still hook up other Express applications as
 * subapplications (e.g. mount an admin frontend under the `/admin` path).
 *
 * To get access to the active application object, use the `app` property of
 * either `IncomingMessage` or `ServerResponse`.
 *
 *
 * ## Routes
 *
 * An Express object wraps a Router and has itself all the methods attached to
 * a `RouteKeeper`. That is, you case use `get`, `post`, etc methods to setup
 * routes of the application.
 * Example:
 *
 *     let app = Express()
 *     app.use("/index") {
 *       req, res, _ in res.render("index")
 *     }
 *
 *
 * ## Template Engines
 *
 * Express objects have a mapping of file extensions to 'template engines'. Own
 * engines can be added by calling the `engine` function:
 *
 *     engine("mustache", mustacheExpress)
 *
 * The would call the `mustacheExpress` template engine when templates with the
 * `.mustache` extensions need to be rendered.
 *
 *
 * ## SettingsHolder
 *
 * TODO: document
 *
 *
 * ## Mounted applications
 *
 * Express applications can be organized into 'sub applications' which can be
 * mounted into parent applications.
 *
 * For example to mount an admin frontend into your main application, the code
 * would look like:
 *
 *     let app = express()
 *     app.use("/admin", AdminExpress.admin())
 *
 * Where `admin` returns another Express instance representing the admin
 * application.
 * The neat thing is that the routes used within the admin application are then
 * relative to "/admin", e.g. "/admin/index" for a route targetting "/index".
 *
 */
open class Express: SettingsHolder, MountableMiddlewareObject, MiddlewareObject,
                    RouteKeeper
{
  public let log : Logger

  /// The path of the sourcefile which called `express()`
  let invokingSourceFilePath : StaticString
  let router                 : Router
  var settingsStore          = [ String : Any ]()
  
  public init(id  : String? = nil, mount: String? = nil,
              log : Logger = .init(label: "μ.express.app"),
              invokingSourceFilePath: StaticString = #file)
  {
    // TODO: might need #filePath in Swift 5.4
    
    self.invokingSourceFilePath = invokingSourceFilePath
    self.log                    = log
    self.router                 = Router(id: id, pattern: mount)
    settingsStore.reserveCapacity(16)
    
    let me = mustacheExpress
    engine("mustache", me)
    engine("html",     me)
    
    // defaults
    set("view engine", "mustache")
    
    if let env = process.env["EXPRESS_ENV"], !env.isEmpty {
      set("env", env)
    }
  }
  
  // MARK: - MiddlewareObject
  
  public func handle(request  req : IncomingMessage,
                     response res : ServerResponse,
                     next         : @escaping Next) throws
  {
    let oldApp = req.app
    let oldReq = res.request
    req.environment[ExpressExtKey.App.self]        = self
    res.environment[ExpressExtKey.App.self]        = self
    res.environment[ExpressExtKey.RequestKey.self] = req
    
    if settings.xPoweredBy, req.getHeader("X-Powered-By") == nil {
      res.setHeader("X-Powered-By", productIdentifier)
    }
    
    try router.handle(request: req, response: res) { ( args: Any... ) in
      req.environment[ExpressExtKey.App.self]        = oldApp
      res.environment[ExpressExtKey.App.self]        = oldApp
      res.environment[ExpressExtKey.RequestKey.self] = oldReq

      next() // continue
    }
  }
  open func clearAttachedState(request  req : IncomingMessage,
                               response res : ServerResponse)
  { // break cycles
    req.environment[ExpressExtKey.App.self]        = nil
    res.environment[ExpressExtKey.App.self]        = nil
    res.environment[ExpressExtKey.RequestKey.self] = nil
  }
  

  // MARK: - Route Keeper
  
  public func add(route e: Route) {
    router.add(route: e)
  }
  
  
  // MARK: - SettingsHolder
  
  public func set(_ key: String, _ value: Any?) {
    if let v = value { settingsStore[key] = v }
    else             { settingsStore.removeValue(forKey: key) }
  }
  public func get(_ key: String) -> Any? {
    return settingsStore[key]
  }
  
  // MARK: - Engines
  
  var engines = [ String : ExpressEngine]()
  
  public func engine(_ key: String, _ engine: @escaping ExpressEngine) {
    engines[key] = engine
  }

  
  // MARK: - Mounting
  
  final var mountListeners = EventListenerSet<Express>()
  
  /// Note: The argument is the parent application
  @discardableResult
  public func onMount(execute: @escaping ( Express ) -> Void) -> Self {
    mountListeners.add(execute)
    return self
  }

  /// One or more path patterns on which this instance was mounted as a sub
  /// application.
  open var mountPath : [ String ]?
  
  public func mount(at: String, parent: Express) {
    if mountPath == nil {  mountPath = [ at ] }
    else { mountPath!.append(at) }
    mountListeners.emit(parent)
  }
  

  // MARK: - Extension Point for Subclasses
  
  open func viewDirectory(for engine: String, response: ServerResponse)
            -> String
  {
    // Maybe that should be an array
    // This should allow 'views' as a relative path.
    // Also, in Apache it should be a configuration directive.
    let viewsPath = (get("views") as? String)
                 ?? process.env["EXPRESS_VIEWS"]
             //  ?? apacheRequest.pathRelativeToServerRoot(filename: "views")
                 ?? process.cwd()
    return viewsPath
  }

  /// The identifier used in the x-powered-by header
  open var productIdentifier : String {
    return "MacroExpress"
  }
}

extension Express: CustomStringConvertible {
  
  public var description : String {
    var ms = "<\(type(of: self)):"
    
    if router.isEmpty         { ms += " no-routes"               }
    else if router.count == 1 { ms += " route"                   }
    else                      { ms += " #routes=\(router.count)" }
    
    if let mountPath = mountPath, !mountPath.isEmpty {
      if mountPath.count == 1 {
        ms += " mounted=\(mountPath[0])"
      }
      else {
        ms += " mounted=[\(mountPath.joined(separator: ","))]"
      }
    }
    
    if !engines.isEmpty {
      ms += " engines="
      ms += engines.keys.joined(separator: ",")
    }
    
    if !settingsStore.isEmpty {
      for ( key, value ) in settingsStore { ms += " '\(key)'='\(value)'" }
    }
    
    ms += ">"
    return ms
  }

}

public typealias ExpressEngine = (
                   _ path:    String,
                   _ options: Any?,
                   _ done:    @escaping ( Any?... ) -> Void
                 ) -> Void


// keys for extra dictionary in IncomingRequest/ServerResponse

enum ExpressExtKey {

  /// A reference to the active application. Updated when subapps are triggered.
  enum App: EnvironmentKey {
    static let defaultValue : Express? = nil
    static let loggingKey   = "app"
  }
  
  /// A reference to the request associated with a response.
  enum RequestKey: EnvironmentKey {
    static let defaultValue : IncomingMessage? = nil
    static let loggingKey   = "request"
  }
  
  /// The active route.
  enum RouteKey: EnvironmentKey {
    static let defaultValue : Route? = nil
    static let loggingKey   = "route"
  }
  
  enum BaseURL: EnvironmentKey {
    static let defaultValue : String? = nil
    static let loggingKey   = "baseurl"
  }

  /**
   * Request parameters.
   *
   * Example:
   *
   *     app.use(/users/:id/view) { req, res, next in
   *       guard let id = req.params[int: "id"]
   *        else { return try res.sendStatus(400) }
   *     }
   *
   */
  enum Params: EnvironmentKey {
    // TBD: Should the value be `Any`?
    static let defaultValue : [ String : String ] = [:]
    static let loggingKey   = "params"
  }
  
  /**
   * The query parameters as parsed by the `qs.parse` function.
   */
  enum Query: EnvironmentKey {
    static let defaultValue : [ String : Any ]? = nil
    static let loggingKey   = "query"
  }

  /**
   * This is legacy, an app can also just use `EnvironmentKey`s with either
   * `IncomingMessage` or `ServerResponse`.
   * `EnvironmentKey`s are guaranteed to be unique.
   *
   * Traditionally `locals` was used to store Stringly-typed keys & values.
   */
  enum Locals: EnvironmentKey {
    static let defaultValue : [ String : Any ] = [:]
    static let loggingKey   = "locals"
  }
}

// MARK: - App access helper

public extension Dictionary where Key : ExpressibleByStringLiteral {
  subscript(int key : Key) -> Int? {
    guard let v = self[key] else { return nil }
    if let i = (v as? Int) { return i }
    return Int("\(v)")
  }
}


// MARK: - Wrap Server

import class http.Server
import func  http.createServer

public extension Express {
  
  /**
   * Create an HTTP server (using http.server) with the `Express` instance
   * as the handler, and then start listening.
   *
   * - Parameters:
   *   - port        : The port the server should listen on.
   *   - host        : The host to bind the socket to,
   *                   defaults to wildcard IPv4 (0.0.0.0).
   *   - backlog     : The amount of socket backlog space (defaults to 512).
   *   - onListening : An optional closure to run when the server started
   *                   listening.
   */
  @inlinable
  @discardableResult
  func listen(_ port: Int? = nil, _ host: String = "0.0.0.0",
              backlog: Int = 512,
              onListening execute: (( http.Server ) -> Void)? = nil) -> Self
  {
    let server = http.createServer(handler: requestHandler)
    _ = server.listen(port, host, backlog: backlog, onListening: execute)
    return self
  }
  
  /**
   * Create an HTTP server (using http.server) with the `Express` instance
   * as the handler, and then start listening.
   *
   * - Parameters:
   *   - port        : The port the server should listen on.
   *   - host        : The host to bind the socket to,
   *                   defaults to wildcard IPv4 (0.0.0.0).
   *   - backlog     : The amount of socket backlog space (defaults to 512).
   *   - onListening : An optional closure to run when the server started
   *                   listening.
   */
  @inlinable
  @discardableResult
  func listen(_ port: Int?, _ host: String = "0.0.0.0", backlog: Int = 512,
              onListening execute: @escaping () -> Void) -> Self
  {
    return listen(port, host, backlog: backlog) { _ in execute() }
  }
}
