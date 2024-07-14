//
//  BodyParser.swift
//  Noze.io / MacroExpress
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2016-2023 ZeeZide GmbH. All rights reserved.
//

import MacroCore // for `|` operator
import struct   MacroCore.Buffer
import enum     MacroCore.JSONModule
import protocol MacroCore.EnvironmentKey
import func     MacroCore.concat
import enum     http.querystring

/**
 * An enum which stores the result of the ``bodyParser`` middleware.
 *
 * The parsing result enum can be accessed using the ``IncomingMessage/body``
 * property:
 * ```
 * if case .JSON(let json) = request.body {
 *   // do JSON stuff
 * }
 * ```
 *
 * The enum has a set of convenience helper properties/functions to access the
 * body using the expected format, e.g.:
 * - `json`: e.g. `if let json = request.body.json as? [ String : Any ] {}`
 * - `text`: e.g. `if let text = request.body.text {}`
 *
 * Those things "coerce", e.g. one can access a body that was transfered
 * URL encoded as "JSON".
 *
 * If the body is structured, keys can be looked up directly on the body,
 * e.g. if the body is JSON like this (or similar URL encoded):
 * ```json
 * { "answer": 42, "years": [ 1973, 1976 ] }
 * ```
 * It can be retrieved like:
 * ```
 * request.body.answer as? Int
 * request.body.count   // 2
 * request.body.isEmpty // false
 * ```
 *
 * It also provides a set of subscripts:
 * ```
 * request.body["answer"]         //  42  (`Any?`)
 * request.body[int: "answer"]    //  42  (`Int?`)
 * request.body[string: "answer"] // "42" (`String`)
 * ```
 */
@dynamicMemberLookup
public enum BodyParserBody {
  
  /// The request has not been parsed yet by the ``bodyParser`` middleware.
  case notParsed
  
  /// The request doesn't contain a body.
  case noBody // IsPerfect
  
  /// An error occurred while parsing the body.
  case error(Swift.Error)
  
  /// The body was URL encoded, the associated value is the pair of URL encoded
  /// parameters.
  case urlEncoded([ String : Any ])
  
  /// The body was decoded as JSON, the associated value contains the
  /// JSON structure.
  case json(Any)
  
  /// The body was decoded as raw bytes.
  case raw(Buffer)
  
  /// The body was decoded as text and could be converted to a Swift String.
  case text(String)
  
  /**
   * Lookup a value of a key/value based format directly on the `body`,
   * e.g. if the body is JSON like this:
   * ```json
   * { "answer": 42 }
   * ```
   * It can be retrieved like:
   * ```
   * if let answer = request.body.answer as? Int {}
   * ```
   */
  @inlinable
  public subscript(dynamicMember k: String) -> Any? {
    return self[k]
  }
}

public extension BodyParserBody {
  
  /**
   * Returns the body as basic "JSON types", i.e. strings, dicts, arrays etc.
   *
   * It is not actually limited to JSON, but also returns a value for `text`
   * and `urlEncoded` bodies.
   */
  @inlinable
  var json: Any? {
    switch self {
      case .json      (let json): return json
      case .text      (let text): return text
      case .urlEncoded(let dict): return dict
      default: return nil
    }
  }
  
  /**
   * Returns a String representation of the body, if possible.
   *
   * - If the body is raw data, this attempts to convert it to an UTF-8 string
   * - If the body is JSON, attempts to generate JSON
   * - If the body is URL encoded, attempts to generate a URL encoded string
   *
   * To check whether the body is actual `text`, check the enum case.
   */
  @inlinable
  var text: String? {
    switch self {
      case .text(let s)          : return s
      case .notParsed, .error    : return nil
      case .noBody               : return ""
      case .raw (let b)          : return try? b.toString()
      case .json(let json)       : return JSONModule .stringify(json)
      case .urlEncoded(let dict) : return querystring.stringify(dict)
    }
  }
}

public extension BodyParserBody {
  
  /**
   * Returns whether the body is "empty".
   *
   * It is considered empty if:
   * - it hasn't been parsed yet, had no body, or there was an error
   * - if it was URL encoded and the resulting dictionary is empty
   * - if it was JSON and the resulting `[String:Any]` dictionary or `[Any]`
   *   array was emtpy (returns false for all other content).
   * - if the body was raw data and that's empty
   * - if the body was a String and that's empty
   */
  @inlinable
  var isEmpty: Bool {
    switch self {
      case .notParsed, .noBody, .error: return true
      case .urlEncoded(let values): return values.isEmpty
  
      case .json(let json):
        if let v = json as? [ String : Any ] { return v.isEmpty }
        if let v = json as? [ Any ]          { return v.isEmpty }
        return false

      case .raw (let buffer): return buffer.isEmpty
      case .text(let string): return string.isEmpty
    }
  }
  
