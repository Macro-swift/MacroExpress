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

  /// Shorthand for `protocol == "https"`.
  @inlinable
  var secure : Bool { return `protocol` == "https" }

  /**
   * Returns the subdomain array of the hostname in reverse order (rightmost
   * subdomain first). The last two parts (TLD + domain) are stripped. A
   * trailing dot (FQDN) is ignored.
   *
   * `"a.b.example.com"` returns `["b", "a"]`.
   */
  @inlinable
  var subdomains : [ String ] {
    guard var host = hostname?[...] else { return [] }
    if host.hasSuffix(".") { host = host.dropLast() }

    // Find the last two dots to locate the domain boundary
    guard let lastDot = host.lastIndex(of: ".") else { return [] }
    let beforeLast = host[..<lastDot]
    guard let secondDot = beforeLast.lastIndex(of: ".") else { return [] }

    // Everything before secondDot is subdomains.
    // Walk backwards to produce reversed order per Express.js
    // convention (rightmost subdomain first).
    let sub    = host[host.startIndex..<secondDot]
    var result = [ String ]()
    var end    = sub.endIndex
    while end > sub.startIndex {
      if let dot = sub[sub.startIndex..<end].lastIndex(of: ".") {
        result.append(String(sub[sub.index(after: dot)..<end]))
        end = dot
      }
      else {
        result.append(String(sub[sub.startIndex..<end]))
        break
      }
    }
    return result
  }
}

// MARK: - Conditional Requests
public extension IncomingMessage {
  /**
   * Whether the request is "fresh" (304-eligible).
   *
   * Per RFC 9110 Section 13.2.2, `If-None-Match` takes precedence:
   * when present, `If-Modified-Since` is ignored. `If-None-Match` is
   * a list header -- all header lines are combined and any ETag match
   * (weak comparison) means fresh. `If-Modified-Since` is a singleton
   * and only evaluated when `If-None-Match` is absent.
   *
   * Only meaningful for GET / HEAD with a 2xx or 304 status.
   */
  var fresh : Bool {
    guard method == "GET" || method == "HEAD" else { return false }
    guard let res = response else { return false }

    let sc = res.statusCode
    guard (sc >= 200 && sc < 300) || sc == 304 else { return false }

    // If-None-Match is a list field; collect all header lines.
    let inmHeaders = headers["If-None-Match"]
    if !inmHeaders.isEmpty {
      guard let etag = res.getHeader("ETag") as? String else { return false }
      let sv = etag.hasPrefix("W/") ? etag.dropFirst(2) : etag[...]

      // Any match across all header lines means fresh (OR).
      for line in inmHeaders {
        let trimmed = trimSpaces(line)
        if trimmed == "*" { return true }
        for tag in line.split(separator: ",") {
          let t = trimSpaces(tag)
          let cv = t.hasPrefix("W/") ? t.dropFirst(2) : t[...]
          if cv == sv { return true }
        }
      }
      // If-None-Match present but no match => stale.
      return false
    }

    // If-Modified-Since: singleton, only when If-None-Match
    // is absent (RFC 9110 Section 13.1.3).
    // Fresh if Last-Modified <= If-Modified-Since.
    if let ims = headers["If-Modified-Since"].first,
       let lm = res.getHeader("Last-Modified") as? String
    {
      if lm == ims { return true }
      guard let imsDate = parseHTTPDate(ims),
            let lmDate  = parseHTTPDate(lm) else { return false }
      return lmDate <= imsDate
    }

    return false
  }

  /// Inverse of ``fresh``.
  @inlinable
  var stale : Bool { return !fresh }
}

// MARK: - Content Negotiation
public extension IncomingMessage {
  
  /**
   * Checks whether the client accepts one of the given languages based on the 
   * `Accept-Language` header.
   *
   * Returns the first matched language, or `nil`.
   */
  @inlinable
  func acceptsLanguages(_ languages: String...) -> String? {
    return acceptsHeader("Accept-Language", languages)
  }

  /**
   * Checks whether the client accepts one of the given charsets based on the 
   * `Accept-Charset` header.
   *
   * Returns the first matched charset, or `nil`.
   */
  @inlinable
  func acceptsCharsets(_ charsets: String...) -> String? {
    return acceptsHeader("Accept-Charset", charsets)
  }

  /**
   * Checks whether the client accepts one of the given encodings based on the
   * `Accept-Encoding` header.
   *
   * Returns the first matched encoding, or `nil`.
   */
  @inlinable
  func acceptsEncodings(_ encodings: String...) -> String? {
    return acceptsHeader("Accept-Encoding", encodings)
  }

