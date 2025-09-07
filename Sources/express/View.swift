//
//  View.swift
//  MacroExpress
//
//  Created by Helge Heß on 07.09.25.
//

import Macro

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
  @inlinable
  var views : [ String ] {
    switch settings["views"] {
      case .none:
        return [ process.env["EXPRESS_VIEWS"] ??  __dirname() + "/views" ]
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
    public let engine   : ExpressEngine?
    
    /// All known engines
    private let engines : [ String : ExpressEngine ]
   
    /// The resolved path (for cached views)
    var path : String?
    
    public required init(name: String, options: Express) {
      self.name          = name
      self.ext           = Macro.path.extname(name)
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
      
      lookupFilePath(pathesToCheck, yield: yield)
    }
    
    /**
     * This asynchronously finds the first path in the given set of pathes that
     * exists.
     */
    public func lookupFilePath(_ pathesToCheck: [ String ], 
                               yield: @escaping ( String? ) -> Void)
    {
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
}
