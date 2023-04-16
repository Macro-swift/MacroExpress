//
//  RouteMounts.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 2023-04-16.
//  Copyright © 2016-2023 ZeeZide GmbH. All rights reserved.
//

import NIOHTTP1

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
