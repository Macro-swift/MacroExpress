//
//  Express.swift
//  Noze.io / ExExpress / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum MacroCore.process
import enum MacroCore.EventListenerSet
import http

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
 *       req, res, _ in try res.render("index")
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
 *     let app = ApacheExpress.express(cmd, name: "mods_testapexdb")
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
  
  let router        : Router
  var settingsStore = [ String : Any ]()
  
  public init(id: String? = nil, mount: String? = nil) {
    router = Router(id: id, pattern: mount)
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
                     next         : @escaping Next)
  {
    let oldApp = req.app
    let oldReq = res.request
    req.extra[ExpressExtKey.app] = self
    res.extra[ExpressExtKey.app] = self
    res.extra[ExpressExtKey.req] = req
    
    router.handle(request: req, response: res) { ( args: Any... ) in
      req.extra[ExpressExtKey.app] = oldApp
      res.extra[ExpressExtKey.app] = oldApp
      res.extra[ExpressExtKey.req] = oldReq

      next() // continue
    }
  }
  open func clearAttachedState(request  req : IncomingMessage,
                               response res : ServerResponse)
  { // break cycles
    req.extra[ExpressExtKey.app] = nil
    res.extra[ExpressExtKey.app] = nil
    res.extra[ExpressExtKey.req] = nil
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
  
  open var description : String {
    var ms = "<\(type(of: self)):"
    
    if router.isEmpty {
      ms += " no-routes"
    }
    else if router.count == 1 {
      ms += " route"
    }
    else {
      ms += " #routes=\(router.count)"
    }
    
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
      for ( key, value ) in settingsStore {
        ms += " '\(key)'='\(value)'"
      }
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
  static let app     = "macro.express.app"
  static let req     = "macro.express.request"
  static let params  = "macro.express.params"
  static let locals  = "macro.express.locals"
  static let route   = "macro.express.route"
  static let baseURL = "macro.express.baseurl"
  static let query   = "macro.express.query"
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

public extension Express {
  
  @inlinable
  @discardableResult
  func listen(_ port: Int? = nil, backlog: Int = 512,
              onListening cb : (( http.Server ) -> Void)? = nil) -> Self
  {
    let server = http.createServer(handler: requestHandler)
    _ = server.listen(port, backlog: backlog, onListening: cb)
    return self
  }
}
