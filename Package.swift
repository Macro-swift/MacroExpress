// swift-tools-version:5.0

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
             from: "0.8.9"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "1.0.1")
  ],
  
  targets: [
    .target(name: "mime",    dependencies: []),
    .target(name: "dotenv",  dependencies: [ "MacroCore", "fs" ]),
    .target(name: "multer",
            dependencies: [ "MacroCore", "fs", "http", "mime", "connect" ]),
    .target(name: "connect",
            dependencies: [ "MacroCore", "http", "fs", "mime" ]),
    .target(name: "express",
            dependencies: [
              "MacroCore", "http", "fs",
              "connect",   "mime", "mustache"
            ]),
    .target(name: "MacroExpress",
            dependencies: [ 
              "MacroCore", "xsys", "http",    "fs",
              "dotenv",    "mime", "connect", "express", "multer"
            ]),

    .testTarget(name: "mimeTests",       dependencies: [ "mime"    ]),
    .testTarget(name: "multerTests",     dependencies: [ "multer"  ]),
    .testTarget(name: "bodyParserTests", dependencies: [ "connect", "Macro" ]),
    .testTarget(name: "dotenvTests",     dependencies: [ "dotenv"  ]),
    .testTarget(name: "RouteTests",
                dependencies: [ "express", "MacroTestUtilities" ])
  ]
)
