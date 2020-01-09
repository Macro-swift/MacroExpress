//
//  MIME.swift
//  ExExpress / Macro
//
//  Created by Helge Hess on 11/06/17.
//  Copyright © 2017-2020 ZeeZide GmbH. All rights reserved.
//

// desired API:
//   https://www.npmjs.com/package/mime-types

import struct Foundation.URL

public enum MIMEModule {}
public typealias mime = MIMEModule

public extension MIMEModule {
  
  /**
   * Returns a MIME type for the given extension or filesystem path.
   *
   * Examples:
   *
   *     mime.lookup("json")       => application/json; charset=UTF-8
   *     mime.lookup("index.html") => text/html; charset=UTF-8
   *
   */
  @inlinable
  static func lookup(_ path: String) -> String? {
    if !path.contains(".") && !path.contains("/") {
      if let ctype = types[path] {
        if let cs = defaultCharsets[ctype] {
          return ctype + "; charset=" + cs
        }
        return ctype
      }
    }
    
    let url = Foundation.URL(fileURLWithPath: path)
    guard let ctype = types[url.pathExtension] else { return nil }
    if let cs = defaultCharsets[ctype] { return ctype + "; charset=" + cs }
    return ctype
  }
  
  @inlinable
  static func charset(_ ctype: String) -> String? {
    return defaultCharsets[ctype]
  }

  static let types : [ String : String ] = [
    "html":     "text/html",
    "js":       "application/javascript",
    "ico":      "image/x-icon",
    "svg":      "image/svg+xml",
    "eot":      "application/vnd.ms-fontobject",
    "woff":     "application/x-font-woff",
    "woff2":    "application/x-font-woff",
    "ttf":      "application/x-font-ttf",
    "markdown": "text/x-markdown",
    "json":     "application/json"
  ]
  
  static let extensions : [ String : [ String ] ] = [
    "text/html":                     [ "html"          ],
    "application/javascript":        [ "js"            ],
    "image/x-icon":                  [ "ico"           ],
    "image/svg+xml":                 [ "svg"           ],
    "application/vnd.ms-fontobject": [ "eot"           ],
    "application/x-font-woff":       [ "woff", "woff2" ],
    "application/x-font-ttf":        [ "ttf"           ],
    "text/x-markdown":               [ "markdown"      ],
    "application/json":              [ "json"          ]
  ]

  static let defaultCharsets : [ String : String ] = [
    "text/html":              "UTF-8",
    "application/javascript": "UTF-8",
    "image/svg+xml":          "UTF-8",
    "text/x-markdown":        "UTF-8",
    "application/json":       "UTF-8"
  ]
}