  /**
   * Returns whether the number of top-level items in the body.
   *
   * - Returns 0 if it hasn't been parsed yet, had no body, or there was an
   *   error.
   * - If it was URL encoded, returns the number of items in the decoded
   *   dictionary.
   * - If it was JSON and the result was a `[String:Any]` dictionary or `[Any]`
   *   array, the count of that, otherwise 1.
   * - The number of bytes in a raw data body.
   * - The number of characters in a Strign body.
   */
  @inlinable
  var count: Int {
    switch self {
      case .notParsed, .noBody, .error: return 0
      case .urlEncoded(let values): return values.count
  
      case .json(let json):
        if let v = json as? [ String : Any ] { return v.count }
        if let v = json as? [ Any ]          { return v.count }
        return 1
      
      case .raw (let buffer): return buffer.count
      case .text(let string): return string.count
    }
  }
}

public extension BodyParserBody {
  
  /**
   * Lookup the value for a key in either a URL encoded dictionary,
   * or in a `[ String : Any ]` JSON dictionary.
   * Returns `nil` for everything else.
   */
  @inlinable
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
  
  /**
   * Lookup the value for a key in either a URL encoded dictionary,
   * or in a `[ String : Any ]` JSON dictionary,
   * and convert that to a String.
   * Returns an empty String if the key was not found,
   * the value if it was a String already,
   * otherwise the CustomStringConvertible or system description.
   */
  @inlinable
  subscript(string key: String) -> String {
    get {
      guard let value = self[key] else { return "" }
      if let s = value as? String                  { return s }
      if let s = value as? CustomStringConvertible { return s.description }
      return String(describing: value)
    }
  }
  
  /**
   * Lookup the value for a key in either a URL encoded dictionary,
   * or in a `[ String : Any ]` JSON dictionary,
   * and convert that to an `Int`, if possible..
   * Returns `nil` if the key was not found,
   * the value if it was an `Int` / `Int64` already,
   * the `Int(double)` value for a `Double`,
   * and the `Int(string)` parse result for a `String`.
   * Or `nil` for all other types.
   */
  @inlinable
  subscript(int key: String) -> Int? {
    get {
      guard let value = self[key] else { return nil }
      switch value { // TBD
        case let v as Int    : return v
        case let v as Int64  : return Int(v)
        case let v as String : return Int(v)
        case let v as Double : return Int(v)
        default: return nil
      }
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

  /// Create a `text` body.
  @inlinable
  public init(stringLiteral value: String) {
    self = .text(value)
  }
  /// Create a `text` body.
  @inlinable
  public init(extendedGraphemeClusterLiteral value: StringLiteralType) {
    self = .text(value)
  }
  /// Create a `text` body.
  @inlinable
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
    
    /// Whether the body should be decompressed.
    /// Unsupported yet.
    public let inflate  = false
    
    /// The maximum number of bytes that will be loaded into memory.
    /// Defaults to just 100kB, must be explicitly set if larger
    /// bodies are allowed! (also consider using multer).
    public var limit    : Int
    
    /// If set, `qs.parse` is used to parse URL parameters, otherwise
    /// `querystring.parse` is used.
    public var extended : Bool
    
    /// If set, this is used to check whether a bodyParser should run for a
    /// given request.
    public var type     : (( IncomingMessage ) -> Bool)?
    
    /**
     * Setup ``bodyParser`` options.
     *
     * - Parameters:
     *   - limit:    The maximum number of bytes that will be loaded into memory
     *               (defaults to just 100kB, explictly set for larger bodies!).
     *   - extended: Whether to use `qs.parse` or `querystring.parse` for
     *               URL encoded parameters.
     *   - type:     Override the default MIME type of the request that is being
     *               checked.
     */
    @inlinable
    public init(limit: Int = 100_000, extended: Bool = true,
                type: String? = nil)
    {
      self.limit    = limit
      self.extended = extended
      if let type { self.type = { typeIs($0, [ type ]) != nil } }
    }
  }

  fileprivate enum BodyKey: EnvironmentKey {
    static let defaultValue : BodyParserBody = .notParsed
    static let loggingKey   = "body"
  }
}

fileprivate extension bodyParser.Options {
  
  func checkType(_ req: IncomingMessage, defaultType: String? = nil) -> Bool {
    if let type        { return type(req)                           }
    if let defaultType { return typeIs(req, [ defaultType ]) != nil }
    return true
  }
}

public enum BodyParserError : Error {
  
