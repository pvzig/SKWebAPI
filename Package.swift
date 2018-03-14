// swift-tools-version:4.0
import PackageDescription

let package = Package(
    name: "SKWebAPI",
    products: [
        .library(name: "SKWebAPI", targets: ["SKWebAPI"])
    ],
    dependencies: [
    	.package(url: "https://github.com/NoRespect/SKCore", .branch("master"))
    ],
    targets: [
    	.target(name: "SKWebAPI",
        dependencies: ["SKCore"],
    			path: "Sources")
    ]
)
