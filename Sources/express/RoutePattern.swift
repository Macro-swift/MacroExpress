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
    
    let comps = extractEscapedURLPathComponents(for: s)
    
    var isFirst = true
    
    var pattern : [ RoutePattern ] = []
    for c in comps {
      if isFirst {
        isFirst = false
        if c == "" { // root
          pattern.append(.root)
          continue
        }
      }
      
      if c == "*" {
        pattern.append(.wildcard)
        continue
      }
      
      if c.hasPrefix(":") {
        let vIdx = c.index(after: c.startIndex)
        pattern.append(.variable(String(c[vIdx..<c.endIndex])))
        continue
      }
      
      if c.hasPrefix("*") {
        let vIdx = c.index(after: c.startIndex)
        let cLen = c.count
        if c == "**" {
          pattern.append(.wildcard)
        }
        else if c.hasSuffix("*") && cLen > 1 {
          let eIdx = c.index(before: c.endIndex)
          pattern.append(.contains(String(c[vIdx..<eIdx])))
        }
        else {
          pattern.append(.suffix(String(c[vIdx..<c.endIndex])))
        }
        continue
      }
      if c.hasSuffix("*") {
        let eIdx = c.index(before: c.endIndex)
        pattern.append(.prefix(String(c[c.startIndex..<eIdx])))
        continue
      }

      pattern.append(.text(c))
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
      if case .wildcard = pattern.last! {
        let endIdx = pattern.count - 1
        pattern = Array<RoutePattern>(pattern[0..<endIdx])
      }
    }
    
    // I don't know if this special case is the best way to handle this but there was a one off error where
    // any routes that use "/" for the pattern would match all routes
    if case .root  = pattern[0], pattern.count == 1 && escapedPathComponents.count > 1 { return nil }
    
    // there have to be more or the same number of components in the path like
    // things to match in the pattern ...
    guard escapedPathComponents.count >= pattern.count else { return nil }
    
    // If the pattern ends in $
    if let lastComponent = pattern.last {
      if case .eol = lastComponent {
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

      if case .variable(let s) = patternComponent {
        variables[s] = matchComponent // TODO: unescape
      }
      
      
      // Special case, last component is a wildcard. Like /* or /todos/*. In
      // this case we ignore extra URL path stuff.
      let isLast = i + 1 == pattern.count
      if isLast {
        if case .wildcard = patternComponent {
          lastWasWildcard = true
        }
        if case .eol = patternComponent {
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

func extractEscapedURLPathComponents(for urlPath: String) -> [ String ] {
  guard !urlPath.isEmpty else { return [] }
  
  let isAbsolute = urlPath.hasPrefix("/")
  let pathComps  = urlPath.split(separator: "/",
                                 omittingEmptySubsequences: false)
                          .map(String.init)
  /* Note: we cannot just return a leading slash for absolute pathes as we
   *       wouldn't be able to distinguish between an absolute path and a
   *       relative path starting with an escaped slash.
   *   So: Absolute pathes instead start with an empty string.
   */
  var gotAbsolute = isAbsolute ? false : true
  return pathComps.filter {
    if $0 != "" || !gotAbsolute {
      if !gotAbsolute { gotAbsolute = true }
      return true
    }
    else {
      return false
    }
  }
}
