//
//  JSON.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/3/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import MacroCore
import class http.ServerResponse

public extension ServerResponse {
  // TODO: add jsonp
  // TODO: be a proper stream
  // TODO: Maybe we don't want to convert to a `JSON`, but rather stream real
  //       object.
  
  func json(_ object: Any?) {
    if canAssignContentType {
      setHeader("Content-Type", "application/json; charset=utf-8")
    }
    _ = writeJSON(object)
    end()
  }
  func json<E: Encodable>(_ object: E) {
    if canAssignContentType {
      setHeader("Content-Type", "application/json; charset=utf-8")
    }
    _ = write(object)
    end()
  }
  func json<E: Encodable>(_ object: E?) {
    guard let object = object else {
      _ = write("")
      return end()
    }
    return json(object)
  }
}
