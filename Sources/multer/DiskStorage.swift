//
//  MemoryStorage.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import struct MacroCore.Buffer
import class  http.IncomingMessage

extension multer {
  
  @available(*, unavailable, message: "DiskStorage is not working yet.")
  open class DiskStorage: MulterStorage {
    
    // TODO: This needs API changes for async in the `MulterStorage` to account
    //       for sync writes. The disk storage needs to async write files using
    //       a file stream or the the NIO disk I/O, and only call `next` when
    //       all files are done.
    //       `File` is intentionally an object already, so that the Disk storage
    //       can reconcile operations.
    
    public typealias DestinationSelector =
      ( IncomingMessage, File, @escaping ( Swift.Error?, String ) -> Void )
      -> Void
    
    public typealias FilenameSelector =
      ( IncomingMessage, File, @escaping ( Swift.Error?, String ) -> Void )
      -> Void

    public let destination : DestinationSelector
    public let filename    : FilenameSelector?
    
    public init(destination : @escaping DestinationSelector,
                filename    : FilenameSelector? = nil)
    {
      self.destination = destination
      self.filename    = filename
    }
    
    public convenience init(dest: String) {
      self.init(destination: { req, file, yield in
        yield(nil, dest)
      })
    }
    
    
    // MARK: - Storage API

    public func startFile(_ file: multer.File, in ctx: MulterStorageContext) {
    }
    public func endFile  (_ file: multer.File, in ctx: MulterStorageContext) {
    }

    public func write(_ data: Buffer, to file: multer.File,
                      in ctx: MulterStorageContext) throws
    {
    }
  }
}
