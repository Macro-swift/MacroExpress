//
//  Module.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 4/3/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import MacroCore
@_exported import connect

public enum ExpressModule {}

public extension ExpressModule {
  
  @inlinable
  static func express(middleware: Middleware...) -> Express {
    let app = Express()
    middleware.forEach { app.use($0) }
    return app
  }
}

@inlinable
public func express(middleware: Middleware...) -> Express {
  let app = Express()
  middleware.forEach { app.use($0) }
  return app
}
