//
//  BasicAuth.swift
//  Macro
//
//  Created by Helge Heß on 6/3/16.
//  Copyright © 2020-2023 ZeeZide GmbH. All rights reserved.
//

#if canImport(Foundation)
  import Foundation
#endif
import http
import protocol MacroCore.EnvironmentKey

public enum BasicAuthModule {}
public typealias expressBasicAuth = BasicAuthModule

public extension BasicAuthModule {
  // https://medium.com/javascript-in-plain-english/add-basic-authentication-to-an-express-app-9536f5095e88
  
  typealias Credentials = http.BasicAuthModule.Credentials
  
  #if canImport(Foundation) // String.Encoding.utf8, provide alternative
    @inlinable
    static func auth(_ req: IncomingMessage, encoding: String.Encoding = .utf8)
                  throws -> Credentials
    {
      return try http.BasicAuthModule.auth(req, encoding: encoding)
    }
  #endif // canImport(Foundation)

  typealias SyncAuthorizer  = (_ user: String, _ password: String ) -> Bool
  typealias AsyncAuthorizer = (_ user: String, _ password: String,
                               @escaping ( Swift.Error?, Bool ) -> Void) -> Void

  struct Options {
    public enum Authorizer {
      case none
      case sync (SyncAuthorizer)
      case async(AsyncAuthorizer)
    }
    
    public var realm      : String?
    public var users      : [ String : String ]
    public var authorizer : Authorizer
    public var challenge  = true
    
    public var unauthorizedResponse : (( IncomingMessage ) -> String)?
    
    public init(realm: String? = nil, users: [String : String] = [:],
                authorizer: Authorizer = .none, challenge: Bool = true,
                unauthorizedResponse: ((IncomingMessage) -> String)? = nil)
    {
      self.realm                = realm
      self.users                = users
      self.authorizer           = authorizer
      self.challenge            = challenge
      self.unauthorizedResponse = unauthorizedResponse
    }
  }
  
  /**
   * Perform HTTP Basic authentication. Only let the request continue if the
   * authentication is successful.
   *
   * Basic usage:
   * ```
   * app.use(expressBasicAuth.basicAuth(users: [
   *   "admin": "supersecret"
   * ]))
   *
   * app.use { req, res, next in
   *   console.log("user is authorized:", req.authenticatedBasicAuthUser)
   * }
   * ```
   *
   * Using a custom authenticator:
   * ```
   * app.use(expressBasicAuth.basicAuth { login, password in
   *   return login == "admin" && password == "supersecret"
   * })
   * ```
   *
   * Asynchronous authentication:
   * ```
   * app.use(expressBasicAuth.basicAuth { login, password, yield in
   *   yield(nil, login == "admin" && password == "supersecret")
   * })
   * ```
   *
   * - Parameters:
   *   - options:    The configuration for the authentication, see ``Options``.
   *   - users:      An optional dictionary of users/passwords to run the auth
   *                 against (convenience argument, also available via ``Options``).
   *   - authorizer: An optional, synchronous, authorization function
   *                 (convenience argument, also available via ``Options``).
   */
  @inlinable
  static func basicAuth(_ options  : Options = Options(),
                        users      : [ String: String ]? = nil,
                        authorizer : SyncAuthorizer?     = nil)
              -> Middleware
  {
    var options = options
    users.flatMap { $0.forEach { options.users[$0] = $1 } }
    if let authorizer = authorizer { options.authorizer = .sync(authorizer) }
    return basicAuth(options: options)
  }
  
  /**
   * Perform HTTP Basic authentication. Only let the request continue if the
   * authentication is successful.
   *
   * Basic usage:
   *
   *     app.use(expressBasicAuth.basicAuth(users: [
   *       "admin": "supersecret"
   *     ]))
   *
   *     app.use { req, res, next in
   *       console.log("user is authorized:", req.authenticatedBasicAuthUser)
   *     }
   *
   * Using a custom authenticator:
   *
   *     app.use(expressBasicAuth.basicAuth { login, password in
   *       return login == "admin" && password == "supersecret"
   *     })
   *
   * Asynchronous authentication:
   *
   *     app.use(expressBasicAuth.basicAuth { login, password, yield in
   *       yield(nil, login == "admin" && password == "supersecret")
   *     })
   *
   */
  @inlinable
  static func basicAuth(_ options  : Options,
                        users      : [ String: String ]? = nil,
                        authorizer : @escaping AsyncAuthorizer)
              -> Middleware
  {
    var options = options
    users.flatMap { $0.forEach { options.users[$0] = $1 } }
    options.authorizer = .async(authorizer)
    return basicAuth(options: options)
  }

  @inlinable
  static func safeCompare(_ lhs: String, _ rhs: String) -> Bool {
    return lhs == rhs // right, no difference in Swift?
  }
  
  @usableFromInline
  internal static func basicAuth(options: Options) -> Middleware {
    let unauthorizedResponse = options.unauthorizedResponse ?? { _ in
      if let realm = options.realm {
        return "Authentication failed, realm: \(realm)"
      }
      else {
        return "Authentication failed."
      }
    }
    
    return { req, res, next in
      
      func sendAuthenticationFailure() {
        res.statusCode = 401
        
        if options.challenge { // TBD
          if let realm = options.realm { // TODO: escaping
            res.setHeader("WWW-Authenticate", "Basic realm=\"\(realm)\"")
          }
          else {
            res.setHeader("WWW-Authenticate", "Basic")
          }
        }
        
        res.write(unauthorizedResponse(req))
        return res.end()
      }
      
      /* Parse credentials using `http` module */
      let credentials : Credentials
      do {
        credentials = try auth(req)
      }
      catch {
        req.log.error("Authentication failed w/ error:", error)
        return sendAuthenticationFailure()
      }
      
      /* Track (unauthenticated) user in Logger */
      req.log[metadataKey: "basic.user"] = .string(credentials.name)

      
      /* Authenticate */
      
      if let password = options.users[credentials.name] {
        guard safeCompare(credentials.pass, password) else {
          return sendAuthenticationFailure()
        }
        req.environment[BasicAuthUserKey.self] = credentials.name
        return next()
      }
      
      switch options.authorizer {
      
        case .async(let authorizer):
          authorizer(credentials.name, credentials.pass) { error, ok in
            if let error = error {
              req.log.error("Error during authentication of:", credentials.name,
                            error)
              req.emit(error: error)
              return res.sendStatus(500)
            }
            
            guard ok else { return sendAuthenticationFailure() }
            
            req.environment[BasicAuthUserKey.self] = credentials.name
            return next()
          }
          
        case .sync(let authorizer):
          guard authorizer(credentials.name, credentials.pass) else {
            return sendAuthenticationFailure()
          }
          req.environment[BasicAuthUserKey.self] = credentials.name
          return next()
          
        case .none:
          if options.users.isEmpty {
            req.log.warn("No authentication setup in basicAuth middleware?")
          }
          return sendAuthenticationFailure()
      }
    }
  }
}

// MARK: - IncomingMessage extension

private enum BasicAuthUserKey: EnvironmentKey {
  static let defaultValue = ""
  static let loggingKey   = "user"
}

public extension IncomingMessage {

  /**
   * Returns the login of a user which got successfully authenticated using
   * the `basicAuth` middleware.
   */
  var authenticatedBasicAuthUser : String {
    get { return self[BasicAuthUserKey.self] }
  }
}
