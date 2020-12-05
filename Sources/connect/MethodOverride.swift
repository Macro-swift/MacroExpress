//
//  MethodOverride.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/31/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import let MacroCore.console

public func methodOverride(header  : String = "X-HTTP-Method-Override",
                           methods : [ String ] = [ "POST" ])
            -> Middleware
{
  return { req, res, next in
    // TODO: support query values
    
    guard methods.contains(req.method)        else { next(); return }
    guard let hvs = req.headers[header].first else { next(); return }
    
    // patch method and continue
    req.method = hvs
    next()
  }
}
