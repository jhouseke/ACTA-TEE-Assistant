// SpacedRepetitionTests.swift — SM-2 scheduling math (FEATURES.md F3).

import XCTest
@testable import ACTATEEAssistantCore

final class SpacedRepetitionTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000) // fixed, deterministic

    private func makeCard(
        easeFactor: Double = SpacedRepetition.defaultEaseFactor,
        intervalDays: Double = 0,
        repetitions: Int = 0,
        dueDate: Date? = nil
    ) -> QuizCardRecord {
        QuizCardRecord(
            prompt: "P",
            answer: "A",
            questionType: .missedView,
            dueDate: dueDate ?? t0,
            easeFactor: easeFactor,
            intervalDays: intervalDays,
            repetitions: repetitions
        )
    }

    // MARK: - Initial state

    func testNewCardDefaults() {
        let card = SpacedRepetition.newCard(prompt: "P", answer: "A", questionType: .findingRecall, now: t0)
        XCTAssertEqual(card.easeFactor, 2.5)
        XCTAssertEqual(card.intervalDays, 0)
        XCTAssertEqual(card.repetitions, 0)
        XCTAssertEqual(card.dueDate, t0) // due immediately
        XCTAssertNil(card.lastReviewed)
        XCTAssertEqual(card.questionType, .findingRecall)
        XCTAssertNil(card.caseLogID)
    }

    // MARK: - Quality 5 boundary

    func testQuality5FirstReviewSchedulesOneDay() {
        let updated = SpacedRepetition.review(card: makeCard(), quality: 5, now: t0)
        XCTAssertEqual(updated.repetitions, 1)
        XCTAssertEqual(updated.intervalDays, 1)
        XCTAssertEqual(updated.easeFactor, 2.6, accuracy: 0.0001) // +0.1
        XCTAssertEqual(updated.dueDate, t0.addingTimeInterval(86_400))
        XCTAssertEqual(updated.lastReviewed, t0)
    }

    // MARK: - Fixture sequence (SM-2 canonical progression)

    func testFixtureSequenceThroughThirdPassAndFail() {
        // Pass 1 (q=5): 1 day, EF 2.6
        let c1 = SpacedRepetition.review(card: makeCard(), quality: 5, now: t0)
        XCTAssertEqual(c1.intervalDays, 1)
        XCTAssertEqual(c1.repetitions, 1)
        XCTAssertEqual(c1.easeFactor, 2.6, accuracy: 0.0001)

        // Pass 2 (q=5): 6 days, EF 2.7
        let c2 = SpacedRepetition.review(card: c1, quality: 5, now: t0.addingTimeInterval(86_400))
        XCTAssertEqual(c2.intervalDays, 6)
        XCTAssertEqual(c2.repetitions, 2)
        XCTAssertEqual(c2.easeFactor, 2.7, accuracy: 0.0001)

        // Pass 3 (q=4): previous × EF = round(6 × 2.7) = 16 days, EF unchanged
        let c3 = SpacedRepetition.review(card: c2, quality: 4, now: t0.addingTimeInterval(7 * 86_400))
        XCTAssertEqual(c3.intervalDays, 16)
        XCTAssertEqual(c3.repetitions, 3)
        XCTAssertEqual(c3.easeFactor, 2.7, accuracy: 0.0001)

        // Fail (q=0): repetitions reset, relearn tomorrow, EF −0.8 → 1.9
        let c4 = SpacedRepetition.review(card: c3, quality: 0, now: t0.addingTimeInterval(23 * 86_400))
        XCTAssertEqual(c4.repetitions, 0)
        XCTAssertEqual(c4.intervalDays, 1)
        XCTAssertEqual(c4.easeFactor, 1.9, accuracy: 0.0001)
        XCTAssertEqual(c4.dueDate, t0.addingTimeInterval(24 * 86_400))
    }

    // MARK: - Quality 0 boundary

    func testQuality0ResetsAndEaseFactorFloorsAt130() {
        let c1 = SpacedRepetition.review(card: makeCard(), quality: 0, now: t0)
        XCTAssertEqual(c1.repetitions, 0)
        XCTAssertEqual(c1.intervalDays, 1)
        XCTAssertEqual(c1.easeFactor, 1.7, accuracy: 0.0001) // 2.5 − 0.8

        let c2 = SpacedRepetition.review(card: c1, quality: 0, now: t0)
        XCTAssertEqual(c2.easeFactor, 1.3, accuracy: 0.0001) // 1.7 − 0.8 → floor

        let c3 = SpacedRepetition.review(card: c2, quality: 0, now: t0)
        XCTAssertEqual(c3.easeFactor, 1.3, accuracy: 0.0001) // clamped, never below
    }

    // MARK: - Quality semantics

    func testQuality3IsAPass() {
        let updated = SpacedRepetition.review(card: makeCard(), quality: 3, now: t0)
        XCTAssertEqual(updated.repetitions, 1)
        XCTAssertEqual(updated.intervalDays, 1)
        XCTAssertEqual(updated.easeFactor, 2.36, accuracy: 0.0001) // 2.5 − 0.14
    }

    func testQuality2IsAFail() {
        let updated = SpacedRepetition.review(card: makeCard(), quality: 2, now: t0)
        XCTAssertEqual(updated.repetitions, 0)
        XCTAssertEqual(updated.intervalDays, 1)
        XCTAssertEqual(updated.easeFactor, 2.18, accuracy: 0.0001) // 2.5 − 0.32
    }

    func testQualityClampingTreatsHighAsFiveLowAsZero() {
        let high = SpacedRepetition.review(card: makeCard(), quality: 99, now: t0)
        XCTAssertEqual(high.repetitions, 1)
        XCTAssertEqual(high.easeFactor, 2.6, accuracy: 0.0001)

        let low = SpacedRepetition.review(card: makeCard(), quality: -4, now: t0)
        XCTAssertEqual(low.repetitions, 0)
        XCTAssertEqual(low.easeFactor, 1.7, accuracy: 0.0001)
    }

    func testIntervalAfterLongHistoryUsesEaseFactor() {
        // reps ≥ 2 → round(interval × EF), independent of how many reps
        let card = makeCard(easeFactor: 2.0, intervalDays: 10, repetitions: 4)
        let updated = SpacedRepetition.review(card: card, quality: 5, now: t0)
        XCTAssertEqual(updated.intervalDays, 20)
        XCTAssertEqual(updated.repetitions, 5)
        XCTAssertEqual(updated.dueDate, t0.addingTimeInterval(20 * 86_400))
    }

    // MARK: - dueCards ordering

    func testDueCardsFiltersFutureAndOrdersByDueDate() {
        let now = t0
        let dueEarly = makeCard(dueDate: now.addingTimeInterval(-86_400))
        let dueLater = makeCard(dueDate: now.addingTimeInterval(-3600))
        let future = makeCard(dueDate: now.addingTimeInterval(3600))

        let due = SpacedRepetition.dueCards([future, dueLater, dueEarly], now: now)
        XCTAssertEqual(due.map(\.id), [dueEarly.id, dueLater.id])
    }

    func testDueCardsTieBreakIsStableById() {
        let now = t0
        let a = makeCard(dueDate: now)
        let b = makeCard(dueDate: now)
        let due = SpacedRepetition.dueCards([b, a], now: now)
        XCTAssertEqual(due.map(\.id), [a, b].sorted { $0.id.uuidString < $1.id.uuidString }.map(\.id))
    }

    func testDueCardsEmptyForNoCards() {
        XCTAssertTrue(SpacedRepetition.dueCards([], now: t0).isEmpty)
    }
}
