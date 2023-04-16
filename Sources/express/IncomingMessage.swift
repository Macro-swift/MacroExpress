//
//  IncomingMessage.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2023 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
  import Foundation
#endif
import class http.IncomingMessage
import NIOHTTP1

public extension IncomingMessage {
  
  // TODO: baseUrl, originalUrl, path
  // TODO: hostname, ip, ips, protocol
  
  // TODO: originalUrl, path
  // TODO: hostname, ip, ips, protocol

  /// A reference to the active application. Updated when subapps are triggered.
  var app : Express? { return environment[ExpressExtKey.App.self] }
  
  /**
   * Contains the request parameters.
   *
   * Example:
   * ```
   * app.use(/users/:id/view) { req, res, next in
   *   guard let id = req.params[int: "id"]
   *    else { return try res.sendStatus(400) }
   * }
   * ```
   */
  var params : [ String : String ] {
    set { environment[ExpressExtKey.Params.self] = newValue }
    get { return environment[ExpressExtKey.Params.self] }
  }
  
  /**
   * Returns the query parameters as parsed by the `qs.parse` function.
   */
  var query : [ String : Any ] {
    if let q = environment[ExpressExtKey.Query.self] { return q }
    
    // this should be filled by Express when the request arrives. It depends on
    // the 'query parser' setting:
    // - false    => disable
    // - simple   => querystring.parse
    // - extended => qs.parse
    // - custom   - custom parser function
    
    // TODO: shoe[color]=blue gives shoe.color = blue
    // FIXME: cannot use url.parse due to overload
    // FIXME: improve parser (fragments?!)
    // TBD: just use Foundation?!
    guard let idx = url.firstIndex(of: "?") else {
      environment[ExpressExtKey.Query.self] = [:]
      return [:]
    }
    let q  = url[url.index(after: idx)...]
    let qp = qs.parse(String(q))
    environment[ExpressExtKey.Query.self] = qp
    return qp
  }
  
  /**
   * Contains the part of the URL which matched the current route. Example:
   * ```
   * app.get("/admin/index") { ... }
   * ```
   *
   * when this is invoked with "/admin/index/hello/world", the baseURL will
   * be "/admin/index".
   */
  var baseURL : String? {
    set { environment[ExpressExtKey.BaseURL.self] = newValue }
    get { return environment[ExpressExtKey.BaseURL.self] }
  }
  
  /// The active route.
  var route : Route? {
    set { environment[ExpressExtKey.RouteKey.self] = newValue }
    get { return environment[ExpressExtKey.RouteKey.self] }
  }
  
  
  /**
   * Checks whether the Accept header of the client indicates that the client
   * can deal with the given type, and returns the Accept pattern which matched
   * the type.
   *
   * Example:
   * ```
   * app.get("/index") { req, res, next in
   *   if req.accepts("json") != nil {
   *     try res.json(todos.getAll())
   *   }
   *   else { try res.send("Hello World!") }
   * }
   * ```
   *
   * - Parameters:
   *   - contentType: The content-type look for in the `Accept` header
   * - Returns: The value of the matching content-type part.
   */
  @inlinable
  func accepts(_ contentType: String) -> String? {
    // TODO: allow array values
    for acceptHeader in headers["Accept"] {
      // FIXME: naive and incorrect implementation :-)
      // TODO: parse quality, patterns, etc etc
      let acceptedTypes = acceptHeader.split(separator: ",")
      for mimeType in acceptedTypes {
        #if canImport(Foundation)
          if mimeType.contains(contentType) { return String(mimeType) }
        #else // prefix match if Foundation is missing
          let length = contentType.count
          if mimeType.count >= length && mimeType.prefix(length) == s {
            return String(mimeType)
          }
        #endif
      }
    }
    return nil
  }
   
  /**
   * Check whether the Content-Type of the request matches the given `pattern`.
   *
   * Refer to the connect `typeIs` function for the actual matching
   * implementation being used.
   *
   * Example:
   * ```
   * app.use { req, res, next in
   *   guard req.is("application/json") else { return next() }
   *   // deal with JSON
   * }
   * ```
   *
   * - Parameters:
   *   - pattern: The type to check for, does a prefix or contains match on the
   *              `Content-Type` header. Lowercased first.
   * - Returns: `true` if the header matched.
   */
  @inlinable
  func `is`(_ pattern: String) -> Bool {
    return typeIs(self, [ pattern.lowercased() ]) != nil
  }
  
  /**
   * Returns true if the request originated from an `XMLHttpRequest` (aka
   * browser AJAX).
   *
   * This is checking whether the `X-Requested-With` header exists,
   * and whether that contains the `XMLHttpRequest` string.
   */
  @inlinable
  var xhr : Bool {
    guard let h = headers["X-Requested-With"].first else { return false }
    return h.contains("XMLHttpRequest")
  }
}
