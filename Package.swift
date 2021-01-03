// swift-tools-version:5.0

import PackageDescription

let package = Package(
  
  name: "MacroExpress",

  products: [
    .library(name: "MacroExpress", targets: [ "MacroExpress" ]),
    .library(name: "express",      targets: [ "express"      ]),
    .library(name: "connect",      targets: [ "connect"      ]),
    .library(name: "mime",         targets: [ "mime"         ]),
    .library(name: "dotenv",       targets: [ "dotenv"       ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/Macro-swift/Macro.git",
             from: "0.6.2"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "0.5.9")
  ],
  
  targets: [
    .target(name: "mime",    dependencies: []),
    .target(name: "dotenv",  dependencies: [ "MacroCore" ]),
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
              "dotenv",    "mime", "connect", "express"
            ]),

    .testTarget(name: "mimeTests",       dependencies: [ "mime"    ]),
    .testTarget(name: "bodyParserTests", dependencies: [ "connect", "Macro" ]),
    .testTarget(name: "dotenvTests",     dependencies: [ "dotenv"  ]),
    .testTarget(name: "RouteTests",
                dependencies: [ "express", "MacroTestUtilities" ])
  ]
)
