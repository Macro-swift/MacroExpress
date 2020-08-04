//
//  Logger.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 31/05/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum  MacroCore.process
import enum  MacroCore.console
import class http.IncomingMessage
import class http.ServerResponse
import xsys // timespec and extensions
#if os(Linux)
  import func Glibc.isatty
#else
  import func Darwin.isatty
#endif

// TODO: do some actual parsing of formats :-)

/// Logging middleware.
///
/// Currently accepts four formats:
/// - default
/// - short
/// - tiny
/// - dev    (colorized status)
///
public func logger(_ format: String = "default") -> Middleware {
  return { req, res, next in
    let startTS = timespec.monotonic()
    let fmt     = formats[format] ?? format
    
    func printLog() {
      let endTS = timespec.monotonic()
      let diff  = (endTS - startTS).milliseconds
      let info  = LogInfoProvider(req: req, res: res, diff: diff)
      var msg   = ""
      
      switch fmt {
        case formats["short"]!:
          msg += "\(info.remoteAddr) -"
          msg += " \"\(req.method) \(req.url) HTTP/\(req.httpVersion)\""
          msg += " \(info.status) \(info.clen)"
          msg += " - \(info.responseTime) ms"
        
        case formats["dev"]!:
          msg += "\(req.method) \(info.paddedURL)"
          msg += " \(info.colorStatus) \(info.clen)"
          let rts = "\(info.responseTime)"
          let rt = rts.count < 3
            ? rts.padding(toLength: 3, withPad: " ", startingAt: 0)
            : rts
          msg += " - \(rt) ms"
        
        case formats["tiny"]!:
          msg += "\(req.method) \(req.url)"
          msg += " \(info.status) \(info.clen)"
          msg += " - \(info.responseTime) ms"
        
        case formats["default"]!:
          fallthrough
        default:
          msg += "\(info.remoteAddr) - - [\(info.date)]"
          msg += " \"\(req.method) \(req.url) HTTP/\(req.httpVersion)\""
          msg += " \(info.status) \(info.clen)"
          msg += " \(info.qReferrer) \(info.qUA)"
      }
      
      // let msg = res.statusMessage ?? HTTPStatus.text(forStatus: res.statusCode!)
      console.log(msg)
    }
    
    _ = res.onceFinish { printLog() }
    next()
  }
}


private let formats = [
  "default":
    ":remote-addr - - [:date] \":method :url HTTP/:http-version\"" +
    " :status :res[content-length] \":referrer\" \":user-agent\"",
  "short":
    ":remote-addr - :method :url HTTP/:http-version" +
    " :status :res[content-length] - :response-time ms",
  "tiny": ":method :url :status :res[content-length] - :response-time ms",
  "dev":
     ":method :paddedurl :colorstatus :res[content-length] - :response-time ms"
]


private struct LogInfoProvider {
  
  let req  : IncomingMessage
  let res  : ServerResponse
  let diff : Int
  
  let noval        = "-"
  
  var remoteAddr   : String {
    guard let sock = req.socket         else { return noval }
    guard let addr = sock.remoteAddress else { return noval }
    return addr.description
  }
  var responseTime : String { return "\(diff)" }
  
  var ua           : String? { return req.headers["User-Agent"].first }
  var referrer     : String? { return req.headers["Referrer"]  .first }
  
  var qReferrer : String {
    guard let s = referrer else { return noval }
    return "\"\(s)\""
  }
  var qUA : String {
    guard let s = ua else { return noval }
    return "\"\(s)\""
  }
  
  var date  : String {
    // 31/May/2016:07:53:29 +0200
    let logdatefmt = "%d/%b/%Y:%H:%M:%S %z"
    let time = xsys.time(nil).componentsInLocalTime
    return "\(time.format(logdatefmt))"
  }
  
  var clen  : String {
    let clenI = Int((res.getHeader("Content-Length") as? String) ?? "") ?? -1
    return clenI >= 0 ? "\(clenI)" : noval
  }
  
