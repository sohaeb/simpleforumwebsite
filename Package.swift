// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "project4",
    dependencies: [
        .package(url: "https://github.com/IBM-Swift/Kitura.git", .upToNextMinor(from: "2.0.0")),
        .package(url: "https://github.com/IBM-Swift/HeliumLogger.git", .upToNextMinor(from: "1.7.1")),
        .package(url: "https://github.com/IBM-Swift/Kitura-CouchDB.git", .upToNextMinor(from: "1.7.2")),
        .package(url: "https://github.com/IBM-Swift/Kitura-Session.git", .upToNextMinor(from: "2.0.0")),
        .package(url: "https://github.com/IBM-Swift/Kitura-StencilTemplateEngine.git", .upToNextMinor(from: "1.8.3")),        
    ],
    targets: [
        .target(
            name: "project4",
            dependencies: ["Kitura" , "HeliumLogger", "CouchDB", "KituraStencil", "KituraSession"]
        ),
    ]
)
