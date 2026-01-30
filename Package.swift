// swift-tools-version:5.5

import PackageDescription

let package = Package(
  
  name: "MacroExpress",

  products: [
    .library(name: "MacroExpress", targets: [ "MacroExpress" ]),
    .library(name: "express",      targets: [ "express"      ]),
    .library(name: "connect",      targets: [ "connect"      ]),
    .library(name: "compression",  targets: [ "compression"  ]),
    .library(name: "mime",         targets: [ "mime"         ]),
    .library(name: "dotenv",       targets: [ "dotenv"       ]),
    .library(name: "multer",       targets: [ "multer"       ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/Macro-swift/Macro.git",
             from: "1.0.10"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "1.0.2"),
    .package(url: "https://github.com/apple/swift-nio.git",
             from: "2.80.0"),
    .package(url: "https://github.com/apple/swift-nio-extras.git",
             from: "1.24.0")
  ],
  
  targets: [
    .target(name: "mime",   dependencies: []),
    .target(name: "compression", dependencies: [
      .product(name: "http",    package: "Macro"),
      .product(name: "NIOCore", package: "swift-nio"),
      .product(name: "NIOHTTPCompression", package: "swift-nio-extras"),
      "connect"
    ]),
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
    ], exclude: [ "README.md" ]),
    .target(name: "express", dependencies: [
      .product(name: "MacroCore", package: "Macro"),
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      "connect", "mime", 
      .product(name: "Mustache",  package: "Mustache")
    ], exclude: [ "README.md" ]),
    .target(name: "MacroExpress", dependencies: [
      .product(name: "MacroCore", package: "Macro"),
      .product(name: "fs",        package: "Macro"),
      .product(name: "http",      package: "Macro"),
      .product(name: "xsys",      package: "Macro"),
      "dotenv", "mime", "connect", "compression", "express", "multer"
    ], exclude: [ "README.md" ]),

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
