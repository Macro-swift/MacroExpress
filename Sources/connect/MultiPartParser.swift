//
//  MultiPartParser.swift
//  MacroExpress
//
//  Created by Helge Heß
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import struct NIO.ByteBuffer
import struct NIO.ByteBufferView
import struct MacroCore.Buffer
import class  MacroCore.MacroCore

fileprivate struct Chars {
  
  static let dash : UInt8 = 45
  static let CR   : UInt8 = 13
  static let LF   : UInt8 = 10
  static let SP   : UInt8 = 32
  static let HTAB : UInt8 = 0x09
  
  static let CRLFCRLF : [ UInt8 ] = [ CR, LF, CR, LF ]
}

/**
 * This parser splits a multipart body into its (top level) segments. The
 * segments have a header and a (binary) body.
 */
public struct MultiPartParser {
  // This is not entirely correct and can't be used for arbitrary MIME parts
  // yet. E.g. it doesn't support wrapped header lines.
  // https://github.com/Macro-swift/MacroExpress/issues/7
  // https://tools.ietf.org/html/rfc7578
  
  enum State {
    case preamble
    case postamble
    case header
    case body
    case fatalError(ParseError)
  }
  
  public enum ParseError: Swift.Error {
    case maximumHeaderLengthExceeded(allowed: Int, buffered: Int)
    case charsetError(Swift.Error)
    case invalidHeaderLine(String)
    case failedToParseHeader
  }
  
  public enum Event {
    case preambleData (Buffer)
    case postambleData(Buffer)
    case startPart    ([ ( name: String, value: String ) ])
    case bodyData     (Buffer)
    case endPart
    case parseError   (ParseError)
  }
  public typealias Handler = ( Event ) -> Void
  
  let boundary        : [ UInt8 ] // including the initial `--`, excluding CRLF
  let boundaryLength  : Int
  let maxHeaderLength : Int
  let headerEncoding  : String.Encoding
  
  var state           = State.preamble
  var buffer          : Buffer?
  
  /**
   * - Argument boundary: The plain boundary w/o the two leading dashes
   */
  public init(boundary        : String,
              headerEncoding  : String.Encoding = .utf8,
              maxHeaderLength : Int = 4096)
  {
    self.headerEncoding  = headerEncoding
    self.maxHeaderLength = maxHeaderLength
    self.boundary        = [ UInt8 ]([ Chars.dash, Chars.dash ] + boundary.utf8)
    self.boundaryLength  = self.boundary.count
  }
  
  
  // MARK: - Buffer
  
  private mutating func stage(_ buffer: Buffer) {
    if nil == self.buffer?.append(buffer) { self.buffer = buffer }
  }
  private mutating func unstage(with bytes: Buffer) -> Buffer {
    guard var input = self.buffer else { return bytes }
    self.buffer = nil
    input.append(bytes)
    return input
  }
  

  // MARK: - API

  public mutating func write(_ bytes: Buffer, handler: Handler) {
    parse(bytes, handler: handler)
  }

  public mutating func end(handler: Handler) {
    finish(handler: handler)
  }
  
  
  // MARK: - Parsing

  private mutating func finish(handler: Handler) {
    // Note: We need no 'done' event, because the consumer itself pushes the
    //       finish.
    let trailer = unstage(with: Buffer(capacity: 0))
    switch state {
      case .fatalError:
        break
      case .preamble  : if !trailer.isEmpty { handler(.preambleData (trailer)) }
      case .postamble : if !trailer.isEmpty { handler(.postambleData(trailer)) }
      case .header: handler(.parseError(ParseError.failedToParseHeader))
      case .body:
        if !trailer.isEmpty { handler(.bodyData(trailer)) }
        handler(.endPart)
    }
  }

