//
//  MacroExpress.swift
//  MacroExpress
//
//  Created by Helge Heß.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

@_exported import func      MacroCore.nextTick
@_exported import func      MacroCore.setTimeout
@_exported import let       MacroCore.console
@_exported import enum      MacroCore.process
@_exported import func      MacroCore.concat
@_exported import enum      MacroCore.json
@_exported import struct    MacroCore.Buffer
@_exported import enum      MacroCore.ReadableError
@_exported import enum      MacroCore.WritableError
@_exported import func      MacroCore.__dirname
@_exported import protocol  NIO.EventLoop
@_exported import protocol  NIO.EventLoopGroup

@_exported import enum      dotenv.dotenv

@_exported import class     http.IncomingMessage
@_exported import class     http.OutgoingMessage
@_exported import class     http.ServerResponse

@_exported import enum      mime.mime
@_exported import func      connect.connect
@_exported import typealias connect.Middleware
@_exported import typealias connect.Next
@_exported import func      connect.cookieParser
@_exported import let       connect.cookies
@_exported import func      connect.cors
@_exported import func      connect.logger
@_exported import func      connect.methodOverride
@_exported import func      connect.pause
@_exported import enum      connect.qs
@_exported import func      connect.serveStatic
@_exported import func      connect.session
@_exported import func      connect.typeIs
@_exported import func      connect.nocache

@_exported import class     express.Express
@_exported import typealias express.ExpressEngine
@_exported import typealias express.Router
@_exported import class     express.Route

@_exported import struct    multer.multer

// We need to import those fully, because they contain query a few extensions,
// which we can't import selectively :-/
@_exported import MacroCore
@_exported import connect
@_exported import express

// MARK: - Submodules in `fs` Target

import enum      fs.FileSystemModule
public typealias fs = FileSystemModule
import enum      fs.PathModule
public typealias path = PathModule
import enum      fs.JSONFileModule
public typealias jsonfile = JSONFileModule

// MARK: - Submodules in `http` Target

import enum      http.HTTPModule
public typealias http = HTTPModule
import enum      express.BasicAuthModule
public typealias expressBasicAuth = express.expressBasicAuth
import enum      http.QueryStringModule
public typealias querystring = QueryStringModule

// MARK: - Process stuff

@inlinable
public var argv : [ String ]          { return process.argv }
@inlinable
public var env  : [ String : String ] { return process.env  }
