// swift-tools-version:5.0

import PackageDescription

let package = Package(
  
  name: "MacroExpress",

  platforms: [
    .macOS(.v10_14), .iOS(.v11)
  ],
  
  products: [
    .library(name: "MacroExpress", targets: [ "MacroExpress" ]),
    .library(name: "express",      targets: [ "express"      ])
  ],
  
  dependencies: [
    .package(url: "https://github.com/macro-swift/Macro.git",
             from: "0.0.2"),
    .package(url: "https://github.com/AlwaysRightInstitute/mustache.git",
             from: "0.5.9")
  ],
  
  targets: [
    .target(name: "express",
            dependencies: [ "MacroCore", "http", "fs" ]),
    .target(name: "MacroExpress",
            dependencies: [ 
                "MacroCore", "xsys", "http", "fs"
            ])
  ]
)
