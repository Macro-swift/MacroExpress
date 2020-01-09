//
//  JSON.swift
//  Noze.io
//
//  Created by Helge Heß on 6/3/16.
//  Copyright © 2016 ZeeZide GmbH. All rights reserved.
//

import MacroCore
import http

public extension ServerResponse {
  // TODO: add jsonp
  // TODO: be a proper stream
  // TODO: Maybe we don't want to convert to a `JSON`, but rather stream real
  //       object.
  
  func json(_ object: Any?) {
    if canAssignContentType {
      setHeader("Content-Type", "application/json; charset=utf-8")
    }
    writeJSON(object)
    end()
  }
  func json<E: Encodable>(_ object: E?) {
    if canAssignContentType {
      setHeader("Content-Type", "application/json; charset=utf-8")
    }
    writeJSON(object)
    end()
  }
}
