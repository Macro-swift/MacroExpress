//
//  QS.swift
//  Noze.io / ExExpress / Macro
//
//  Created by Helge Heß on 02.05.17.
//  Copyright © 2017-2026 ZeeZide GmbH. All rights reserved.
//

public enum qs {
  // TODO: doesn't really belong here, but well.
  // TODO: stringify etc
  // TODO: this is a little funky because URL parsing really happens at a byte
  //       level (% decoding etc)
}

public extension qs {
  
  final class Options {
    let separator      : Character = "&"
    let pairSeparator  : Character = "="
    let depth          : Int       = 5
    let parameterLimit : Int       = 1000
    let arrayLimit     : Int       = 20
    let allowsDot      : Bool      = false
  }

  private class EmptyArraySlot {}
  static let sparseArrayDefaultValue : Any = EmptyArraySlot()
  
  static func parse(_ string              : String,
                    separator             : Character = "&",
                    pairSeparator         : Character = "=",
                    depth                 : Int       = 5,
                    parameterLimit        : Int       = 1000,
                    arrayLimit            : Int       = 20,
                    allowsDot             : Bool      = false,
                    decodeURIComponent dd : (( String ) -> String)? = nil)
              -> [ String : Any ]
  {
    let decodeURIComponent = dd ?? _unescape
    if allowsDot { fatalError("allowsDot unsupported") }

    let parsedQV = RefStringAnyDictionary()
    var count = 0
    let pairs = string.split(separator: separator,
                             omittingEmptySubsequences: true)
    for pair in pairs {
      guard count < parameterLimit else { break }
      count += 1
      
      let pairParts = pair.split(separator: pairSeparator, maxSplits: 1,
                                 omittingEmptySubsequences: true)
      guard !pairParts.isEmpty else { continue }
    
      let key   = decodeURIComponent(String(pairParts[0]))
      let value = pairParts.count > 1
                ? decodeURIComponent(String(pairParts[1])) : ""
          
      let path = parseKeyPath(key, depth: depth, allowsDot: allowsDot)
      guard !path.isEmpty, path.allSatisfy({
        switch $0 {
          case .index(let index): return index <= arrayLimit && index < Int.max
          case .error: return false
          default: return true
        }
      }) else { continue }

      _ = insert(value, along: path[...], into: parsedQV)
    }

    return parsedQV.flatten() as? [ String : Any ] ?? [:]
  }

  /// Slots keep the type of its first value.
  private static func insert(_      value : String,
                             along   path : ArraySlice<QueryParameterKeyPart>,
                             into current : Any?) -> Any?
  {
    let existing = current is EmptyArraySlot ? nil : current
    guard let part = path.first else {
      return existing == nil || existing is String ? value : nil
    }
    
    let tail = path.dropFirst()
    switch part {
      case .key(let key):
        let child = existing == nil ? RefStringAnyDictionary()
                                    : (existing as? RefStringAnyDictionary)
        guard let child, 
              let next = insert(value, along: tail, into: child[key]) else 
        {
          return nil
        }
      
        child[key] = next
        return child

      case .array, .index:
        let child = existing == nil ? RefAnyArray() : existing as? RefAnyArray
        guard let child else { return nil }
      
        if case .index(let index) = part {
          let slot = index < child.count ? child[index] : nil
          guard let next = insert(value, along: tail, into: slot) else {
            return nil
          }
          
          child.ensureSize(index + 1, defaultValue: sparseArrayDefaultValue)
          child[index] = next
        }
        else if let next = insert(value, along: tail, into: nil) {
          child.append(next)
        }
        else { return nil }
      
        return child

      case .error: return nil
    }
  }
}


// Hm

protocol RefTypeFlatten: AnyObject {
  
  func flatten() -> Any
  
}

private typealias RefAnyArray            = RefArray<Any>
private typealias RefStringAnyDictionary = RefDictionary<String, Any>

private class RefArray<Element>: RefTypeFlatten {
  
  var storage = Array<Element>()
  
  var isEmpty : Bool { return storage.isEmpty }
  var count   : Int  { return storage.count   }
  
  subscript(key: Int) -> Element {
    set { storage[key] = newValue }
    get { return storage[key]     }
  }

  func ensureSize(_ size: Int, defaultValue: @autoclosure () -> Element) {
    guard count < size else { return }
    
    let value = defaultValue()
    for _ in count..<size {
      append(value)
    }
  }
  
  func append(_ element: Element) {
    storage.append(element)
  }

  func flatten() -> Any {
    var fstorage = Array<Any>()
    fstorage.reserveCapacity(count)
    
    for value in storage {
      if let rd = value as? RefTypeFlatten {
        fstorage.append(rd.flatten())
      }
      else {
        fstorage.append(value)
      }
    }
    return fstorage
  }
}

