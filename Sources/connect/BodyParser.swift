//
//  BodyParser.swift
//  Noze.io / MacroExpress
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

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
  
  case raw(Buffer)
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

extension BodyParserBody : CustomStringConvertible {
  
  public var description: String {
    switch self {
      case .notParsed        : return "<Body: not-parsed>"
      case .noBody           : return "<NoBody: is-perfect>"
      case .error(let error) : return "<BodyParserError: \(error)>"
      case .raw(let buffer)  : return "<RawBody: \(buffer)>"
      
      case .text(let string):
        guard !string.isEmpty else { return "<TextBody: empty>" }
        let clean = string
                    .replacingOccurrences(of: "\r", with: "\\r")
                    .replacingOccurrences(of: "\n", with: "\\n")
        if clean.count < 40 { return "<Body \"\(clean)\">" }
        else                { return "<Body \"\(clean.prefix(38))\"..>" }

      case .urlEncoded(let params):
        guard !params.isEmpty else { return "<URLBody: empty>" }
        var ms = "<URLBody:"
        for ( name, value ) in params {
          ms += " \(name)="
          switch value {
            case let string as String:
              ms += "\""
              let clean = string
                          .replacingOccurrences(of: "\r", with: "\\r")
                          .replacingOccurrences(of: "\n", with: "\\n")
              if clean.count < 40 { ms += clean + "\"" }
              else                { ms += clean.prefix(38) + "\".." }
            case let int as Int:
              ms += "\(int)"
            default:
              ms += "\(value)"
          }
        }
        ms += ">"
        return ms

      case .json(let value):
        if let s = JSONModule.stringify(value) { return "<JSONBody: \(s)>" }
        else { return "<InvalidJSONBody: \(value)>" }
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


/// Module holding the different variants of bodyParsers.
public enum bodyParser {
  
  /**
   * Options for use in request body parsers.
   */
  public class Options {
    let inflate  = false
    let limit    = 100 * 1024
    let extended = true

    public init() {}
  }
  
  fileprivate static let requestKey = "macro.connect.body-parser.body"

  fileprivate enum BodyKey: EnvironmentKey {
    static let defaultValue : BodyParserBody = .notParsed
    static let loggingKey   = "body"
  }
}

public enum BodyParserError : Error {
  
  case extraStoreInconsistency
  case couldNotDecodeString(Swift.Error)
}


// MARK: - IncomingMessage extension

public extension IncomingMessage {
  
  var body: BodyParserBody {
    set { environment[bodyParser.BodyKey.self] = newValue }
    get { return environment[bodyParser.BodyKey.self] }
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
      guard typeIs(req, [ "json" ]) != nil else { return next() }
      
      struct CouldNotParseJSON: Swift.Error {}
      
      func setBodyIfNotNil(_ result: Any?) {
        guard let result = result else {
          req.body = .error(CouldNotParseJSON())
          return
        }
        req.body = .json(result)
      }

      switch req.body {
        case .json:
          return next() // already parsed JSON
      
        case .noBody, .error: // already parsed as nothing or error
          return next()
      
        case .notParsed:
          // lame, should be streaming
          concatError(request: req, next: next) { bytes in
            setBodyIfNotNil(JSONModule.parse(bytes))
            return nil
          }
          
        case .urlEncoded(let values):
          req.log.notice("remapping URL encoded body data to JSON")
          req.body = .json(values)
          next()
          
        case .raw(let bytes):
          setBodyIfNotNil(JSONModule.parse(bytes))
          next()
        case .text(let string):
          setBodyIfNotNil(JSONModule.parse(string))
          next()
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
                         handler : @escaping ( Buffer ) -> Swift.Error?)
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

  /**
   * Returns a middleware for puts the raw request bytes into the `req.body`
   * field.
   *
   * This parser ignores the content-type and just returns the raw bytes.
   *
   * Note: Make sure to place this middleware behind other middleware parsing
   *       more specific content types!
   *
   * # Usage
   *
   *     app.use(bodyParser.raw())
   *
   *     app.post("/post") { req, res, next in
   *       console.log("Request body is:", req.body)
   *       next()
   *     }
   *
   * - Parameter options: The options to be used for parsing.
   * - Returns: A middleware which does the parsing as described.
   */
  static func raw(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      switch req.body {
        case .raw, .noBody, .error:
          return next() // already loaded
        
        case .notParsed:
          concatError(request: req, next: next) { bytes in
            req.body = .raw(bytes)
            return nil
          }

        default:
          req.log.warning("not overriding parsed body \(req.body) w/ .raw")
          return next()
      }
    }
  }
  
  /**
   * Returns a middleware for parsing text (string) POST bodies.
   *
   * If the request has a "text" content-type (e.g. `text/html`, `text/plain`),
   * this parser kicks in and decodes the raw bytes into a Swift `String`.
   *
   * The results of the parsing are available using the `request.body` enum,
   * or for text, the shortcut `request.body.text`.
   * If the parsing fails, that will be set to the `.error` case.
   *
   * Note: Make sure to place this middleware behind other middleware parsing
   *       more specific content types!
   *
   * # Usage
   *
   *     app.use(bodyParser.text())
   *
   *     app.post("/post") { req, res, next in
   *       console.log("Request text is:", req.text)
   *       next()
   *     }
   *
   * - Parameter options: The options to be used for parsing.
   * - Returns: A middleware which does the parsing as described.
   */
  static func text(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      // text/plain, text/html etc
      // TODO: properly process charset parameter, this assumes UTF-8
      guard typeIs(req, [ "text" ]) != nil else { return next() }
      
      switch req.body {
        case .text, .noBody, .error:
          return next() // already loaded
        
        case .notParsed:
          concatError(request: req, next: next) { bytes in
            do {
              req.body = .text(try bytes.toString())
              return nil
            }
            catch {
              req.body = .error(BodyParserError.couldNotDecodeString(error))
              return error
            }
          }
          
        case .raw(let bytes):
          do {
            req.body = .text(try bytes.toString())
            next()
          }
          catch {
            let bpError = BodyParserError.couldNotDecodeString(error)
            req.body = .error(bpError)
            return next(error)
          }

        default:
          req.log.warning("not overriding parsed body \(req.body) w/ .text")
          return next()
      }
    }
  }
}


// MARK: - URL Encoded

public extension bodyParser {
  
  /**
   * Returns a middleware for parsing form encoded POST bodies.
   *
   * If the request has a content-type of `application/x-www-form-urlencoded`
   * this parser kicks in and parses the encoded values.
   * It either uses
   * `qs.parse` if `extended` is enabled in the `Options`,
   * or `querystring.parse` if not.
   *
   * The results of the parsing are available using the `request.body` enum.
   * If the parsing fails, that will be set to the `.error` case.
   *
   * # Usage
   *
   *     app.use(bodyParser.urlencoded())
   *
   *     app.post("/post") { req, res, next in
   *       console.log("Query is:", req.body[string: "query"])
   *       next()
   *     }
   *
   * - Parameter options: The options to be used for parsing. Use the `extended`
   *                      setting to enable the use of `qs.parse`.
   * - Returns: A middleware which does the parsing as described.
   */
  static func urlencoded(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      guard typeIs(req, [ "application/x-www-form-urlencoded" ]) != nil else {
        return next()
      }
      
      switch req.body {
        case .urlEncoded, .noBody, .error:
          return next() // already loaded

        case .notParsed:
          concatError(request: req, next: next) { bytes in
            do {
              let s    = try bytes.toString()
              let qp   = opts.extended ? qs.parse(s) : querystring.parse(s)
              req.body = .urlEncoded(qp)
              return nil
            }
            catch {
              req.body = .error(BodyParserError.couldNotDecodeString(error))
              return error
            }
          }
          
        case .json(let json):
          guard let dict = json as? [ String : Any ] else {
            req.log.warning(
              "cannot remap non-dict JSON encoded body \(json) to urlencoded")
            return next()
          }
          req.log.notice("remapping JSON encoded body data to urlencoded")
          req.body = .urlEncoded(dict)
          next()
          
        case .raw(let bytes):
          do {
            let s    = try bytes.toString()
            let qp   = opts.extended ? qs.parse(s) : querystring.parse(s)
            req.body = .urlEncoded(qp)
          }
          catch {
            let bpError = BodyParserError.couldNotDecodeString(error)
            req.body = .error(bpError)
            return next(error)
          }
          
        case .text(let s):
          let qp   = opts.extended ? qs.parse(s) : querystring.parse(s)
          req.body = .urlEncoded(qp)
          next()
      }
    }
  }
}
