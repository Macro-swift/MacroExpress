//
//  Middleware.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import struct MacroCore.Buffer
import http
import connect

public extension multer {
  
  /**
   * Parse `multipart/form-data` form fields with a set of restrictions.
   *
   * There are multiple convenience methods to restrict the set of fields to
   * accept:
   * - `single(fieldName)` (accept just one file for the specified name)
   * - `array(fieldName)`  (accept just multiple files for the specified name)
   * - `none`              (accept no file, just form regular fields)
   * - `any`               (accept all files, careful!)
   *
   * All convenience methods call into this middleware.
   *
   * - Parameter fields: An optional set of restrictions on fields containing
   *                     files.
   * - Returns: The middleware to parse the form data.
   */
  func fields(_ fields: [ ( fieldName: String, maxCount: Int? ) ]?)
       -> Middleware
  {
    return { req, res, next in
      guard typeIs(req, [ "multipart/form-data" ]) != nil else { return next() }

      guard let ctype    = req.headers["Content-Type"].first,
            let boundary = extractHeaderArgument(for: "boundary", from: ctype)
      else {
        req.log.warn("missing boundary in multipart/form-data",
                     req.getHeader("Content-Type") ?? "-")
        return next()
      }
      
      // Interact properly w/ bodyParser
      switch req.body {
        case .json, .urlEncoded, .text:
          return next() // already parsed as another type
        
        case .noBody, .error: // already parsed as nothing or error
          return next()
          
        case .notParsed:
          let ctx = Context(request: req, response: res, boundary: boundary,
                            multer: self, next: next)
          req.onReadable {
            let data = req.read()
            ctx.write(data)
          }
          req.onError(execute: ctx.handleError)
          req.onEnd  (execute: ctx.finish)
          
        case .raw(let bytes):
          let ctx = Context(request: req, response: res, boundary: boundary,
                            multer: self, next: next)
          ctx.write(bytes)
          ctx.finish()
      }
    }
  }
  
  private final class Context {
    
    let multer   : multer
    let request  : IncomingMessage
    let response : ServerResponse
    var next     : Next?
    var parser   : MultiPartParser
    
    init(request  : IncomingMessage,
         response : ServerResponse,
         boundary : String,
         multer   : multer,
         next     : @escaping Next)
    {
      self.request  = request
      self.response = response
      self.next     = next
      self.multer   = multer
      self.parser   = MultiPartParser(boundary: boundary)
      
      #if DEBUG && true
        print("BOUNDARY:", boundary)
      #endif
    }
    
    func finish() {
      parser.end(handler: handleEvent)
      
      // TODO: push parsed values (Buffer's still!)
      // check '_charset_' form value for charset
      // Body.urlEncoded([ String : Any ])
      // values & files
      
      guard let next = next else { return }
      next()
      self.next = nil
    }
    func write(_ bytes: Buffer) { parser.write(bytes, handler: handleEvent) }
    
    func handleError(_ error: Swift.Error) {
      if case .notParsed = request.body { request.body = .error(error) }
      guard let next = next else { return }
      next(error)
      self.next = nil
    }
    
    
    // MARK: - Parser
    
    enum Value {
      case single  (Buffer)
      case multiple([ Buffer ])
    }
    
    var values   = [ String : Value ]()
    var files    = [ String : [ File ]]()
    var header   : [ ( name: String, value: String ) ]?
    var bodyData : Buffer?
    
    private func finishPart() {
      defer { header = nil; bodyData = nil }
      guard let header = header else { return }
      request.log.log("end part:", header, bodyData, values)
    }
    
    func handleEvent(_ event: MultiPartParser.Event) {
      guard next != nil else {
        return request.log
          .warn("multipart parse event, but next has been called:", event)
      }
      
      #if DEBUG && true
        print("EVENT:", event)
      #endif
      
      // TODO: this needs to write into the storage
      switch event {
        case .parseError(let error):
          request.log.error("multipart/form-data parse error:", error)
          handleError(error)
        case .preambleData(let buffer):
          request.log.log("ignoring multipart preamble:", buffer)
        case .postambleData(let buffer):
          request.log.log("ignoring multipart postamble:", buffer)
        
        case .startPart(let header):
          // TODO: create file or form value. We get:
          //   Content-Disposition: form-data; name="file"; filename="abc.csv"
          //   Content-Type:        application/octet-stream
          // TODO: how do we differentiate file and regular form field?
          //       by 'filename', or 'content-type'?
          //       By Content-type is not text/plain?? or filename is set?
          // Note: As per RFC 7578:
          // - each part _must_ have a form-data Content-Disposition.
          // - "filename" is optional
          // - Content-Type defaults to 'text/plain', can have charset
          // - can have Content-Transfer-Encoding, e.g. quoted-printable
          //   - not used in practice
          // - there can be a special `_charset_` form value carrying the
          //   default charset (e.g. 'iso-8859-1')
          finishPart() // close existing
          
          request.log.log("start:", header)
          
          // FIXME: how do we distinguish
          
          self.header = header
          
        case .endPart:
          finishPart()
          
        case .bodyData(let data):
          // stream to storage?
          request.log.log("body data:", data)
      }
    }
  }
}

fileprivate func extractHeaderArgument(for header: String, from value: String)
                 -> String?
{
  // Naive version, which we had structured headers ;-)
  // multipart/form-data; boundary="abc"
  // multipart/form-data; boundary=abc
  let parts = value
    .split(separator: ";", maxSplits: 20, omittingEmptySubsequences: true)
    .map { $0.trimmingCharacters(in: .whitespaces) }
  
  guard let boundary = parts.first(where: { $0.hasPrefix("\(header)=")})?
                            .dropFirst(9)
                            .trimmingCharacters(in: .whitespaces),
        !boundary.isEmpty
  else {
    return nil
  }
  
  assert(boundary.count > 5, "Unexpected short boundary: \(boundary)")
  
  if boundary.first == "\"" {
    guard boundary.count > 2 && boundary.last == "\"" else {
      assertionFailure("Unexpected header value quoting in: \(value)")
      return nil
    }
    return String(boundary.dropFirst().dropLast())
  }
  
  return boundary
}