private class RefDictionary<Key : Hashable, Value>: RefTypeFlatten {
  
  var storage = Dictionary<Key, Value>()
  
  var isEmpty : Bool { return storage.isEmpty }
  
  subscript(key: Key) -> Value? {
    set { storage[key] = newValue }
    get { return storage[key]     }
  }
  
  func flatten() -> Any {
    var fstorage = Dictionary<Key, Any>()
    for ( key, value ) in storage {
      if let rd = value as? RefTypeFlatten {
        fstorage[key] = rd.flatten()
      }
      else {
        fstorage[key] = value
      }
    }
    return fstorage
  }
}


// 'foo[bar][baz]=foobarbaz' -> [ "foo": [ "bar": [ "baz": "foobarbaz" ] ] ]
// 'a[]=b&a[]=c')            -> [ "a": [ "b", "c" ] ]
// 'a[1]=b&a[3]=c'           -> [ "a": [ nil, "b", nil, "c" ] ]  (max: 20)
// 'a.b=c' (allowsDot)       -> [ "a": [ "b": "c" ] ]     // NOT SUPPORTED YET
// 'a[][b]=c'                -> [ "a": [ [ "b": "c" ] ] ]
enum QueryParameterKeyPart {
  case key(String) // hello or [hello]
  case index(Int)  // [1]
  case array       // []
  case error(String)
}

extension qs {
  
  static func parseKeyPath(_ s: String, depth: Int = 5, allowsDot: Bool)
              -> [ QueryParameterKeyPart ]
  {
    guard let first = s.first, first != "[" else { return [] }
    
    var idx      = s.startIndex
    let endIndex = s.endIndex
    
    func consume(_ count: Int = 1) {
      idx = s.index(idx, offsetBy: count)
    }
    func isDigit(_ c: Character) -> Bool {
      switch c {
        case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9": return true
        default: return false
      }
    }
    
    func parseIdentifier() -> String? {
      guard idx < endIndex else { return nil }
      
      var hitDot = false
      var lidx = idx
      while lidx < endIndex {
        if allowsDot && s[lidx] == "." {
          hitDot = true
          break
        }
        if s[lidx] == "[" {
          break
        }
        
        lidx = s.index(after: lidx)
      }
      
      if hitDot {
        let r = s[idx..<lidx]
        idx = s.index(after: lidx)
        return String(r)
      }
      
      let r = s[idx..<lidx]
      idx = lidx
      return String(r)
    }
    
    func parseNumber() -> Int? {
      guard idx < endIndex else { return nil }
      
      var lidx = idx
      while lidx < endIndex {
        guard isDigit(s[lidx]) else { break }
        lidx = s.index(after: lidx)
      }
      
      let sv = s[idx..<lidx]
      idx = lidx
      
      return Int(sv)
    }
    
    func parseSubscript() -> QueryParameterKeyPart? {
      guard idx < endIndex else { return nil }
      guard s[idx] == "["  else { return nil }
      
      consume() // "["
      guard idx < endIndex else { return .error("lbrack not closed") }
      
      if s[idx] == "]" {
        consume() // ]
        return .array
      }
      
      if isDigit(s[idx]) {
        guard let v = parseNumber()
         else { return .error("could not parse number") }
        guard idx < endIndex, s[idx] == "]"
         else { return .error("lbrack not closed") }
        
        consume() // ]
        return .index(v)
      }
      
      var lidx = idx
      while lidx < endIndex {
        if s[lidx] == "]" { break }
        lidx = s.index(after: lidx)
      }
      guard lidx < endIndex, s[lidx] == "]"
       else { return .error("lbrack not closed") }
      
      let r = s[idx..<lidx]
      idx = s.index(after: lidx)
      
      return .key(String(r))
    }
    
    func parseKeyPart() -> QueryParameterKeyPart? {
      guard idx < endIndex else { return nil }
      
      if s[idx] == "[" {
        return parseSubscript()
      }
      
      guard let kid = parseIdentifier() else { return nil }
      return .key(kid)
    }
    
    var parts = [ QueryParameterKeyPart ]()
    while idx < endIndex {
      if !parts.isEmpty, !allowsDot, s[idx] != "[" { return [] }
      guard let part = parseKeyPart() else { return [] }
      if case .error = part { return [] }
      parts.append(part)
      
      // check depth limit.
      if parts.count > depth {
        if idx < endIndex {
          parts.append(.key(String(s[idx..<endIndex])))
        }
        break
      }
    }
    return parts
  }
  
}


import Foundation

/// %-unescape a string.
private func _unescape(string: String) -> String {
  return string.replacingOccurrences(of: "+", with: " ")
               .removingPercentEncoding ?? string
}
