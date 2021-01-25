//
//  MulterError.swift
//  MacroExpress / multer
//
//  Created by Helge Heß on 30/05/16.
//  Copyright © 2021 ZeeZide GmbH. All rights reserved.
//

public extension multer {
  
  enum MulterError: Swift.Error {
    case limitUnexpectedFile(File)
    case tooManyFiles
    case tooManyFields
    case fileTooLarge
    case fieldNameTooLong
    case filedValueTooLong
  }
}
