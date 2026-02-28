//
//  Middleware.swift
//  MacroExpress
//
//  Created by Helge Heß on 2/28/26.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

import MacroCore
import NIOCore

/**
 * A variant of ``Middleware`` that can itself invoke async calls.
 *
 * They take a request (``IncomingMessage``) and a response
 * (``ServerResponse``) object, as well as a closure to signal
 * whether they fully handled the request or whether the
 * respective "Router" (e.g. Connect) should run the next
 * middleware.
 *
 * Call ``Next`` when the request processing needs to continue,
 * just return if the request was fully processed.
 *
 * Use the ``async(_:)-1t2gx`` free function to convert an
 * `AsyncMiddleware` into a regular ``Middleware`` that can be
 * registered with a ``Route``:
 * ```swift
 * app.use(async { req, res, next in
 *   let data = try await fetchData()
 *   res.json(data)
 * })
 * 
 * app.use(async { req, res, next in
 *   let data = try await doStuff()
 *   next() // continue
 * })
 * ```
 */
public typealias AsyncMiddleware =
                   ( IncomingMessage, ServerResponse, @escaping Next )
                   async throws -> Void

/**
 * A variant of ``FinalMiddleware`` that can itself invoke async calls.
 *
 * Async final middleware are functions that deal with HTTP
 * transactions using Swift concurrency (`async`/`await`).
 * Unlike ``AsyncMiddleware``, `AsyncFinalMiddleware` always
 * ends the response and never calls ``Next``.
 *
 * The closures takes a request (``IncomingMessage``) and a response
 * (``ServerResponse``) object.
 *
 * Use the ``async(_:)-6fwgt`` free function to convert an
 * `AsyncFinalMiddleware` into a regular ``Middleware``:
 * ```swift
 * app.get("/hello", async { req, res in
 *   let greeting = try await generateGreeting()
 *   res.send(greeting)
 * })
 * ```
 */
public typealias AsyncFinalMiddleware =
                   ( IncomingMessage, ServerResponse ) async throws -> Void

/**
 * Convert an ``AsyncMiddleware`` into a synchronous
 * ``Middleware`` that can be used with Connect/Express
 * routing.
 *
 * The returned middleware spawns a `Task` that runs the
 * async closure. If the async middleware throws, the error
 * is forwarded to ``Next`` so that error middleware in the
 * chain can handle it.
 *
 * Example:
 * ```swift
 * app.use(async { req, res, next in
 *   let user = try await db.findUser(req.params["id"])
 *   req.extra[ObjectIdentifier(User.self)] = user
 *   next()
 * })
 * ```
 *
 * - Note: This uses `MacroCore.shared.retain()` /
 *   `release()` to keep the process alive while the
 *   `Task` is running. The `next` closure is dispatched
 *   back onto the NIO event loop.
 * - Parameters:
 *   - middleware: The async middleware to wrap.
 * - Returns:      A synchronous ``Middleware`` suitable for `route.use()`.
 */
public func `async`(_ middleware: @escaping AsyncMiddleware) -> Middleware {
  // This is not exactly cheap, but a convenient measure until we can do this
  // in a better way. Also requires IncomingRequest/Response to be Sendable,
  // which ideally would not be necessary (should be non-isolated and get sent
  // around).
  return { req, res, next in
    let module = MacroCore.shared.retain()

    // Make a sendable-ish wrapper around `next`.
    let sendableNext: @Sendable (Any...) -> Void = { (args: Any...) in
      module.fallbackEventLoop().execute {
        switch args.count {
          case 0  : next()                 // no  arguments
          case 1  : next(args[0])          // one argument
          case 2  : next(args[0], args[1]) // two arguments
          default :                        // more than two arguments
            // can't flatten, pass as array, but preserve error
            if let err = args.first as? Error {
              next(err, Array(args.dropFirst()))
            }
            else { next(args) }
        }
        module.release()
      }
    }

    Task {
      do {
        try await middleware(req, res, sendableNext)
      }
      catch { // forward error via next(error)
        sendableNext(error)
      }
    }
  }
}

/**
 * Convert an ``AsyncFinalMiddleware`` into a synchronous
 * ``Middleware`` that can be used with Connect/Express
 * routing.
 *
 * The returned middleware spawns a `Task` that runs the
 * async closure. Since final middleware never calls ``Next``,
 * any thrown error is forwarded to ``Next`` as an error so
 * that error middleware in the chain can handle it.
 *
 * Example:
 * ```swift
 * app.get("/hello", async { req, res in
 *   let greeting = try await generateGreeting()
 *   res.send(greeting)
 * })
 * ```
 *
 * - Note: This uses `MacroCore.shared.retain()` /
 *   `release()` to keep the process alive while the
 *   `Task` is running.
 *   
 * - Parameters:
 *   - middleware: The async final middleware to wrap.
 * - Returns:      A synchronous ``Middleware`` suitable for `route.get()` etc.
 */
@inlinable
public func `async`(_ middleware: @escaping AsyncFinalMiddleware) -> Middleware
{
  return { req, res, next in
    let module = MacroCore.shared.retain()

    Task {
      do {
        try await middleware(req, res)
        module.release()
      }
      catch {
        module.fallbackEventLoop().execute {
          next(error)
          module.release()
        }
      }
    }
  }
}
