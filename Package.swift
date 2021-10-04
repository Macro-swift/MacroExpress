// swift-tools-version:5.2

import PackageDescription

let package = Package(
  
  name: "MacroExpress",

  products: [
    .library(name: "MacroExpress", targets: [ "MacroExpress" ]),
    .library(name: "express",      targets: [ "express"      ]),
    .library(name: "connect",      targets: [ "connect"      ]),
    .library(name: "mime",         targets: [ "mime"         ]),
    .library(name: "dotenv",       targets: [ "dotenv"       ]),
    .library(name: "multer",       targets: [ "multer"       ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/Macro-swift/Macro.git",
             from: "0.8.11"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "1.0.1")
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
    ]),
    .target(name: "connect", dependencies: [ 
      .product(name: "MacroCore", package: "Macro"), 
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      "mime" 
    ]),
    .target(name: "express", dependencies: [
      .product(name: "MacroCore", package: "Macro"),
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      "connect",   "mime", "mustache"
    ]),
    .target(name: "MacroExpress", dependencies: [ 
      .product(name: "MacroCore", package: "Macro"), 
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      .product(name: "xsys",      package: "Macro"),
      "dotenv", "mime", "connect", "express", "multer"
    ]),

    .testTarget(name: "mimeTests",       dependencies: [ "mime"    ]),
    .testTarget(name: "multerTests",     dependencies: [ "multer"  ]),
    .testTarget(name: "bodyParserTests", dependencies: [ "connect", "Macro" ]),
    .testTarget(name: "dotenvTests",     dependencies: [ "dotenv"  ]),
    .testTarget(name: "RouteTests", dependencies: [
      .product(name: "MacroTestUtilities", package: "Macro"),
      "express"
    ])
  ]
)
