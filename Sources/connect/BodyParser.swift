//
//  BodyParser.swift
//  Noze.io / MacroExpress
//
//  Created by Helge Hess on 30/05/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import struct NIO.ByteBuffer
import MacroCore
import http

/// An enum which stores the result of the `bodyParser` middleware. The result
/// can be accessed as `request.body`, e.g.
///
///     if case .JSON(let json) = request.body {
///       // do JSON stuff
///     }
///
@dynamicMemberLookup
public enum BodyParserBody {
  
  case notParsed
  case noBody // IsPerfect
  case error(Swift.Error)
  
  case urlEncoded([ String : Any ])
  
  case json(Any)
  
  case raw(ByteBuffer)
  case text(String)
  
  public subscript(dynamicMember k: String) -> Any? {
    return self[k]
  }
}

public extension BodyParserBody {
  
  var json: Any? {
    switch self {
      case .json      (let json): return json
      case .text      (let text): return text
      case .urlEncoded(let dict): return dict
      default: return nil
    }
  }
  
  var text: String? {
    switch self {
      case .text(let s): return s
      default: return nil
    }
  }
}

public extension BodyParserBody {
  
  subscript(key: String) -> Any? {
    switch self {
      case .urlEncoded(let dict):
        return dict[key]
      
      case .json(let json):
        guard let dict = json as? [ String : Any ] else { return nil }
        return dict[key]

      default: return nil
    }
  }
  subscript(string key: String) -> String {
    get {
      guard let value = self[key] else { return "" }
      if let s = value as? String                  { return s }
      if let s = value as? CustomStringConvertible { return s.description }
      return String(describing: value)
    }
  }
}

extension BodyParserBody : ExpressibleByStringLiteral {

  public init(stringLiteral value: String) {
    self = .text(value)
  }
  public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
    self = .text(value)
  }
  public init(unicodeScalarLiteral value: StringLiteralType) {
    self = .text(value)
  }
}


// Module holding the different variants of bodyParsers.
public struct bodyParser {
  
  public class Options {
    let inflate  = false
    let limit    = 100 * 1024
    let extended = true

    public init() {}
  }
  
  fileprivate static let requestKey = "macro.connect.body-parser.body"
}


public enum BodyParserError : Error {
  
  case extraStoreInconsistency
  case couldNotDecodeString
}


// MARK: - IncomingMessage extension

public extension IncomingMessage {
  
  var body: BodyParserBody {
    set { extra[bodyParser.requestKey] = newValue }
    get {
      guard let body = extra[bodyParser.requestKey] else {
        return BodyParserBody.notParsed
      }
      if let body = body as? BodyParserBody { return body }
      return BodyParserBody.error(BodyParserError.extraStoreInconsistency)
    }
  }
}


// MARK: - JSON

// curl -H "Content-type: application/json" -X POST \
//   -d '{ "login": "xyz", "password": "opq", "port": 80 }' \
//   http://localhost:1337/login

public extension bodyParser {
  
  /// This middleware parses the request body if the content-type is JSON,
  /// and pushes the the JSON parse result into the `body` property of the
  /// request.
  ///
  /// Example:
  ///
  ///     app.use(bodyParser.json())
  ///     app.use { req, res, next in
  ///       print("Log JSON Body: \(req.body.json)")
  ///       next()
  ///     }
  ///
  static func json(options opts: Options = Options()) -> Middleware {
    
    return { req, res, next in
      guard typeIs(req, [ "json" ]) != nil else { next(); return }

      // lame, should be streaming
      concatError(request: req, next: next) { bytes in
        let result = JSONModule.parse(bytes)
        // TODO: error?! (just logged)
        req.body = result != nil ? .json(result!) : .noBody
        return nil
      }
    }
  }
}


// MARK: - Raw & Text

// FIXME: consolidate the didCallNext error handling stuff. Just using another
//        middleware which does just the concat, the onceError and the call
//        state

private func concatError(request : IncomingMessage,
                         next    : @escaping Next,
                         handler : @escaping ( ByteBuffer ) -> Swift.Error?)
{
  var didCallNext = false
  
  request | concat { bytes in
    guard !didCallNext else { return }
    if let error = handler(bytes) {
      next(error)
    }
    else {
      next()
    }
  }
  .onceError { error in
    guard !didCallNext else { return }
    didCallNext = true
    next(error)
  }
}

public extension bodyParser {

  static func raw(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      concatError(request: req, next: next) { bytes in
        req.body = .raw(bytes)
        return nil
      }
    }
  }
  
  static func text(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      // text/plain, text/html etc
      // TODO: properly process charset parameter, this assumes UTF-8
      guard typeIs(req, [ "text" ]) != nil else { next(); return }
      
      concatError(request: req, next: next) { bytes in
        guard let s = bytes.getString(at: bytes.readerIndex,
                                      length: bytes.readableBytes) else
        {
          let error = BodyParserError.couldNotDecodeString
          req.body = .error(error)
          return error
        }
        req.body = .text(s)
        return nil
      }
    }
  }
}


// MARK: - URL Encoded

public extension bodyParser {
  
  static func urlencoded(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      guard typeIs(req, [ "application/x-www-form-urlencoded" ]) != nil else {
        next()
        return
      }
      
      // TBD: `extended` option. (maps to our zopeFormats?)
      concatError(request: req, next: next) { bytes in
        guard let s = bytes.getString(at: bytes.readerIndex,
                                      length: bytes.readableBytes) else
        {
          let error = BodyParserError.couldNotDecodeString
          req.body = .error(error)
          return error
        }
        let qp = opts.extended ? qs.parse(s) : querystring.parse(s)
        req.body = .urlEncoded(qp)
        return nil
      }
    }
  }
}
