//
//  Pause.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 21/07/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import func MacroCore.setTimeout

/// Middleware to simulate latency.
///
/// Pause all requests:
///
///     app.use(pause(1337)) // wait for 1337ms, then continue
///     app.get("/") { req, res in
///       res.send("Waited 1337 ms")
///     }
///
public func pause(_ timeout: Int, _ error: Error? = nil) -> Middleware {
  return { req, res, next in
    print("pausing:",ObjectIdentifier(req))
    setTimeout(timeout) {
      print("done pausing:",ObjectIdentifier(req))
      if let error = error {
        next(error)
      }
      else {
        next()
      }
    }
  }
}
