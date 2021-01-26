//
//  Multer.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import MacroCore
import http
import connect


/**
 * Middleware to parse `multipart/form-data` payloads.
 *
 * E.g. files submitted using an HTML form like:
 *
 *     <form action="/upload" method="POST" enctype="multipart/form-data">
 *       <input type="file" name="file" multiple="multiple" />
 *       <input type="submit" value="Upload" />
 *     </form>
 *
 * Roughly designed after the Node
 * [multer](https://github.com/expressjs/multer#readme)
 * package.
 */
public struct multer {
  
  public typealias FileFilter =
    ( IncomingMessage, File, @escaping ( Swift.Error?, Bool ) -> Bool ) -> Void
  
  public var storage    : MulterStorage
  public var fileFilter : FileFilter?
  public var limits     : Limits
  public var dest       : String?
  
  
  // MARK: - Init
  
  #if false // Swift 5.0 is not clever enough to consider the nested unavail
  @available(*, unavailable, message: "DiskStorage is not working yet.")
  @inlinable
  public init(storage    : MulterStorage? = nil,
              dest       : String,
              limits     : Limits         = Limits(),
              fileFilter : FileFilter?    = nil)
  {
    self.dest       = dest
    self.fileFilter = fileFilter
    self.limits     = limits
    self.storage    = storage ?? DiskStorage(dest: dest)
  }
  #endif

  @inlinable
  public init(storage    : MulterStorage? = nil,
              limits     : Limits         = Limits(),
              fileFilter : FileFilter?    = nil)
  {
    self.dest       = nil
    self.fileFilter = fileFilter
    self.limits     = limits
    self.storage    = storage ?? MemoryStorage()
  }
}

public extension multer { // MARK: - Storage Factory
  
  @inlinable
  static func memoryStorage() -> MemoryStorage {
    return MemoryStorage()
  }
  
  #if false // Swift 5.0 is not clever enough to consider the nested unavail
  @available(*, unavailable, message: "DiskStorage is not working yet.")
  @inlinable
  static
  func diskStorage(destination : @escaping DiskStorage.DestinationSelector,
                   filename    : DiskStorage.FilenameSelector? = nil)
       -> DiskStorage
  {
    return DiskStorage(destination: destination, filename: filename)
  }
  #endif
}


public extension multer { // MARK: - Middleware Convenience

  /**
   * Accept a single file for the specific `fieldName`.
   *
   * - Parameter fieldName: The name of the form field associated with a file.
   * - Returns: The middleware to parse the form data.
   */
  @inlinable
  func single(_ fieldName: String) -> Middleware {
    return fields([ ( fieldName, 1 )])
  }
  
  /**
   * Accept a set of files for the specific `fieldName`.
   *
   * - Parameter fieldName: The name of the form field associated with the files.
   * - Returns: The middleware to parse the form data.
   */
  @inlinable
  func array(_ fieldName: String, _ maxCount: Int? = nil) -> Middleware {
    return fields([ ( fieldName, maxCount )])
  }

  /**
   * Accept text fields only.
   *
   * Emits a `limitUnexpectedFile` error if a file is encountered.
   *
   * - Returns: The middleware to parse the form data.
   */
  @inlinable
  func none() -> Middleware {
    return fields([])
  }
  /**
   * Accept all incoming files. The files will be available in the
   * `request.files` property.
   *
   * - Returns: The middleware to parse the form data.
   */
  @inlinable
  func any() -> Middleware {
    return fields(nil)
  }
}
