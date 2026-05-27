//
//  VHost.swift
//  MacroExpress
//

import MacroCore // EnvironmentKey, EnvironmentValues
import http      // IncomingMessage, ServerResponse

/**
 * Per-request info populated by ``vhost(_:_:)-1uy0v`` (and its overloads) when 
 * a host pattern matches. Read it via``IncomingMessage/vhost``.
 *
 * - `host`:     the raw `Host:` header value as received.
 * - `hostname`: port-stripped host. (== ``IncomingMessage/hostname``)
 * - `pattern`:  the matched pattern.
 * - `captures`: ordered list of glob `*` captures (e.g. matching 
 *               `*.example.com` against`foo.example.com` populates `["foo"]`).
 *               For Regex patterns, populated only when 
 *               `Output == AnyRegexOutput` (or when the caller manually 
 *               requests storage).
 */
public struct VHostInfo: Sendable, Hashable {

  public let host     : String
  public let hostname : String
  public let pattern  : String
  public let captures : [ String ]

  @inlinable
  public init(host: String, hostname: String, pattern: String,
              captures: [ String ] = [])
  {
    self.host     = host
    self.hostname = hostname
    self.pattern  = pattern
    self.captures = captures
  }
}

@usableFromInline
internal enum VHostExtKey: EnvironmentKey {
  @usableFromInline static let defaultValue : VHostInfo? = nil
  @usableFromInline static let loggingKey   = "vhost"
}

public extension IncomingMessage {

  /// Set by ``vhost(_:_:)-1uy0v`` when a host pattern matched the request. 
  /// `nil` otherwise.
  @inlinable
  var vhost: VHostInfo? {
    get { environment[VHostExtKey.self] }
    set { environment[VHostExtKey.self] = newValue }
  }
}

public extension EnvironmentValues {

  /**
   * Per-request info when a host pattern matches.
   *
   * - `host`:     the raw `Host:` header value as received.
   * - `hostname`: port-stripped host. (== ``IncomingMessage/hostname``)
   * - `pattern`:  the matched pattern.
   * - `captures`: ordered list of glob `*` captures (e.g. matching 
   *               `*.example.com` against`foo.example.com` populates `["foo"]`).
   *               For Regex patterns, populated only when 
   *               `Output == AnyRegexOutput` (or when the caller manually 
   *               requests storage).
   */
  @inlinable
  var vhost: VHostInfo? {
    get { self[VHostExtKey.self] }
    set { self[VHostExtKey.self] = newValue }
  }
}


/**
 * Convert a Node-`vhost`-style glob (`*` matches any sequence of characters 
 * non-greedily, including dots) into a Swift `Regex<AnyRegexOutput>`. 
 * Anchored, case-insensitive. Mirrors the upstream package's semantics: see 
 * `expressjs/vhost`'s `index.js`:
 * `hostname.replace(/[^*\w]/g, escapeChar)
 *          .replace(/[*]/g, '(?:.*?)')`.
 *
 * We use **capturing** groups (`(.*?)`) instead of non-capturing (`(?:.*?)`) so 
 * the matched fragments are exposed via ``VHostInfo/captures``.
 *
 * Examples:
 * - `"example.com"`:   matches exactly `example.com`
 * - `"*.example.com"`: matches `foo.example.com` and `foo.bar.example.com`. 
 *                      Captures `["foo"]` and `["foo.bar"]` respectively.
 * - `"diary.*":        matches `diary.zeezide.de`, 
 *                      captures `["diary.zeezide.de"]`.
 */
