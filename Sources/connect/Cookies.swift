//
//  Cookies.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 10/06/16.
//  Copyright © 2016-2026 ZeeZide GmbH. All rights reserved.
//

import Logging
import MacroCore // console
import http      // IncomingMessage,ServerResponse

/**
 * Usage:
 * ```swift
 * let cookies = Cookies(req, res)
 * 
 * cookies.set("theAnswer", "42")           // set a cookie
 * if let answer = cookies.get("theAnswer") // get a cookie
 * ```
 */
public struct Cookies: Sendable {
  // "Set-Cookie:" Name "=" Value *( ";" Attribute)
  // "Cookie:"     Name "=" Value *( ";" Name "=" Value)
  //
  // W/ percent encoding handled.
  
  public let res                : ServerResponse?
  
  /// This just checks `X-Forwarded-Proto`, `localhost` etc.
  public let isSecureConnection : Bool
  
  public let cookies : [ String : String ]


  /**
   * - Parameters:
   *   - req:    The request to read the cookies from.
   *   - res:    The response to set cookies on.
   *   - secure: Whether the connection is encrypted, detected if `nil`.
   */
  public init(_  req : IncomingMessage, _ res: ServerResponse? = nil,
              secure : Bool? = nil)
  {
    self.res = res
    
    self.cookies = req.extractStringCookieDictionary()
    self.isSecureConnection = secure ?? req.isLikelySecureConnection
  }
  
  
  // get/set funcs
  
  @inlinable
  public func get(_ name: String) -> String? {
    return cookies[name]
  }
  
  /**
   * Adds a `Set-Cookie` header for the cookie to the response.
   *
   * An invalid cookie is not set, but logged.
   */
  @inlinable
  public func set(cookie c: Cookie) {
    guard let res = res else {
      return console.warn("attempt to set cookie, but got no response object!")
    }
    if let error = c.validationError {
      return res.log.error("Not setting invalid cookie:", c.name, error)
    }
    if c.secure && !isSecureConnection {
      // Client will ignore it
      res.log.warn("Setting `Secure` cookie on an plain connection:", c.name)
    }
    var values : [ String ]
    switch res.getHeader("Set-Cookie") {
      case .some(let v as String)     : values = [ v ]
      case .some(let v as [ String ]) : values = v
      case .some(let v)               : values = [ "\(v)" ]
      case .none                      : values = []
    }
    values.append(c.httpHeaderValue)
    res.setHeader("Set-Cookie", values)
  }
  
  @inlinable
  public func set(_ cookie: Cookie) {
    // TODO: convenience, deprecated one
    set(cookie: cookie)
  }
  
  @inlinable
  public func set(_   name : String, _           value    : String,
                  path     : String?      = "/", httpOnly : Bool    = true,
                  domain   : String?      = nil, comment  : String? = nil,
                  expires  : xsys.time_t? = nil, maxAge   : Int?    = nil,
                  secure   : Bool = false, sameSite : Cookie.SameSite? = nil)
  {
    // Node checks the `req.protocol` == https from Express, but that's one
    // layer above.
    let cookie = Cookie(name: name, value: value, path: path, httpOnly:httpOnly,
                        domain: domain, comment: comment, maxAge: maxAge, 
                        expires: expires, secure: secure, sameSite: sameSite)
    set(cookie: cookie)
  }
  
  @inlinable
  public func reset(_ name: String) {
    set(cookie: Cookie(name: name, maxAge: 0))
  }
  
  // subscript
  
  @inlinable
  public subscript(name : String) -> String? {
    set {
      guard let newValue = newValue else {
        let log = res?.log ?? console
        return log.error("attempt to set nil-value cookie: \(name), ignoring.")
      }
      set(name, newValue)
    }
    get { return get(name) }
  }
}

extension Cookies: CustomStringConvertible {
  
  public var description: String {
    var ms = "<Cookies:"
    if cookies.isEmpty {
      if let res = res {
        if let c = res.getHeader("Set-Cookie") {
          ms += " no-cookies, response w/ setCookie: \(c)"
        }
        else if let c = res.getHeader("Cookie") {
          ms += " no-cookies, response w/ Cookie: \(c)"
        }
        else {
          ms += " no-cookies, response w/o Cookie headers"
        }
      }
      else {
        ms += " no-cookies, no-response"
      }
    }
    else {
      ms += " "
      ms += String(cookies.keys.joined(separator: ","))
    }
    ms += ">"
    return ms
  }
}

// Expose the type under the "cookies" name for naming compat.
public let cookies = Cookies.self

public struct Cookie: Hashable, Sendable {

  public enum SameSite: String, Hashable, Sendable {
    case strict = "Strict"
    case lax    = "Lax"
    case none   = "None"
  }

  public let name     : String
  public var value    : String
  public var path     : String?
  public var httpOnly : Bool
  public var domain   : String?
  public var comment  : String?
  public var maxAge   : Int?    // in seconds
  public var expires  : xsys.time_t?
  public var secure   : Bool
  public var sameSite : SameSite?

