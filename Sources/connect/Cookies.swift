//
//  Cookies.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 10/06/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum  MacroCore.console
import class http.IncomingMessage
import class http.ServerResponse

// "Set-Cookie:" Name "=" Value *( ";" Attribute)
// "Cookie:"     Name "=" Value *( ";" Name "=" Value)
//
// TODO:
// - do proper RFC 2109, add quoting and such.
// - add signing ala keygrip
// - support for `secure` (only use with https)

/// Module and object at the same time
///
/// Usage:
///
///    let cookies = Cookies(req, res)
///
///    cookies.set("theAnswer", "42")           // set a cookie
///    if let answer = cookies.get("theAnswer") // get a cookie
///
public final class Cookies {
  
  public let res : ServerResponse?
  
  public let cookies : [ String : String ]
  
  public init(_ req: IncomingMessage, _ res: ServerResponse? = nil) {
    self.res = res
    
    // request values we care about
    self.cookies  = req.extractStringCookieDictionary()
  }
  
  
  // get/set funcs
  
  public func get(_ name: String) -> String? {
    return cookies[name]
  }
  
  public func set(cookie c: Cookie) {
    guard res != nil else {
      console.warn("attempt to set cookie, but got no response object!")
      return
    }
    res!.setHeader("Set-Cookie", c.description)
  }
  
  public func set(_ name: String, _ value: String,
                  path     : String? = "/",
                  httpOnly : Bool    = true,
                  domain   : String? = nil,
                  comment  : String? = nil,
                  expires  : Date?   = nil,
                  maxAge   : Int?    = nil)
  {
    // TODO:
    // - check `secure`. Node has `req.protocol` == https ?
    
    let cookie = Cookie(name:   name,   value:    value,
                        path:   path,   httpOnly: httpOnly,
                        domain: domain, comment:  comment,
                        maxAge: maxAge, expires:  expires)
    set(cookie: cookie)
  }
  
  public func reset(_ name: String) {
    set(cookie: Cookie(name: name, maxAge: 0))
  }
  
  // subscript
  
  public subscript(name : String) -> String? {
    set {
      if let newValue = newValue {
        set(name, newValue)
      }
      else {
        console.error("attempt to set nil-value cookie: \(name), ignoring.")
      }
    }
    get {
      return get(name)
    }
  }
}

public let cookies = Cookies.self

// MARK: - Internals

import struct Foundation.Date

public struct Cookie {
  public let name     : String
  public var value    : String
  public var path     : String?
  public var httpOnly : Bool
  public var domain   : String?
  public var comment  : String?
  public var maxAge   : Int?    // in seconds
  public var expires  : Date?
  // let secure : Bool
  
  public init(name: String, value: String = "",
              path     : String? = "/",
              httpOnly : Bool    = true,
              domain   : String? = nil,
              comment  : String? = nil,
              maxAge   : Int?    = nil,
              expires  : Date?   = nil)
  {
    self.name     = name
    self.value    = value
    self.path     = path
    self.httpOnly = httpOnly
    self.domain   = domain
    self.comment  = comment
    self.maxAge   = maxAge
    self.expires  = expires
  }
}

import struct xsys.time_t

public extension Cookie {
  
  var httpHeaderValue: String {
    // TODO: quoting
    var s = "\(name)=\(value)"
    
    if let v = path    { s += "; Path=\(v)"    }
    if let v = domain  { s += "; Domain=\(v)"  }
    if let v = comment { s += "; Comment=\(v)" }
    if let v = maxAge  { s += "; Max-Age=\(v)" }
    
    if let v = expires {
      s += "; expires="
      
      func generateDateHeader(timestamp ts: time_t) -> String {
        // TBD: %Z emits UTC
        let HTTPDateFormat = "%a, %d %b %Y %H:%M:%S GMT"
        return ts.componentsInUTC.format(HTTPDateFormat)
      }
      
      s += generateDateHeader(timestamp: time_t(v.timeIntervalSince1970))
    }
    
    return s
  }
}

extension Cookie : CustomStringConvertible {
  public var description: String {
    return httpHeaderValue
  }
}

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
    // TODO: using describing here is wrong
    let s0 = splits[0], s1 = splits[1]
    return ( String(describing: s0), String(describing: s1) )
  }
}

private func splitCookieFields(headerValue v: String) -> [ String ] {
  return v.splitAndTrim(splitchar: 59) // semicolon
}

private extension IncomingMessage {

  func extractStringCookieDictionary() -> [ String : String ] {
    // Note: This just picks the first cookie! Newer clients send multiple
    //       cookies, but in proper ordering.
    
    var result = Dictionary<String, String>()
    
    for rawCookie in extractStringCookieHeaderArray() {
      let cEqual : UInt8 = 61
      let ( name, value ) = rawCookie.splitPair(splitchar: cEqual)
      
      guard result[name] == nil else { continue } // multiple cookies same name
      result[name] = value
    }
    
    return result
  }
  
  func extractStringCookieHeaderArray() -> [ String ] {
    let cookieHeader = headers["Cookie"]
    return cookieHeader.reduce([], { $0 + splitCookieFields(headerValue: $1) })
  }
}
