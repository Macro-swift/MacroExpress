//
//  Render.swift
//  Noze.io / Macro / ExExpress
//
//  Created by Helge Heß on 6/2/16.
//  Copyright © 2016-2025 ZeeZide GmbH. All rights reserved.
//

import enum  MacroCore.process
import class http.ServerResponse
import let   MacroCore.console
import fs

public enum ExpressRenderingError: Swift.Error {
  case responseHasNoAppObject
  case unsupportedViewEngine(String)
  case didNotFindTemplate(String)
  case templateError(Swift.Error?)
}

public extension ServerResponse {
  
  /**
   * Lookup a template with the given name, locate the rendering engine for it,
   * and render it with the options that are passed in.
   *
   * Example:
   * ```swift
   * app.get { _, res in
   *   res.render("index", [ "title": "Hello World!" ])
   * }
   * ```
   *
   * Assuming your 'views' directory contains an `index.mustache` file, this
   * would trigger the Mustache engine to render the template with the given
   * dictionary as input.
   *
   * When no options are passed in, render will fallback to the `view options`
   * setting in the application (TODO: merge the two contexts).
   */
  func render(_ template: String, _ options : Any? = nil) {
    guard let app = self.app else {
      log.error("No app object assigned to response: \(self)")
      emit(error: ExpressRenderingError.responseHasNoAppObject)
      finishRender500IfNecessary()
      return
    }
    
    app.render(template, options) { errorMaybe, contentMaybe in
      if let error = errorMaybe {
        self.emit(error: error)
        return self.finishRender500IfNecessary()
      }
      
      guard let content = contentMaybe else { 
        return self.sendStatus(204) 
      }
      
      // Wow, this is harder than it looks. we may want to consider a MIMEType
      // object as a value :-)
      // FIXME: also consider extension of template (.html, .vcf etc)
      self.setHeader("Content-Type", detectTypeForContent(string: content))
      
      self.send(content)
    }
  }
  
  fileprivate func finishRender500IfNecessary() {
    guard !writableEnded else { return }
    writeHead(500)
    end()
  }
}

public extension Express {

  /**
   * Lookup a template with the given name, locate the rendering engine for it,
   * and render it with the options that are passed in.
   *
   * Example:
   * ```swift
   * app.render("index", [ "title": "Hello World!" ]) { error, html in
   *   ...
   * }
   * ```
   *
   * Assuming your 'views' directory contains an `index.mustache` file, this
   * would trigger the Mustache engine to render the template with the given
   * dictionary as input.
   *
   * When no options are passed in, render will fallback to the `view options`
   * setting in the application (TODO: merge the two contexts).
   */
  func render(_ template: String, _ options : Any? = nil,
              yield: @escaping ( Error?, String? ) -> Void)
  {
    let log            = self.log
    let cacheOn        = settings.enabled("view cache")
    let emptyOpts      : [ String : Any ] = [:]
    let appViewOptions = get("view options") ?? emptyOpts // Any?
    let viewOptions    = options ?? appViewOptions // TODO: merge if possible
      // not usually possible, because not guaranteed to be dicts!

    if cacheOn, let view = viewCache.withLockedValue({ $0[template] }),
       let path = view.path
    {
      log.trace("Using cached view:", template)
      return self.render(path: path, options: viewOptions, yield: yield)
    }
    
    let viewType : View.Type = (get("view") as? View.Type) ?? View.self
    let view = viewType.init(name: template, options: self)
    let name = path.basename(template, path.extname(template))
    view.lookup(name) { pathOrNot in
      guard let path = pathOrNot else {
        return yield(ExpressRenderingError.didNotFindTemplate(template), nil)
      }
      
      view.path = path // cache path
      if cacheOn {
        log.trace("Caching view:", template)
        self.viewCache.withLockedValue {
          $0[template] = view
        }
      }
      
      self.render(path: path, options: viewOptions, yield: yield)
    }
  }
  
  /**
   * Locate the rendering engine for a given path and render it with the options 
   * that are passed in.
   *
   * Refer to the ``ServerResponse/render`` method for details.
   * 
   * - Parameters:
   *   - path:    the filesystem path to a template.
   *   - options: Any options passed to the rendering engine.
   *   - yield:   The result of template being rendered.
   */
  func render(path: String, options: Any?, 
              yield: @escaping ( Error?, String? ) -> Void) 
  {
    let log        = self.log
    let ext        = fs.path.extname(path)
    let viewEngine = ext.isEmpty ? defaultEngine : ext
    
    guard let engine = engines[viewEngine] else {
      log.error("Did not find view engine for extension: \(viewEngine)")
      return yield(ExpressRenderingError.unsupportedViewEngine(viewEngine), nil)
    }
    
    engine(path, options) { ( results: Any?... ) in
      if let value = results.first, let error = value {
        log.error("view engine error:", error)
        yield(ExpressRenderingError.templateError(error as? Swift.Error), nil)
        return
      }
      
      guard let input = results.dropFirst().first, let result = input else {
        log.warn("View engine returned no content for:", path, results)
        return yield(nil, nil)
      }

      // TBD: maybe support a stream as a result? (result.pipe(res))
      // Or generators, there are many more options.
      if !(result is String) {
        log.warn("template rendering result is not a String:", result)
        assertionFailure("Non-template rendering result \(type(of: result))")
      }
      
      let s = (result as? String) ?? "\(result)"
      yield(nil, s)
    }
  }
  
}


import enum mime.mime

fileprivate
func detectTypeForContent(string: String,
                          default: String = "text/html; charset=utf-8")
     -> String
{
  // TODO: more clever detection? ;-)
  for ( prefix, type ) in mime.typePrefixMap {
    if string.hasPrefix(prefix) { return type }
  }
  return `default`
}


// MARK: - X Compile Support - Macro/fs/Utils/StatStruct
// Dupe to support:
// https://github.com/SPMDestinations/homebrew-tap/issues/2

#if !os(Windows)
import struct xsys.stat_struct
#if os(Linux)
  import let Glibc.S_IFMT
  import let Glibc.S_IFREG
#else
  import let Darwin.S_IFMT
  import let Darwin.S_IFREG
#endif

fileprivate extension xsys.stat_struct {
  func isFile() -> Bool { return (st_mode & S_IFMT) == S_IFREG }
}
#endif // !os(Windows)
