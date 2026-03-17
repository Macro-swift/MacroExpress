//
//  ServerResponse.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2026 ZeeZide GmbH. All rights reserved.
//

import Logging
import NIOHTTP1   // HTTPResponseStatus/HTTPHeaders
import MacroCore  // Buffer
import http       // IncomingMessage/ServerResponse

public extension ServerResponse {
  
  /// A reference to the active application. Updated when subapps are triggered.
  var app : Express? { return environment[ExpressExtKey.App.self] }

  
  /// A reference to the request associated with this response.
  var request : IncomingMessage? {
    set { environment[ExpressExtKey.RequestKey.self] = newValue }
    get { return environment[ExpressExtKey.RequestKey.self] }
  }

  typealias Locals = ExpressWrappedDictionary<Any>

  /**
   * This is legacy, an app can also just use `EnvironmentKey`s with either
   * `IncomingMessage` or `ServerResponse`.
   * `EnvironmentKey`s are guaranteed to be unique.
   *
   * Traditionally `locals` was used to store Stringly-typed keys & values.
   */
  var locals : Locals {
    set { environment[ExpressExtKey.Locals.self] = newValue }
    get { return environment[ExpressExtKey.Locals.self] }
  }
}

public extension ServerResponse {
  // TODO: Would be cool: send(stream: GReadableStream), then stream.pipe(self)
  
  
  // MARK: - Status Handling
  
  /// Set the HTTP status, returns self.
  ///
  /// Example:
  /// ```swift
  /// res
  ///   .status(404)
  ///   .send("I looked, but couldn't find it!")
  /// ```
  ///
  @discardableResult
  @inlinable
  func status(_ code: Int) -> Self {
    statusCode = code
    return self
  }
  
  /// Set the HTTP status code and send the status
  /// description as the body.
  ///
  /// If the headers have already been sent, only `end()`
  /// is called (no body). Otherwise `Content-Length` is
  /// set to match the reason phrase so a previously set
  /// `Content-Length: 0` is corrected.
  @inlinable
  func sendStatus(_ code: Int, _ headers: HTTPHeaders = [:]) {
    if headersSent {
      if statusCode != code {
        log.error(
          "sendStatus(\(code)) called but headers already sent with status \(statusCode)")
      }
      else {
        log.warning("sendStatus(\(code)) called but headers already sent")
      }
      addTrailers(headers)
      return end()
    }
    
    for ( name, value ) in headers { self.setHeader(name, value) }
    statusCode = code
    let reason = HTTPResponseStatus(statusCode: code).reasonPhrase
    setHeader("Content-Length", reason.utf8.count)
    write(reason)
    end()
  }
  
  
  // MARK: - Redirects
  
  /**
   * Sets the HTTP `Location` header. The location must be URL encoded already.
   *
   * If the given string is `back`, it will be replaced with the value of the
   * `Referer` header, or `/` if there is none.
   *
   * If the string is empty or nil, the header will be removed.
   */
  func location(_ location: String?) {
    guard let location = location, !location.isEmpty else {
      removeHeader("Location")
      return
    }
    
    if location == "back" {
      if let referer = getHeader("Referer") as? String, !referer.isEmpty {
        setHeader("Location", referer)
      }
      else {
        setHeader("Location", "/")
      }
    }
    else {
      // TBD: make absolute based on Host?
      // Also: make paths absolute (e.g. when given 'admin/new')
      setHeader("Location", location)
    }
  }
  
  func redirect(_ statusCode: Int, _ location: String) {
    self.status(statusCode)
    self.location(location)
    self.end()
  }
  func redirect(_ location: String) {
    redirect(302, location) // work around swiftc confusion
  }
  
  
  // MARK: - Sending Content
 
  @inlinable
  func send(_ string: String) {
    if canAssignContentType {
      var ctype = string.hasPrefix("<html") ? "text/html" : "text/plain"
      ctype += "; charset=utf-8"
      setHeader("Content-Type", ctype)
    }
    
    write(string)
    end()
  }
  
  @inlinable
  func send(_ data: Buffer) {
    if canAssignContentType {
      setHeader("Content-Type", "application/octet-stream")
    }
    
    write(data)
    end()
  }
  
  @inlinable
  func send<T>(_ data: T) where T: Collection, T.Element == UInt8 {
    self.send(Buffer(data))
  }

  @inlinable
  func send<T: Encodable>(_ object: T) {
    json(object)
  }
  @inlinable
  func send<T: Encodable>(_ object: T?) {
    guard let object = object else {
      log.warn("sending empty string for nil Encodable object?!")
      return send("")
    }
    json(object)
  }

  @inlinable
  var canAssignContentType : Bool {
    return !headersSent && getHeader("Content-Type") == nil
  }
  
