//
//  MiddlewareObject.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 02/06/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import http
import connect
import enum MacroCore.console

/**
 * An object representation of a `Middleware` closure.
 */
public protocol MiddlewareObject {
  
  func handle(request  req: IncomingMessage,
              response res: ServerResponse,
              next     cb:  @escaping Next)
  
}

public extension MiddlewareObject {
  
  /**
   * Returns a `Middleware` closure which targets this `MiddlewareObject`.
   */
  var middleware: Middleware {
    return { req, res, cb in
      self.handle(request: req, response: res, next: cb)
    }
  }

  /**
   * Returns a request handler closure which targets this `MiddlewareObject`.
   */
  var requestHandler: ( IncomingMessage, ServerResponse ) -> Void {
    return { req, res in
      self.handle(request: req, response: res) { ( args: Any... ) in
        if let error = args.first as? Error {
          // essentially the final handler
          console.error("No middleware catched the error:",
                        "\(self) \(req.method) \(req.url):",
                        error)
          res.writeHead(500)
          res.end()
        }
        else {
          // essentially the final handler
          console.warn("No middleware called end:",
                       "\(self) \(req.method) \(req.url)")
          res.writeHead(404)
          res.end()
        }
      }
    }
  }
}
