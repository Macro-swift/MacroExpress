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
  var app : Express? { return extra[ExpressExtKey.app] as? Express }

  
  /// A reference to the request associated with this response.
  var request : IncomingMessage? {
    return extra[ExpressExtKey.req] as? IncomingMessage
  }

  /**
   * The locals dictionary of the response. Use this to store response-scoped
   * data. Be careful with key naming, so that you don't override the data
   * of other middleware.
   *
   * Difference between `extra` and `locals`. Conceptually they are the same,
   * but provide different namespaces. `extra` is used for framework internal
   * stuff (and hence requires unique key, we recommend reverse DNS),
   * while `locals` is open to the application and it is reasonable to use
   * 'plain' keys (like "pageTitle", "results" etc).
   */
  var locals : [ String : Any ] {
    set {
      extra[ExpressExtKey.locals] = newValue
    }
    get {
      return extra[ExpressExtKey.locals] as? [ String : Any ] ?? [:]
    }
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
  
  func redirect(_ statusCode: Int, _ location: String) throws {
    self.status(statusCode)
    self.location(location)
    try self.end()
  }
  func redirect(_ location: String) throws {
    try redirect(302, location) // work around swiftc confusion
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
  func send<T: Encodable>(_ object: T) { json(object) }
  
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
