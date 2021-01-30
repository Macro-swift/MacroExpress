//
//  ServeStatic.swift
//  Noze.io / MacroExpress
//
//  Created by Helge Heß on 08/05/16.
//  Copyright © 2016-2021 ZeeZide GmbH. All rights reserved.
//

import enum   MacroCore.process
import struct Foundation.URL
import fs
import mime
import xsys

/**
 * Specify file permissions for `serveStatic`
 */
public enum ServeFilePermission {
  
  /// Allow access to the file.
  case allow
  
  /// Deny access to the file, will usually return a 404 (as a 403 exposes the
  /// existence)
  case deny
  
  /// Ignore a file, i.e. behave as if it didn't exist
  case ignore
}

/**
 * Specifies the supported processing of index-files.
 *
 * If the local path targetted by serveStatic is a directory,
 * serveStatic will check for index-files as specified by
 * this behaviour.
 * Possible modes are: no index file handling, a single index file or multiple
 * index files.
 */
public enum IndexBehaviour {
  
  /// Don't do any index-file processing.
  case none
  
  /// Support a single index-file with the specified name (e.g. index.html)
  case indexFile (String)
  
  /// Support a set of index files.
  case indexFiles([ String ])
  
  @inlinable
  public init() {
    self = .indexFile("index.html")
  }
}

/**
 * Options supported by `serveStatic`.
 */
public struct ServeStaticOptions {
  
  public let dotfiles      = ServeFilePermission.allow
  public let etag          = false
  public let extensions    : [ String ]? = nil
  public let index         = IndexBehaviour()
  public let lastModified  = true
  public let redirect      = true
  public let `fallthrough` = true
 
  public init() {} // otherwise init is private
}

public enum ServeStaticError: Swift.Error {
  case couldNotConstructIndexPath
  case couldNotParseURL
  case fileMissing        (URL)
  case indexFileIsNotAFile(URL)
  case pathIsNotAFile     (URL)
}

/**
 * Serve static files, designed after:
 *
 *   https://github.com/expressjs/serve-static
 *
 * Example:
 *
 *     app.use(serveStatic(__dirname() + "/public"))
 *
 */
public func serveStatic(_       p : String             = process.cwd(),
                        options o : ServeStaticOptions = ServeStaticOptions())
            -> Middleware
{
  // Note: 'static' is a reserved word ...
  // TODO: wrapped request with originalUrl, baseUrl etc
  
  let baseFileURL = URL(fileURLWithPath: p.isEmpty ? process.cwd() : p)
                      .standardized
  
  // options
  let options = ServeStaticOptions()
  
  // middleware
  return { req, res, next in
    // we only want HEAD + GET
    guard req.method == "HEAD" || req.method == "GET" else {
      if o.fallthrough { return next() }
      res.writeHead(.methodNotAllowed)
      res.end()
      return
    }
    
    // parse URL
    guard let url = URL(string: req.url)?.standardized, !url.path.isEmpty else {
      if o.fallthrough { return next() }
      return next(ServeStaticError.couldNotParseURL)
    }
    let rqPath = url.path
    
    // FIXME: sanitize URL, remove '..' etc!!!
    
    // naive implementation
    let fsURL : URL
    if rqPath.isEmpty || rqPath == "/" {
      fsURL = baseFileURL
    }
    else {
      let relPath = rqPath.hasPrefix("/") ? String(rqPath.dropFirst()) : rqPath
      guard let url = URL(string: relPath, relativeTo: baseFileURL) else {
        if o.fallthrough { return next() }
        return next(ServeStaticError.couldNotParseURL)
      }
      fsURL = url
    }
    
    
    // dotfiles
    
    if fsURL.lastPathComponent.hasPrefix(".") {
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
    fs.stat(fsURL.path) { err, stat in
      guard let lStat = stat, err == nil else {
        if o.fallthrough { return next() }
        res.writeHead(.notFound)
        res.end()
        return
      }
      
      // directory
      
      if lStat.isDirectory() {
        if options.redirect && !rqPath.hasSuffix("/") {
          res.writeHead(.permanentRedirect,
                        headers: [ "Location": rqPath + "/" ])
          res.end()
          return
        }
        
        switch options.index {
          case .indexFile(let filename):
            guard let indexFileURL =
                        URL(string: filename, relativeTo: fsURL) else {
              return next(ServeStaticError.couldNotConstructIndexPath)
            }
            
            fs.stat(indexFileURL.path) { err, stat in // TODO: reuse closure
              guard let lStat = stat, err == nil else {
                if o.fallthrough { return next() }
                res.writeHead(.notFound)
                res.end()
                return
              }
              guard lStat.isFile() else {
                return next(ServeStaticError.indexFileIsNotAFile(indexFileURL))
              }

              if res.headers["Content-Type"].isEmpty,
                 let type = mime.lookup(indexFileURL.path)
              {
                res.setHeader("Content-Type", type)
              }
              res.setHeader("Content-Length", lStat.size)
              
              // TODO: content-type?
              res.writeHead(200)
              if req.method == "HEAD" { res.end() }
              else { _ = fs.createReadStream(indexFileURL.path).pipe(res) }
            }
            return
          
          default: // TODO: implement multi-option
            res.writeHead(404)
            res.end()
            return
        }
      }
      
      
      // regular file
      
      guard lStat.isFile() else {
        return next(ServeStaticError.pathIsNotAFile(fsURL))
      }

      if res.headers["Content-Type"].isEmpty,
         let type = mime.lookup(fsURL.path)
      {
        res.setHeader("Content-Type", type)
      }
      res.setHeader("Content-Length", lStat.size)

      res.writeHead(200)
      if req.method == "HEAD" { res.end() }
      else {
        _ = fs.createReadStream(fsURL.path).pipe(res)
      }
    }
  }
}
