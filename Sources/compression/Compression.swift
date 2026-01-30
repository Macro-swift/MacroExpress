//
//  Compression.swift
//  MacroExpress
//
//  Created by Helge Hess.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

import class http.IncomingMessage
import class http.ServerResponse
import class http.Server
import class NIOHTTPCompression.HTTPResponseCompressor
import NIOCore
import connect

/**
 * Compression middleware that enables gzip/deflate response compression.
 *
 * Usage:
 * ```swift
 * let app = express()
 * app.use(compression())
 *
 * app.get("/") { req, res, next in
 *   res.send("Hello World!")  // Compressed if client supports it
 * }
 *
 * app.listen(1337)
 * ```
 *
 * The compression is automatic based on the client's `Accept-Encoding` header.
 * Supported encodings are gzip and deflate. The `Vary: Accept-Encoding` header
 * is added for proper caching behavior.
 *
 * - Returns: A middleware that enables HTTP response compression.
 */
public func compression() -> Middleware {
  return { req, res, next in
    // Add Vary header for proper caching behavior
    if let existing = res.getHeader("Vary") as? String {
      if !existing.lowercased().contains("accept-encoding") {
        res.setHeader("Vary", "\(existing), Accept-Encoding")
      }
    }
    else {
      res.setHeader("Vary", "Accept-Encoding")
    }

    // Add compressor to pipeline if headers not sent yet
    guard !res.headersSent, let channel = res.socket else {
      return next()
    }

    // Check if compressor already added to this connection
    channel.pipeline.handler(type: HTTPResponseCompressor.self)
      .whenComplete { result in
        switch result {
          case .success:
            // Already has compressor, just continue
            next()

          case .failure:
            // Get our HTTP handler by name, then add compressor before it
            channel.pipeline.context(name: http.Server.httpHandlerName)
              .whenComplete { ctxResult in
                switch ctxResult {
                  case .success(let ctx):
                    // Run on event loop to use syncOperations (non-Sendable)
                    channel.eventLoop.execute {
                      let position =
                        ChannelPipeline.SynchronousOperations.Position
                          .before(ctx.handler)
                      do {
                        try channel.pipeline.syncOperations.addHandler(
                          HTTPResponseCompressor(),
                          position: position
                        )
                      }
                      catch {
                        res.log.error(
                          "Failed to add compression handler: \(error)")
                      }
                      next()
                    }

                  case .failure(let error):
                    res.log.error(
                      "Failed to find HTTP handler for compression: \(error)")
                    next()
                }
              }
        }
      }
  }
}