  var status      : String {
    return res.statusCode > 0 ? "\(res.statusCode)" : noval
  }
  var colorStatus : String {
    let colorStatus : String
    
    // TODO: Add `isTTY` from Noze
    let isStdoutTTY = isatty(xsys.STDOUT_FILENO) != 0
    if isStdoutTTY || process.isRunningInXCode {
      colorStatus = self.status
    }
    else if res.statusCode > 0 {
      switch res.statusCode {
        case 200..<300: colorStatus = "\u{001B}[0;32m\(status)\u{001B}[0m"
        case 300..<400: colorStatus = "\u{001B}[0;34m\(status)\u{001B}[0m"
        case 400..<500: colorStatus = "\u{001B}[0;35m\(status)\u{001B}[0m"
        case 500..<600: colorStatus = "\u{001B}[0;31m\(status)\u{001B}[0m"
        default:        colorStatus = "\(status)"
      }
    }
    else {
      colorStatus = noval
    }
    
    return colorStatus
  }
  
  static var urlPadLen = 28
  var paddedURL : String {
    let url       = req.url
    let oldLength = url.count
    if oldLength > LogInfoProvider.urlPadLen {
      LogInfoProvider.urlPadLen = oldLength + ( oldLength % 2)
    }
    let padlen = LogInfoProvider.urlPadLen
    
    // right pad :-)
    let s = Array<Character>(repeating: " ", count: (padlen - oldLength))
    return url + String(s)
  }
}


// MARK: - X Compile Support - Macro/xsys/time.swift
// Dupe to support:
// https://github.com/SPMDestinations/homebrew-tap/issues/2

#if !os(Windows)
#if os(Windows)
  import WinSDK
#elseif os(Linux)
  import Glibc

  public typealias struct_tm = Glibc.tm
  public typealias time_t    = Glibc.time_t
  
  public let time          = Glibc.time
  public let gmtime_r      = Glibc.gmtime_r
  public let localtime_r   = Glibc.localtime_r
  public let strftime      = Glibc.strftime
  
#else
  import Darwin
  
  public typealias struct_tm = Darwin.tm
  public typealias time_t    = Darwin.time_t

  public let time          = Darwin.time
  public let gmtime_r      = Darwin.gmtime_r
  public let localtime_r   = Darwin.localtime_r
  public let strftime      = Darwin.strftime
#endif

/// The Unix `tm` struct is essentially NSDateComponents PLUS some timezone
/// information (isDST, offset, tz abbrev name).
internal extension xsys.struct_tm {
  
  /// Create a Unix date components structure from a timestamp. This variant
  /// creates components in the local timezone.
  init(_ tm: time_t) {
    self = tm.componentsInLocalTime
  }
  
  /// Create a Unix date components structure from a timestamp. This variant
  /// creates components in the UTC timezone.
  init(utc tm: time_t) {
    self = tm.componentsInUTC
  }
  
  var utcTime : time_t {
    var tm = self
    return timegm(&tm)
  }
  var localTime : time_t {
    var tm = self
    return mktime(&tm)
  }
  
  /// Example `strftime` format (`man strftime`):
  ///   "%a, %d %b %Y %H:%M:%S GMT"
  ///
  func format(_ sf: String, defaultCapacity: Int = 100) -> String {
    var tm = self
    
    // Yes, yes, I know.
    let attempt1Capacity = defaultCapacity
    let attempt2Capacity = defaultCapacity > 1024 ? defaultCapacity * 2 : 1024
    var capacity = attempt1Capacity
    
    var buf = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
    #if swift(>=4.1)
      defer { buf.deallocate() }
    #else
      defer { buf.deallocate(capacity: capacity) }
    #endif
  
    let rc = xsys.strftime(buf, capacity, sf, &tm)
  
    if rc == 0 {
      #if swift(>=4.1)
        buf.deallocate()
      #else
        buf.deallocate(capacity: capacity)
      #endif
      capacity = attempt2Capacity
      buf = UnsafeMutablePointer<CChar>.allocate(capacity: capacity)
  
      let rc = xsys.strftime(buf, capacity, sf, &tm)
      assert(rc != 0)
      guard rc != 0 else { return "" }
    }
  
    return String(cString: buf);
  }
}

#endif // !os(Windows)
