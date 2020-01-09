//
//  MiddlewareWalker.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import class     http.IncomingMessage
import class     http.ServerResponse
import typealias connect.Next

internal final class MiddlewareWalker {
  
  var stack      : ArraySlice<Middleware>
  var errorStack : ArraySlice<ErrorMiddleware>
  let request    : IncomingMessage
  let response   : ServerResponse
  var endNext    : Next?
  var error      : Swift.Error?
  
  init(_ stack      : ArraySlice<Middleware>,
       _ errorStack : ArraySlice<ErrorMiddleware>,
       _ request    : IncomingMessage,
       _ response   : ServerResponse,
       _ endNext    : @escaping Next)
  {
    self.stack      = stack
    self.errorStack = errorStack
    self.request    = request
    self.response   = response
    self.endNext    = endNext
  }
  
  func step(_ args: Any...) {
    if let s = args.first as? String, s == "route" || s == "router" {
      endNext?(); endNext = nil
      return
    }
    
    if let error = (args.first as? Error) ?? self.error {
      self.error = error
      if let middleware = errorStack.popFirst() {
        middleware(error, request, response, self.step)
      }
      else {
        endNext?(error); endNext = nil
      }
      return
    }
    
    if let middleware = stack.popFirst() {
      middleware(request, response, self.step)
    }
    else {
      assert(error == nil)
      endNext?(); endNext = nil
    }
  }
}
