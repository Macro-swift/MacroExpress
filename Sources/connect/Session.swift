//
//  Session.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 6/16/16.
//  Copyright © 2016-2025 ZeeZide GmbH. All rights reserved.
//

import let      MacroCore.console
import protocol MacroCore.EnvironmentKey
import class    http.IncomingMessage
import class    http.ServerResponse
import struct   Foundation.UUID
import struct   NIOConcurrencyHelpers.NIOLock

fileprivate let sessionIdCookie = Cookie(
  name: "NzSID", 
  path: "/",
  httpOnly: true,
  maxAge: 3600
)

fileprivate var sessionIdCounter = 0

public typealias SessionIdGenerator = ( IncomingMessage ) -> String

func nextSessionID(msg: IncomingMessage) -> String {
  // https://github.com/SwiftWebUI/SwiftWebUI/issues/4
  // https://neilmadden.blog/2018/08/30/moving-away-from-uuids/
  return UUID().uuidString
}

public func session(store s : SessionStore        = InMemorySessionStore(),
                    cookie  : Cookie?             = nil,
                    genid   : SessionIdGenerator? = nil)
            -> Middleware
{
  return { req, res, next in
    // This is just a workaround for recursive funcs crashing the compiler.
    let ctx = SessionContext(request        : req,
                             response       : res,
                             store          : s,
                             templateCookie : cookie ?? sessionIdCookie,
                             genid          : genid  ?? nextSessionID)
    
    guard let sessionID = ctx.sessionID else {
      // no cookie with session-ID, register new
      ctx.configureNewSession()
      return next()
    }
    
    // TODO: This should do a session-checkout.
    // retrieve from store
    s.get(sessionID: sessionID) { err, session in
      if let rerr = err {
        req.log
          .notice("could not retrieve session with ID \(sessionID): \(rerr)")
        ctx.configureNewSession()
        return next()
      }
      
      guard let rsession = session else {
        req.log.notice(
          "No error, but could not retrieve session with ID \(sessionID)")
        ctx.configureNewSession()
        return next()
      }
      
      // found a session, store into request
      req.environment[SessionKey.self] = rsession
      ctx.pushSessionCookie()
      _ = res.onceFinish {
        // TODO: This should do the session-checkin.
        s.set(sessionID: sessionID, session: req.session) { err in
          if let err = err {
            req.log.error("could not save session \(sessionID): \(err)")
          }
        }
      }
      next()
    }
  }
}

class SessionContext {
  // FIXME: This is temporary until the swiftc crash with inner functions
  //        is fixed.
  // A class because we pass it around in closures.
  
  let req       : IncomingMessage
  let res       : ServerResponse
  let store     : SessionStore
  let template  : Cookie
  let genid     : SessionIdGenerator
  
  let cookies   : Cookies
  var sessionID : String? = nil
  
  init(request: IncomingMessage, response: ServerResponse,
       store: SessionStore, templateCookie: Cookie,
       genid: @escaping SessionIdGenerator)
  {
    self.req       = request
    self.res       = response
    self.store     = store
    self.template  = templateCookie
    self.genid     = genid
    
    // Derived
    self.cookies   = Cookies(req, res)
    self.sessionID = self.cookies[templateCookie.name]
  }
  
  func pushSessionCookie() {
    guard let sessionID = self.sessionID else { return }
    var ourCookie = template
    ourCookie.value = sessionID
    cookies.set(cookie: ourCookie)
  }
  
  func configureNewSession() {
    let newSessionID = genid(req)
    req.environment[SessionKey.self] = Session()
    
    sessionID = newSessionID
    pushSessionCookie()
    
    // capture some stuff locally
    let req   = self.req
    let store = self.store
    
    _ = res.onceFinish {
      store.set(sessionID: newSessionID, session: req.session) { err in
        if let err = err {
          req.log.error("could not save new session \(newSessionID): \(err)")
        }
      }
    }
  }
  
  @inlinable
  var hasSessionID : Bool { return self.sessionID != nil }
}


// MARK: - Session Class

