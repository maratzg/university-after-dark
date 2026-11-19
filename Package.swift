// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "UniversityAfterDark",
    platforms: [.macOS(.v15)],
    products: [.library(name: "UniversityAfterDarkCore", targets: ["UniversityAfterDarkCore"])],
    targets: [
        .target(name: "UniversityAfterDarkCore", path: ".", exclude: ["Application", "Tests", "Tools", "Documentation", "UniversityAfterDark.xcodeproj", "README.md", "Info.plist", "Package.swift", "build", "Resources/Audio", "Resources/AppIcon.icns", "Resources/reveal.wav", "Resources/nuclear.wav", "Resources/transition.wav", "Resources/selection.wav"], sources: ["Core"], resources: [.copy("Resources/questions.json")]),
        .testTarget(name: "UniversityAfterDarkTests", dependencies: ["UniversityAfterDarkCore"], path: "Tests")
    ],
    swiftLanguageModes: [.v5]
)
