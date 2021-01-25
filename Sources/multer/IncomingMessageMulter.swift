//
//  IncomingMessageMulter.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

import protocol MacroCore.EnvironmentKey
import class    http.IncomingMessage

extension multer {
  
  enum FilesKey: EnvironmentKey {
    static let defaultValue : [ String : [ multer.File ] ]? = nil
    static let loggingKey   = "files"
  }
}

public extension IncomingMessage {
  
  /**
   * The parsed files keyed by form field name. Each field can contain multiple
   * files!
   */
  var files : [ String : [ multer.File ] ] {
    set { environment[multer.FilesKey.self] = newValue }
    get { return environment[multer.FilesKey.self] ?? [:] }
  }
  
  /**
   * Returns the first parsed file.
   */
  var file : multer.File? {
    // TBD: Own key or not?
    get { return environment[multer.FilesKey.self]?.first?.value.first  }
  }
}
