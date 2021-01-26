//
//  PartType.swift
//  MacroExpress / multer
//
//  Created by Helge Heß
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import Foundation

internal extension multer {
  
  // Whether to create a file or form value.
  // We get:
  //   Content-Disposition: form-data; name="file"; filename="abc.csv"
  //   Content-Type:        application/octet-stream
  //
  // Note: As per RFC 7578:
  // - each part _must_ have a form-data Content-Disposition.
  // - "filename" is optional
  // - Content-Type defaults to 'text/plain', can have charset
  // - can have Content-Transfer-Encoding, e.g. quoted-printable
  //   - not used in practice
  // - there can be a special `_charset_` form value carrying the
  //   default charset (e.g. 'iso-8859-1')
  
  /**
   * The type of a specific multipart/form-data part.
   *
   * It is either a file, a field, or something unknown.
   */
  enum PartType: Equatable {
    
    case file (File)
    case field(String)
    case invalid
    
    var name : String {
      switch self {
        case .file (let file) : return file.fieldName
        case .field(let name) : return name
        case .invalid         : return ""
      }
    }
    
    /**
     * Returns `.none` if there is not `Content-Disposition`, or it doesn't
     * contain a `name` parameter.
     *
     * Returns `.file` if the `Content-Disposition` contains either a `filename`
     * parameter, of it the `Content-Type` isn't "text/plain".
     *
     * Otherwise returns `.field`.
     */
    init(with header: MultiPartParser.Header) {
      // Content-Disposition: form-data; name="file"; filename="abc.csv"
      // Content-Type:        application/octet-stream
      guard let cd = header.valueForHeader("Content-Disposition") else {
        self = .invalid
        return
      }
      guard let name = extractHeaderArgument("name", from: cd) else {
        self = .invalid
        return
      }
      
      let ctype    = header.valueForHeader("Content-Type") ?? "text/plain"
      let filename = extractHeaderArgument("filename", from: cd)
      
      if filename != nil || !ctype.hasPrefix("text/plain") {
        self = .file(File(fieldName: name, originalName: filename ?? "",
                          mimeType: ctype, path: nil, buffer: nil))
      }
      else {
        self = .field(name)
      }
    }
  }
}
