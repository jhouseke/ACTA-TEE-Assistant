// ProgressViewModel.swift — requirements screen state (§7.4).

import Foundation
import Observation
import TEELogCore

@Observable
final class ProgressViewModel {
    var cases: [CaseLog] = []
    var trackID: TrackID = .nbeAdvanced

    var total = 0
    var overallPercent: Double = 0
    var categories: [CategoryProgress] = []

    // Focus alert
    var focus: CategoryProgress?
    var focusProcedures: [ProcedureType] = []

    // Milestones
    var projectedDate: Date?
    var monthsLeft = 0

    var track: Track { Track.track(id: trackID) }

    func update(cases: [CaseLog], trackID: TrackID, now: Date = Date()) {
        self.cases = cases
        self.trackID = trackID
        let p = RequirementsEngine.progress(cases: cases, track: track)
        total = p.total
        overallPercent = p.overallPercent
        categories = p.categories

        focus = RequirementsEngine.largestGap(p.categories)
        focusProcedures = focus.map { RequirementsEngine.recommendedProcedures(for: $0.category) } ?? []

        let earliest = cases.map(\.examDate).min()
        projectedDate = earliest.map {
            RequirementsEngine.projectedCompletionDate(
                total: total,
                totalMinimum: track.totalMinimum,
                earliestExamDate: $0,
                now: now
            )
        }
        monthsLeft = projectedDate.map { RequirementsEngine.monthsUntil($0, from: now) } ?? 0
    }
}
