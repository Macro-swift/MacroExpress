//
//  Router.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import typealias connect.Next
import typealias connect.Middleware

// A Route itself now can do everything a Router could do before (most
// importantly it can hold an array of middleware)
public typealias Router = Route

public extension Router {
  
  convenience init(id: String? = nil, _ pattern: String?,
                   _ middleware: Middleware...)
  {
    self.init(id: id, pattern: pattern, method: nil,
              middleware: middleware)
  }
}