  public init(name   : String,            value    : String = "",
              path   : String?   = "/",   httpOnly : Bool         = true,
              domain : String?   = nil,   comment  : String?      = nil,
              maxAge : Int?      = nil,   expires  : xsys.time_t? = nil,
              secure : Bool      = false, sameSite : SameSite?    = nil)
  {
    self.name     = name
    self.value    = value
    self.path     = path
    self.httpOnly = httpOnly
    self.domain   = domain
    self.comment  = comment
    self.maxAge   = maxAge
    self.expires  = expires
    self.secure   = secure
    self.sameSite = sameSite
  }
}

import struct xsys.time_t

public extension Cookie {
  
  /// The `Set-Cookie` header value. Percent-encoded if it has disallowed chars.
  var httpHeaderValue: String {
    var s = "\(name)=\(Cookie.encodeValue(value))"
    
    if let v = path     { s += "; Path=\(v)"                   }
    if let v = domain   { s += "; Domain=\(v)"                 }
    if let v = comment  { s += "; Comment=\(v)"                }
    if let v = maxAge   { s += "; Max-Age=\(v)"                }
    if secure           { s += "; Secure"                      }
    if let v = sameSite { s += "; SameSite=\(v.rawValue)"      }
    if httpOnly         { s += "; HttpOnly"                    }
    if let v = expires  { s += "; expires=\(v.httpDateString)" }

    return s
  }
}

public extension Cookie {

  /// Why the cookie can't be sent.
  var validationError: String? {
    func isValidName(_ name: String) -> Bool { // `tchar`s only
      !name.isEmpty && name.utf8.allSatisfy { c in
        switch c {
          case 0x30...0x39, 0x41...0x5A, 0x61...0x7A: return true // 0-9 A-Z a-z
          case 0x21, 0x23, 0x24, 0x25, 0x26, 0x27, 0x2A, 0x2B, 0x2D, 0x2E,
               0x5E, 0x5F, 0x60, 0x7C, 0x7E:          // !#$%&'*+-.^_`|~
            return true
          default: return false
        }
      }
    }
    func isValidAttributeValue(_ value: String?) -> Bool {
      guard let value else { return true }
      return !value.utf8.contains { $0 == 59 || $0 < 32 || $0 == 127 }
    }
    
    if !isValidName(name)              { return "invalid name"    }
    if !isValidAttributeValue(path)    { return "invalid path"    }
    if !isValidAttributeValue(domain)  { return "invalid domain"  }
    if !isValidAttributeValue(comment) { return "invalid comment" }
    return nil
  }
  
  private static let hex = Array("0123456789ABCDEF".utf8)

  /// As-is if valid, otherwise percent-encoded.
  static func encodeValue(_ value: String) -> String {
    func isCookieOctet(_ c: UInt8) -> Bool {
      switch c { // visible ASCII except `"`, `,`, `;` and `\`.
        case 0x21, 0x23...0x2B, 0x2D...0x3A,0x3C...0x5B,0x5D...0x7E: return true
        default: return false
      }
    }
  
    let percent       = UInt8(ascii: "%")
    let needsEncoding = value.utf8.contains {
      $0 == percent || !isCookieOctet($0)
    }
    guard needsEncoding else { return value }

    var bytes = [ UInt8 ](); bytes.reserveCapacity(value.utf8.count * 3)
    for c in value.utf8 {
      if c != percent && isCookieOctet(c) { bytes.append(c); continue }
      bytes.append(percent)
      bytes.append(hex[Int(c >> 4)])
      bytes.append(hex[Int(c & 0x0F)])
    }
    return String(decoding: bytes, as: UTF8.self)
  }

  /// Strips double quotes and decodes percent-escapes.
  static func decodeValue<S: StringProtocol>(_ raw: S) -> String {
    var value = Substring(raw)
    if value.count >= 2, value.first == "\"", value.last == "\"" {
      value = value.dropFirst().dropLast()
    }
    guard value.contains("%") else { return String(value) }

    func hexValue(_ c: UInt8) -> UInt8? {
      switch c {
        case 0x30...0x39: return c - 0x30
        case 0x41...0x46: return c - 0x41 + 10
        case 0x61...0x66: return c - 0x61 + 10
        default:          return nil
      }
    }

    var bytes = [ UInt8 ](); bytes.reserveCapacity(value.utf8.count)
    var it = value.utf8.makeIterator()
    while let c = it.next() {
      guard c == 37 else { bytes.append(c); continue }
      
      guard let h = it.next().flatMap(hexValue),
            let l = it.next().flatMap(hexValue) else 
      {
        return String(value)
      }
      bytes.append(h << 4 | l)
    }
    
    /// Make sure it's valid UTF-8, otherwise preserve (likely Latin-1).
    var codec    = UTF8()
    var iterator = bytes.makeIterator()
    while true {
      switch codec.decode(&iterator) {
        case .scalarValue : continue
        case .emptyInput  : return String(decoding: bytes, as: UTF8.self)
        case .error       : return String(value) // preserve the input as-is
      }
    }
  }
}

extension Cookie : CustomStringConvertible {
  
  @inlinable public var description: String { return httpHeaderValue }
}

// MARK: - Internals

