//
//  URLState.swift
//  MacroExpress / connect
//
//  Created by Helge Heß.
//  Copyright © 2026 ZeeZide GmbH. All rights reserved.
//

import class    http.IncomingMessage
import protocol MacroCore.EnvironmentKey

/**
 * Per-request URL / routing state used by the connect and express routing 
 * layers (and available to other middleware that needs to track URL-derived 
 * state).
 *
 * Held by reference so that nested middleware and route handlers can mutate the
 * derived/cached fields without copying.
 *
 * All fields are combined into a single environment slot for performance.
 */
public final class URLState: @unchecked Sendable {

  /// Cache key (the URL path string) for the matching ``routingURLComponents`` 
  /// value. Empty when the cache is unpopulated.
  public var routingURLCacheKey   = ""

  /// Pre-split URL path components, cached so sibling routes at the same mount
  /// level don't each re-split the same URL. Empty when unpopulated.
  public var routingURLComponents = [ String ]()

  /// The original request URL, captured before any route-mount URL rewriting.
  /// Empty until first captured.
  public var originalURL          = ""

  /// The URL prefix that matched the current route's mount path. Empty when no 
  /// mount is active.
  public var baseURL              = ""

  /// Per-request parameter dictionary. Express fills this with the captured 
  /// route parameters (e.g. `:id` -> `"42"`), other middleware may use it for 
  /// their own keyed state.
  public var params               = [ String : String ]()

  @usableFromInline
  internal init() {}
}

public extension IncomingMessage {

  enum URLStateKey: EnvironmentKey {
    public static let defaultValue : URLState? = nil
    public static let loggingKey   = "urlState"
  }

  /**
   * Per-request connect/express routing state (route match cache, originalURL,
   * baseURL, params).
   *
   * Hot paths should grab the holder once into a local and read/write fields 
   * through it.
   */
  @inlinable
  var urlState : URLState {
    if let s = environment[URLStateKey.self] { return s }
    let s = URLState()
    environment[URLStateKey.self] = s
    return s
  }
  
  /**
   * The original URL as received from the client, before any URL rewriting by
   * mounted middleware.
   *
   * Unlike ``url``, this is never modified by routing. Falls back to ``url`` if 
   * not yet set.
   */
  @inlinable
  var originalURL : String {
    get {
      let s = urlState.originalURL
      return s.isEmpty ? url : s
    }
    set { urlState.originalURL = newValue }
  }
}
