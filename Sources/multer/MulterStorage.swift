//
//  MulterStorage.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import struct MacroCore.Buffer

public protocol MulterStorageContext {
  
  var config : multer { get }
  
  func handleError(_ error: Swift.Error)
}

public protocol MulterStorage {
  
  func startFile(_ file: multer.File, in context: MulterStorageContext)
  func endFile  (_ file: multer.File, in context: MulterStorageContext)

  func write(_ data: Buffer, to file: multer.File,
             in context: MulterStorageContext) throws
}
