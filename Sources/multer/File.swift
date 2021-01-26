//
//  File.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import struct MacroCore.Buffer

public extension multer {
  
  final class File: Equatable {
    
    /// Name in form field
    public var fieldName    : String
    
    /// Name of file (filename in content-disposition)
    public var originalName : String

    // TBD: encoding?
    
    /**
     * MIME type of the file - as declared by the browser/user-agent, e.g.
     * `image/png` or `application/octet-stream`.
     * Defaults to the latter if not found.
     */
    public var mimeType : String
    
    /**
     * The path of the file on the local filesystem, if available. I.e. when
     * used together with the disk storage.
     */
    public var path : String?
    
    /**
     * The Buffer of the file, if loaded into memory. I.e. when used together
     * with the memory storage.
     */
    public var buffer : Buffer?
    
    @inlinable
    public init(fieldName    : String,
                originalName : String,
                mimeType     : String,
                path         : String? = nil,
                buffer       : Buffer? = nil)
    {
      self.fieldName    = fieldName
      self.originalName = originalName
      self.mimeType     = mimeType
      self.path         = path
      self.buffer       = buffer
    }
    
    @inlinable
    public static func ==(lhs: File, rhs: File) -> Bool {
      return lhs.fieldName    == rhs.fieldName
          && lhs.originalName == rhs.originalName
          && lhs.mimeType     == rhs.mimeType
          && lhs.path         == rhs.path
          && lhs.buffer       == rhs.buffer
    }
  }
}

#if canImport(Foundation)

import struct Foundation.URL

public extension multer.File {
  
  /**
   * The name of the file on the local filesystem, if available. I.e. when
   * used together with the disk storage.
   */
  var filename : String? {
    guard let path = path else { return nil }
    return URL(fileURLWithPath: path).lastPathComponent
  }
  
  /**
   * The folder of the file in the local filesystem, if available. I.e. when
   * used together with the disk storage.
   */
  var destination : String? {
    guard let path = path else { return nil }
    return URL(fileURLWithPath: path).deletingLastPathComponent().path
  }
}
#endif // canImport(Foundation)
