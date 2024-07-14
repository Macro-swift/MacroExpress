//
//  Settings.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 02/06/16.
//  Copyright © 2016-2024 ZeeZide GmbH. All rights reserved.
//

/**
 * Just a special kind of dictionary. The `Express` application class is
 * currently the sole example.
 *
 * Examples:
 *
 *     app.set("env", "production")
 *     app.enable("x-powered-by")
 *
 *     let env = app.settings.env
 */
public protocol SettingsHolder {
  
  func set(_ key: String, _ value: Any?)
  func get(_ key: String) -> Any?
}

public extension SettingsHolder {
  
  @inlinable
  func enable(_ key: String) {
    set(key, true)
  }
  @inlinable
  func disable(_ key: String) {
    set(key, false)
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
}

public extension SettingsHolder {
  
  /**
   * Returns an object representing the settings in the holder (i.e. in the
   * MacroExpress app).
   *
   * Example:
   *
   *     if app.settings.env == "production" { ... }
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
