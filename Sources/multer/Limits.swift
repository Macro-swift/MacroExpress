//
//  Limits.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021-2025 ZeeZide GmbH. All rights reserved.
//

public extension multer {
  
  /**
   * Upload limits configuration for multer.
   * 
   * This allows to configure file size or count limits. And various other 
   * limits.
   */
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
    
    /**
     * Create a new multer limits configuration.
     * 
     * All parameters are optional, defaults:
     * - field name size: 100
     * - field size:      1MB
     * - header pairs:    2000
     * 
     * - Parameters:
     *   - fieldNameSize: Maximum size of field names (100 bytes)
     *   - fieldSize:     Maximum size of field value (1MB)
     *   - fields:        Maximum number of non-file fields (unlimited)
     *   - fileSize:      Max file size (unlimited)
     *   - files:         Maximum number of file fields (unlimited)
     *   - headerPairs:   Maximum number of header fields (2000)
     */
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
