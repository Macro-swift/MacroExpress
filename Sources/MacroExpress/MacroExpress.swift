//
//  MacroExpress.swift
//  MacroExpress
//
//  Created by Helge Heß.
//  Copyright © 2020 ZeeZide GmbH. All rights reserved.
//

@_exported import MacroCore
@_exported import connect
@_exported import express
import enum mime.mime

@_exported import func     MacroCore.nextTick
@_exported import func     MacroCore.setTimeout
@_exported import enum     MacroCore.console
@_exported import enum     MacroCore.process
@_exported import func     MacroCore.concat
@_exported import enum     MacroCore.json
@_exported import struct   MacroCore.Buffer
@_exported import enum     MacroCore.ReadableError
@_exported import enum     MacroCore.WritableError
@_exported import protocol NIO.EventLoop
@_exported import protocol NIO.EventLoopGroup
@_exported import enum     mime.mime

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
import enum      http.BasicAuthModule
public typealias basicAuth = BasicAuthModule
import enum      http.QueryStringModule
public typealias querystring = QueryStringModule

// MARK: - Process stuff

public var argv : [ String ]          { return process.argv }
public var env  : [ String : String ] { return process.env  }
