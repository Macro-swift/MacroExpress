//
//  RouteKeeper.swift
//  Noze.io / ExExpress / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//

import typealias connect.Middleware

/**
 * An object which keeps routes.
 *
 * The `Express` object itself is a route keeper, and so are the `Router`
 * object, and even a `Route` itself.
 *
 * The primary purpose of this protocol is to decouple all the convenience
 * `use`, `get` etc functions from the actual functionality: `add(route:)`.
 */
public protocol RouteKeeper: AnyObject {
  
  func add(route e: Route)
  
}

// MARK: - Route Method

public extension RouteKeeper {
  
  /**
   * Returns a route to gate on a path. Since a `Route` itself is a RouteKeeper,
   * you can then hookup additional routes.
   *
   * Attached routes are mounted, i.e. their path is relative to the parent
   * route.
   *
   * Examples:
   *
   *     app.route("/cows")
   *       .get  { req, res, next ... }
   *       .post { req, res, next ... }
   *
   *     app.route("/admin"
   *       .get("/view") { .. }   // does match `/admin/view`, not `/view`
   *
   * One can also mount using a separate `Express` instance.
   */
  @inlinable
  func route(id: String? = nil, _ path: String) -> Route {
    let route = Route(id: id, pattern: path)
    add(route: route)
    return route
  }
}


// MARK: - Add Middleware
  
// TBD: all the duplication below looks a little stupid, is there a better way
//      w/o resorting to Any? Also we can only take uniform lists of middleware
//      (e.g. not mix & match regular and error mw)

public extension RouteKeeper {
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ cb: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: nil, middleware: cb))
    return self
  }
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil, middleware: cb))
    return self
  }
  
  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil, middleware: cb))
    return self
  }
  
  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .GET, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .POST, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PUT, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String, _ cb: Middleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH, middleware: cb))
    return self
  }

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ cb: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .GET, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ cb: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .POST, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ cb: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .HEAD, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ cb: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PUT, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ cb: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .DELETE, middleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ cb: Middleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PATCH, middleware: cb))
    return self
  }
}


public extension RouteKeeper { // Error Middleware Versions
    
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ cb: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: nil, errorMiddleware: cb))
    return self
  }
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     errorMiddleware: cb))
    return self
  }
  
  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: nil,
                     errorMiddleware: cb))
    return self
  }
  
  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .GET,
                     errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .POST,
                     errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD,
                     errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .PUT,
                     errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self
  {
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE,
                     errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String, _ cb: ErrorMiddleware...)
       -> Self {
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH,
                     errorMiddleware: cb))
    return self
  }

  @discardableResult
  @inlinable
  func get(id: String? = nil, _ cb: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .GET, errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ cb: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .POST, errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ cb: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .HEAD, errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ cb: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PUT, errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ cb: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .DELETE,
                     errorMiddleware: cb))
    return self
  }
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ cb: ErrorMiddleware...) -> Self {
    add(route: Route(id: id, pattern: nil, method: .PATCH, errorMiddleware: cb))
    return self
  }
}

@usableFromInline
internal func mountIfPossible(pattern  : String,
                              parent   : RouteKeeper,
                              children : [ MiddlewareObject ])
{
  guard let parent = parent as? Express else { return }

  for child in children {
    guard let child = child as? MountableMiddlewareObject else { continue }
    child.mount(at: pattern, parent: parent)
  }
}

public extension RouteKeeper {
  // Directly attach MiddlewareObject's as Middleware. That is:
  //   let app   = express()
  //   let admin = express()
  //   app.use("/admin", admin)
  // TBD: should we have a Route which keeps the object? Has various advantages,
  //      particularily during debugging.
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ mw: MiddlewareObject...) -> Self {
    add(route: Route(id: id, pattern: nil, method: nil, middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func use(id: String? = nil, _ pathPattern: String, _ mw: MiddlewareObject...)
       -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: nil, middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func all(id: String? = nil, _ pathPattern: String, _ mw: MiddlewareObject...)
       -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: nil, middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func get(id: String? = nil, _ pathPattern: String, _ mw: MiddlewareObject...)
       -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: .GET,
                     middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func post(id: String? = nil, _ pathPattern: String, _ mw: MiddlewareObject...)
       -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: .POST,
                     middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func head(id: String? = nil, _ pathPattern: String, _ mw: MiddlewareObject...)
       -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: .HEAD,
                     middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func put(id: String? = nil, _ pathPattern: String, _ mw: MiddlewareObject...)
       -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: .PUT,
                     middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func del(id: String? = nil, _ pathPattern: String, _ mw: MiddlewareObject...)
       -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: .DELETE,
                     middleware: mw))
    return self
  }
  
  @discardableResult
  @inlinable
  func patch(id: String? = nil, _ pathPattern: String,
             _ mw: MiddlewareObject...) -> Self
  {
    mountIfPossible(pattern: pathPattern, parent: self, children: mw)
    add(route: Route(id: id, pattern: pathPattern, method: .PATCH,
                     middleware: mw))
    return self
  }
}
