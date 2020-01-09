// swift-tools-version:5.0

import PackageDescription

let package = Package(
  
  name: "MacroExpress",

  platforms: [
    .macOS(.v10_14), .iOS(.v11)
  ],
  
  products: [
    .library(name: "MacroExpress", targets: [ "MacroExpress" ]),
    .library(name: "express",      targets: [ "express"      ]),
    .library(name: "connect",      targets: [ "connect"      ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/macro-swift/Macro.git",
             from: "0.0.10"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "0.5.9")
  ],
  
  targets: [
    .target(name: "connect",
            dependencies: [ "MacroCore", "http", "fs" ]),
    .target(name: "express",
            dependencies: [ "MacroCore", "http", "fs", "connect", "mustache" ]),
    .target(name: "MacroExpress",
            dependencies: [ 
                "MacroCore", "xsys", "http", "fs"
            ])
  ]
)
