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
    
    app.render(template: template, options: options, to: self)
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
   * Refer to the ``ServerResponse/render`` method for details.
   */
  func render(template: String, options: Any?, to res: ServerResponse) {
    let log = self.log

    let defaultEngine  = self.defaultEngine
    let emptyOpts      : [ String : Any ] = [:]
    let appViewOptions = get("view options") ?? emptyOpts // Any?
    let viewOptions    = options ?? appViewOptions // TODO: merge if possible
      // not usually possible, because not guaranteed to be dicts!

    let view = View(name: template, options: self)
    let name = path.basename(template, path.extname(template))
    view.lookup(name) { pathOrNot in
      guard let path = pathOrNot else {
        res.emit(error: ExpressRenderingError.didNotFindTemplate(template))
        res.finishRender500IfNecessary()
        return
      }
      
      let ext        = fs.path.extname(path)
      let viewEngine = ext.isEmpty ? defaultEngine : ext
      guard let engine = self.engines[viewEngine] else {
        log.error("Did not find view engine for extension: \(viewEngine)")
        res.emit(error: ExpressRenderingError.unsupportedViewEngine(viewEngine))
        res.finishRender500IfNecessary()
        return
      }
      
      engine(path, viewOptions) { ( results: Any?... ) in
        let rc = results.count
        let v0 = rc > 0 ? results[0] : nil
        let v1 = rc > 1 ? results[1] : nil
        
        if let error = v0 {
          res.emit(error: ExpressRenderingError
                            .templateError(error as? Swift.Error))
          log.error("template error:", error)
          res.writeHead(500)
          res.end()
          return
        }
        
        guard let result = v1 else { // Hm?
          log.warn("template returned no content: \(template) \(results)")
          res.writeHead(204)
          res.end()
          return
        }

        // TBD: maybe support a stream as a result? (result.pipe(res))
        // Or generators, there are many more options.
        if !(result is String) {
          log.warn("template rendering result is not a String:", result)
        }
        
        let s = (result as? String) ?? "\(result)"
        
        // Wow, this is harder than it looks when we want to consider a MIMEType
        // object as a value :-)
        var setContentType = true
        if let oldType = res.getHeader("Content-Type") {
          let s = (oldType as? String) ?? String(describing: oldType) // FIXME
          setContentType = (s == "httpd/unix-directory") // a hack for Apache
        }
        
        if setContentType {
          // FIXME: also consider extension of template (.html, .vcf etc)
          res.setHeader("Content-Type", detectTypeForContent(string: s))
        }
        
        res.writeHead(200)
        res.write(s)
        res.end()
      }
    }
  }
  
  func lookupTemplatePath(_ template: String, in dir: String,
                          preferredEngine: String? = nil,
                          yield: @escaping ( String? ) -> Void)
  {
    // Hm, Swift only has pathComponents on URL?
    // FIXME
    
    let pathesToCheck : [ String ] = { () -> [ String ] in
        if let ext = preferredEngine { return [ ext ] + engines.keys }
        else                         { return Array(engines.keys) }
      }()
      .map { 
        assert($0.hasPrefix("."))
        return "\(dir)/\(template)\($0)" 
      }
    
    guard !pathesToCheck.isEmpty else { return yield(nil) }
    
    final class State {
      var pending : ArraySlice<String>
      let yield   : ( String? ) -> Void
      
      init(_ pathesToCheck: [ String ], yield: @escaping ( String? ) -> Void) {
        pending = pathesToCheck[...]
        self.yield = yield
      }
      
      func step() {
        guard let pathToCheck = pending.popFirst() else { return yield(nil) }
        fs.stat(pathToCheck) { error, stat in
          guard let stat = stat, stat.isFile() else {
            return self.step()
          }
          self.yield(pathToCheck)
        }
      }
    }
    
    let state = State(pathesToCheck, yield: yield)
    state.step()
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
