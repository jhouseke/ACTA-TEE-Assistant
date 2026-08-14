// InsightsEngineTests.swift — deterministic pattern aggregations (F2).

import XCTest
@testable import TEELogCore

final class InsightsEngineTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d)) ?? .distantPast
    }

    private func makeCase(
        procedure: ProcedureType = .avr,
        examDate: Date = Date(timeIntervalSince1970: 0),
        views: [TEEView] = [],
        findings: [ValveFindingRecord] = [],
        lvefQualitative: String? = nil,
        rvFunction: String? = nil,
        indications: [IndicationType] = []
    ) -> CaseRecord {
        CaseRecord(
            id: UUID(),
            examDate: examDate,
            procedure: procedure.rawValue,
            indications: indications.map(\.rawValue),
            viewsObtained: views.map(\.rawValue),
            lvefQualitative: lvefQualitative,
            rvFunction: rvFunction,
            valveFindings: findings
        )
    }

    private func finding(_ valve: Valve, _ lesion: LesionType, _ severity: SeverityGrade) -> ValveFindingRecord {
        ValveFindingRecord(valve: valve, lesion: lesion, severity: severity)
    }

    // MARK: - 1. View coverage

    func testViewCoverageComputesSkipRate() {
        // 10 AVR cases; 7 log ME RV inflow-outflow → 30% skip
        let cases = (0..<10).map { i in
            makeCase(procedure: .avr, views: i < 7 ? [.meRvInflowOutflow] : [])
        }
        let stats = InsightsEngine.viewCoverage(from: cases)
        let stat = stats.first { $0.procedure == .avr && $0.view == .meRvInflowOutflow }
        XCTAssertEqual(stat?.obtainedCount, 7)
        XCTAssertEqual(stat?.caseCount, 10)
        XCTAssertEqual(stat?.skipRate ?? 0, 0.3, accuracy: 0.0001)
        XCTAssertEqual(stat?.skipPercentText, "30%")
    }

    func testViewCoverageOnlyEmitsSkippedViews() {
        let cases = [makeCase(views: TEEView.allCases)] // fully covered
        let stats = InsightsEngine.viewCoverage(from: cases)
        XCTAssertTrue(stats.isEmpty)
    }

    func testViewCoverageZeroViewsCountsAllStandardViewsSkipped() {
        let cases = [makeCase(views: [])]
        let stats = InsightsEngine.viewCoverage(from: cases)
        XCTAssertEqual(stats.count, TEEView.allCases.count)
        XCTAssertTrue(stats.allSatisfy { $0.obtainedCount == 0 && $0.caseCount == 1 })
    }

    func testViewCoverageIsSortedByProcedureThenView() {
        let cases = [makeCase(procedure: .cabg, views: [.me4c]), makeCase(procedure: .avr, views: [.me4c])]
        let stats = InsightsEngine.viewCoverage(from: cases)
        let sorted = stats.sorted {
            if $0.procedure.displayName != $1.procedure.displayName {
                return $0.procedure.displayName < $1.procedure.displayName
            }
            return $0.view.displayName < $1.view.displayName
        }
        XCTAssertEqual(stats, sorted)
        XCTAssertEqual(stats.first?.procedure, .avr) // "AVR" < "CABG"
    }

    // MARK: - 2. Severity distribution

    func testSeverityDistributionCountsAndDominant() {
        let cases = [
            makeCase(findings: [finding(.mitral, .regurgitation, .moderate)]),
            makeCase(findings: [finding(.mitral, .regurgitation, .moderate)]),
            makeCase(findings: [finding(.mitral, .regurgitation, .moderate)]),
            makeCase(findings: [finding(.mitral, .regurgitation, .mild)])
        ]
        let dist = InsightsEngine.severityDistributions(from: cases).first
        XCTAssertEqual(dist?.valve, .mitral)
        XCTAssertEqual(dist?.caseCount, 4)
        XCTAssertEqual(dist?.counts[.moderate], 3)
        XCTAssertEqual(dist?.counts[.mild], 1)
        XCTAssertEqual(dist?.dominant, .moderate)
    }

    func testOvercallFlaggedAboveQuarterThreshold() {
        // 3 of 4 MR findings ≥ 2+ → 75% > 25% → flagged
        let cases = (0..<4).map { i in
            makeCase(findings: [finding(.mitral, .regurgitation, i < 3 ? .moderate : .mild)])
        }
        let dist = InsightsEngine.severityDistributions(from: cases).first
        XCTAssertEqual(dist?.overcallFlagged, true)
    }

    func testOvercallNotFlaggedAtOrBelowQuarter() {
        // 1 of 4 = exactly 25% → NOT flagged (strict >)
        let cases = (0..<4).map { i in
            makeCase(findings: [finding(.mitral, .regurgitation, i == 0 ? .severe : .mild)])
        }
        let dist = InsightsEngine.severityDistributions(from: cases).first
        XCTAssertEqual(dist?.overcallFlagged, false)

        // mild-only → not flagged
        let mildOnly = (0..<4).map { _ in
            makeCase(findings: [finding(.aortic, .stenosis, .mild)])
        }
        XCTAssertEqual(InsightsEngine.severityDistributions(from: mildOnly).first?.overcallFlagged, false)
    }

    func testDominantTieBreaksToMoreSevere() {
        let cases = [
            makeCase(findings: [finding(.aortic, .regurgitation, .moderate)]),
            makeCase(findings: [finding(.aortic, .regurgitation, .severe)])
        ]
        let dist = InsightsEngine.severityDistributions(from: cases).first
        XCTAssertEqual(dist?.dominant, .severe) // tie at 1 each → more severe wins
    }

    // MARK: - 3. RV undercall

    func testRVUndercallFlagsNormalishRVWithBadLV() {
        let cases = [
            makeCase(lvefQualitative: "severe", rvFunction: SeverityGrade.mild.rawValue),
            makeCase(lvefQualitative: "moderate", rvFunction: SeverityGrade.none.rawValue),
            makeCase(lvefQualitative: "severe", rvFunction: nil) // RV unlogged counts as normal-ish
        ]
        XCTAssertEqual(InsightsEngine.rvUndercalls(from: cases).count, 3)
    }

    func testRVUndercallSkipsAdequateRVAndNormalLV() {
        let cases = [
            makeCase(lvefQualitative: "severe", rvFunction: SeverityGrade.moderate.rawValue), // RV already moderate
            makeCase(lvefQualitative: "normal", rvFunction: SeverityGrade.mild.rawValue),     // LV fine
            makeCase(lvefQualitative: nil, rvFunction: SeverityGrade.mild.rawValue)           // LV unlogged
        ]
        XCTAssertTrue(InsightsEngine.rvUndercalls(from: cases).isEmpty)
    }

    // MARK: - 4. Indication–procedure mismatch

    func testMismatchFlagsMitraclipWithoutValvularIndication() {
        let cases = [
            makeCase(procedure: .mitraclip, indications: [.hemodynamic])
        ]
        let mismatches = InsightsEngine.mismatches(from: cases)
        XCTAssertEqual(mismatches.count, 1)
        XCTAssertEqual(mismatches.first?.procedure, .mitraclip)
        XCTAssertEqual(mismatches.first?.expected, [.valvular, .structural])
    }

    func testMismatchSkipsMatchingIndication() {
        let cases = [
            makeCase(procedure: .mitraclip, indications: [.valvular]),
            makeCase(procedure: .cabg, indications: [.ischemia]),
            makeCase(procedure: .cabg, indications: [.hemodynamic]),
            makeCase(procedure: .other, indications: []) // other never flags
        ]
        XCTAssertTrue(InsightsEngine.mismatches(from: cases).isEmpty)
    }

    func testMismatchFlagsCabgWithoutCardiacIndication() {
        let cases = [makeCase(procedure: .cabg, indications: [.pericardial])]
        XCTAssertEqual(InsightsEngine.mismatches(from: cases).count, 1)
    }

    // MARK: - 5. Monthly mix

    func testMonthlyMixCountsAndSorts() {
        let cases = [
            makeCase(procedure: .avr, examDate: date(2026, 7, 3)),
            makeCase(procedure: .avr, examDate: date(2026, 7, 20)),
            makeCase(procedure: .cabg, examDate: date(2026, 7, 25)),
            makeCase(procedure: .avr, examDate: date(2026, 8, 1))
        ]
        let mix = InsightsEngine.monthlyMix(from: cases)
        XCTAssertEqual(mix, [
            .init(yearMonth: "2026-07", procedure: .avr, count: 2),
            .init(yearMonth: "2026-07", procedure: .cabg, count: 1),
            .init(yearMonth: "2026-08", procedure: .avr, count: 1)
        ])
    }

    // MARK: - Takeaways

    func testMostSkippedViewTakeaway() {
        // 3 cases log every view; 7 log everything except ME RV inflow-outflow
        let baseline = TEEView.allCases.filter { $0 != .meRvInflowOutflow }
        let cases = (0..<10).map { i in
            makeCase(views: i < 3 ? TEEView.allCases : baseline)
        }
        XCTAssertEqual(
            InsightsEngine.mostSkippedViewTakeaway(from: cases),
            "You skip ME RV inflow-outflow in 70% of AVR cases."
        )
    }

    func testOvercallTakeawayText() {
        let cases = (0..<4).map { i in
            makeCase(findings: [finding(.mitral, .regurgitation, i < 3 ? .moderate : .mild)])
        }
        let takeaways = InsightsEngine.overcallTakeaways(from: cases)
        XCTAssertEqual(takeaways, ["MV Regurgitation graded 2+/4+ in 75% of cases — possible overcall."])
    }

    func testRVUndercallTakeaway() {
        let cases = [makeCase(lvefQualitative: "severe", rvFunction: SeverityGrade.mild.rawValue)]
        XCTAssertEqual(
            InsightsEngine.rvUndercallTakeaway(from: cases),
            "1 case with normal/mild RV but moderate/severe LV — check for undercalled RV dysfunction."
        )
    }

    func testMismatchTakeaway() {
        let cases = [makeCase(procedure: .mitraclip, indications: [.hemodynamic])]
        XCTAssertEqual(
            InsightsEngine.mismatchTakeaway(from: cases),
            "1 mismatch: MitraClip without a Valvular or Structural indication."
        )
    }

    func testMonthlyMixTakeaway() {
        let cases = [
            makeCase(procedure: .avr, examDate: date(2026, 7, 3)),
            makeCase(procedure: .avr, examDate: date(2026, 7, 20)),
            makeCase(procedure: .cabg, examDate: date(2026, 7, 25))
        ]
        XCTAssertEqual(
            InsightsEngine.monthlyMixTakeaway(from: cases),
            "Most active month: 2026-07 — AVR (2 cases)."
        )
    }

    func testEmptyReportHasNoTakeaways() {
        let report = InsightsEngine.report(from: [])
        XCTAssertTrue(report.viewCoverage.isEmpty)
        XCTAssertTrue(report.severityDistributions.isEmpty)
        XCTAssertTrue(report.rvUndercalls.isEmpty)
        XCTAssertTrue(report.mismatches.isEmpty)
        XCTAssertTrue(report.monthlyMix.isEmpty)
        XCTAssertNil(report.mostSkippedViewTakeaway)
        XCTAssertTrue(report.overcallTakeaways.isEmpty)
        XCTAssertNil(report.rvUndercallTakeaway)
        XCTAssertNil(report.mismatchTakeaway)
        XCTAssertNil(report.monthlyMixTakeaway)
    }
}