import let xsys.strchr
import let xsys.strlen
import let xsys.memcpy

extension String {
  // Ah, this extension is crap. FIXME
  
  func trim(splitchar c: Int8 = 32) -> String {
    return withCString { start in
      if strchr(start, Int32(c)) == nil { return self } // contains no trimchar
      
      var p = start
      var didTrimLeft = false
      while p.pointee == c && p.pointee != 0 { p += 1; didTrimLeft = true }
      guard p.pointee != 0 else { return "" }
      
      var len = Int(strlen(p))
      var didTrimRight = false
      while len > 0 && p[len - 1] == c {
        len -= 1
        didTrimRight = true
      }
      guard len != 0 else { return "" }
      
      if !didTrimLeft && !didTrimRight { return self } // as-is
      if !didTrimRight { return String(cString: p) }
      
      // lame and slow zero terminate
      let buflen = len + 1
      let buf    = UnsafeMutablePointer<CChar>.allocate(capacity: buflen)
      _ = memcpy(buf, p, len)
      buf[len] = 0 // zero terminate
      
      let s = String(cString: buf)
      buf.deallocate()
      return s
    }
  }
  
  func splitAndTrim(splitchar c: UInt8) -> [ String ] {
    guard !isEmpty else { return [] }
    
    let splitChar : UInt8 = 59 // semicolon
    let rawFields = utf8.split(separator: splitChar)
    
    // TODO: lame imp, too much copying
    var fields = Array<String>()
    fields.reserveCapacity(rawFields.count)
    
    for field in rawFields  {
      guard field.count > 0 else { continue }
      
      let s = String(field)!
      fields.append(s.trim())
    }
    
    // TODO: split on ';', trim
    return fields
  }
  
  func splitPair(splitchar c: UInt8) -> ( String, String ) {
    let splits = utf8.split(separator: c, maxSplits: 1)
    guard splits.count > 1 else { return ( self, "" ) }
    assert(splits.count == 2, "max split was 1, but got more items?")
    let s0 : UTF8View.SubSequence = splits[0], s1 = splits[1]
    return ( String(decoding: s0, as: UTF8.self),
             String(decoding: s1, as: UTF8.self) )
  }
}

/// "Cookie: a=10; b=20" => [ "a=10", "b=20" ]
private func splitCookieFields(headerValue v: String) -> [ String ] {
  return v.splitAndTrim(splitchar: 59) // semicolon (multiple cookies in line)
}

fileprivate extension IncomingMessage {

  func extractStringCookieDictionary() -> [ String : String ] {
    // Note: This just picks the first cookie! Newer clients send multiple
    //       cookies, but in proper ordering.
    
    var result = Dictionary<String, String>()
    
    for rawCookie in extractStringCookieHeaderArray() {
      let cEqual : UInt8 = 61
      let ( name, value ) = rawCookie.splitPair(splitchar: cEqual)
      
      guard result[name] == nil else { continue } // multiple cookies same name
      result[name] = Cookie.decodeValue(value)
    }
    
    return result
  }
  
  /// Checks Host/X-Forwarded-Proto
  var isLikelySecureConnection : Bool {
    func equalsIgnoringASCIICase<C>(_ bytes: C, _ token: StaticString)
         -> Bool where C: Collection, C.Element == UInt8
    {
      guard bytes.count == token.utf8CodeUnitCount else { return false }
      return token.withUTF8Buffer { t in
        zip(bytes, t).allSatisfy { ( b: UInt8, t: UInt8 ) -> Bool in
          if b == t { return true }
          let isUpper = b >= 65 && b <= 90 // A-Z
          return isUpper && b + 32 == t
        }
      }
    }
    func firstListElement(of value: String.UTF8View , is token: StaticString) 
         -> Bool
    {
      let isSpace = { ( c: UInt8 ) in c == 32 || c == 9 }
      let element = value.prefix { $0 != 44 /* , */ }
      guard let start = element.firstIndex(where: { !isSpace($0) }),
            let last  = element.lastIndex (where: { !isSpace($0) })
      else {
        return false
      }
      return equalsIgnoringASCIICase(element[start...last], token)
    }
    
    if let proto = headers["X-Forwarded-Proto"].first,
       firstListElement(of: proto.utf8, is: "https")
    {
      return true
    }
    
    guard let host = headers["Host"].first?.utf8 else { return false }
    // Strip the port: `localhost:1339`, `[::1]:1339`
    let name = host.first == 91 /* [ */
        ? host.prefix(through: host.firstIndex(of: 93 /* ] */) ?? host.endIndex)
        : host.prefix(while: { $0 != 58 /* : */ })
    return equalsIgnoringASCIICase(name, "localhost")
        || equalsIgnoringASCIICase(name, "127.0.0.1")
        || equalsIgnoringASCIICase(name, "[::1]")
        || equalsIgnoringASCIICase(name.suffix(10), ".localhost")
  }

  func extractStringCookieHeaderArray() -> [ String ] {
    let cookieHeader = headers["Cookie"]
    return cookieHeader.reduce([], { $0 + splitCookieFields(headerValue: $1) })
  }
}
