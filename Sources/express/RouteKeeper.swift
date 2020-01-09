//
//  RouteKeeper.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import typealias connect.Middleware

/**
 * A `RouteKeeper` is an object which carries a set of `Route`s. The `Express` application
 * class is an example.
 */
public protocol RouteKeeper {
  
  func add(route e: Route)
  
}

// MARK: - Add Middleware
  
public extension RouteKeeper {
  
  @discardableResult
  @inlinable
  func use(_ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: nil, method: nil, middleware: [cb]))
    return self
  }
  
  @discardableResult
  @inlinable
  func use(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: nil, middleware: [cb]))
    return self
  }
  
  @discardableResult
  @inlinable
  func all(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: nil, middleware: [cb]))
    return self
  }
  
  @discardableResult
  @inlinable
  func get(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: .GET, middleware: [cb]))
    return self
  }
  @discardableResult
  @inlinable
  func post(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: .POST, middleware: [cb]))
    return self
  }
  @discardableResult
  @inlinable
  func head(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: .HEAD, middleware: [cb]))
    return self
  }
  @discardableResult
  @inlinable
  func put(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: .PUT, middleware: [cb]))
    return self
  }
  @discardableResult
  @inlinable
  func del(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: .DELETE, middleware: [cb]))
    return self
  }
  @discardableResult
  @inlinable
  func patch(_ p: String, _ cb: @escaping Middleware) -> Self {
    add(route: Route(pattern: p, method: .PATCH, middleware: [cb]))
    return self
  }
}

public extension RouteKeeper {
  // Directly attach MiddlewareObject's as Middleware. That is:
  //   let app   = express()
  //   let admin = express()
  //   app.use("/admin", admin)
  
  @discardableResult
  @inlinable
  func use(_ middleware: MiddlewareObject) -> Self {
    return use(middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func use(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return use(p, middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func all(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return all(p, middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func get(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return get(p, middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func post(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return post(p, middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func head(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return head(p, middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func put(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return put(p, middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func del(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return del(p, middleware.middleware)
  }
  
  @discardableResult
  @inlinable
  func patch(_ p: String, _ middleware: MiddlewareObject) -> Self {
    return patch(p, middleware.middleware)
  }
}
