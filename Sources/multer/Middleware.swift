//
//  Middleware.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import typealias connect.Middleware

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
    fatalError("NOT IMPLEMENTED")
  }
}
