// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Canvo",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "Canvo",
            targets: ["Canvo"]
        ),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "Canvo",
            dependencies: []
        )
    ]
)
