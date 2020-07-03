//
//  dotenv.swift
//  MacroExpress
//
//  Created by Helge Heß on 02.07.20.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

#if os(Linux)
  import func Glibc.setenv
#else
  import func Darwin.setenv
#endif

import enum  MacroCore.console
import func  MacroCore.__dirname
import class Foundation.FileManager

public enum dotenv {}

public extension dotenv {
  
  #if swift(>=5.3) // oh this mess
  /**
   * Read the .env config file, apply it to the environment, and return the
   * parsed values.
   *
   * Important: Remember to call this as early as possible, otherwise Foundation
   *            might not pick up the changed environment! (which also affects
   *            `process.env`)
   *
   * Values which are already set in the environment are not overridden (unless
   * the `override` argument is set).
   *
   * Syntax:
   * - empty lines are skipped
   * - lines starting w/ `#` are skipped (comments)
   * - key & value are trimmed
   * - missing values become the empty string ""
   *
   * Note: This does none of the quoting stuff of the original yet.
   *
   * Original JS module: https://github.com/motdotla/dotenv
   */
  @discardableResult
  static func config(path     : String? = nil,
                     override : Bool    = false,
                     caller   : String  = #filePath) -> [ String : String ]?
  {
    do {
      return try tryConfig(path: path, override: override, logError: true,
                           caller: caller)
    }
    catch {
      return nil
    }
  }
  
  /// See `config` for details. This is a throwing variant
  static func tryConfig(path     : String? = nil,
                        override : Bool    = false,
                        logError : Bool    = false,
                        caller   : String  = #filePath)
                throws -> [String : String]
  {
    let path = path ?? (__dirname(caller: caller) + "/.env")
    let fm   = FileManager.default
    
    guard fm.fileExists(atPath: path) else { return [:] } // not an error

    do {
      let config = parse(try String(contentsOfFile: path))
      
      for ( key, value ) in config {
        setenv(key, value, override ? 1 : 0)
      }
      
      return config
    }
    catch {
      if logError {
        console.error("dotenv failed to load .env file:", path,
                      "  error:", error)
      }
      throw error
    }
  }
  #else
  /**
   * Read the .env config file, apply it to the environment, and return the
   * parsed values.
   *
   * Important: Remember to call this as early as possible, otherwise Foundation
   *            might not pick up the changed environment! (which also affects
   *            `process.env`)
   *
   * Values which are already set in the environment are not overridden (unless
   * the `override` argument is set).
   *
   * Syntax:
   * - empty lines are skipped
   * - lines starting w/ `#` are skipped (comments)
   * - key & value are trimmed
   * - missing values become the empty string ""
   *
   * Note: This does none of the quoting stuff of the original yet.
   *
   * Original JS module: https://github.com/motdotla/dotenv
   */
  @discardableResult
  static func config(path     : String? = nil,
                     override : Bool    = false,
                     caller   : String  = #file) -> [ String : String ]?
  {
    do {
      return try tryConfig(path: path, override: override, logError: true,
                           caller: caller)
    }
    catch {
      return nil
    }
  }
  
  /// See `config` for details. This is a throwing variant
  static func tryConfig(path     : String? = nil,
                        override : Bool    = false,
                        logError : Bool    = false,
                        caller   : String  = #file) throws -> [String : String]
  {
    let path = path ?? (__dirname(caller: caller) + "/.env")
    let fm   = FileManager.default
    
    guard fm.fileExists(atPath: path) else { return [:] } // not an error

    do {
      let config = parse(try String(contentsOfFile: path))
      
      for ( key, value ) in config {
        setenv(key, value, override ? 1 : 0)
      }
      
      return config
    }
    catch {
      if logError {
        console.error("dotenv failed to load .env file:", path,
                      "  error:", error)
      }
      throw error
    }
  }
  #endif // <= Swift 5.2

  /**
   * Parse the string passed as a .env file.
   *
   * Syntax:
   * - empty lines are skipped
   * - lines starting w/ `#` are skipped (comments)
   * - key & value are trimmed
   * - missing values become the empty string ""
   *
   * Note: This does none of the quoting stuff of the original yet.
   */
  static func parse(_ string: String) -> [ String : String ] {
    guard !string.isEmpty else { return [:] }

    var parsed = [ String : String ]()
    parsed.reserveCapacity(string.count / 20) // short lines assumed
    
    for line in string.components(separatedBy: .newlines) {
      guard !line.isEmpty        else { continue }
      guard !line.hasPrefix("#") else { continue }
      
      let components = line.split(separator: "=", maxSplits: 1)
      guard !components.isEmpty  else { continue }
      
      let key   = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
      let value = components.count < 2
                ? ""
                : components[1].trimmingCharacters(in: .whitespacesAndNewlines)
      
      if let existing = parsed[key] { parsed[key] = existing + value } // TBD
      else                          { parsed[key] = value }
    }
    
    return parsed
  }
}
