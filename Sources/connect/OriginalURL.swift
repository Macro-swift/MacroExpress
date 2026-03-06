//
//  OriginalURL.swift
//  MacroExpress / connect
//
//  Created by Helge Heß.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

import class    http.IncomingMessage
import protocol MacroCore.EnvironmentKey

public extension IncomingMessage {

  enum OriginalURLKey: EnvironmentKey {
    public static let defaultValue : String? = nil
    public static let loggingKey   = "originalurl"
  }

  /**
   * The original URL as received from the client,
   * before any URL rewriting by mounted middleware.
   *
   * Unlike ``url``, this is never modified by routing.
   * Falls back to ``url`` if not yet set.
   */
  var originalURL : String {
    get { environment[OriginalURLKey.self] ?? url }
    set { environment[OriginalURLKey.self] = newValue }
  }
}