  private mutating func parse(_ bytes: Buffer, handler: Handler) {
    guard !bytes.isEmpty else { return }
    
    switch state {
    
      case .fatalError(let error):
        handler(.parseError(error))
    
      case .preamble:
        switch parseBoundary(bytes, content: { .preambleData($0) }, handler) {
          case .notFound:
            break
            
          case .found(let remainder):
            state = .header
            parse(remainder, handler: handler)
            
          case .foundEnd(let remainder):
            state = .postamble
            parse(remainder, handler: handler)
        }
        
      case .header:
        switch parseHeader(bytes) {
          case .needMoreData:
            break
          case .error(let error):
            state = .fatalError(error)
            handler(.parseError(error))
          case .header(let header, let remainder):
            handler(.startPart(header))
            state = .body
            parse(remainder, handler: handler)
        }
        
      case .body:
        switch parseBoundary(bytes, content: { .bodyData($0) }, handler) {
          case .notFound:
            break
            
          case .found(let remainder):
            handler(.endPart)
            state = .preamble
            parse(remainder, handler: handler)
            
          case .foundEnd(let remainder):
            handler(.endPart)
            state = .postamble
            parse(remainder, handler: handler)
        }

      case .postamble:
        let input = unstage(with: bytes)
        if !input.isEmpty { handler(.postambleData(input)) }
    }
  }
  
  
  // MARK: - Header Parser
  
  private enum HeaderParseResult {
    case needMoreData
    case header([ ( name: String, value: String ) ], remainder: Buffer)
    case error (ParseError)
  }
  
  private let fallbackEncoding : String.Encoding = .isoLatin1
  
  private mutating func parseHeader(_ data: Buffer) -> HeaderParseResult {
    let input = unstage(with: data)
    guard input.count < maxHeaderLength else {
      stage(input) // TBD
      return .error(.maximumHeaderLengthExceeded(allowed: maxHeaderLength,
                                                 buffered: input.count))
    }
    
    func needMoreData() -> HeaderParseResult {
      stage(input) // incomplete, wait for more data
      return .needMoreData
    }
    
    let idx = input.indexOf(Chars.CRLFCRLF) // TODO: support LFLF?
    guard idx >= 0 else  { return needMoreData() }
    
    let headerData = input.slice(0, idx)
    let remainder  = input.slice(idx + 4)
    
    let headerString : String
    do {
      headerString = try headerData.toString(headerEncoding)
    }
    catch {
      if headerEncoding != fallbackEncoding,
         let s = try? headerData.toString(fallbackEncoding)
      {
        headerString = s
      }
      else { return .error(.charsetError(error)) }
    }
    
    // Yes, naive parser, header lines could be wrapped etc
    let headerLines = headerString.components(separatedBy: "\r\n")
    var header = [ ( name: String, value: String ) ]()
    header.reserveCapacity(headerLines.count)
    
    for line in headerLines {
      guard let idx = line.firstIndex(of: ":") else {
        return .error(.invalidHeaderLine(line))
      }
      let name  = line[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else {
        return .error(.invalidHeaderLine(line))
      }
      let value = line[line.index(after: idx)...]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
      header.append( ( name: name, value: value ) )
    }
    
    return .header(header, remainder: remainder)
  }
  
  // MARK: - Boundary Parser
  
  private enum BoundaryParseResult {
    case notFound
    case found   (remainder: Buffer)
    case foundEnd(remainder: Buffer)
  }
  
  private mutating func parseBoundary(_   bytes : Buffer,
                                      content   : ( Buffer ) -> Event,
                                      _ handler : Handler)
                        -> BoundaryParseResult
  {
    let input = unstage(with: bytes)
    
    let idx = input.indexOf(boundary, options: .partialSuffixMatch)
    if idx < 0 {
      handler(content(input))
      return .notFound
    }
    
    if idx > 0 { handler(content(input.slice(0, idx))) }
    let remainder = idx > 0 ? input.slice(idx) : input
    
    func needMoreData() -> BoundaryParseResult {
      stage(remainder) // incomplete, wait for more data
      return .notFound
    }
    func uselessTrailer() -> BoundaryParseResult {
      // TBD: What if the boundary is just dashes, would be recurse too much?
      //      => unroll
      // This must be true:
      assert(remainder[0] == Chars.dash)
      assert(remainder[1] == Chars.dash)
      handler(content(remainder.slice(0, 1)))
      return parseBoundary(remainder.slice(1), content: content, handler)
    }
    
    
    /* attempt to parse trailer, can contain transport spacing */
    var cursor = boundaryLength
    let len    = remainder.count
    guard cursor < len else { return needMoreData() }
        
    let isClose : Bool
    if remainder[cursor] == Chars.dash { // check for close delimiter
      cursor += 1
      guard cursor < len                    else { return needMoreData() }
      guard remainder[cursor] == Chars.dash else { return uselessTrailer() }
      isClose = true
    }
    else { // check for regular delimiter
      isClose = false
    }
    
    // Transport Padding
    while cursor < len { // skip spaces & tabs
      // Strictly speaking LWSP also consumes CRLF when followed by a SP/HTAB!
      let c = remainder[cursor]
      if c != Chars.SP && c != Chars.HTAB { break }
      cursor += 1
    }
    guard cursor < len else { return needMoreData() }
    
    // Consume CR. Note: We allow just LF as the end marker
    if remainder[cursor] == Chars.CR {
      cursor += 1
      guard len > cursor else { return needMoreData() }
    }
    
    guard remainder[cursor] == Chars.LF else { return uselessTrailer() }
    cursor += 1
    
    if isClose {
      return .foundEnd(remainder: remainder.slice(cursor))
    }
    else {
      return .found(remainder: remainder.slice(cursor))
    }
  }
}

extension MultiPartParser.Event: CustomStringConvertible {
  
