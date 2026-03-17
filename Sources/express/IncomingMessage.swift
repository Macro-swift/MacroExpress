//
//  IncomingMessage.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2026 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
  import Foundation
#endif
import http
import NIOHTTP1
import NIOCore

public extension IncomingMessage {
  
  typealias Params = ExpressWrappedDictionary<String>
  typealias Query  = ExpressWrappedDictionary<Any>

  /// The associated response (set by Express).
  var response : ServerResponse? {
    return environment[ExpressExtKey.ResponseKey.self]
  }

  /// The hostname from the `Host` header, or
  /// `X-Forwarded-Host` when trust proxy is enabled.
  @inlinable
  var hostname: String? {
    let host: String
    if app?.settings.trustProxy ?? false,
       let fh = headers["X-Forwarded-Host"].first
    {
      if let i = fh.firstIndex(of: ",") { host = String(fh[..<i]) }
      else { host = fh }
    }
    else if let h = headers["Host"].first { host = h }
    else { return nil }
    
    // IPv6 bracket notation: strip port after `]`
    if host.hasPrefix("[") {
      guard let b = host.firstIndex(of: "]") else { return host }
      let a = host.index(after: b)
      if a < host.endIndex, host[a] == ":" { return String(host[..<a]) }
      return String(host[...b])
    }
    if let i = host.firstIndex(of: ":") {
      return String(host[..<i])
    }
    return host
  }
  
  /// The client IP. Uses `X-Forwarded-For` when trust
  /// proxy is enabled.
  @inlinable
  var ip: String? {
    if app?.settings.trustProxy ?? false,
       let xff = headers["X-Forwarded-For"].first
    {
      if let i = xff.firstIndex(of: ",") { return String(xff[..<i]) }
      return xff
    }
    return socket?.remoteAddress?.ipAddress
  }

  /// All IPs from `X-Forwarded-For` when trust proxy
  /// is enabled, empty otherwise.
  @inlinable
  var ips: [ String ] {
    guard app?.settings.trustProxy ?? false,
          let xff = headers["X-Forwarded-For"].first else { return [] }
    return xff.split(separator: ",").map { part in
      String(part.drop(while: { $0.isWhitespace }))
    }
  }

  /**
   * `"https"` when behind a trusted proxy setting
   * `X-Forwarded-Proto`, `"http"` otherwise.
   */
  @inlinable
  var `protocol`: String {
    if app?.settings.trustProxy ?? false,
       let proto = headers["X-Forwarded-Proto"].first
    {
      if let i = proto.firstIndex(of: ",") {
        return String(proto[..<i])
      }
      return proto
    }
    return "http"
  }

  /// The URL path without the query string.
  @inlinable
  var path: String {
    guard let qIdx = url.firstIndex(of: "?") else {
      return url.isEmpty ? "/" : url
    }
    if url.startIndex == qIdx { return "/" } // empty
    return String(url[..<qIdx])
  }

  /// A reference to the active application. Updated when subapps are triggered.
  var app : Express? { return environment[ExpressExtKey.App.self] }
  
  /**
   * Contains the request parameters.
   *
   * Example:
   * ```swift
   * app.use("/users/:id/view") { req, res, next in
   *   guard let id = req.params[int: "id"] else {
   *     return try res.sendStatus(400) 
   *   }
   * }
   * ```
   */
  var params : Params {
    set { environment[ExpressExtKey.Params.self] = newValue }
    get { return environment[ExpressExtKey.Params.self] }
  }

  /**
   * Returns the query parameters as parsed by the `qs.parse` function.
   */
  var query : Query {
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
      environment[ExpressExtKey.Query.self] = Query([:])
      return Query([:])
    }
    let q  = url[url.index(after: idx)...]
    let qp = qs.parse(String(q))
    environment[ExpressExtKey.Query.self] = Query(qp)
    return Query(qp)
  }
  
  /**
   * Contains the part of the URL which matched the current
   * route. Example:
   * ```
   * app.get("/admin/index") { ... }
   * ```
   *
   * when this is invoked with "/admin/index/hello/world",
   * the baseURL will be "/admin/index".
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
   * Looks up a parameter by checking route params, the request body,
   * then the query string.
   *
   * Returns `nil` when not found or when the value is
   * an empty string.
   *
   * Example:
   * ```swift
   * app.post("/users/:id") { req, res, next in
   *   let id   = req.param("id")
   *   let name = req.param("name") // body or query
   * }
   * ```
   */
  @inlinable
  func param(_ name: String) -> Any? {
    if let v = params[name], !v.isEmpty { return v }
    if let v = body[name] {
      if let s = v as? String { if !s.isEmpty { return s } }
      else { return v }
    }
    if let v = query[name] {
      if let s = v as? String { if !s.isEmpty { return s } }
      else { return v }
    }
    return nil
  }

  /**
   * Looks up a parameter by checking route params, the request body,
   * then the query string.
   *
   * Returns a default string when not found.
   *
   * Example:
   * ```swift
   * app.post("/users/:id") { req, res, next in
   *   let id   = req.param("id")
   *   let name = req.param("name") // body or query
   * }
   * ```
   */
  @inlinable
  func param(string name: String, default: String = "") -> String {
    guard let v = param(name) else { return `default` }
    return String(describing: v)
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
