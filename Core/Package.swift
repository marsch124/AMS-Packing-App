// swift-tools-version:5.9
import PackageDescription

// The model of AMS Packing: pure logic, no screen, no database, no network.
// It is a port of the web app's js/model.js and must give the same answers —
// the parity checker in tools/ holds it to that on real data.
let package = Package(
    name: "PackingCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PackingCore", targets: ["PackingCore"]),
    ],
    targets: [
        .target(name: "PackingCore"),
        .testTarget(name: "PackingCoreTests", dependencies: ["PackingCore"]),
    ]
)
