// QuizCard.swift — SwiftData entity for the spaced-repetition quiz (F3).
//
// APP TARGET ONLY (SwiftData is Apple-only). The pure scheduler works
// against `QuizCardRecord` (ACTATEEAssistantCore); `record` maps this entity to it,
// per the CaseLog ↔ CaseRecord convention.
//
// FEATURES.md F3 — fields match the spec exactly.

import Foundation
import SwiftData
import ACTATEEAssistantCore

@Model
final class QuizCard {
    @Attribute(.unique) var id: UUID
    var prompt: String            // question text
    var answer: String            // canonical answer
    var options: [String]?        // for MCQ; nil = free-text recall
    var caseLogID: UUID?          // origin case (nil = protocol question)
    var questionType: String      // QuizQuestionType rawValue
    var dueDate: Date
    var easeFactor: Double        // SM-2, init 2.5
    var intervalDays: Double      // init 0
    var repetitions: Int          // init 0
    var lastReviewed: Date?

    init(
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
        self.questionType = questionType.rawValue
        self.dueDate = dueDate
        self.easeFactor = easeFactor
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.lastReviewed = lastReviewed
    }

    /// Convenience: build from a generated record (QuizCardGenerator).
    convenience init(record: QuizCardRecord) {
        self.init(
            id: record.id,
            prompt: record.prompt,
            answer: record.answer,
            options: record.options,
            caseLogID: record.caseLogID,
            questionType: record.questionType,
            dueDate: record.dueDate,
            easeFactor: record.easeFactor,
            intervalDays: record.intervalDays,
            repetitions: record.repetitions,
            lastReviewed: record.lastReviewed
        )
    }

    // MARK: - Typed accessors

    var questionTypeEnum: QuizQuestionType? { QuizQuestionType(rawValue: questionType) }

    /// Mapping to the pure scheduler record (ACTATEEAssistantCore).
    var record: QuizCardRecord {
        QuizCardRecord(
            id: id,
            prompt: prompt,
            answer: answer,
            options: options,
            caseLogID: caseLogID,
            questionType: questionTypeEnum ?? .missedView,
            dueDate: dueDate,
            easeFactor: easeFactor,
            intervalDays: intervalDays,
            repetitions: repetitions,
            lastReviewed: lastReviewed
        )
    }

    /// Applies the scheduler's updated state back onto the entity after a
    /// review (SM-2 fields only; question content is immutable).
    func apply(_ updated: QuizCardRecord) {
        easeFactor = updated.easeFactor
        intervalDays = updated.intervalDays
        repetitions = updated.repetitions
        dueDate = updated.dueDate
        lastReviewed = updated.lastReviewed
    }
}
