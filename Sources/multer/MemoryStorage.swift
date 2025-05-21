//
//  MemoryStorage.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021-2025 ZeeZide GmbH. All rights reserved.
//

import struct MacroCore.Buffer

extension multer {

  /**
   * A ``MulterStorage`` that writes the file contents to the ``File/buffer``
   * property of the ``File`` object, i.e. stores it in-memory.
   */
  open class MemoryStorage: MulterStorage {
    // TBD: does this have to be a class?
    
    public init() {}
    
    // MARK: - Storage API

    @inlinable
    public func startFile(_ file: multer.File, in ctx: MulterStorageContext) {}
    @inlinable
    public func endFile  (_ file: multer.File, in ctx: MulterStorageContext) {}

    @inlinable
    public func write(_ data: Buffer, to file: multer.File,
                      in ctx: MulterStorageContext) throws
    {
      if let v = ctx.config.limits.fileSize {
        let newSize = (file.buffer?.count ?? 0) + data.count
        guard newSize <= v else {
          return ctx.handleError(MulterError.fileTooLarge)
        }
      }
      
      if nil == file.buffer?.append(data) { file.buffer = data }
    }
  }
}
