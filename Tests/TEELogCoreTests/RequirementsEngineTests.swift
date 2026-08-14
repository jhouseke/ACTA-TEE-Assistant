// RequirementsEngineTests.swift — fixture cases → expected counts/gaps (§5, §14).

import XCTest
@testable import TEELogCore

final class RequirementsEngineTests: XCTestCase {

    // MARK: - Fixtures

    private func makeCase(_ categories: [CaseCategory], id: UUID = UUID()) -> CaseRecord {
        CaseRecord(id: id, categories: categories.map(\.rawValue))
    }

    private func progress(_ cases: [CaseRecord], track: Track) -> (total: Int, categories: [CategoryProgress], overallPercent: Double) {
        RequirementsEngine.progress(cases: cases, track: track)
    }

    // MARK: - Counts

    func testEmptyCaseListYieldsZeroProgress() {
        let p = progress([], track: .nbeAdvanced)
        XCTAssertEqual(p.total, 0)
        XCTAssertEqual(p.overallPercent, 0)
        XCTAssertEqual(p.categories.count, Track.nbeAdvanced.targets.count)
        XCTAssertTrue(p.categories.allSatisfy { $0.count == 0 && $0.gap == $0.minimum && !$0.isMet })
    }

    func testCountsAccumulateAcrossCases() {
        let cases = [
            makeCase([.valvular, .hemodynamic]),
            makeCase([.valvular]),
            makeCase([.mcs])
        ]
        let p = progress(cases, track: .nbeAdvanced)
        XCTAssertEqual(p.total, 3)
        let valvular = p.categories.first { $0.category == .valvular }
        XCTAssertEqual(valvular?.count, 2)
        let hemodynamic = p.categories.first { $0.category == .hemodynamic }
        XCTAssertEqual(hemodynamic?.count, 1)
        let mcs = p.categories.first { $0.category == .mcs }
        XCTAssertEqual(mcs?.count, 1)
        let transplant = p.categories.first { $0.category == .transplant }
        XCTAssertEqual(transplant?.count, 0)
    }

    func testUnknownCategoryRawValueIsIgnored() {
        let caseWithJunk = CaseRecord(categories: ["valvular", "not-a-real-category"])
        let p = progress([caseWithJunk], track: .nbeAdvanced)
        XCTAssertEqual(p.total, 1)
        let valvular = p.categories.first { $0.category == .valvular }
        XCTAssertEqual(valvular?.count, 1)
        // No category should have counted the junk string.
        XCTAssertTrue(p.categories.allSatisfy { $0.count == 0 || $0.category == .valvular })
    }

    // MARK: - CategoryProgress math

    func testCategoryProgressPercentGapAndMet() {
        let partial = CategoryProgress(category: .valvular, count: 10, minimum: 50)
        XCTAssertEqual(partial.percent, 0.2, accuracy: 0.0001)
        XCTAssertEqual(partial.gap, 40)
        XCTAssertFalse(partial.isMet)

        let met = CategoryProgress(category: .valvular, count: 50, minimum: 50)
        XCTAssertEqual(met.percent, 1)
        XCTAssertEqual(met.gap, 0)
        XCTAssertTrue(met.isMet)

        let over = CategoryProgress(category: .valvular, count: 75, minimum: 50)
        XCTAssertEqual(over.percent, 1) // capped
        XCTAssertEqual(over.gap, 0)
        XCTAssertTrue(over.isMet)

        let zero = CategoryProgress(category: .valvular, count: 0, minimum: 0)
        XCTAssertEqual(zero.percent, 0) // §5.2 formula: max(minimum, 1) guards div-by-zero
        XCTAssertEqual(zero.gap, 0)
        XCTAssertTrue(zero.isMet) // nothing required → met
    }

    // MARK: - Overall percent

    func testOverallPercentIsCappedAtOne() {
        let over = Array(repeating: makeCase([.valvular]), count: 350)
        XCTAssertEqual(progress(over, track: .nbeAdvanced).overallPercent, 1)
    }

    func testOverallPercentScalesWithTotal() {
        let half = Array(repeating: makeCase([.valvular]), count: 150)
        XCTAssertEqual(progress(half, track: .nbeAdvanced).overallPercent, 0.5, accuracy: 0.0001)
    }

    // MARK: - Gap helpers

