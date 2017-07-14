import PackageDescription

let package = Package(
    name: "SKWebAPI",
    targets: [
        Target(name: "SKWebAPI")
    ],
    dependencies: [
        .Package(url: "https://github.com/SlackKit/SKCore", majorVersion: 4)
    ]
)
