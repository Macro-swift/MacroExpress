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
      
      // TODO: extract the boundary!
      assertionFailure("TODO: boundary!")
      
      // Interact properly w/ bodyParser
      switch req.body {
        case .json, .urlEncoded, .text:
          return next() // already parsed as another type
        
        case .noBody, .error: // already parsed as nothing or error
          return next()
      
        case .notParsed:
          handle(request: req, response: res, next: next)
          
        case .raw(let bytes):
          handle(request: req, response: res, content: bytes, next: next)
      }
    }
  }
  
  private func handle(request  : IncomingMessage,
                      response : ServerResponse,
                      content  : Buffer? = nil,
                      next     : @escaping Next)
  {
    // content is set if the body was already loaded using a bodyParser
    // TODO: here we need to
    // - setup the parser
    // - wait for content if necessary (a stream!)
    
    // TBD: maybe wrap all that in a class?
    
    var parser = MultiPartParser(boundary: "TODO")
    // TODO: provide a callback
    
    func handleEvent(_ event: MultiPartParser.Event) {
      fatalError("NOT IMPLEMENTED")
    }
    
    if let content = content {
      parser.write(content, handler: handleEvent)
      parser.end(handler: handleEvent)
    }
    else {
      request.onReadable {
        let data = request.read()
        parser.write(data, handler: handleEvent)
      }
      request.onEnd {
        parser.end(handler: handleEvent)
      }
    }
  }
}
