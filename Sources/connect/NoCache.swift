//
//  NoCache.swift
//  MacroExpress
//
//  Created by Helge Heß on 12.06.25.
//

/**
 * Sets up HTTP caching headers to disable caching.
 * 
 * Sets the following headers:
 * - `Cache-Control`:     no-store, no-cache, must-revalidate, proxy-revalidate
 * - `Pragma`:            no-cache
 * - `Expires`:           0
 * - `Surrogate-Control`: no-store
 * 
 * Node: https://www.npmjs.com/package/nocache
 * MDN:  https://developer.mozilla.org/en-US/docs/Web/HTTP/Guides/Caching
 *
 * - Returns: A middleware that disable HTTP caching.
 */
public func nocache() -> Middleware {
  return { req, res, next in
    res.setHeader("Cache-Control", 
                  "no-store, no-cache, must-revalidate, proxy-revalidate")
    res.setHeader("Pragma",  "no-cache")
    res.setHeader("Expires", "0")
    res.setHeader("Surrogate-Control", "no-store")
    next()
  }
}
