// swift-tools-version: 5.10
//
// TEELogCore — the pure-Swift core of TEE Log (models + engine).
//
// Every file in this target imports Foundation at most — NO UIKit/SwiftUI/
// SwiftData/Speech/PDFKit. This keeps the engine (requirements, auto-
// categorization, dictation mapping, CSV export) unit-testable on Linux
// with `swift test`. The iOS app consumes this package via XcodeGen
// (`project.yml`).
//
// Sources live inside the app tree (TEELog/Models, TEELog/Engine) so the
// on-disk structure matches IMPLEMENTATION.md §3; the app target excludes
// these files (they are compiled here, once, into TEELogCore).

import PackageDescription

let package = Package(
    name: "TEELog",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TEELogCore", targets: ["TEELogCore"])
    ],
    targets: [
        .target(
            name: "TEELogCore",
            path: ".",
            sources: [
                "TEELog/Models/Enums.swift",
                "TEELog/Models/Tracks.swift",
                "TEELog/Models/CaseRecord.swift",
                "TEELog/Engine/RequirementsEngine.swift",
                "TEELog/Engine/AutoCategorizer.swift",
                "TEELog/Engine/DictationMapper.swift",
                "TEELog/Engine/ExportService.swift",
                "TEELog/Engine/SpacedRepetition.swift",
                "TEELog/Engine/QuizCardGenerator.swift",
                "TEELog/Engine/InsightsEngine.swift"
            ]
        ),
        .testTarget(
            name: "TEELogCoreTests",
            dependencies: ["TEELogCore"],
            path: "Tests/TEELogCoreTests"
        )
    ]
)
