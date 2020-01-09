//
//  Router.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import class     http.IncomingMessage
import class     http.ServerResponse
import typealias connect.Next

open class Router: MiddlewareObject, RouteKeeper {
  
  var routes        = ContiguousArray<Route>()
  var errorHandlers = ContiguousArray<ErrorMiddleware>()

  open func add(route e: Route) {
    routes.append(e)
  }
  
  
  // MARK: MiddlewareObject
  
  public func handle(request      req : IncomingMessage,
                     response     res : ServerResponse,
                     next     endNext : @escaping Next)
  {
    guard !self.routes.isEmpty else { return endNext() }
        
    let state = MiddlewareWalker(routes[routes.indices],
                                 req, res, endNext)
    state.step()
  }
}
