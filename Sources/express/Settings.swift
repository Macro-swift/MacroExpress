//
//  Settings.swift
//  Noze.io / Macro
//
//  Created by Helge Hess on 02/06/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

/**
 * Just a special kind of dictionary. The `Express` application class is currently the sole example.
 */
public protocol SettingsHolder {
  
  func set(_ key: String, _ value: Any?)
  func get(_ key: String) -> Any?
}

public extension SettingsHolder {
  
  func enable(_ key: String) {
    set(key, true)
  }
  func disable(_ key: String) {
    set(key, false)
  }
  
  subscript(setting key : String) -> Any? {
    get { return get(key)    }
    set { set(key, newValue) }
  }
}