  /**
   * Generic Accept- header negotiation.
   *
   * Parses the specified header and returns the first candidate that matches,
   * respecting q-values for preference ordering.
   */
  @usableFromInline
  internal func acceptsHeader(_ headerName: String, _ candidates: [ String ]) 
                -> String?
  {
    let allHeaders = headers[headerName]
    guard !allHeaders.isEmpty else { return candidates.first }

    var entries = [ ( value: Substring, quality: Double ) ]()
    for header in allHeaders {
      for raw in header.split(separator: ",") {
        let parts = raw.split(separator: ";")
        let value = parts.first.map(trimSpaces) ?? raw[...]
        var q     = 1.0
        for part in parts.dropFirst() {
          let p = trimSpaces(part)
          if p.hasPrefix("q=") { q = Double(p.dropFirst(2)) ?? 1.0 }
        }
        entries.append((value: value, quality: q))
      }
    }

    // Only sort when qualities actually differ.
    if entries.count > 1 {
      let firstQ = entries[0].quality
      if entries.contains(where: { $0.quality != firstQ }) {
        entries.sort { $0.quality > $1.quality }
      }
    }

    for candidate in candidates {
      for entry in entries {
        let ev = entry.value
        if ev == "*" { return candidate }
        if ev.caseInsensitiveCompare(candidate) == .orderedSame {
          return candidate
        }
        // prefix: "en" matches "en-US" and vice versa
        if candidate.count < ev.count {
          let endIdx = ev.index(ev.startIndex, offsetBy: candidate.count)
          let range  = ev.startIndex..<endIdx
          if ev[range].caseInsensitiveCompare(candidate) == .orderedSame { 
            return candidate 
          }
        }
        else if ev.count < candidate.count {
          let endIdx = candidate.index(candidate.startIndex, offsetBy: ev.count)
          let range = candidate.startIndex..<endIdx
          if candidate[range].caseInsensitiveCompare(ev) == .orderedSame { 
            return candidate 
          }
        }
      }
    }
    return nil
  }
}

// MARK: - Range
public extension IncomingMessage {
  
  /**
   * Parses the `Range` request header against the given resource size.
   *
   * Returns an array of byte ranges, or `nil` if the header is missing or 
   * malformed.
   *
   * Example:
   * ```swift
   * if let ranges = req.range(fileSize) {
   *   // serve partial content
   * }
   * ```
   */
  func range(_ size: Int) -> [ ClosedRange<Int> ]? {
    guard let header = headers["Range"].first else { return nil }
    guard header.hasPrefix("bytes=") else {
      log.warning("Unsupported range unit: \(header)")
      return nil
    }

    let spec = header.dropFirst(6) // "bytes="
    var ranges = [ ClosedRange<Int> ]()
    for part in spec.split(separator: ",") {
      let t = trimSpaces(part)
      guard let dash = t.firstIndex(of: "-") else {
        log.warning("Malformed range part (no dash): \(t) in \(header)")
        return nil
      }
      let before = t[t.startIndex..<dash]
      let after  = t[t.index(after: dash)...]
      if before.isEmpty { // suffix: "-500"
        guard let suffix = Int(after), suffix > 0 else {
          log.warning("Invalid suffix range: \(t) in \(header)")
          return nil
        }
        ranges.append(max(0, size - suffix)...(size - 1))
      }
      else if after.isEmpty { // open: "500-"
        guard let start = Int(before), start < size else {
          log.warning("Unsatisfiable range: \(t) (size=\(size)) in \(header)")
          return nil
        }
        ranges.append(start...(size - 1))
      }
      else {
        guard let start = Int(before), let end = Int(after),
              start <= end, end < size else {
          log.warning("Unsatisfiable range: \(t) (size=\(size)) in \(header)")
          return nil
        }
        ranges.append(start...end)
      }
    }
    return ranges.isEmpty ? nil : ranges
  }
}

@usableFromInline
internal func trimSpaces<S>(_ s: S) -> Substring
  where S: StringProtocol, S.SubSequence == Substring
{
  var start = s.startIndex, end = s.endIndex
  while start < end && s[start] == " " { s.formIndex(after: &start) }
  while end > start {
    let prev = s.index(before: end)
    guard s[prev] == " " else { break }
    end = prev
  }
  return s[start..<end]
}


// MARK: - HTTP Date Parsing

#if canImport(Darwin)
  import Darwin
#elseif canImport(Glibc)
  import Glibc
#endif

/// Parses an HTTP-date (RFC 9110 Section 5.6.7) to a Unix
/// timestamp. Supports IMF-fixdate, obsolete RFC 850, and
/// asctime formats.
@usableFromInline
internal func parseHTTPDate(_ string: String) -> time_t? {
  string.withCString { cstr in
    var tm = tm()
    for fmt in httpDateFormats {
      if strptime(cstr, fmt, &tm) != nil {
        let time = timegm(&tm)
        if time != -1 { return time }
      }
    }
    return nil
  }
}

private let httpDateFormats = [
  // IMF-fixdate: Sun, 06 Nov 1994 08:49:37 GMT
  "%a, %d %b %Y %H:%M:%S GMT",
  // obsolete RFC 850: Sunday, 06-Nov-94 08:49:37 GMT
  "%A, %d-%b-%y %H:%M:%S GMT",
  // ANSI C asctime(): Sun Nov  6 08:49:37 1994
  "%a %b %e %H:%M:%S %Y"
]
