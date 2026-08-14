// QuizCardEnqueuer.swift — app-only glue: generate + dedupe + insert quiz
// cards on case save (FEATURES.md F3).
//
// APP TARGET ONLY (uses SwiftData ModelContext). The generation math lives
// in QuizCardGenerator (TEELogCore, unit-tested); this type only decides
// which generated cards are already queued for the origin case.
//
// Rule (FEATURES.md F3): on each case save, enqueue up to 2 cards
// (missed-view + finding-recall) if not already queued for that case.
// Dedupe key: caseLogID + questionType — so re-saving an edited case never
// duplicates, and a case with an existing card of a type never re-queues it.

import Foundation
import SwiftData
import TEELogCore

enum QuizCardEnqueuer {

    /// Fetches every QuizCard (the deck is small — hundreds of cards at
    /// most), builds the dedupe key set, and inserts generated cards that
    /// aren't queued yet. Safe to call on every save; no-op when the case
    /// can't support any question type.
    static func enqueue(for caseLog: CaseLog, context: ModelContext) {
        let generated = QuizCardGenerator.cards(for: caseLog.record)
        guard !generated.isEmpty else { return }

        let existing: [QuizCard]
        do {
            existing = try context.fetch(FetchDescriptor<QuizCard>())
        } catch {
            existing = []
        }
        let queuedKeys = Set(existing.compactMap { card -> String? in
            guard let caseLogID = card.caseLogID else { return nil }
            return key(caseLogID: caseLogID, questionType: card.questionType)
        })

        var inserted = false
        for card in generated {
            guard let caseLogID = card.caseLogID else { continue }
            let cardKey = key(caseLogID: caseLogID, questionType: card.questionType.rawValue)
            guard !queuedKeys.contains(cardKey) else { continue }
            context.insert(QuizCard(record: card))
            inserted = true
        }
        if inserted {
            try? context.save()
        }
    }

    private static func key(caseLogID: UUID, questionType: String) -> String {
        "\(caseLogID.uuidString)|\(questionType)"
    }
}
