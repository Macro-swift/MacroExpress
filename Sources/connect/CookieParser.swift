//
//  CookieParser.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/16/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum     MacroCore.process
import protocol MacroCore.EnvironmentKey
import class    http.IncomingMessage

/**
 * After running the `cookieParser` middleware you can access the cookies
 * via `request.cookies` (a [String:String]).
 *
 * Example:
 *
 *     app.use(cookieParser())
 *     app.get("/cookies") { req, res, _ in
 *       res.json(req.cookies)
 *     }
 *
 */
public func cookieParser() -> Middleware {
  return { req, res, next in
    if req[CookieKey.self] == nil {
      let cookies = Cookies(req, res)
      req.environment[CookieKey.self] = cookies.cookies // grab all
    }
    next()
  }
}

// MARK: - IncomingMessage extension

private enum CookieKey: EnvironmentKey {
  static let defaultValue : [ String : String ]? = nil
  static let loggingKey   = "cookie"
}

public extension IncomingMessage {
  
  /// Returns the cookies embedded in the request. Note: Make sure to invoke
  /// the `cookieParser` middleware first, so that this property is actually
  /// filled.
  var cookies : [ String : String ] {
    get {
      // This concept is a little weird as so many thinks in Node. Why not just
      // parse the cookies on-demand?
      guard let cookies = self[CookieKey.self] else {
        process.emitWarning(
          "attempt to access `cookies` of request, " +
          "but cookieParser middleware wasn't invoked"
        )
        
        // be smart
        let cookies = Cookies(self)
        self.environment[CookieKey.self] = cookies.cookies // grab all
        return cookies.cookies
      }
      
      return cookies
    }
  }
}
