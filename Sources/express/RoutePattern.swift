//
//  Render.swift
//  Noze.io / Macro / ExExpress
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

fileprivate let debugMatcher = false

public enum RoutePattern {
  
  case root
  case text    (String)
  case variable(String)
  case wildcard
  case prefix  (String)
  case suffix  (String)
  case contains(String)
  case eol
  
  func match(string s: String) -> Bool {
    switch self {
      case .root:            return s == ""
      case .text(let v):     return s == v
      case .wildcard:        return true
      case .variable:        return true // allow anything, like .Wildcard
      case .prefix(let v):   return s.hasPrefix(v)
      case .suffix(let v):   return s.hasSuffix(v)
      case .contains(let v): return s.contains(v)
      case .eol:             return false // nothing should come anymore
    }
  }
  
  public var description : String {
    switch self {
      case .root:             return "/"
      case .text(let v):      return v
      case .wildcard:         return "*"
      case .eol:              return "$"
      case .variable (let n): return ":\(n)"
      case .prefix(let v):    return "\(v)*"
      case .suffix(let v):    return "*\(v)"
      case .contains(let v):  return "*\(v)*"
    }
  }

  /**
   * Creates a pattern for a given 'url' string.
   *
   * - the "*" string is considered a match-all.
   * - otherwise the string is split into path components (on '/')
   * - if it starts with a "/", the pattern will start with a Root symbol
   * - "*" (like in `/users/ * / view`) matches any component (spaces added)
   * - if the component starts with `:`, it is considered a variable.
   *   Example: `/users/:id/view`
   * - "text*", "*text*", "*text" creates hasPrefix/hasSuffix/contains patterns
   * - otherwise the text is matched AS IS
   */
  static func parse(_ s: String) -> [ RoutePattern ]? {
    if s == "*" { return nil } // match-all
    
    var url = URL()
    url.path = s
    let comps = url.escapedPathComponents!
    
    var isFirst = true
    
    var pattern : [ RoutePattern ] = []
    for c in comps {
      if isFirst {
        isFirst = false
        if c == "" { // root
          pattern.append(.Root)
          continue
        }
      }
      
      if c == "*" {
        pattern.append(.Wildcard)
        continue
      }
      
      if c.hasPrefix(":") {
        let vIdx = c.index(after: c.startIndex)
        pattern.append(.Variable(String(c[vIdx..<c.endIndex])))
        continue
      }
      
      if c.hasPrefix("*") {
        let vIdx = c.index(after: c.startIndex)
        #if swift(>=3.2)
          let cLen = c.count
        #else
          let cLen = c.characters.count
        #endif
        if c == "**" {
          pattern.append(.Wildcard)
        }
        else if c.hasSuffix("*") && cLen > 1 {
          let eIdx = c.index(before: c.endIndex)
          pattern.append(.Contains(String(c[vIdx..<eIdx])))
        }
        else {
          pattern.append(.Suffix(String(c[vIdx..<c.endIndex])))
        }
        continue
      }
      if c.hasSuffix("*") {
        let eIdx = c.index(before: c.endIndex)
        pattern.append(.Prefix(String(c[c.startIndex..<eIdx])))
        continue
      }

      pattern.append(.Text(c))
    }
    
    return pattern
  }
  
  
  // MARK: - Pattern Matching
  
  static func match(pattern p: [ RoutePattern ],
                    against escapedPathComponents: [ String ],
                    variables: inout [ String : String ]) -> String?
  {
    // Note: Express does a prefix match, which is important for mounting.
    // TODO: Would be good to support a "$" pattern which guarantees an exact
    //       match.
    var pattern = p
    var matched = ""
    
    if debugMatcher {
      print("match: components: \(escapedPathComponents)\n" +
            "       against:    \(pattern)")
    }
    
    // this is to support matching "/" against the "/*" ("", "*") pattern
    // That is:
    //   /hello/abc  [pc = 2]
    // will match
    //   /hello*     [pc = 1]
    if escapedPathComponents.count + 1 == pattern.count {
      if case .Wildcard = pattern.last! {
        let endIdx = pattern.count - 1
        pattern = Array<RoutePattern>(pattern[0..<endIdx])
      }
    }
    
    // there have to be more or the same number of components in the path like
    // things to match in the pattern ...
    guard escapedPathComponents.count >= pattern.count else { return nil }
    
    // If the pattern ends in $
    if let lastComponent = pattern.last {
      if case .EOL = lastComponent {
        // is this correct?
        guard escapedPathComponents.count < pattern.count else { return nil }
      }
    }
    
    
    var lastWasWildcard = false
    var lastWasEOL      = false
    for i in pattern.indices {
      let patternComponent = pattern[i]
      let matchComponent   = escapedPathComponents[i] // TODO: unescape?
      
      guard patternComponent.match(string: matchComponent) else {
        if debugMatcher {
          print("  no match on: '\(matchComponent)' (\(patternComponent))")
        }
        return nil
      }
      
      if i == 0 && matchComponent.isEmpty {
        matched += "/"
      }
      else {
        if matched != "/" { matched += "/" }
        matched += matchComponent
      }
      
      if debugMatcher {
        print("  comp matched[\(i)]: \(patternComponent) " +
              "against '\(matchComponent)'")
      }

      if case .Variable(let s) = patternComponent {
        variables[s] = matchComponent // TODO: unescape
      }
      
      
      // Special case, last component is a wildcard. Like /* or /todos/*. In
      // this case we ignore extra URL path stuff.
      let isLast = i + 1 == pattern.count
      if isLast {
        if case .Wildcard = patternComponent {
          lastWasWildcard = true
        }
        if case .EOL = patternComponent {
          lastWasEOL = true
        }
      }
    }

    if debugMatcher {
      if lastWasWildcard || lastWasEOL {
        print("MATCH: last was WC \(lastWasWildcard) EOL \(lastWasEOL)")
      }
    }
    
    if escapedPathComponents.count > pattern.count {
      //if !lastWasWildcard { return nil }
      if lastWasEOL { return nil } // all should have been consumed
    }
    
    if debugMatcher { print("  match: '\(matched)'") }
    return matched
  }
}
