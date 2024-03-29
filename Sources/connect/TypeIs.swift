//
//  TypeIs.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2016-2023 ZeeZide GmbH. All rights reserved.
//

import class http.IncomingMessage
import NIOHTTP1

// TODO: the API is both crap nor really the same like Node

@inlinable
public func typeIs(_ message: IncomingMessage, _ types: [ String ]) -> String? {
  guard let ctype = message.headers["Content-Type"].first else { return nil }
  return typeIs(ctype, types)
}

@inlinable
public func typeIs(_ type: String, _ types: [ String ]) -> String? {
  let lcType = type.lowercased()
  
  for matchType in types {
    if does(type: lcType, match: matchType) {
      return matchType
    }
  }
  
  return nil
}

@usableFromInline
internal func does(type lcType: String, match matchType: String) -> Bool {
  let lcMatch = matchType.lowercased()
  
  if lcType == lcMatch { return true }
  
  // FIXME: completely naive implementation :->
  
  if lcMatch.hasSuffix("*") {
    let idx = lcMatch.index(before: lcMatch.endIndex)
    return lcType.hasPrefix(lcMatch[lcMatch.startIndex..<idx])
  }
  
  if lcType.contains(lcMatch) {
    return true
  }
  
  return false
}
