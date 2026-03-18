//
//  ResponseTime.swift
//  MacroExpress
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import xsys // timespec

/**
 * Response timing middleware.
 *
 * Measures request duration and sets the specified header on the response just
 * before the headers are flushed, using the ``ServerResponse/onceWriteHead``
 * hook (equivalent to Node.js `on-headers`).
 *
 * Usage:
 * ```swift
 * app.use(responseTime())
 * ```
 *
 * Node: https://www.npmjs.com/package/response-time
 *
 * - Parameters:
 *   - header: Header name (default: `X-Response-Time`).
 *   - suffix: Append `ms` to the value (default: true).
 * - Returns:  A middleware that records response timing.
 */
public func responseTime(_ header: String = "X-Response-Time",
                         suffix: Bool = true) -> Middleware
{
  return { req, res, next in
    let startTS = timespec.monotonic()
    _ = res.onceWriteHead { res in
      let endTS = timespec.monotonic()
      let diff  = (endTS - startTS).milliseconds
      let value = suffix ? "\(diff)ms" : "\(diff)"
      res.setHeader(header, value)
    }
    next()
  }
}