  @inlinable
  func format(handlers: [ String : () -> () ]) {
    var defaultHandler : (() -> ())? = nil
    
    guard let rq = request else {
      handlers["default"]?()
      return
    }
    
    for ( key, handler ) in handlers {
      guard key != "default" else { defaultHandler = handler; continue }
      
      if let mimeType = rq.accepts(key) {
        if canAssignContentType {
          setHeader("Content-Type", mimeType)
        }
        handler()
        return
      }
    }
    if let cb = defaultHandler { cb() }
  }
  
  
  // MARK: - Header Accessor Renames
  
  @inlinable
  func get(_ header: String) -> Any? { return getHeader(header) }
  @inlinable
  func set(_ header: String, _ value: Any?) {
    if let v = value { setHeader(header, v) }
    else             { removeHeader(header) }
  }
}

// MARK: - Content-Type
public extension ServerResponse { 

  /**
   * Sets the `Content-Type` header using MIME lookup.
   *
   * Short types like `"json"` or `"html"` are resolved via `mime.lookup()`. 
   * Full MIME types are set as-is.
   *
   * Example:
   * ```swift
   * res.type("json") // application/json; charset=UTF-8
   * res.type("html") // text/html; charset=UTF-8
   * res.type("text/plain") // text/plain
   * ```
   */
  @discardableResult
  @inlinable
  func type(_ type: String) -> Self {
    if      type.contains("/")         { setHeader("Content-Type", type) }
    else if let ct = mime.lookup(type) { setHeader("Content-Type", ct)   }
    else                               { setHeader("Content-Type", type) }
    return self
  }

  /**
   * Sets the `Content-Type` header using MIME lookup.
   *
   * Short types like `"json"` or `"html"` are resolved via `mime.lookup()`. 
   * Full MIME types are set as-is.
   *
   * Example:
   * ```swift
   * res.type("json") // application/json; charset=UTF-8
   * res.type("html") // text/html; charset=UTF-8
   * res.type("text/plain") // text/plain
   * ```
   */
  @discardableResult
  @inlinable
  func contentType(_ type: String) -> Self { return self.type(type) }

}

// MARK: - Cookies
public extension ServerResponse { 

  /**
   * Sets a cookie on the response.
   *
   * Example:
   * ```swift
   * res.cookie("session", token, httpOnly: true, secure: true,
   *            sameSite: .strict)
   * ```
   */
  @inlinable
  func cookie(_ name: String, _ value: String,
              path: String? = "/", httpOnly: Bool = true,
              domain: String? = nil, maxAge: Int? = nil,
              expires: Date? = nil, secure: Bool = false,
              sameSite: Cookie.SameSite? = nil)
  {
    let c = Cookie(name: name, value: value, path: path,
                   httpOnly: httpOnly, domain: domain,
                   maxAge: maxAge, expires: expires,
                   secure: secure, sameSite: sameSite)
    var existing = [ String ]()
    for v in headers["Set-Cookie"] { existing.append(v) }
    existing.append(c.httpHeaderValue)
    setHeader("Set-Cookie", existing)
  }

  /**
   * Clears a cookie by setting its `Max-Age` to 0.
   *
   * The `path` and `domain` must match the original cookie.
   */
  @inlinable
  func clearCookie(_ name: String, path: String? = "/", domain: String? = nil) {
    let c = Cookie(name: name, value: "", path: path,
                   httpOnly: false, domain: domain,
                   maxAge: 0)
    var existing = [ String ]()
    for v in headers["Set-Cookie"] { existing.append(v) }
    existing.append(c.httpHeaderValue)
    setHeader("Set-Cookie", existing)
  }
}

// MARK: - Downloads
public extension ServerResponse {

  /**
   * Sets the `Content-Disposition` header to `attachment`.
   *
   * If a filename is given, sets the filename parameter and the `Content-Type` 
   * based on the file extension.
   */
  @inlinable
  func attachment(_ filename: String? = nil) {
    if let filename = filename {
      let base = path.basename(filename)
      setHeader("Content-Disposition", "attachment; filename=\"\(base)\"")
      if canAssignContentType, let ct = mime.lookup(filename) {
        setHeader("Content-Type", ct)
      }
    }
    else { setHeader("Content-Disposition", "attachment") }
  }

  /**
   * Streams a file as a download attachment.
   *
   * Sets `Content-Disposition` and `Content-Type`, then pipes the file to the 
   * response.
   *
   * Example:
   * ```swift
   * res.download("/path/to/report.pdf")
   * res.download("/path/to/data.csv", "export.csv")
   * ```
   */
  func download(_ filePath: String, _ filename: String? = nil,
                _ callback: (( Swift.Error? ) -> Void)? = nil)
  {
    let name = filename ?? path.basename(filePath)
    attachment(name)
    let stream = fs.createReadStream(filePath)
    stream.onError { error in callback?(error) }
    _ = stream.pipe(self)
    if let cb = callback { _ = onceFinish { cb(nil) } }
  }
}
