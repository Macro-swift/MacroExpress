//
//  Settings.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 02/06/16.
//  Copyright © 2016-2025 ZeeZide GmbH. All rights reserved.
//

/**
 * Just a special kind of dictionary. The ``Express`` application class is
 * currently the sole example.
 *
 * Examples:
 * ```swift
 * app.set("env", "production")
 * app.enable("x-powered-by")
 *
 * let env = app.settings.env
 * ```
 */
public protocol SettingsHolder {
  
  /**
   * Sets or removes a configuration key in the settings store.
   *
   * Example:
   * ```swift
   * app.set("view engine", "html")
   *    .set("views", __dirname() + "/views")
   *    .enable("x-powered-by")
   * ```
   *
   * - Parameters:
   *   - key:   The name of the key, e.g. "view engine"
   *   - value: The associated value, if `nil` is passed in, the value is
   *            removed from the store.
   * - Returns: `self` for chaining.
   */
  @discardableResult
  func set(_ key: String, _ value: Any?) -> Self
  
  /**
   * Returns the value of a configuration key from the settings store.
   *
   * Example:
   * ```swift
   * let engine = app.get("view engine")
   * ```
   *
   * - Parameters:
   *   - key:   The name of the key, e.g. "view engine"
   * - Returns: The value in the store, or `nil` if missing.
   */
  func get(_ key: String) -> Any?
}

public extension SettingsHolder {
  
  /**
   * Set configuration key in the settings store to `true`.
   *
   * Example:
   * ```swift
   * app.enable("x-powered-by")
   * ```
   *
   * - Parameters:
   *   - key:   The name of the bool key, e.g. "view engine"
   * - Returns: `self` for chaining.
   */
  @inlinable
  @discardableResult
  func enable(_ key: String) -> Self {
    return set(key, true)
  }
  
  /**
   * Set configuration key in the settings store to `false`.
   *
   * Example:
   * ```swift
   * app.disable("x-powered-by")
   * ```
   *
   * - Parameters:
   *   - key:   The name of the bool key, e.g. "view engine"
   * - Returns: `self` for chaining.
   */
  @inlinable
  @discardableResult
  func disable(_ key: String) -> Self {
    return set(key, false)
  }
  
  @inlinable
  subscript(setting key : String) -> Any? {
    get { return get(key)    }
    set { set(key, newValue) }
  }
}

/**
 * An object representing the settings in the associated holder (i.e. in the
 * MacroExpress app).
 *
 * Modules can extend this structure to add more, predefined and typed
 * settings.
 */
@dynamicMemberLookup
public struct ExpressSettings {
  
  public let holder : SettingsHolder

  @inlinable
  public init(_ holder: SettingsHolder) { self.holder = holder }

  @inlinable
  subscript(dynamicMember key: String) -> Any? {
    return holder[setting: key]
  }

  @inlinable
  subscript(_ key: String) -> Any? {
    return holder[setting: key]
  }
}

public extension SettingsHolder {
  
  /**
   * Returns an object representing the settings in the holder (i.e. in the
   * MacroExpress app).
   *
   * Example:
   * ```swift
   * if app.settings.env == "production" { ... }
   * ```
   */
  @inlinable
  var settings : ExpressSettings { return ExpressSettings(self) }
}


// MARK: - Predefined Settings

import enum MacroCore.process

public extension ExpressSettings {

  /**
   * Returns the runtime environment we are in, e.g. `production` or
   * `development`.
   *
   * This first checks for an explicit `env` setting in the SettingsHolder
   * (i.e. Express application object).
   * If that's missing, it checks the `MACRO_ENV` environment variable.
   */
  @inlinable
  var env : String {
    if let v = holder .get("env") as? String { return v }
    if let v = process.env["MACRO_ENV"]      { return v }
    
    #if DEBUG
      return "development"
    #else
      return "production"
    #endif
  }
  
  /**
   * Returns true if the Macro should add the x-powered-by header to the
   * response.
   */
  @inlinable
  var xPoweredBy : Bool {
    guard let v = holder.get("x-powered-by") else { return true }
    return boolValue(v)
  }
}


// MARK: - Helpers

@usableFromInline
func boolValue(_ v : Any) -> Bool {
  // TODO: this should be some Foundation like thing
  if let b = v as? Bool   { return b      }
  if let b = v as? Int    { return b != 0 }
  #if swift(>=5.10)
  if let i = (v as? any BinaryInteger) { return Int(i) != 0 }
  #endif
  if let s = v as? String {
    switch s.lowercased() {
      case "no", "false", "0", "disable": return false
      default: return true
    }
  }
  return true
}
