//
//  Express.swift
//  Noze.io / MacroExpress
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import http

open class Express: SettingsHolder, MiddlewareObject, RouteKeeper {
  
  let router   = Router()
  var settings = [ String : Any ]()
  
  public init() {
    // defaults
    set   ("view engine", "mustache")
    engine("mustache", mustacheExpress)
    engine("html",     mustacheExpress)
  }
  
  // MARK: - MiddlewareObject
  
  public func handle(request  req : IncomingMessage,
                     response res : ServerResponse,
                     next     cb  : @escaping Next)
  {
    let oldApp = req.app
    let oldReq = res.request
    req.extra[appKey] = self
    res.extra[appKey] = self
    res.extra[reqKey] = req
    
    router.handle(request: req, response: res) { ( args: Any... ) in
      req.extra[appKey] = oldApp
      res.extra[appKey] = oldApp
      res.extra[reqKey] = oldReq
      
      cb() // continue
    }
  }
  
  // MARK: - Route Keeper
  
  public func add(route e: Route) {
    router.add(route: e)
  }
  
  // MARK: - SettingsHolder
  
  public func set(_ key: String, _ value: Any?) {
    if let v = value {
      settings[key] = v
    }
    else {
      settings.removeValue(forKey: key)
    }
  }
  
  public func get(_ key: String) -> Any? {
    return settings[key]
  }
  
  // MARK: - Engines
  
  var engines = [ String : ExpressEngine]()
  
  public func engine(_ key: String, _ engine: @escaping ExpressEngine) {
    engines[key] = engine
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
