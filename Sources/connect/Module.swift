//
//  Module.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 4/3/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

@_exported import MacroCore

public enum ConnectModule {
}

public extension ConnectModule {
  
  @inlinable
  static func connect(middleware: Middleware...) -> Connect {
    let app = Connect()
    
    for m in middleware {
      _ = app.use(m)
    }
    
    return app
  }
}
