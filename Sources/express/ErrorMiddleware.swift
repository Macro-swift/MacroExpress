//
//  Route.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import class     http.IncomingMessage
import class     http.ServerResponse
import typealias connect.Next

/**
 * Middleware are just functions that deal with HTTP transactions.
 * The Express "ErrorMiddleware" enhances the concepts with special middleware
 * functions which also take a `Swift.Error` value as the first parameter.
 *
 * As soon as the middleware stack encounters and error (the regular middleware
 * either threw an error, or passed an error object to the `next` handler),
 * an Express router will switch to process the stack of error middleware.
 *
 * They take a request (`IncomingMessage`) and response (`ServerResponse`)
 * object as well as a closure to signal whether they fully handled the request
 * or whether the respective "Router" (e.g. Connect) should run the next
 * middleware.
 *
 * Call `Next` when the request processing needs to continue, just return if the
 * request was fully processed.
 */
public typealias ErrorMiddleware =
                   ( Swift.Error,
                     IncomingMessage, ServerResponse, @escaping Next )
                    throws -> Void
