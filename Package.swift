// swift-tools-version:5.0

import PackageDescription

let package = Package(
  
  name: "MacroExpress",

  products: [
    .library(name: "MacroExpress", targets: [ "MacroExpress" ]),
    .library(name: "express",      targets: [ "express"      ]),
    .library(name: "connect",      targets: [ "connect"      ]),
    .library(name: "mime",         targets: [ "mime"         ]),
    .library(name: "DotEnv",       targets: [ "DotEnv"       ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/Macro-swift/Macro.git",
             from: "0.5.3"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "0.5.9")
  ],
  
  targets: [
    .target(name: "mime",    dependencies: []),
    .target(name: "DotEnv",  dependencies: [ "MacroCore" ]),
    .target(name: "connect",
            dependencies: [ "MacroCore", "http", "fs", "mime" ]),
    .target(name: "express",
            dependencies: [
              "MacroCore", "http", "fs",
              "connect", "mime",
              "mustache"
            ]),
    .target(name: "MacroExpress",
            dependencies: [ 
              "MacroCore", "xsys", "http", "fs",
              "DotEnv", "mime", "connect", "express"
            ]),

    .testTarget(name: "mimeTests",       dependencies: [ "mime"    ]),
    .testTarget(name: "bodyParserTests", dependencies: [ "connect" ]),
    .testTarget(name: "DotEnvTests", dependencies: ["DotEnv"]),
    .testTarget(name: "RouteTests",
                dependencies: [ "express", "MacroTestUtilities" ])
  ]
)
