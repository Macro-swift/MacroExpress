//
//  QueryParser.swift
//  MacroExpress
//
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

import class http.IncomingMessage

/// Default strings recognized as boolean values by
/// ``queryParser`` and ``boolParser``.
public let defaultBoolStrings : Set<String> = [
  "true", "false", "TRUE", "FALSE", "True", "False",
  "yes", "no", "YES", "NO", "Yes", "No"
]

/**
 * Middleware that converts string values in `req.query` to
 * typed values (`Bool`, `Int`, `Double`).
 *
 * Similar to the Node.js `express-query-parser` package.
 *
 * - Parameters:
 *   - parseBoolean: Convert boolean-like strings to `Bool`.
 *   - parseNumber: Convert numeric strings to `Int` or
 *     `Double`.
 *   - boolStrings: The set of string values to treat as
 *     booleans. Pass `nil` to use ``defaultBoolStrings``.
 *   - keys: If set, only convert these query parameter
 *     keys. Pass `nil` to convert all matching keys.
 *   - exclude: Query parameter keys to skip.
 *
 * Usage:
 * ```swift
 * app.use(queryParser(parseBoolean: true,
 *                     parseNumber: true))
 * ```
 */
public func queryParser(parseBoolean : Bool = false,
                        parseNumber  : Bool = false,
                        keys         : Set<String>? = nil,
                        exclude      : Set<String>? = nil,
                        boolStrings  : Set<String>? = nil) -> Middleware
{
  let recognized = boolStrings ?? defaultBoolStrings
  return { req, res, next in
    var query   = req.query
    var changed = false

    for key in query.keys {
      if let keys    = keys,    !keys.contains(key)    { continue }
      if let exclude = exclude,  exclude.contains(key) { continue }
      guard let s = query[key] as? String else { continue }

      if parseBoolean && recognized.contains(s) {
        query[key] = query[bool: key]
        changed = true
      }
      else if parseNumber {
        if let i = Int(s) {
          query[key] = i
          changed = true
        }
        else if let d = Double(s) {
          query[key] = d
          changed = true
        }
      }
    }

    if changed {
      req.environment[ExpressExtKey.Query.self] = query
    }
    next()
  }
}

/**
 * Convenience middleware that converts boolean-like string
 * values in `req.query` to actual `Bool` values.
 *
 * Equivalent to `queryParser(parseBoolean: true, ...)`.
 * Similar to the Node.js `express-query-boolean` package.
 *
 * Usage:
 * ```swift
 * app.use(boolParser())
 * app.get("/items") { req, res, next in
 *   let verbose = req.query[bool: "verbose"]
 * }
 * ```
 */
@inlinable
public func boolParser(keys        : Set<String>? = nil,
                       exclude     : Set<String>? = nil,
                       boolStrings : Set<String>? = nil) -> Middleware
{
  queryParser(parseBoolean: true,
              keys: keys, exclude: exclude, boolStrings: boolStrings)
}
