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
  
  @inlinable
  public init(storage    : MulterStorage? = nil,
              dest       : String?        = nil,
              limits     : Limits         = Limits(),
              fileFilter : FileFilter?    = nil)
  {
    self.dest       = dest
    self.fileFilter = fileFilter
    self.limits     = limits
    self.storage    = storage ?? {
      if let dest = dest { return DiskStorage(dest: dest) }
      else               { return MemoryStorage()         }
    }()
  }
  
  
  // MARK: - Storage Factory
  
  @inlinable
  public static func memoryStorage() -> MemoryStorage {
    return MemoryStorage()
  }
  
  @inlinable
  public static
  func diskStorage(destination : @escaping DiskStorage.DestinationSelector,
                   filename    : DiskStorage.FilenameSelector? = nil)
       -> DiskStorage
  {
    return DiskStorage(destination: destination, filename: filename)
  }

}
