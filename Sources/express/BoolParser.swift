//
//  BoolParser.swift
//  MacroExpress
//
//  Copyright © 2025-2026 ZeeZide GmbH. All rights reserved.
//

import class http.IncomingMessage

/// Default strings recognized as boolean values by
/// ``boolParser``.
public let defaultBoolStrings : Set<String> = [
  "true", "false", "TRUE", "FALSE", "True", "False",
  "yes", "no", "YES", "NO", "Yes", "No"
]

/**
 * Middleware that converts boolean-like string values in
 * `req.query` to actual `Bool` values.
 *
 * Recognizes: `true`/`false`, `yes`/`no`, `1`/`0`
 * (case insensitive), and empty string (as `false`).
 *
 * - Parameters:
 *   - boolStrings: The set of string values to treat as
 *     booleans. Pass `nil` to use the default set.
 *   - keys: If set, only convert these query parameter
 *     keys. Pass `nil` to convert all matching keys.
 *   - exclude: Query parameter keys to skip even if they
 *     match. Pass `nil` to exclude nothing.
 *
 * Usage:
 * ```swift
 * app.use(boolParser())
 * app.get("/items") { req, res, next in
 *   let verbose = req.query[bool: "verbose"]
 * }
 * ```
 */
public func boolParser(boolStrings : Set<String>? = nil,
                       keys        : Set<String>? = nil,
                       exclude     : Set<String>? = nil)
  -> Middleware
{
  let recognized = boolStrings ?? defaultBoolStrings
  return { req, res, next in
    var query   = req.query
    var changed = false
    for key in query.keys {
      if let keys    = keys,    !keys.contains(key)    { continue }
      if let exclude = exclude,  exclude.contains(key) { continue }
      guard let s = query[key] as? String,
            recognized.contains(s) else { continue }
      query[key] = query[bool: key]
      changed = true
    }
    if changed {
      req.environment[ExpressExtKey.Query.self] = query
    }
    next()
  }
}
