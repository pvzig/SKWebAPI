// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "SKWebAPI",
    products: [
        .library(name: "SKWebAPI", targets: ["SKWebAPI"])
    ],
    dependencies: [
    	.package(url: "https://github.com/SlackKit/SKCore", .upToNextMinor(from: "4.1.0"))
    ],
    targets: [
    	.target(name: "SKWebAPI",
        dependencies: ["SKCore"],
    			path: "Sources")
    ]
)
