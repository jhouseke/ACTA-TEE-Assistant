// QuizCardGeneratorTests.swift — question generation from real cases (F3).

import XCTest
@testable import TEELogCore

final class QuizCardGeneratorTests: XCTestCase {

    private func makeCase(
        procedure: ProcedureType = .avr,
        views: [TEEView] = [],
        findings: [ValveFindingRecord] = [],
        lvefPercent: Int? = nil,
        lvefQualitative: String? = nil,
        rvFunction: String? = nil,
        indications: [IndicationType] = []
    ) -> CaseRecord {
        CaseRecord(
            procedure: procedure.rawValue,
            indications: indications.map(\.rawValue),
            viewsObtained: views.map(\.rawValue),
            lvefQualitative: lvefQualitative,
            lvefPercent: lvefPercent,
            rvFunction: rvFunction,
            valveFindings: findings
        )
    }

    /// 14 of the standard views, deliberately omitting meBicaval.
    private let fourteenViews: [TEEView] = Array(TEEView.allCases.filter { $0 != .meBicaval }.prefix(14))

    // MARK: - missedView

    func testMissedViewNamesAViewNotLogged() {
        let card = QuizCardGenerator.card(.missedView, for: makeCase(views: fourteenViews))
        XCTAssertEqual(card?.questionType, .missedView)
        XCTAssertEqual(card?.answer, "ME bicaval")
        XCTAssertFalse(fourteenViews.contains { $0.displayName == card?.answer })
        XCTAssertTrue(card?.prompt.contains("AVR") == true)
        XCTAssertTrue(card?.prompt.contains("14 views") == true)
        XCTAssertEqual(card?.options?.count, 4)
        XCTAssertTrue(card?.options?.contains("ME bicaval") == true)
    }

    func testMissedViewNilWhenNoViewsLogged() {
        XCTAssertNil(QuizCardGenerator.card(.missedView, for: makeCase(views: [])))
    }

    func testMissedViewFirstMissingInProtocolOrder() {
        // Missing views = me4c, meAvSax, … — first in protocol order wins
        let views: [TEEView] = [.me2c, .meLax, .meAvSax]
        let card = QuizCardGenerator.card(.missedView, for: makeCase(views: views))
        XCTAssertEqual(card?.answer, "ME 4C")
    }

    // MARK: - nextView

    func testNextViewFollowsProtocolOrder() {
        let card = QuizCardGenerator.card(.nextView, for: makeCase(views: [.me4c, .me2c]))
        XCTAssertEqual(card?.questionType, .nextView)
        XCTAssertEqual(card?.answer, "ME LAX") // after ME 2C
        XCTAssertTrue(card?.prompt.contains("ME 2C") == true)
    }

    func testNextViewNilWhenOnlyOneView() {
        XCTAssertNil(QuizCardGenerator.card(.nextView, for: makeCase(views: [.me4c])))
    }

    func testNextViewUsesLastObtainedInProtocolOrderAsAnchor() {
        let card = QuizCardGenerator.card(.nextView, for: makeCase(views: [.meLax, .me4c]))
        XCTAssertEqual(card?.answer, "ME AV SAX") // meLax is later in protocol order
    }

    // MARK: - findingRecall

    func testFindingRecallDerivesFromActualFinding() {
        let finding = ValveFindingRecord(valve: .mitral, lesion: .regurgitation, severity: .moderate)
        let card = QuizCardGenerator.card(
            .findingRecall,
            for: makeCase(procedure: .cabg, findings: [finding], lvefPercent: 35)
        )
        XCTAssertEqual(card?.questionType, .findingRecall)
        XCTAssertEqual(card?.answer, "Mitral regurgitation 2+")
        XCTAssertTrue(card?.prompt.contains("CABG") == true)
        XCTAssertTrue(card?.prompt.contains("EF 35%") == true)
        XCTAssertEqual(card?.options?.count, 4)
        XCTAssertTrue(card?.options?.contains("Mitral regurgitation 2+") == true)
        // No duplicate options
        XCTAssertEqual(Set(card?.options ?? []).count, 4)
    }

