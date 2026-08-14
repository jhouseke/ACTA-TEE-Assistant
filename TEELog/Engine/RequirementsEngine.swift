// RequirementsEngine.swift — counts, progress, gaps.
//
// Pure function of `[CaseRecordProtocol]` + `Track`. Data-driven: all
// minima live in Tracks.swift. Pure Swift (Foundation only) — compiles on
// Linux as part of TEELogCore.
//
// IMPLEMENTATION.md §5.2

import Foundation

/// Pace classification used by the Progress screen and dashboard gap alert
/// (§5.2): percent < 0.75 → behind pace (orange), percent < 0.5 → critical
/// gap (red), else on track (green).
public enum PaceLevel: String, Sendable {
    case onTrack
    case behindPace
    case criticalGap

    public init(percent: Double) {
        if percent < 0.5 {
            self = .criticalGap
        } else if percent < 0.75 {
            self = .behindPace
        } else {
            self = .onTrack
        }
    }
}

public enum RequirementsEngine {

    /// Per-track progress: total case count, per-category progress against
    /// the track's targets, and overall percent of the total-case minimum.
    public static func progress<C: CaseRecordProtocol>(
        cases: [C],
        track: Track
    ) -> (total: Int, categories: [CategoryProgress], overallPercent: Double) {
        let total = cases.count
        var counts: [CaseCategory: Int] = [:]
        for c in cases {
            for raw in c.categories {
                if let cat = CaseCategory(rawValue: raw) {
                    counts[cat, default: 0] += 1
                }
            }
        }
        let categories = track.targets.map {
            CategoryProgress(category: $0.category, count: counts[$0.category, default: 0], minimum: $0.minimum)
        }
        return (total, categories, min(Double(total) / Double(max(track.totalMinimum, 1)), 1))
    }

    // MARK: - Gap helpers

    /// Categories behind pace (percent < 0.75 and not yet met). Drives the
    /// dashboard "what's missing" alert (§7.1).
    public static func behindPace(_ categories: [CategoryProgress]) -> [CategoryProgress] {
        categories.filter { !$0.isMet && $0.percent < 0.75 }
    }

    /// Critical gaps (percent < 0.5).
    public static func criticalGaps(_ categories: [CategoryProgress]) -> [CategoryProgress] {
        categories.filter { !$0.isMet && $0.percent < 0.5 }
    }

    /// The single largest relative gap (largest remaining count; ties broken
    /// by lowest percent). Drives the Progress screen focus alert (§7.4).
    public static func largestGap(_ categories: [CategoryProgress]) -> CategoryProgress? {
        categories
            .filter { !$0.isMet }
            .sorted {
                if $0.gap != $1.gap { return $0.gap > $1.gap }
                return $0.percent < $1.percent
            }
            .first
    }

    /// Lookup table: gap category → procedure types that close it fastest
    /// (§7.4 focus alert). Indication-driven categories (mass, pericardial,
    /// endocarditis) have no dedicated procedure — return empty and the view
    /// falls back to "log any case with the matching indication".
    public static func recommendedProcedures(for category: CaseCategory) -> [ProcedureType] {
        switch category {
        case .valvular: [.avr, .mvr, .tavr, .mitraclip]
        case .prosthetic: [.avr, .mvr, .tavr, .tmvr]
        case .ventricular: [.cabg, .heartTransplant, .lvad]
        case .hemodynamic: [.cabg, .avr, .mvr]
        case .aorticPathology: [.aorticRoot, .ascendingAorta, .typeADissection, .tavr]
        case .structural: [.tavr, .mitraclip, .tmvr, .tricuspidClip, .laao]
        case .mcs: [.lvad, .rvad, .ecmo, .iabp]
        case .transplant: [.heartTransplant, .lungTransplant]
        case .ischemia: [.cabg]
        case .congenital: [.heartTransplant, .lungTransplant]
        case .mass, .pericardial, .endocarditis: []
        }
    }

    // MARK: - Milestone projection

    /// Projected date the total-case minimum is reached, extrapolating the
    /// observed rate from the earliest exam date to now. Returns nil when
    /// there are no cases or no elapsed time.
    public static func projectedCompletionDate(
        total: Int,
        totalMinimum: Int,
        earliestExamDate: Date,
        now: Date = Date()
    ) -> Date? {
        guard total > 0, totalMinimum > total else { return now }
        let elapsed = max(now.timeIntervalSince(earliestExamDate), 86400) // ≥ 1 day
        let rate = Double(total) / elapsed // cases per second
        let remaining = Double(totalMinimum - total)
        return now.addingTimeInterval(remaining / rate)
    }

    /// Number of whole months until `date` (used by the milestones card).
    public static func monthsUntil(_ date: Date, from now: Date = Date()) -> Int {
        guard date > now else { return 0 }
        return max(Int(ceil(date.timeIntervalSince(now) / (30 * 86400))), 1)
    }
}
