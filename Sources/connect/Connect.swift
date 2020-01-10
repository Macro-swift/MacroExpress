//
//  Connect.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 5/3/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import class http.IncomingMessage
import class http.ServerResponse
import class http.Server
import func  http.createServer

public enum ConnectModule {}

public extension ConnectModule {
  
  @inlinable
  static func connect(middleware: Middleware...) -> Connect {
    let app = Connect()
    middleware.forEach { app.use($0) }
    return app
  }
}

@inlinable
public func connect(middleware: Middleware...) -> Connect {
  let app = Connect()
  middleware.forEach { app.use($0) }
  return app
}

public class Connect {
  
  struct MiddlewareEntry {
    
    let urlPrefix  : String?
    let middleware : Middleware
    
    init(middleware: @escaping Middleware) {
      self.middleware = middleware
      self.urlPrefix  = nil
    }
    
    init(urlPrefix: String, middleware: @escaping Middleware) {
      self.urlPrefix  = urlPrefix
      self.middleware = middleware
    }
    
    func matches(request rq: IncomingMessage) -> Bool {
      if urlPrefix != nil && !rq.url.isEmpty {
        guard rq.url.hasPrefix(urlPrefix!) else { return false }
      }
      
      return true
    }
    
  }
  
  var middlewarez = ContiguousArray<MiddlewareEntry>()
  
  public init() {}
  
  
  // MARK: - use()
  
  @discardableResult
  public func use(_ cb: @escaping Middleware) -> Self {
    middlewarez.append(MiddlewareEntry(middleware: cb))
    return self
  }
  @discardableResult
  public func use(_ p: String, _ cb: @escaping Middleware) -> Self {
    middlewarez.append(MiddlewareEntry(urlPrefix: p, middleware: cb))
    return self
  }
  
  
  // MARK: - Closures to pass on
  
  public var handle : ( IncomingMessage, ServerResponse ) -> Void {
    return { req, res in
      self.doRequest(req, res)
    }
  }
  public var middleware : Middleware {
    return { req, res, cb in
      self.doRequest(req, res) // THIS IS WRONG, need to call cb() only on last
      cb()
    }
  }
  
  
  // MARK: - run middleware
  
  func doRequest(_ request: IncomingMessage, _ response: ServerResponse) {
    final class State {
      var stack    : ArraySlice<Middleware>
      let request  : IncomingMessage
      let response : ServerResponse
      var next     : Next?
      
      init(_ stack    : ArraySlice<Middleware>,
           _ request  : IncomingMessage,
           _ response : ServerResponse,
           _ next     : @escaping Next)
      {
        self.stack    = stack
        self.request  = request
        self.response = response
        self.next     = next
      }
      
      func step(_ args : Any...) {
        if let middleware = stack.popFirst() {
          do {
            print("TRY middleware")
            try middleware(request, response, self.step)
          }
          catch {
            self.step(error)
          }
        }
        else {
          print("FINISHED middleware stack, going to parent")
          next?(); next = nil
        }
      }
    }
    
    func finalHandler(_ args: Any...) {
      request.log.notice(
        "no middleware handled request:\n  \(request)\n  \(response)"
      )
      response.writeHead(404)
      response.end()
    }
    
    // first lookup all middleware matching the request (i.e. the URL prefix
    // matches)
    // TODO: would be nice to have this as a lazy filter.
    
    let middleware = middlewarez.filter { $0.matches(request: request) }
                                .map    { $0.middleware }
    let state = State(middleware[middleware.indices],
                      request, response, finalHandler)
    
    print("START middleware")
    state.step()
  }
  
}


// MARK: - Wrap Server

public extension Connect {
  
  @inlinable
  @discardableResult
  func listen(_ port: Int?, backlog: Int = 512,
              onListening cb : (( http.Server ) -> Void)? = nil) -> Self
  {
    let server = http.createServer(handler: self.handle)
    _ = server.listen(port, "0.0.0.0", backlog: backlog, onListening: cb)
    return self
  }
  
  @inlinable
  @discardableResult
  func listen(_ port: Int?, backlog: Int = 512,
              onListening cb : @escaping () -> Void) -> Self
  {
    return listen(port, backlog: backlog) { _ in cb() }
  }
}

import enum   MacroCore.process
import func   fs.statSync
import struct Foundation.URL

/**
 * An attempt to emulate the `__dirname` variable in Node modules,
 * requires a function in Swift.
 *
 * The complicated thing is that SPM does not have proper resource locations.
 * A workaround is to use the `#file` compiler directive, which contains the
 * location of the Swift sourcefile _calling_ `__dirname()`.
 *
 * Now the difficult part is, that the environment may not have access to the
 * source file anymore (because just the library is being deployed).
 * In this case, we return `process.cwd`.
 *
 * Note: Does synchronous I/O, be careful when to call this!
 */
public func __dirname(caller: String = #file) -> String {
  do {
    _ = try statSync(caller)
    return URL(fileURLWithPath: caller).deletingLastPathComponent().path
  }
  catch {
    return process.cwd()
  }
}
