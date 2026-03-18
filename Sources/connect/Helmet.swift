//
//  Helmet.swift
//  MacroExpress
//
//  Created by Helge Hess.
//  Copyright (C) 2026 ZeeZide GmbH. All rights reserved.
//

import class http.ServerResponse

/**
 * Security headers middleware, modelled after the Node.js `helmet` package.
 *
 * Sets standard security headers and removes `X-Powered-By` by default.
 *
 * Usage:
 * ```swift
 * app.use(helmet())
 *
 * var opts = Helmet.Options()
 * opts.xFrameOptions = nil  // disable
 * app.use(helmet(opts))
 * ```
 *
 * Node: https://www.npmjs.com/package/helmet
 */
public struct Helmet {

  public struct Options {

    /**
     * Controls which resources the browser is allowed to load (scripts, styles, 
     * images, etc.). Mitigates XSS and data injection attacks.
     *
     * Header: `Content-Security-Policy`
     */
    public var contentSecurityPolicy         : String?

    /**
     * Controls whether a top-level document can share a browsing context group 
     * with cross-origin documents. 
     * Required for `SharedArrayBuffer` / high-resolution timers.
     *
     * Header: `Cross-Origin-Opener-Policy`
     */
    public var crossOriginOpenerPolicy       : String?

    /**
     * Prevents other origins from reading this response. Blocks cross-origin 
     * no-cors requests to protect against Spectre-like side-channel attacks.
     *
     * Header: `Cross-Origin-Resource-Policy`
     */
    public var crossOriginResourcePolicy     : String?

    /**
     * Hints the browser to isolate the origin into its own agent cluster for
     * improved performance isolation.
     *
     * Header: `Origin-Agent-Cluster`
     */
    public var originAgentCluster            : String?

    /**
     * Controls how much referrer information is sent with navigation and 
     * sub-resource requests. `no-referrer` prevents leaking URL paths to third 
     * parties.
     *
     * Header: `Referrer-Policy`
     */
    public var referrerPolicy                : String?

    /**
     * Tells the browser to only use HTTPS for this domain for the specified 
     * duration (in seconds). `includeSubDomains` extends the policy to all 
     * subdomains.
     *
     * Header: `Strict-Transport-Security`
     */
    public var strictTransportSecurity       : String?

    /**
     * Prevents the browser from MIME-sniffing a response away from the declared 
     * `Content-Type`, blocking attacks that exploit type confusion.
     *
     * Header: `X-Content-Type-Options`
     */
    public var xContentTypeOptions           : String?

    /**
     * Controls whether the browser prefetches DNS for links on the page. 
     * `off` prevents DNS leaks about which external links appear on a page.
     *
     * Header: `X-DNS-Prefetch-Control`
     */
    public var xDNSPrefetchControl           : String?

    /**
     * Prevents IE8+ from executing downloads in the site's context (legacy IE 
     * protection).
     *
     * Header: `X-Download-Options`
     */
    public var xDownloadOptions              : String?

    /**
     * Controls whether the page can be embedded in `<frame>`, `<iframe>`, or 
     * `<object>` elements. `SAMEORIGIN` allows framing only by the same origin, 
     * preventing clickjacking.
     *
     * Header: `X-Frame-Options`
     */
    public var xFrameOptions                 : String?

    /**
     * Restricts Adobe Flash and Acrobat from loading data from this domain via 
     * cross-domain policy files.
     *
     * Header: `X-Permitted-Cross-Domain-Policies`
     */
    public var xPermittedCrossDomainPolicies : String?

    /**
     * Disables the legacy XSS Auditor in older browsers. Set to `0` because the 
     * auditor itself can introduce vulnerabilities.
     *
     * Header: `X-XSS-Protection`
     */
    public var xXSSProtection                : String?

    /**
     * Whether to strip the `X-Powered-By` response header to avoid revealing 
     * the server technology.
     */
    public var removeXPoweredBy              : Bool

    public init(
      contentSecurityPolicy         : String? = "default-src 'self'",
      crossOriginOpenerPolicy       : String? = "same-origin",
      crossOriginResourcePolicy     : String? = "same-origin",
      originAgentCluster            : String? = "?1",
      referrerPolicy                : String? = "no-referrer",
      strictTransportSecurity       : String? =
        "max-age=15552000; includeSubDomains",
      xContentTypeOptions           : String? = "nosniff",
      xDNSPrefetchControl           : String? = "off",
      xDownloadOptions              : String? = "noopen",
      xFrameOptions                 : String? = "SAMEORIGIN",
      xPermittedCrossDomainPolicies : String? = "none",
      xXSSProtection                : String? = "0",
      removeXPoweredBy              : Bool    = true
    )
    {
      self.contentSecurityPolicy         = contentSecurityPolicy
      self.crossOriginOpenerPolicy       = crossOriginOpenerPolicy
      self.crossOriginResourcePolicy     = crossOriginResourcePolicy
      self.originAgentCluster            = originAgentCluster
      self.referrerPolicy                = referrerPolicy
      self.strictTransportSecurity       = strictTransportSecurity
      self.xContentTypeOptions           = xContentTypeOptions
      self.xDNSPrefetchControl           = xDNSPrefetchControl
      self.xDownloadOptions              = xDownloadOptions
      self.xFrameOptions                 = xFrameOptions
      self.xPermittedCrossDomainPolicies = xPermittedCrossDomainPolicies
      self.xXSSProtection                = xXSSProtection
      self.removeXPoweredBy              = removeXPoweredBy
    }
  }

  @inlinable
  public init() {}

  public func callAsFunction(_ options: Options = Options()) -> Middleware {
    return { req, res, next in
      func h(_ name: String, _ value: String?) {
        if let v = value { res.setHeader(name, v) }
      }
      h("Content-Security-Policy"      , options.contentSecurityPolicy)
      h("Cross-Origin-Opener-Policy"   , options.crossOriginOpenerPolicy)
      h("Cross-Origin-Resource-Policy" , options.crossOriginResourcePolicy)
      h("Origin-Agent-Cluster"         , options.originAgentCluster)
      h("Referrer-Policy"              , options.referrerPolicy)
      h("Strict-Transport-Security"    , options.strictTransportSecurity)
      h("X-Content-Type-Options"       , options.xContentTypeOptions)
      h("X-DNS-Prefetch-Control"       , options.xDNSPrefetchControl)
      h("X-Download-Options"           , options.xDownloadOptions)
      h("X-Frame-Options"              , options.xFrameOptions)
      h("X-XSS-Protection"             , options.xXSSProtection)
      h("X-Permitted-Cross-Domain-Policies",
        options.xPermittedCrossDomainPolicies)
      if options.removeXPoweredBy { res.removeHeader("X-Powered-By") }
      next()
    }
  }
}

public let helmet = Helmet()
