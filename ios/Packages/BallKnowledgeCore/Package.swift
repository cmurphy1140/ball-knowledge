// swift-tools-version: 6.0
import PackageDescription

// The game logic of Ball Knowledge, ported from src/page.html. Foundation only, no UI.
// Tests compare every function against golden vectors written by the real web game
// (ios/tools/oracle, npm run golden).
let package = Package(
    name: "BallKnowledgeCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [
        .library(name: "BallKnowledgeCore", targets: ["BallKnowledgeCore"])
    ],
    targets: [
        .target(name: "BallKnowledgeCore"),
        .testTarget(
            name: "BallKnowledgeCoreTests",
            dependencies: ["BallKnowledgeCore"],
            resources: [.copy("Golden")]
        )
    ],
    swiftLanguageModes: [.v6]
)
