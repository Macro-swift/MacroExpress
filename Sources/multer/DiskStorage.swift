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
  
  open class DiskStorage: MulterStorage {
    
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
