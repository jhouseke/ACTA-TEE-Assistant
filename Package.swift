// swift-tools-version: 5.10
//
// ACTATEEAssistantCore — the pure-Swift core of ACTA TEE Assistant (models + engine).
//
// Every file in this target imports Foundation at most — NO UIKit/SwiftUI/
// SwiftData/Speech/PDFKit. This keeps the engine (requirements, auto-
// categorization, dictation mapping, CSV export) unit-testable on Linux
// with `swift test`. The iOS app consumes this package via XcodeGen
// (`project.yml`).
//
// Sources live inside the app tree (ACTATEEAssistant/Models, ACTATEEAssistant/Engine) so the
// on-disk structure matches IMPLEMENTATION.md §3; the app target excludes
// these files (they are compiled here, once, into ACTATEEAssistantCore).

import PackageDescription

let package = Package(
    name: "ACTA-TEE-Assistant",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "ACTATEEAssistantCore", targets: ["ACTATEEAssistantCore"])
    ],
    targets: [
        .target(
            name: "ACTATEEAssistantCore",
            path: ".",
            sources: [
                "ACTATEEAssistant/Models/Enums.swift",
                "ACTATEEAssistant/Models/Tracks.swift",
                "ACTATEEAssistant/Models/CaseRecord.swift",
                "ACTATEEAssistant/Engine/RequirementsEngine.swift",
                "ACTATEEAssistant/Engine/AutoCategorizer.swift",
                "ACTATEEAssistant/Engine/DictationMapper.swift",
                "ACTATEEAssistant/Engine/ExportService.swift",
                "ACTATEEAssistant/Engine/SpacedRepetition.swift",
                "ACTATEEAssistant/Engine/QuizCardGenerator.swift",
                "ACTATEEAssistant/Engine/InsightsEngine.swift"
            ]
        ),
        .testTarget(
            name: "ACTATEEAssistantCoreTests",
            dependencies: ["ACTATEEAssistantCore"],
            path: "Tests/ACTATEEAssistantCoreTests"
        )
    ]
)
