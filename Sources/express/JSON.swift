//
//  JSON.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/3/16.
//  Copyright © 2016-2023 ZeeZide GmbH. All rights reserved.
//

import MacroCore
import class http.ServerResponse

public extension ServerResponse {
  // TODO: add jsonp
  // TODO: be a proper stream
  // TODO: Maybe we don't want to convert to a `JSON`, but rather stream real
  //       object.
  
  #if canImport(Foundation)
  /**
   * Serializes the given object using Foundation's `JSONSerialization`,
   * writes it to the response, and ends the response.
   *
   * If the content-type can still be assigned (no data has been written yet),
   * the `Content-Type` header to `application/json; charset=utf-8` is set.
   *
   * Example:
   * ```
   * app.get { req, res, next in
   *   res.json([ "answer": 42 ] as Any)
   * }
   * ```
   *
   * - Parameters:
   *   - object: The object to JSON encode and send to the client.
   */
  func json(_ object: Any?) {
    if canAssignContentType {
      setHeader("Content-Type", "application/json; charset=utf-8")
    }
    _ = writeJSON(object)
    end()
  }
  #endif // canImport(Foundation)
  
  
  /**
   * Serializes the given value using its `Encodable` implementation to JSON,
   * writes it to the response, and ends the response.
   *
   * If the content-type can still be assigned (no data has been written yet),
   * the `Content-Type` header to `application/json; charset=utf-8` is set.
   *
   * Example:
   * ```
   * app.get { req, res, next in
   *   res.json([ "answer": 42 ])
   * }
   * ```
   *
   * - Parameters:
   *   - object: The value to JSON encode and send to the client.
   */
  func json<E: Encodable>(_ object: E) {
    if canAssignContentType {
      setHeader("Content-Type", "application/json; charset=utf-8")
    }
    _ = write(object)
    end()
  }

  /**
   * Serializes the given value using its `Encodable` implementation to JSON,
   * writes it to the response, and ends the response.
   * If the object is `nil`, and empty string is sent (and the response ends).
   *
   * If the content-type can still be assigned (no data has been written yet),
   * the `Content-Type` header to `application/json; charset=utf-8` is set.
   *
   * Example:
   * ```
   * app.get { req, res, next in
   *   res.json(nil)
   * }
   * ```
   *
   * - Parameters:
   *   - object: The value to JSON encode and send to the client.
   */
  func json<E: Encodable>(_ object: E?) {
    guard let object = object else {
      _ = write("")
      return end()
    }
    return json(object)
  }
}
