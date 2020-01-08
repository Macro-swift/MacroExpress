//
//  IncomingMessage.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import http

public extension IncomingMessage {
  
  // TODO: baseUrl, originalUrl, path
  // TODO: hostname, ip, ips, protocol
  
  func accepts(_ s: String) -> String? {
    // TODO: allow array values
    guard let acceptHeader = (self.headers["Accept"] as? String) else {
      return nil
    }
    
    // FIXME: naive and incorrect implementation :-)
    // TODO: parse quality, patterns, etc etc
    let acceptedTypes = acceptHeader.split(separator: ",")
    for mimeType in acceptedTypes {
      if mimeType.contains(s) { return mimeTypeString }
    }
    return nil
  }
 
  
  var xhr : Bool {
    guard let h = headers["X-Requested-With"].first else { return false }
    return h.contains("XMLHttpRequest")
  }
}
