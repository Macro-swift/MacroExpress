//
//  IncomingMessage.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import class http.IncomingMessage

public extension IncomingMessage {
  
  // TODO: baseUrl, originalUrl, path
  // TODO: hostname, ip, ips, protocol
  
  // TODO: originalUrl, path
  // TODO: hostname, ip, ips, protocol

  /// A reference to the active application. Updated when subapps are triggered.
  var app : Express? { return extra[ExpressExtKey.app] as? Express }
  
  /**
   * Contains the request parameters.
   *
   * Example:
   *
   *     app.use(/users/:id/view) { req, res, next in
   *       guard let id = req.params[int: "id"]
   *        else { return try res.sendStatus(400) }
   *     }
   */
  var params : [ String : String ] {
    set {
      extra[ExpressExtKey.params] = newValue
    }
    get {
      // TODO: should be :Any
      return (extra[ExpressExtKey.params] as? [ String : String ]) ?? [:]
    }
  }
  
  var query : [ String : Any ] {
    if let q = extra[ExpressExtKey.query] as? [ String : Any ] { return q }
    
    // this should be filled by Express when the request arrives. It depends on
    // the 'query parser' setting:
    // - false    => disable
    // - simple   => querystring.parse
    // - extended => qs.parse
    // - custom   - custom parser function
    
    // TODO: shoe[color]=blue gives shoe.color = blue
    // FIXME: cannot use url.parse due to overload
    // FIXME: improve parser (fragments?
    guard let idx = url.firstIndex(of: "?") else {
      extra[ExpressExtKey.query] = [:]
      return [:]
    }
    let q  = url[url.index(after: idx)...]
    let qp = qs.parse(String(q))
    extra[ExpressExtKey.query] = qp
    return qp
  }
  
  /**
   * Contains the part of the URL which matched the current route. Example:
   *
   *     app.get("/admin/index") { ... }
   *
   * when this is invoked with "/admin/index/hello/world", the baseURL will
   * be "/admin/index".
   */
  var baseURL : String? {
    set { extra[ExpressExtKey.baseURL] = newValue }
    get { return extra[ExpressExtKey.baseURL] as? String }
  }
  
  /// The active route.
  var route : Route? {
    set { extra[ExpressExtKey.route] = newValue }
    get { return extra[ExpressExtKey.route] as? Route }
  }
  
  
  /**
   * Checks whether the Accept header of the client indicates that the client
   * can deal with the given type, and returns the Accept pattern which matched
   * the type.
   *
   * Example:
   *
   *     app.get("/index") { req, res, next in
   *       if req.accepts("json") != nil {
   *         try res.json(todos.getAll())
   *       }
   *       else { try res.send("Hello World!") }
   *     }
   */
  @inlinable
  func accepts(_ s: String) -> String? {
    // TODO: allow array values
    for acceptHeader in headers["Accept"] {
      // FIXME: naive and incorrect implementation :-)
      // TODO: parse quality, patterns, etc etc
      let acceptedTypes = acceptHeader.split(separator: ",")
      for mimeType in acceptedTypes {
        if mimeType.contains(s) { return String(mimeType) }
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
   *
   *     app.use { req, res, next in
   *       guard req.is("application/json") else { return next() }
   *       // deal with JSON
   *     }
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
