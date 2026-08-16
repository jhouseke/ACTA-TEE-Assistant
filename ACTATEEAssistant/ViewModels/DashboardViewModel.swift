// DashboardViewModel.swift — Home screen state (§7.1).

import Foundation
import Observation
import ACTATEEAssistantCore

@Observable
final class DashboardViewModel {
    var cases: [CaseLog] = []
    var trackID: TrackID = .nbeAdvanced

    var total = 0
    var overallPercent: Double = 0
    var categories: [CategoryProgress] = []
    var behindPace: [CategoryProgress] = []
    var recentCases: [CaseLog] = []

    var track: Track { Track.track(id: trackID) }

    /// Recompute derived state from the @Query snapshot (view calls this on
    /// appear/change; SwiftData remains the source of truth via @Query).
    func update(cases: [CaseLog], trackID: TrackID) {
        self.cases = cases
        self.trackID = trackID
        let p = RequirementsEngine.progress(cases: cases, track: track)
        total = p.total
        overallPercent = p.overallPercent
        categories = p.categories
        behindPace = RequirementsEngine.behindPace(p.categories)
        recentCases = Array(
            cases
                .filter { $0.procedureType != nil }
                .sorted { $0.examDate > $1.examDate }
                .prefix(3)
        )
    }
}