  public var description: String {
    switch self {
      case .preambleData (let buffer): return "<Preamble: \(buffer)>"
      case .postambleData(let buffer): return "<Postamble: \(buffer)>"
      case .bodyData     (let buffer): return "<PartBody: \(buffer)>"

      case .startPart(let header):
        let s = header.map { "\($0.name)=\($0.value)" }.joined(separator: ",")
        return "<StartPart: \(s)>"
      case .endPart: return "<EndPart>"
        
      case .parseError(let error):
        return "<ParseError: \(error)>"
    }
  }
}

extension MultiPartParser.ParseError: Equatable {
  
  public static func ==(lhs: MultiPartParser.ParseError,
                        rhs: MultiPartParser.ParseError) -> Bool
  {
    switch ( lhs, rhs ) {
      case ( .maximumHeaderLengthExceeded(let l1, let l2),
             .maximumHeaderLengthExceeded(let r1, let r2)):
        return (l1 == r1) && (l2 == r2)
      case ( .charsetError, .charsetError ):
        return true
      case ( .failedToParseHeader, .failedToParseHeader ):
        return true
      case ( .invalidHeaderLine(let lhs), .invalidHeaderLine(let rhs)):
        return lhs == rhs
      default:
        return false
    }
  }
}

extension MultiPartParser.Event: Equatable {
  
  public static func ==(lhs: MultiPartParser.Event,
                        rhs: MultiPartParser.Event) -> Bool
  {
    switch ( lhs, rhs ) {
      case ( .preambleData(let lhs), .preambleData(let rhs)):
        return lhs == rhs
      case ( .postambleData(let lhs), .postambleData(let rhs)):
        return lhs == rhs
      case ( .bodyData(let lhs), .bodyData(let rhs)):
        return lhs == rhs
        
      case ( .startPart(let lhs), .startPart(let rhs)):
        guard lhs.count == rhs.count else { return false }
        for ( idx, ( nl, vl )) in lhs.enumerated() {
          let ( nr, vr ) = rhs[idx]
          guard (nl == nr) && (vl == vr) else { return false }
        }
        return true
        
      case ( .endPart, .endPart ): return true
        
      case ( .parseError(let lhs), .parseError(let rhs) ): // Hm
        return lhs == rhs
        
      default:
        return false
    }
  }
}
