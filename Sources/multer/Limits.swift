//
//  Limits.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

public extension multer {
  
  struct Limits {
    
    /// Maximum size of field names (100 bytes)
    public var fieldNameSize : Int? = 100
    
    /// Maximum size of field value (1MB)
    public var fieldSize     : Int? = 1024 * 1024
    
    /// Maximum number of non-file fields (unlimited)
    public var fields        : Int? = nil
    
    /// Max file size (unlimited)
    public var fileSize      : Int? = nil
    
    /// Maximum number of file fields (unlimited)
    public var files         : Int? = nil
    
    /// Maximum number of header fields (2000)
    /// Note: This is not checked yet.
    public var headerPairs   : Int? = 2000
    
    public init(fieldNameSize : Int? = 100,
                fieldSize     : Int? = 1024 * 1024,
                fields        : Int? = nil,
                fileSize      : Int? = nil,
                files         : Int? = nil,
                headerPairs   : Int? = 2000)
    {
      self.fieldNameSize = fieldNameSize
      self.fieldSize     = fieldSize
      self.fields        = fields
      self.fileSize      = fileSize
      self.files         = files
      self.headerPairs   = headerPairs
    }
  }
}
