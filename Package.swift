// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dotfile-converter",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "AnyConvertCore", targets: ["AnyConvertCore"]),
        .executable(name: "anyconvert", targets: ["anyconvert"]),
        .executable(name: "AnyConvertGUI", targets: ["AnyConvertGUI"]),
    ],
    targets: [
        .target(
            name: "AnyConvertCore"
        ),
        .executableTarget(
            name: "anyconvert",
            dependencies: ["AnyConvertCore"]
        ),
        .executableTarget(
            name: "AnyConvertGUI",
            dependencies: ["AnyConvertCore"]
        ),
    ]
)
