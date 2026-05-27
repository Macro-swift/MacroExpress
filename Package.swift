// swift-tools-version:6.0

import PackageDescription

let package = Package(
  
  name: "MacroExpress",

  platforms: [ .macOS(.v15), .iOS(.v15) ],

  products: [
    .library(name: "MacroExpress", targets: [ "MacroExpress" ]),
    .library(name: "express",      targets: [ "express"      ]),
    .library(name: "connect",      targets: [ "connect"      ]),
    .library(name: "mime",         targets: [ "mime"         ]),
    .library(name: "dotenv",       targets: [ "dotenv"       ]),
    .library(name: "multer",       targets: [ "multer"       ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/apple/swift-log.git",   from: "1.11.0"),
    .package(url: "https://github.com/Macro-swift/Macro.git", from: "1.0.58"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "1.0.2")
  ],
  
  targets: [
    .target(name: "mime",   dependencies: []),
    .target(name: "dotenv", dependencies: [ 
      .product(name: "MacroCore", package: "Macro"), 
      .product(name: "fs", package: "Macro") 
    ]),
    .target(name: "multer", dependencies: [ 
      .product(name: "MacroCore", package: "Macro"), 
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      "mime", "connect" 
    ], exclude: [ "README.md" ]),
    
    .target(name: "connect", dependencies: [ 
      .product(name: "MacroCore", package: "Macro"), 
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      "mime" 
    ], exclude: [ "README.md" ], swiftSettings: [ .swiftLanguageMode(.v5) ]),
    
    .target(name: "express", dependencies: [
      .product(name: "MacroCore", package: "Macro"),
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      "connect", "mime", 
      .product(name: "Mustache",  package: "Mustache")
    ], exclude: [ "README.md" ], swiftSettings: [ .swiftLanguageMode(.v5) ]),
    
    .target(name: "MacroExpress", dependencies: [ 
      .product(name: "MacroCore", package: "Macro"), 
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      .product(name: "xsys",      package: "Macro"),
      "dotenv", "mime", "connect", "express", "multer"
    ], exclude: [ "README.md" ]),

    
    .testTarget(name: "mimeTests",       dependencies: [ "mime"    ]),
    .testTarget(name: "multerTests",     dependencies: [ "multer"  ], 
                swiftSettings: [ .swiftLanguageMode(.v5) ]),
    
    .testTarget(name: "bodyParserTests", dependencies: [ "connect", "Macro" ], 
                swiftSettings: [ .swiftLanguageMode(.v5) ]),
    
    .testTarget(name: "dotenvTests",     dependencies: [ "dotenv"  ]),
    
    .testTarget(name: "RouteTests", dependencies: [
      .product(name: "MacroTestUtilities", package: "Macro"),
      .product(name: "MacroCore",          package: "Macro"),
      "connect", "express"
    ], swiftSettings: [ .swiftLanguageMode(.v5) ])
  ]
)