  case extraStoreInconsistency
  case couldNotDecodeString(Swift.Error)
}


// MARK: - IncomingMessage extension

public extension IncomingMessage {
  
  /**
   * Returns the ``BodyParserBody`` associated with the request,
   * i.e. the result of the ``bodyParser`` middleware.
   * If the middleware wasn't invoked, this will return
   * ``BodyParserBody/notParsed``
   *
   * There is a set of convenience helpers to deal with the result:
   * ```
   * request.json                   // "JSON" types wrapped in `Any`
   * request.text                   // "Hello"
   * request.body.answer as? Int
   * request.body.count             // 2
   * request.body.isEmpty           // false
   * request.body["answer"]         //  42  (`Any?`)
   * request.body[int: "answer"]    //  42  (`Int?`)
   * request.body[string: "answer"] // "42" (`String`)
   * ```
   */
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
  
  /** This middleware parses the request body if the content-type is JSON,
   * and pushes the the JSON parse result into the `body` property of the
   * request.
   *
   * Example:
   * ```
   * app.use(bodyParser.json()) // loads and parses the request
   * app.use { req, res, next in
   *   console.log("Log JSON Body:", req.body.json)
   *   console.log("Answer:", req.body.answer)
   *   next()
   * }
   * ```
   */
  static func json(options opts: Options = Options()) -> Middleware {
    
    return { req, res, next in
      guard opts.checkType(req, defaultType: "json") else { return next() }
      
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
          concatError(request: req, limit: opts.limit, next: next) { bytes in
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
                         limit   : Int,
                         next    : @escaping Next,
                         handler : @escaping ( Buffer ) -> Swift.Error?)
{
  var didCallNext = false // used to share the error state
  
  request | concat(maximumSize: limit) { bytes in
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
   * ## Usage
   *
   * ```
   * app.use(bodyParser.raw()) // load the content, similar to `concat`
   *
   * app.post("/post") { req, res, next in
   *   console.log("Request body is:", req.body)
   *   next()
   * }
   * ```
   *
   * - Parameter options: The options to be used for parsing.
   * - Returns: A middleware which does the parsing as described.
   */
  static func raw(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      guard opts.checkType(req) else { return next() }
      switch req.body {
        case .raw, .noBody, .error:
          return next() // already loaded
        
        case .notParsed:
          concatError(request: req, limit: opts.limit, next: next) { bytes in
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
   * ## Usage
   * ```
   * app.use(bodyParser.text()) // load and parse the request
   *
   * app.post("/post") { req, res, next in
   *   console.log("Request text is:", req.text)
   *   next()
   * }
   * ```
   *
   * - Parameter options: The options to be used for parsing.
   * - Returns: A middleware which does the parsing as described.
   */
  static func text(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      // text/plain, text/html etc
      // TODO: properly process charset parameter, this assumes UTF-8
      guard opts.checkType(req, defaultType: "text") else { return next() }
      
      switch req.body {
        case .text, .noBody, .error:
          return next() // already loaded
        
        case .notParsed:
          concatError(request: req, limit: opts.limit, next: next) { bytes in
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
   * ## Usage
   *
   * ```
   * app.use(bodyParser.urlencoded()) // load an parse the request
   *
   * app.post("/post") { req, res, next in
   *   console.log("Query is:", req.body[string: "query"])
   *   console.log("Query is:", req.body.query)
   *   next()
   * }
   * ```
   *
   * - Parameter options: The options to be used for parsing. Use the `extended`
   *                      setting to enable the use of `qs.parse`.
   * - Returns: A middleware which does the parsing as described.
   */
  static func urlencoded(options opts: Options = Options()) -> Middleware {
    return { req, res, next in
      guard opts.checkType(req,
        defaultType: "application/x-www-form-urlencoded") else { return next() }
      
      switch req.body {
        case .urlEncoded, .noBody, .error:
          return next() // already loaded

        case .notParsed:
          concatError(request: req, limit: opts.limit, next: next) { bytes in
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
