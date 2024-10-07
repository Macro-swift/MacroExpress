//
//  MethodOverride.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/31/16.
//  Copyright © 2016-2024 ZeeZide GmbH. All rights reserved.
//

import let MacroCore.console

/**
 * Enables support for the `X-HTTP-Method-Override` header.
 *
 * The `X-HTTP-Method-Override` allows the client to override the actual HTTP
 * method (e.g. `GET` or `PUT`) with a different one.
 * I.e. the `IncomingMessage/method` property will be set to the specified
 * method.
 *
 * This is sometimes used w/ the HTTP stack is only setup to process say `GET`
 * or `POST` requests, but not something more elaborate like `MKCALENDAR`.
 *
 * - Parameters:
 *   - header:  The header to check for the method override, defaults to
 *              `X-HTTP-Method-Override`. This header will contain the method
 *              name.
 *   - methods: The whitelisted methods that allow the override, defaults to
 *              just `POST`.
 * - Returns: A middleware functions that applies the methodOverride.
 */
public func methodOverride(header  : String = "X-HTTP-Method-Override",
                           methods : [ String ] = [ "POST" ])
            -> Middleware
{
  return { req, res, next in
    // TODO: support query values
    
    guard methods.contains(req.method)        else { next(); return }
    guard let hvs = req.headers[header].first else { next(); return }
    
    // patch method and continue
    req.method = hvs
    next()
  }
}