    func testFindingRecallWithEFOnlyAsksRecordedGrade() {
        let card = QuizCardGenerator.card(
            .findingRecall,
            for: makeCase(procedure: .cabg, lvefPercent: 35, lvefQualitative: "severe")
        )
        XCTAssertEqual(card?.answer, "EF 35% (severe)")
        XCTAssertTrue(card?.options?.contains("EF 35% (severe)") == true)
    }

    func testFindingRecallNilWhenNoFindings() {
        XCTAssertNil(QuizCardGenerator.card(.findingRecall, for: makeCase(procedure: .cabg)))
    }

    // MARK: - severityGrade

    func testSeverityGradeMapsPlusNotationToGrade() {
        let finding = ValveFindingRecord(valve: .tricuspid, lesion: .regurgitation, severity: .moderate)
        let card = QuizCardGenerator.card(.severityGrade, for: makeCase(findings: [finding]))
        XCTAssertEqual(card?.questionType, .severityGrade)
        XCTAssertEqual(card?.answer, "Moderate")
        XCTAssertTrue(card?.prompt.contains("graded 2+") == true)
        XCTAssertEqual(card?.options?.count, 4)
        XCTAssertEqual(Set(card?.options ?? []).count, 4)
    }

    func testSeverityGradeSevereBoundary() {
        let finding = ValveFindingRecord(valve: .aortic, lesion: .regurgitation, severity: .severe)
        let card = QuizCardGenerator.card(.severityGrade, for: makeCase(findings: [finding]))
        XCTAssertEqual(card?.answer, "Severe")
        XCTAssertTrue(card?.prompt.contains("graded 4+") == true)
    }

    func testSeverityGradeNilWhenNoFindings() {
        XCTAssertNil(QuizCardGenerator.card(.severityGrade, for: makeCase()))
    }

    // MARK: - cards(for:) — on-save enqueue (up to 2, dedupe-friendly)

    func testCardsForFullCaseReturnsMissedViewPlusFindingRecall() {
        let finding = ValveFindingRecord(valve: .mitral, lesion: .regurgitation, severity: .moderate)
        let cards = QuizCardGenerator.cards(for: makeCase(views: fourteenViews, findings: [finding]))
        XCTAssertEqual(cards.count, 2)
        XCTAssertEqual(cards.map(\.questionType), [.missedView, .findingRecall])
        XCTAssertEqual(Set(cards.map(\.caseLogID)).count, 1) // same origin case
        XCTAssertEqual(cards[0].easeFactor, 2.5) // fresh cards
    }

    func testCardsFallsBackToSeverityGradeWithoutEF() {
        let finding = ValveFindingRecord(valve: .mitral, lesion: .regurgitation, severity: .moderate)
        let cards = QuizCardGenerator.cards(for: makeCase(views: fourteenViews, findings: [finding]))
        XCTAssertEqual(cards.map(\.questionType), [.missedView, .findingRecall])
    }

    func testCardsOnlyViewQuestionWhenNoFindings() {
        let cards = QuizCardGenerator.cards(for: makeCase(views: fourteenViews))
        XCTAssertEqual(cards.count, 1)
        XCTAssertEqual(cards.first?.questionType, .missedView)
    }

    func testCardsEmptyForEmptyCase() {
        XCTAssertTrue(QuizCardGenerator.cards(for: makeCase()).isEmpty)
    }

    func testCardsNeverExceedTwo() {
        let finding = ValveFindingRecord(valve: .aortic, lesion: .stenosis, severity: .severe)
        let rich = makeCase(
            views: Array(TEEView.allCases),
            findings: [finding],
            lvefPercent: 30,
            lvefQualitative: "severe",
            rvFunction: SeverityGrade.mild.rawValue
        )
        XCTAssertLessThanOrEqual(QuizCardGenerator.cards(for: rich).count, 2)
    }
}
