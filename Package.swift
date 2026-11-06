// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PhotoEvidenceKit",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "PhotoEvidenceDemo", targets: ["PhotoEvidenceDemo"]),
        .library(name: "PhotoEvidenceContracts", targets: ["PhotoEvidenceContracts"]),
        .library(name: "PhotoEvidenceEngine", targets: ["PhotoEvidenceEngine"]),
        .library(name: "PhotoEvidenceUI", targets: ["PhotoEvidenceUI"]),
    ],
    targets: [
        .executableTarget(name: "PhotoEvidenceDemo", dependencies: ["PhotoEvidenceContracts", "PhotoEvidenceEngine", "PhotoEvidenceUI"], path: "Examples/PhotoEvidenceDemo"),
        .target(name: "PhotoEvidenceContracts"),
        .target(name: "PhotoEvidenceEngine", dependencies: ["PhotoEvidenceContracts"]),
        .target(name: "PhotoEvidenceUI", dependencies: ["PhotoEvidenceContracts", "PhotoEvidenceEngine"]),
        .testTarget(name: "PhotoEvidenceKitTests", dependencies: ["PhotoEvidenceContracts", "PhotoEvidenceEngine", "PhotoEvidenceUI"]),
    ],
    swiftLanguageModes: [.v6]
)
