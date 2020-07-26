//
//  MiddlewareObject.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 02/06/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import http
import connect
import enum MacroCore.console

/**
 * MiddlewareObject is the 'object variant' of a Middleware callback.
 *
 * All MiddlewareObject's provide a `handle(request:response:next:)` method.
 *
 * And you can generate a Middleware function for a MiddlewareObject by using
 * the `.middleware` property. Like so:
 *
 *     app.use(otherApp.middleware)
 *
 * Finally, you can also use the as a http-module request handler. Same thing:
 *
 *     http.createServer(onRequest: app.requestHandler)
 *
 */
public protocol MiddlewareObject {
  
  func handle(request  : IncomingMessage,
              response : ServerResponse,
              next     : @escaping Next) throws
}

  
}

public protocol MountableMiddlewareObject : MiddlewareObject {
  
  func mount(at: String, parent: Express)
  
}

public extension MiddlewareObject {
  
  /**
   * Returns a `Middleware` closure which targets this `MiddlewareObject`.
   */
  @inlinable
  var middleware: Middleware {
    return { req, res, next in
      try self.handle(request: req, response: res, next: next)
    }
  }

  /**
   * Returns a request handler closure which targets this `MiddlewareObject`.
   */
  var requestHandler: ( IncomingMessage, ServerResponse ) -> Void {
    return { req, res in
      do {
        try self.handle(request: req, response: res) { ( args: Any... ) in
          if let error = args.first as? Error {
            console.error("No middleware catched the error:",
                          "\(self) \(req.method) \(req.url):",
                          error)
            res.writeHead(500)
            res.end()
          }
          else if req.method == "OPTIONS" {
            // This assumes option headers have been set via cors middleware or
            // sth similar.
            // Just respond with OK and we are done, right?
            
            if res.getHeader("Allow") == nil {
              res.setHeader("Allow",
                            allowedDefaultMethods.joined(separator: ", "))
            }
            if res.getHeader("Server") == nil {
              res.setHeader("Server", "Macro/1.33.7")
            }
            
            res.writeHead(200)
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
      catch {
        console.error("No middleware catched the error:",
                      "\(self) \(req.method) \(req.url):",
                      error)
        res.writeHead(500)
        res.end()
      }
    }
  }
}

fileprivate let allowedDefaultMethods = [
  "GET", "HEAD", "POST", "OPTIONS", "DELETE", "PUT", "PATCH"
]
