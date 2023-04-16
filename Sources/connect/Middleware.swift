//
//  Middleware.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/3/16.
//  Copyright © 2016-2023 ZeeZide GmbH. All rights reserved.
//

import class http.IncomingMessage
import class http.ServerResponse

/**
 * The arguments to next() depend on the actual router, but may include:
 *
 * - `route` / `router` (skip the remaining middleware in the router)
 * - a `Swift.Error` object in case of error
 */
public typealias Next = ( Any... ) -> Void

/**
 * Middleware are just functions that deal with HTTP transactions.
 *
 * They take a request (``IncomingMessage``) and response (``ServerResponse``)
 * object as well as a closure to signal whether they fully handled the request
 * or whether the respective "Router" (e.g. Connect) should run the next
 * middleware.
 *
 * Call ``Next`` when the request processing needs to continue, just return if
 * the request was fully processed.
 */
public typealias Middleware =
                   ( IncomingMessage, ServerResponse, @escaping Next )
                   throws -> Void