    func testBehindPaceFilters() {
        let categories = [
            CategoryProgress(category: .valvular, count: 50, minimum: 50),   // met → out
            CategoryProgress(category: .mcs, count: 6, minimum: 10),         // 60% → behind
            CategoryProgress(category: .transplant, count: 1, minimum: 5),   // 20% → critical
            CategoryProgress(category: .mass, count: 0, minimum: 5)          // 0% → critical
        ]
        let behind = RequirementsEngine.behindPace(categories)
        XCTAssertEqual(behind.map(\.category), [.mcs, .transplant, .mass])
        let critical = RequirementsEngine.criticalGaps(categories)
        XCTAssertEqual(critical.map(\.category), [.transplant, .mass])
    }

    func testLargestGapPicksBiggestRemainingCount() {
        let categories = [
            CategoryProgress(category: .valvular, count: 45, minimum: 50),   // gap 5
            CategoryProgress(category: .ventricular, count: 30, minimum: 60), // gap 30
            CategoryProgress(category: .hemodynamic, count: 49, minimum: 50)  // gap 1
        ]
        XCTAssertEqual(RequirementsEngine.largestGap(categories)?.category, .ventricular)
    }

    func testLargestGapBreaksTiesByPercent() {
        let categories = [
            CategoryProgress(category: .aorticPathology, count: 10, minimum: 20), // gap 10, 50%
            CategoryProgress(category: .mcs, count: 0, minimum: 10)               // gap 10, 0% → wins
        ]
        XCTAssertEqual(RequirementsEngine.largestGap(categories)?.category, .mcs)
    }

    func testLargestGapNilWhenAllMet() {
        let categories = [
            CategoryProgress(category: .valvular, count: 50, minimum: 50),
            CategoryProgress(category: .mcs, count: 10, minimum: 10)
        ]
        XCTAssertNil(RequirementsEngine.largestGap(categories))
    }

    func testPaceLevelThresholds() {
        XCTAssertEqual(PaceLevel(percent: 0.8), .onTrack)
        XCTAssertEqual(PaceLevel(percent: 0.75), .onTrack)
        XCTAssertEqual(PaceLevel(percent: 0.74), .behindPace)
        XCTAssertEqual(PaceLevel(percent: 0.5), .behindPace)
        XCTAssertEqual(PaceLevel(percent: 0.49), .criticalGap)
    }

    // MARK: - Focus alert lookup

    func testRecommendedProceduresLookup() {
        XCTAssertEqual(RequirementsEngine.recommendedProcedures(for: .valvular), [.avr, .mvr, .tavr, .mitraclip])
        XCTAssertEqual(RequirementsEngine.recommendedProcedures(for: .mcs), [.lvad, .rvad, .ecmo, .iabp])
        XCTAssertEqual(RequirementsEngine.recommendedProcedures(for: .aorticPathology), [.aorticRoot, .ascendingAorta, .typeADissection, .tavr])
        XCTAssertEqual(RequirementsEngine.recommendedProcedures(for: .transplant), [.heartTransplant, .lungTransplant])
        // Indication-driven categories have no dedicated procedure.
        XCTAssertTrue(RequirementsEngine.recommendedProcedures(for: .mass).isEmpty)
        XCTAssertTrue(RequirementsEngine.recommendedProcedures(for: .pericardial).isEmpty)
        XCTAssertTrue(RequirementsEngine.recommendedProcedures(for: .endocarditis).isEmpty)
    }

    // MARK: - Projection

    func testProjectedCompletionDate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let start = now.addingTimeInterval(-60 * 86400) // 60 days of logging
        // 50 cases in 60 days ≈ 0.83/day; 300 minimum → ~300 days from now.
        let projected = RequirementsEngine.projectedCompletionDate(
            total: 50, totalMinimum: 300, earliestExamDate: start, now: now
        )
        XCTAssertNotNil(projected)
        let days = projected!.timeIntervalSince(now) / 86400
        XCTAssertEqual(days, 300, accuracy: 10)
    }

    func testProjectedCompletionDateNilWithoutCases() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertNil(RequirementsEngine.projectedCompletionDate(total: 0, totalMinimum: 300, earliestExamDate: now, now: now))
    }

    func testProjectedCompletionDateIsNowWhenMinimumAlreadyMet() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let projected = RequirementsEngine.projectedCompletionDate(
            total: 320, totalMinimum: 300, earliestExamDate: now.addingTimeInterval(-86400), now: now
        )
        XCTAssertEqual(projected, now)
    }

    func testMonthsUntil() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertEqual(RequirementsEngine.monthsUntil(now.addingTimeInterval(45 * 86400), from: now), 2)
        XCTAssertEqual(RequirementsEngine.monthsUntil(now.addingTimeInterval(-86400), from: now), 0)
    }
}
