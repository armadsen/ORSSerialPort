import PackageDescription

let package = Package(
    name: "ORSSerialPort",
    exclude: ["Source/IOKitWrapper"],
    dependencies: [
        .Package(url: "https://github.com/armadsen/SwiftIOKitBridge", majorVersion: 1)
    ]
)