public class Session {
  // Reference type, so that we can do stuff like:
  //
  //   req.session["a"] = 10
  //
  // kinda non-obvious.
  
  // This should not be concurrent but use a checkin/checkout system.
  fileprivate let lock = NIOLock()
  public var values = Dictionary<String, Any>()
  
  public subscript(key: String) -> Any? {
    set {
      lock.withLock {
        if let v = newValue { values[key] = v }
        else { _ = values.removeValue(forKey: key) }
      }
    }
    get { return lock.withLock { values[key] } }
  }
  
  public subscript(int key: String) -> Int {
    guard let v = lock.withLock({ values[key] }) else { return 0 }
    if let iv = v as? Int { return iv }
    #if swift(>=5.10)
    if let i = (v as? any BinaryInteger) { return Int(i) }
    #endif
    return Int("\(v)") ?? 0
  }
}


// MARK: - IncomingMessage extension

private enum SessionKey: EnvironmentKey {
  static let defaultValue : Session? = nil
  static let loggingKey   = "session"
}

public extension IncomingMessage {
  
  func registerNewSession() -> Session {
    let newSession = Session()
    environment[SessionKey.self] = newSession
    return newSession
  }
  
  var session : Session {
    return environment[SessionKey.self] ?? registerNewSession()
  }
}


// MARK: - Session Store

public enum SessionStoreError : Error {
  case SessionNotFound
  case NotImplemented
}

public protocol SessionStore {
  // TODO: this needs the cookie timeout, so that the store can expire old
  //       stuff
  // I don't particularily like the naming, but lets keep it close.
  
  /// Retrieve the session for the given ID
  func get(sessionID sid: String, _ cb: ( Error?, Session? ) -> Void)
  
  /// Store the session for the given ID
  func set(sessionID sid: String, session: Session,
           _ cb: ( Error? ) -> Void)
  
  /// Touch the session for the given ID
  func touch(sessionID sid: String, session: Session,
             _ cb: ( Error? ) -> Void)
  
  /// Destroy the session with the given session ID
  func destroy(sessionID sid: String, _ cb: ( String ) -> Void)
  
  /// Clear all sessions in the store
  func clear(cb: ( Error? ) -> Void )
  
  /// Return the number of sessions in the store
  func length(cb: ( Error?, Int) -> Void)
  
  /// Return all sessions in the store, optional
  func all(cb: ( Error?, [ Session ] ) -> Void)
}

public extension SessionStore {
  func all(cb: ( Error?, [ Session ] ) -> Void) {
    cb(SessionStoreError.NotImplemented, [])
  }
}

public class InMemorySessionStore : SessionStore {
  
  // Well, there should be a checkout/checkin system?!
  fileprivate let lock = NIOLock()
  var store : [ String : Session ]
  
  public init() {
    store = [:]
  }
  
  public func get(sessionID sid: String, _ cb: ( Error?, Session? ) -> Void ) {
    guard let session = lock.withLock({ store[sid] }) else {
      cb(SessionStoreError.SessionNotFound, nil)
      return
    }
    cb(nil, session)
  }
  
  public func set(sessionID sid: String, session: Session,
                  _ cb: ( Error? ) -> Void )
  {
    lock.withLock { store[sid] = session }
    cb(nil)
  }
  
  public func touch(sessionID sid: String, session: Session,
                    _ cb: ( Error? ) -> Void )
  {
    cb(nil)
  }
  
  public func destroy(sessionID sid: String, _ cb: ( String ) -> Void) {
    lock.withLock { _ = store.removeValue(forKey: sid) }
    cb(sid)
  }
  
  public func clear(cb: ( Error? ) -> Void ) {
    lock.withLock { store.removeAll() }
    cb(nil)
  }
  
  public func length(cb: ( Error?, Int) -> Void) {
    cb(nil, lock.withLock { store.count })
  }
  
  public func all(cb: ( Error?, [ Session ] ) -> Void) {
    let values = Array(lock.withLock { store.values })
    cb(nil, values)
  }
}
