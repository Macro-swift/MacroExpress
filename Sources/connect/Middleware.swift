//
//  Middleware.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/3/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
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

/// Supposed to call Next() when it is done.
public typealias Middleware =
                   ( IncomingMessage, ServerResponse, @escaping Next ) -> Void
