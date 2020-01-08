//
//  ServeStatic.swift
//  Noze.io / Macro
//
//  Created by Helge Heß on 08/05/16.
//  Copyright © 2016-2020 ZeeZide GmbH. All rights reserved.
//

import enum   MacroCore.process
import struct Foundation.URL
import fs
import http

public enum ServeFilePermission {
  case allow, deny, ignore
}

public enum IndexBehaviour {
  case none
  case indexFile (String)
  case indexFiles([ String ])
  
  public init() {
    self = .indexFile("index.html")
  }
}

public struct ServeStaticOptions {
  
  public let dotfiles     = ServeFilePermission.allow
  public let etag         = false
  public let extensions   : [ String ]? = nil
  public let index        = IndexBehaviour()
  public let lastModified = true
  public let redirect     = true
 
  public init() {} // otherwise init is private
}

public func serveStatic(_       p : String = process.cwd(),
                        options o : ServeStaticOptions = ServeStaticOptions())
            -> Middleware
{
  // Note: 'static' is a reserved work ...
  // TODO: wrapped request with originalUrl, baseUrl etc
  
  let lPath = !p.isEmpty ? p : process.cwd()
  
  // options
  let options = ServeStaticOptions()
  
  // middleware
  return { req, res, next in
    // we only want HEAD + GET
    guard req.method == "HEAD" || req.method == "GET" else { next(); return }
    
    // parse URL
    guard let url = URL(string: req.url), !url.path.isEmpty else {
      return next()
    }
    let rqPath = url.path
    
    // FIXME: sanitize URL, remove '..' etc!!!
    
    // naive implementation
    let fsPath = lPath + rqPath
    
    
    // dotfiles
    
    // TODO: extract last path component, check whether it is a dotfile
    let isDotFile = fsPath.hasPrefix(".") // TODO
    if isDotFile {
      switch options.dotfiles {
        case .allow:  break
        case .ignore: next(); return
        case .deny:
          res.writeHead(404)
          res.end()
          return
      }
    }
    
    // FIXME: Use NIO sendfile
    
    // stat
    fs.stat(fsPath) { err, stat in
      guard err == nil && stat != nil else { next(); return }
      let lStat = stat!
      
      
      // directory
      
      if lStat.isDirectory() {
        if options.redirect && !rqPath.hasSuffix("/") {
          res.writeHead(308, [ "Location": rqPath + "/" ])
          res.end()
          return
        }
        
        switch options.index {
          case .indexFile(let filename):
            let indexPath =
              (fsPath.hasSuffix("/") ? fsPath : fsPath + "/")
              + filename
            
            fs.stat(indexPath) { err, stat in // TODO: reuse closure
              guard err == nil && stat != nil else { next(); return }
              guard stat?.isFile() ?? false   else { next(); return }
              
              // TODO: content-type?
              res.writeHead(200)
              _ = fs.createReadStream(indexPath) | res
            }
            return
          
          default: // TODO: implement multi-option
            res.writeHead(404)
            res.end()
            return
        }
      }
      
      
      // regular file
      
      guard lStat.isFile() else { next(); return }
      
      // TODO: content-type?
      res.writeHead(200)
      _ = fs.createReadStream(fsPath) | res
    }
  }
}
