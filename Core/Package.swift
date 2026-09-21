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
        .library(name: "PackingLibrary", targets: ["PackingLibrary"]),
    ],
    targets: [
        .target(name: "PackingCore"),
        // The library in memory, the records it is stored and synced as, and the
        // one-time import of a web-app backup. Still no screen and no iCloud in here:
        // the store is a protocol, and tests use the in-memory one. See docs/store.md.
        .target(name: "PackingLibrary", dependencies: ["PackingCore"]),
        // The Swift half of the parity checker (tools/parity): answers the contract's
        // questions about a backup file, through PackingCore's PUBLIC API only.
        .executableTarget(name: "parity", dependencies: ["PackingCore"]),
        // Dry-runs the one-time import on a real backup and says whether it is faithful.
        .executableTarget(name: "import-check", dependencies: ["PackingLibrary"]),
        .testTarget(name: "PackingCoreTests", dependencies: ["PackingCore"]),
        .testTarget(name: "PackingLibraryTests", dependencies: ["PackingLibrary"]),
    ]
)
