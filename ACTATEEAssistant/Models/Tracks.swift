// Tracks.swift — requirement track definitions (configurable constants).
//
// Board minima change over time; every number lives HERE, in one file, and
// the engine (RequirementsEngine) is fully data-driven. Pure Swift
// (Foundation only) — compiles on Linux as part of ACTATEEAssistantCore.
//
// IMPLEMENTATION.md §5.1. Values marked PLACEHOLDER are unconfirmed against
// current board policy (§15.1 open question) — adjust the constants, not
// the engine.

import Foundation

// MARK: - Types

public struct TrackTarget: Equatable, Hashable, Sendable {
    public let category: CaseCategory
    public let minimum: Int

    public init(category: CaseCategory, minimum: Int) {
        self.category = category
        self.minimum = minimum
    }
}

public struct Track: Equatable, Hashable, Sendable {
    public let id: TrackID
    public let name: String
    public let totalMinimum: Int
    public let targets: [TrackTarget]

    public init(id: TrackID, name: String, totalMinimum: Int, targets: [TrackTarget]) {
        self.id = id
        self.name = name
        self.totalMinimum = totalMinimum
        self.targets = targets
    }
}

/// Per-category progress against one track target (§5.2).
public struct CategoryProgress: Equatable, Hashable, Sendable {
    public let category: CaseCategory
    public let count: Int
    public let minimum: Int

    public init(category: CaseCategory, count: Int, minimum: Int) {
        self.category = category
        self.count = count
        self.minimum = minimum
    }

    public var percent: Double { min(Double(count) / Double(max(minimum, 1)), 1) }
    public var gap: Int { max(minimum - count, 0) }
    public var isMet: Bool { count >= minimum }
}

// MARK: - Track definitions

extension Track {
    /// NBE Advanced PTEeXAM — minima per IMPLEMENTATION.md §5.1
    /// (first eight categories confirmed in spec; remainder PLACEHOLDER).
    public static let nbeAdvanced = Track(
        id: .nbeAdvanced,
        name: "NBE Advanced PTEeXAM",
        totalMinimum: 300,
        targets: [
            .init(category: .hemodynamic, minimum: 50),
            .init(category: .ventricular, minimum: 60),
            .init(category: .valvular, minimum: 50),
            .init(category: .prosthetic, minimum: 30),
            .init(category: .aorticPathology, minimum: 20),
            .init(category: .structural, minimum: 25),
            .init(category: .mcs, minimum: 10),
            .init(category: .transplant, minimum: 5),
            // PLACEHOLDER (§15.1) — remaining categories, to be confirmed
            // against current NBE policy.
            .init(category: .ischemia, minimum: 20),
            .init(category: .congenital, minimum: 5),
            .init(category: .mass, minimum: 5),
            .init(category: .pericardial, minimum: 5),
            .init(category: .endocarditis, minimum: 5)
        ]
    )

    /// NBE Basic PTE — PLACEHOLDER values (§15.1); engine is data-driven.
    public static let nbeBasic = Track(
        id: .nbeBasic,
        name: "NBE Basic PTE",
        totalMinimum: 150,
        targets: [
            .init(category: .hemodynamic, minimum: 25),
            .init(category: .ventricular, minimum: 40),
            .init(category: .valvular, minimum: 25),
            .init(category: .ischemia, minimum: 15),
            .init(category: .aorticPathology, minimum: 10),
            .init(category: .prosthetic, minimum: 5),
            .init(category: .structural, minimum: 5),
            .init(category: .congenital, minimum: 5),
            .init(category: .mass, minimum: 5),
            .init(category: .pericardial, minimum: 5),
            .init(category: .endocarditis, minimum: 5),
            .init(category: .mcs, minimum: 0),
            .init(category: .transplant, minimum: 0)
        ]
    )

    /// ACGME CT-anesthesia case log — PLACEHOLDER values (§15.1).
    public static let acgme = Track(
        id: .acgme,
        name: "ACGME",
        totalMinimum: 100,
        targets: [
            .init(category: .hemodynamic, minimum: 20),
            .init(category: .ventricular, minimum: 25),
            .init(category: .valvular, minimum: 25),
            .init(category: .prosthetic, minimum: 10),
            .init(category: .aorticPathology, minimum: 10),
            .init(category: .structural, minimum: 10),
            .init(category: .ischemia, minimum: 10),
            .init(category: .congenital, minimum: 5),
            .init(category: .mass, minimum: 5),
            .init(category: .pericardial, minimum: 5),
            .init(category: .endocarditis, minimum: 5),
            .init(category: .mcs, minimum: 5),
            .init(category: .transplant, minimum: 5)
        ]
    )

    /// All tracks in tab order: NBE Advanced | ACGME | NBE Basic (§7.4).
    public static let all: [Track] = [.nbeAdvanced, .acgme, .nbeBasic]

    public static func track(id: TrackID) -> Track {
        switch id {
        case .nbeAdvanced: .nbeAdvanced
        case .nbeBasic: .nbeBasic
        case .acgme: .acgme
        }
    }
}
