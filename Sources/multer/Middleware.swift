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
   * Accept text fields only.
   *
   * Emits a `limitUnexpectedFile` error if a file is encountered.
   *
   * - Returns: The middleware to parse the form data.
   */
  static func none() -> Middleware {
    fatalError("NOT IMPLEMENTED")
  }
  /**
   * Accept all incoming files. The files will be available in the
   * `request.files` property.
   *
   * - Returns: The middleware to parse the form data.
   */
  static func any() -> Middleware {
    fatalError("NOT IMPLEMENTED")
  }
  
  static func fields(_ fields: [ ( fieldName: String, maxCount: Int? ) ])
              -> Middleware
  {
    fatalError("NOT IMPLEMENTED")
  }
}

public extension multer {

  /**
   * Accept a single file for the specific `fieldName`.
   *
   * - Parameter fieldName: The name of the form field associated with a file.
   * - Returns: The middleware to parse the form data.
   */
  @inlinable
  static func single(_ fieldName: String) -> Middleware {
    return array(fieldName, 1)
  }
  
  /**
   * Accept a set of files for the specific `fieldName`.
   *
   * - Parameter fieldName: The name of the form field associated with the files.
   * - Returns: The middleware to parse the form data.
   */
  @inlinable
  static func array(_ fieldName: String, _ maxCount: Int? = nil) -> Middleware {
    return fields([ ( fieldName, maxCount )])
  }  
}
