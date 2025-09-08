//
//  dirname.swift
//  MacroExpress
//
//  Created by Helge Heß on 09/07/25.
//  Copyright © 2025 ZeeZide GmbH. All rights reserved.
//

// Disambiguate __dirname (connect vs MacroCore, maybe connect should be 
// internal?)

import func MacroCore.__dirname

#if swift(>=5.3)
  func __dirname(caller: String = #filePath) -> String {
    return MacroCore.__dirname(caller: caller)
  }
#else
  func __dirname(caller: String = #file) -> String {
    return MacroCore.__dirname(caller: caller)
  }
#endif