@usableFromInline
internal func vhostCompileGlob(_ pattern: String) throws 
              -> Regex<AnyRegexOutput>
{
  var rx = ""
  rx.reserveCapacity(pattern.count + 8)
  rx.append("^")
  for ch in pattern {
    if ch == "*" {
      rx.append("(.*?)")
    }
    else if regexSpecials.contains(ch) {
      rx.append("\\")
      rx.append(ch)
    }
    else {
      rx.append(ch)
    }
  }
  rx.append("$")
  return try Regex<AnyRegexOutput>(rx).ignoresCase()
}
fileprivate let regexSpecials = Set(#".+?^$()[]{}|\"#)


// MARK: - API

/**
 * Host-keyed mount. Dispatches to the inner ``Middleware``
 * (or ``MiddlewareObject``) only when the request's `Host:` header matches the 
 * given glob pattern; otherwise calls `next()` so subsequent vhost middlewares 
 * can attempt their own match.
 *
 * The glob uses `*` to match a single host label (no dots).
 *
 * Example:
 * ```swift
 * let app    = express()
 * let admin  = express()
 * let public = express()
 * app.use(vhost("admin.*",  admin))
 *    .use(vhost("public.*", public))
 * ```
 *
 * The matched info is stored on the request and accessible via 
 * ``IncomingMessage/vhost``.
 */
public func vhost(_ pattern: String, _ handler: @escaping Middleware) 
            -> Middleware
{
  let regex: Regex<AnyRegexOutput>
  do { regex = try vhostCompileGlob(pattern) }
  catch {
    // Fail-fast at registration time: an invalid pattern is
    // a programmer error, not a per-request failure.
    assertionFailure("vhost: invalid glob pattern \"\(pattern)\": \(error)")
    return { req, res, next in 
      req.log.error("vhost: invalid glob pattern \"\(pattern)\":", error)
      next(error)
    }
  }
  return vhostHandler(pattern: pattern, regex: regex, handler: handler)
}

/**
 * Host-keyed mount. Dispatches to the inner ``Middleware``
 * (or ``MiddlewareObject``) only when the request's `Host:` header matches the 
 * given glob pattern; otherwise calls `next()` so subsequent vhost middlewares 
 * can attempt their own match.
 *
 * The glob uses `*` to match a single host label (no dots).
 *
 * Example:
 * ```swift
 * let app    = express()
 * let admin  = express()
 * let public = express()
 * app.use(vhost("admin.*",  admin))
 *    .use(vhost("public.*", public))
 * ```
 *
 * The matched info is stored on the request and accessible via 
 * ``IncomingMessage/vhost``.
 */
@inlinable
public func vhost(_ pattern: String, _ subApp: MiddlewareObject) -> Middleware {
  return vhost(pattern, subApp.middleware)
}

/**
 * Host-keyed mount taking a Swift Regex. Dispatches to the inner ``Middleware``
 * (or ``MiddlewareObject``) only when the request's `Host:` header matches the 
 * given glob pattern; otherwise calls `next()` so subsequent vhost middlewares 
 * can attempt their own match.
 * 
 * Use this when a glob is not expressive enough (multiple top-level domains, or 
 * reading captures).
 * Example:
 * ```swift
 * let app    = express()
 * app.use(vhost(/^(diary|dashboard)\.[^.]+\.zeezide\.de$/i, diaryApp))
 * ```
 *
 * The matched info is stored on the request and accessible via 
 * ``IncomingMessage/vhost``.
 */
public func vhost<Output>(_   regex : Regex<Output>,
                          _ handler : @escaping Middleware) -> Middleware
{
  let any   = Regex<AnyRegexOutput>(regex)
  let label = "<regex \(String(describing: regex))>"
  return vhostHandler(pattern: label, regex: any, handler: handler)
}

/**
 * Host-keyed mount taking a Swift Regex. Dispatches to the inner ``Middleware``
 * (or ``MiddlewareObject``) only when the request's `Host:` header matches the 
 * given glob pattern; otherwise calls `next()` so subsequent vhost middlewares 
 * can attempt their own match.
 * 
 * Use this when a glob is not expressive enough (multiple top-level domains, or 
 * reading captures).
 * Example:
 * ```swift
 * let app    = express()
 * app.use(vhost(/^(diary|dashboard)\.[^.]+\.zeezide\.de$/i, diaryApp))
 * ```
 *
 * The matched info is stored on the request and accessible via 
 * ``IncomingMessage/vhost``.
 */
@inlinable
public func vhost<Output>(_ regex: Regex<Output>,
                          _ subApp: MiddlewareObject) -> Middleware
{
  return vhost(regex, subApp.middleware)
}


// MARK: - Internal handler

@usableFromInline
internal func vhostHandler(pattern : String,
                           regex   : Regex<AnyRegexOutput>,
                           header  : String = "Host",
                           handler : @escaping Middleware) -> Middleware
{
  // This intentionally doesn't do/check "X-Forwarded-Host" by default.
  return { req, res, next in
    guard let raw = req.get(header) else {
      req.log.info("Request w/o \(header) header?")
      return next()
    }

    /// Strip port (and IPv6 brackets) from a `Host:` header.
    func vhostStripPort(_ host: String) -> String {
      if host.hasPrefix("[") {                       // IPv6
        guard let bracket = host.firstIndex(of: "]") else { return host }
        let after = host.index(after: bracket)
        if after < host.endIndex, host[after] == ":" {
          return String(host[..<after])
        }
        return String(host[...bracket])
      }
      if let colon = host.firstIndex(of: ":") {
        return String(host[..<colon])
      }
      return host
    }
    
    let hostname = vhostStripPort(raw)
    guard let m = try? regex.firstMatch(in: hostname) else {
      return next() // doesn't match
    }
    
    var captures = [ String ]()
    captures.reserveCapacity(m.count - 1)
    for i in 1..<m.count {
      if let s = m[i].substring { captures.append(String(s)) }
    }
    req.vhost = VHostInfo(host: raw, hostname: hostname,
                          pattern: pattern, captures: captures)
    try handler(req, res, next)
  }
}
