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
   * - ``single(_:)``:  accept just one file for the specified name
   * - ``array(_:_:)``: accept just multiple files for the specified name
   * - ``none()``:      accept no file, just form regular fields
   * - ``any()``:       accept all files, careful!
   *
   * All convenience methods call into this middleware.
   *
   * ### Restrictions
   *
   * If not restrictions are set, only the limits in the `multer` config apply.
   * If restrictions are set, an incoming file part MUST be listed, otherwise
   * the middleware will fail with an error.
   *
   *
   * - Parameter fields: An optional set of restrictions on fields containing
   *                     files.
   * - Returns: The middleware to parse the form data.
   */
  func fields(_ fields: [ ( fieldName: String, maxCount: Int? ) ]?)
       -> Middleware
  {
    let restrictions = fields.flatMap { Dictionary(tolerantPairs: $0) }
    
    return { req, res, next in
      guard typeIs(req, [ "multipart/form-data" ]) != nil else { return next() }

      guard let ctype    = req.headers["Content-Type"].first,
            let boundary = extractHeaderArgument("boundary", from: ctype)
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
                            multer: self, restrictions: restrictions,
                            next: next)
          req.onReadable {
            let data = req.read()
            ctx.write(data)
          }
          req.onError(execute: ctx.handleError)
          req.onEnd  (execute: ctx.finish)
          
        case .raw(let bytes):
          let ctx = Context(request: req, response: res, boundary: boundary,
                            multer: self, restrictions: restrictions,
                            next: next)
          ctx.write(bytes)
          ctx.finish()
      }
    }
  }
}
