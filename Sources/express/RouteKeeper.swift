//
//  RouteKeeper.swift
//  Noze.io / ExExpress / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2023 ZeeZide GmbH. All rights reserved.
//

import typealias connect.Middleware
import NIOHTTP1

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

  /**
   * Add the specified ``Route`` to the ``RouteKeeper``.
   *
   * A ``RouteKeeper`` is an object owning routes, even ``Route`` itself is
   * a ``RouteKeeper`` (and can contain "subroutes").
   *
   * This is the designated way to add routes to a keep, methods like
   * ``get(id:_:)`` or ``put(id:_:)`` all call into this primary method.
   *
   * - Parameters:
   *   - route: The ``Route`` to add.
   */
  func add(route: Route)
}


// MARK: - Route Method

public extension RouteKeeper {
  
  /**
   * Returns a route to gate on a path. Since a ``Route`` itself is a
   * ``RouteKeeper``, additional routes can be added.
   *
   * Attached routes are mounted, i.e. their path is relative to the parent
   * route.
   *
   * Examples:
   * ```
   * app.route("/cows")
   *   .get  { req, res, next ... }
   *   .post { req, res, next ... }
   *
   * app.route("/admin")
   *   .get("/view") { .. }   // does match `/admin/view`, not `/view`
   * ```
   *
   * One can also mount using a separate ``Express`` instance.
   */
  @inlinable
  func route(id: String? = nil, _ path: String) -> Route {
    let route = Route(id: id, pattern: path)
    add(route: route)
    return route
  }
}
