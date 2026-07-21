// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "KeyboardModules",
  defaultLocalization: "en",
  platforms: [.iOS(.v17)],
  products: [
    .library(name: "KeyboardFoundation", targets: ["KeyboardFoundation"]),
    .library(name: "AudioRecording", targets: ["AudioRecording"]),
    .library(name: "Transcription", targets: ["Transcription"]),
    .library(name: "Typing", targets: ["Typing"]),
    .library(name: "KeyboardFeature", targets: ["KeyboardFeature"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.26.0"),
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.14.0"),
  ],
  targets: [
    .target(
      name: "KeyboardFoundation"
    ),
    .target(
      name: "AudioRecording",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "Transcription",
      dependencies: [
        "KeyboardFoundation",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "Typing",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
      ]
    ),
    .target(
      name: "KeyboardFeature",
      dependencies: [
        "KeyboardFoundation",
        "AudioRecording",
        "Transcription",
        "Typing",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ]
    ),
    .testTarget(
      name: "KeyboardFeatureTests",
      dependencies: ["KeyboardFeature"]
    ),
    .testTarget(
      name: "TranscriptionTests",
      dependencies: ["Transcription"]
    ),
    .testTarget(
      name: "TypingTests",
      dependencies: ["Typing"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
