//
//  View.swift
//  MacroExpress
//
//  Created by Helge Heß on 09/07/25.
//  Copyright © 2025 ZeeZide GmbH. All rights reserved.
//

import MacroCore
import fs

public extension SettingsHolder {
  
  /**
   * The default engine set by `app.set("view engine", "mustache")`.
   * 
   * Note: The default engine has *no* leading dot!
   */
  @inlinable
  var defaultEngine: String { 
    settings["view engine"] as? String ?? ""
  }
  
  /**
   * The views directory for templates set by `app.set("views", "views")`.
   */
  var views : [ String ] {
    switch settings["views"] {
      case .none:
        return [ process.env["EXPRESS_VIEWS"] ?? __dirname() + "/views" ]
      case let v as String: return [ v ]
      case let v as [ String ]: return v
      case .some(let v):
        assertionFailure("Unexpected value in 'views' option: \(v)")
        return [ String(describing: v) ]
    }
  }
  
}

extension Express {
  
  open class View {
    
    /**
     * The default engine set by `app.set("view engine", "mustache")`.
     */
    public let defaultEngine : String
    
    /// Raw view name passed to ``ServerResponse/render``, e.g. "index.html"
    public let name     : String
    
    /// Extension of the name, if there was one (e.g. ".html" for "index.html")
    public let ext      : String
    
    /**
     * The views directory for templates set by `app.set("views", "views")`.
     */
    public let root     : [ String ]
    
    /// The render function for the extension specified in ``ext`` (i.e. passed
    /// explicitly to the render function, like `render("index.mustache")`.
    public var engine   : ExpressEngine?
    
    /// All known engines
    private let engines : [ String : ExpressEngine ]
   
    /// The resolved path (for cached views)
    var path : String?
    
    public required init(name: String, options: Express) {
      self.name          = name
      self.ext           = fs.path.extname(name)
      self.engines       = options.engines
      self.root          = options.views
      self.defaultEngine = options.defaultEngine
      self.engine        = engines[self.ext]      
    }
    
    /**
     * Lookup the path of a template in the filesystem.
     * 
     * Entry point that can be overridden in subclasses. The View class to use
     * is specified in the `view` setting (e.g. `set("view", MyView.self)`).
     *
     * - Parameters:
     *   - name:  The template name *without* the extension! Whether it was
     *            originally provided or not.
     *   - yield: The function to call once the lookup process has finished.
     */
    open func lookup(_ name: String, yield: @escaping ( String? ) -> Void) {
      // This is synchronous in Express.js.
      
      guard !root.isEmpty else { return yield(nil) }
      
      let preferredEngine = self.ext.isEmpty 
              ? (defaultEngine.isEmpty ? nil : ".\(defaultEngine)") 
              : self.ext
      
      // All this is kinda expensive?! But we might want to cache it.
      var pathesToCheck = [ String ]()
      pathesToCheck.reserveCapacity(root.count * (engines.count + 1) + 1)
      if let ext = preferredEngine {
        for path in root {
          pathesToCheck.append("\(path)/\(name)\(ext)")
        }
      }
      if self.ext.isEmpty { // no explicit extension specified, search for all
        // Real Express.js doesn't do this by default.
        for extraKey in engines.keys.sorted() where extraKey != preferredEngine 
        {
          for path in root {
            pathesToCheck.append("\(path)/\(name)\(extraKey)")
          }        
        }
      }
      
      FileSystemModule.findExistingFile(pathesToCheck, where: { $0.isFile() },
                                        yield: yield)
    }
  }
}

import xsys

public extension FileSystemModule {
  
  /**
   * This asynchronously finds the first path in the given set of pathes that
   * exists.
   */
  static func findExistingFile(_ pathesToCheck: [ String ],
                               where statCondition: @escaping 
                                 ( stat_struct ) -> Bool,
                               yield: @escaping ( String? ) -> Void)
  {
    guard !pathesToCheck.isEmpty else { return yield(nil) }
    
    final class State {
      var pending       : ArraySlice<String>
      let statCondition : ( stat_struct ) -> Bool
      let yield         : ( String? ) -> Void
      
      init(_ pathesToCheck: [ String ], 
           statCondition: @escaping ( stat_struct ) -> Bool, 
           yield: @escaping ( String? ) -> Void) 
      {
        pending            = pathesToCheck[...]
        self.statCondition = statCondition
        self.yield         = yield
      }
      
      func step() {
        let statCondition = self.statCondition
        guard let pathToCheck = pending.popFirst() else { return yield(nil) }
        fs.stat(pathToCheck) { error, stat in
          guard let stat = stat, statCondition(stat) else {
            return self.step()
          }
          self.yield(pathToCheck)
        }
      }
    }
    
    let state = State(pathesToCheck, statCondition: statCondition, yield: yield)
    state.step()
  }
}
