//
//  ServerResponse.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum   NIOHTTP1.HTTPResponseStatus
import struct MacroCore.Buffer
import class  http.IncomingMessage
import class  http.ServerResponse
import struct Foundation.Data

public extension ServerResponse {
  
  /// A reference to the active application. Updated when subapps are triggered.
  var app : Express? { return environment[ExpressExtKey.App.self] }

  
  /// A reference to the request associated with this response.
  var request : IncomingMessage? {
    set { environment[ExpressExtKey.RequestKey.self] = newValue }
    get { return environment[ExpressExtKey.RequestKey.self] }
  }

  /**
   * This is legacy, an app can also just use `EnvironmentKey`s with either
   * `IncomingMessage` or `ServerResponse`.
   * `EnvironmentKey`s are guaranteed to be unique.
   *
   * Traditionally `locals` was used to store Stringly-typed keys & values.
   */
  var locals : [ String : Any ] {
    set { environment[ExpressExtKey.Locals.self] = newValue }
    get { return environment[ExpressExtKey.Locals.self] }
  }
}

public extension ServerResponse {
  // TODO: Would be cool: send(stream: GReadableStream), then stream.pipe(self)
  
  
  // MARK: - Status Handling
  
  /// Set the HTTP status, returns self
  ///
  /// Example:
  ///
  ///     res.status(404).send("didn't find it")
  ///
  @discardableResult
  @inlinable
  func status(_ code: Int) -> Self {
    statusCode = code
    return self
  }
  
  /// Set the HTTP status code and send the status description as the body.
  ///
  @inlinable
  func sendStatus(_ code: Int) {
    let status = HTTPResponseStatus(statusCode: code)
    statusCode = code
    send(status.reasonPhrase)
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
  func send(_ data: Data) {
    if canAssignContentType {
      setHeader("Content-Type", "application/octet-stream")
    }
    
    write(data)
    end()
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
  func get(_ header: String) -> Any? {
    return getHeader(header)
  }
  @inlinable
  func set(_ header: String, _ value: Any?) {
    if let v = value { setHeader(header, v) }
    else             { removeHeader(header) }
  }
}
