//
//  Module.swift
//  Noze.io / MacroExpress
//
//  Created by Helge Heß on 4/3/16.
//  Copyright © 2016 ZeeZide GmbH. All rights reserved.
//

import core
@_exported import connect

public enum ExpressModule {}

public extension ExpressModule {
  
  @inlinable
  public func express(middleware: Middleware...) -> Express {
    let app = Express()
    middleware.forEach(app.use)
    return app
  }
}

@inlinable
public func express(middleware: Middleware...) -> Express {
  let app = Express()
  middleware.forEach(app.use)
  return app
}
