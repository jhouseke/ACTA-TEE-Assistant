// SpacedRepetition.swift — SM-2 scheduler + quiz card value type (F3).
//
// SM-2 (SuperMemo-2) with the standard formula:
//   - quality 0…5 (clamped); quality < 3 → fail (repetitions reset)
//   - interval: first pass 1 day, second pass 6 days, then previous
//     interval × easeFactor (rounded)
//   - easeFactor update: EF' = EF + (0.1 − (5−q)·(0.08 + (5−q)·0.02)),
//     floored at 1.3
//   - dueDate = review time + interval days (86400 s/day — interval math is
//     intentionally calendar-independent for determinism)
//
// Pure Swift (Foundation only) — compiles on Linux as part of ACTATEEAssistantCore.
// The SwiftData QuizCard @Model (app target) mirrors QuizCardRecord here.
//
// FEATURES.md F3

import Foundation

// MARK: - Question type

/// Question kinds generated from real logged cases (FEATURES.md F3).
public enum QuizQuestionType: String, CaseIterable, Codable, Hashable, Sendable {
    case missedView
    case nextView
    case findingRecall
    case severityGrade

    public var displayName: String {
        switch self {
        case .missedView: "Missing view"
        case .nextView: "Next protocol view"
        case .findingRecall: "Finding recall"
        case .severityGrade: "Severity grade"
        }
    }
}

// MARK: - Record

/// Pure value mirror of the persisted `QuizCard` @Model (FEATURES.md F3).
public struct QuizCardRecord: Equatable, Hashable, Sendable {
    public var id: UUID
    public var prompt: String            // question text
    public var answer: String            // canonical answer
    public var options: [String]?        // for MCQ; nil = free-text recall
    public var caseLogID: UUID?          // origin case (nil = protocol question)
    public var questionType: QuizQuestionType
    public var dueDate: Date
    public var easeFactor: Double        // SM-2, init 2.5
    public var intervalDays: Double      // init 0
    public var repetitions: Int          // init 0
    public var lastReviewed: Date?

    public init(
        id: UUID = UUID(),
        prompt: String,
        answer: String,
        options: [String]? = nil,
        caseLogID: UUID? = nil,
        questionType: QuizQuestionType,
        dueDate: Date = Date(),
        easeFactor: Double = SpacedRepetition.defaultEaseFactor,
        intervalDays: Double = 0,
        repetitions: Int = 0,
        lastReviewed: Date? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.answer = answer
        self.options = options
        self.caseLogID = caseLogID
        self.questionType = questionType
        self.dueDate = dueDate
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.lastReviewed = lastReviewed
    }
}

// MARK: - Scheduler

public enum SpacedRepetition {

    public static let defaultEaseFactor = 2.5
    public static let minimumEaseFactor = 1.3
    public static let secondsPerDay: TimeInterval = 86_400

    /// Clamped quality used by the UI buttons: Again → 2, Good → 4, Easy → 5
    /// (anything < 3 fails the card per SM-2).
    public static func clampQuality(_ quality: Int) -> Int {
        min(max(quality, 0), 5)
    }

    /// Applies one SM-2 review to a card, returning the updated record.
    /// `now` is injectable for deterministic tests.
    public static func review(card: QuizCardRecord, quality: Int, now: Date = Date()) -> QuizCardRecord {
        let q = clampQuality(quality)
        var updated = card

        if q >= 3 {
            switch card.repetitions {
            case 0: updated.intervalDays = 1
            case 1: updated.intervalDays = 6
            default: updated.intervalDays = (card.intervalDays * card.easeFactor).rounded()
            }
            updated.repetitions = card.repetitions + 1
        } else {
            // Fail: repetitions reset, relearn tomorrow (SM-2).
            updated.repetitions = 0
            updated.intervalDays = 1
        }

        let delta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
        updated.easeFactor = max(minimumEaseFactor, card.easeFactor + delta)
        updated.dueDate = now.addingTimeInterval(updated.intervalDays * secondsPerDay)
        updated.lastReviewed = now
        return updated
    }

    /// Cards due at or before `now`, ordered by due date (earliest first).
    /// Deterministic: ties break by id for stable ordering.
    public static func dueCards(_ cards: [QuizCardRecord], now: Date = Date()) -> [QuizCardRecord] {
        cards
            .filter { $0.dueDate <= now }
            .sorted {
                if $0.dueDate != $1.dueDate { return $0.dueDate < $1.dueDate }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    /// A brand-new card: due immediately, virgin SM-2 state (ease 2.5,
    /// interval 0, repetitions 0). `now` injectable for tests.
    public static func newCard(
        prompt: String,
        answer: String,
        options: [String]? = nil,
        caseLogID: UUID? = nil,
        questionType: QuizQuestionType,
        now: Date = Date()
    ) -> QuizCardRecord {
        QuizCardRecord(
            prompt: prompt,
            answer: answer,
            options: options,
            caseLogID: caseLogID,
            questionType: questionType,
            dueDate: now,
            easeFactor: defaultEaseFactor,
            intervalDays: 0,
            repetitions: 0,
            lastReviewed: nil
        )
    }
}
