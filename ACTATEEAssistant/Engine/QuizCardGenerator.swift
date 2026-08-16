// QuizCardGenerator.swift — builds quiz cards from real logged cases (F3).
//
// Deterministic (no randomness — tests pin exact outputs). Question types
// (FEATURES.md F3):
//   - missedView:     "This AVR case logged 14 views — which standard view
//                     is missing from this list?"
//   - nextView:       "After ME bicaval, what is the next protocol view?"
//   - findingRecall:  MCQ derived from the case's actual findings
//   - severityGrade:  description → grade mapping from a real ValveFinding
//
// `cards(for:)` is the on-save entry point: up to 2 cards per case
// (missed-view + finding-recall per FEATURES.md), skipping types the case
// can't support. The four `card(...)` factories are public and unit-tested
// so future decks (protocol questions, all-types refreshers) can reuse them.
//
// Pure Swift (Foundation only) — compiles on Linux as part of ACTATEEAssistantCore.

import Foundation

public enum QuizCardGenerator {

    /// Canonical protocol acquisition order. The 20-view protocol in
    /// IMPLEMENTATION.md §4.1 is represented by `TEEView.allCases` (the
    /// enum is the single source of truth for view vocabulary).
    public static var protocolViewOrder: [TEEView] { TEEView.allCases }

    // MARK: - On-save entry point

    /// Up to 2 cards per case: a view question (missedView) plus a findings
    /// question (findingRecall; severityGrade when the case has a valve
    /// finding but no EF to build a recall stem on). Nil entries are
    /// dropped, so a case with no views and no findings yields zero cards.
    public static func cards(for record: CaseRecord) -> [QuizCardRecord] {
        var out: [QuizCardRecord] = []
        if let viewCard = card(.missedView, for: record) { out.append(viewCard) }
        if let findingCard = card(.findingRecall, for: record) ?? card(.severityGrade, for: record) {
            out.append(findingCard)
        }
        return out
    }

    // MARK: - Factories

    /// One card of `type` from a real case, or nil when the case lacks the
    /// data that type needs.
    public static func card(_ type: QuizQuestionType, for record: CaseRecord) -> QuizCardRecord? {
        switch type {
        case .missedView: card(missedViewFor: record)
        case .nextView: card(nextViewFor: record)
        case .findingRecall: card(findingRecallFor: record)
        case .severityGrade: card(severityGradeFor: record)
        }
    }

    /// "This AVR case logged 14 views — which standard view is missing from
    /// this list?" Answer = first standard view (protocol order) not in
    /// viewsObtained. Needs ≥ 1 view logged.
    public static func card(missedViewFor record: CaseRecord) -> QuizCardRecord? {
        let obtained = Set(record.viewsObtained)
        guard !obtained.isEmpty,
              let missing = protocolViewOrder.first(where: { !obtained.contains($0.rawValue) })
        else { return nil }

        // Distractors: plausible missing views (also absent from the case),
        // then any remaining standard views to fill the option set.
        let candidates = protocolViewOrder.filter { $0 != missing }
        var distractors = candidates.filter { !obtained.contains($0.rawValue) }.map(\.displayName)
        if distractors.count < 3 {
            distractors += candidates.filter { obtained.contains($0.rawValue) }.map(\.displayName)
        }

        let procedure = ProcedureType(rawValue: record.procedure)?.displayName ?? record.procedure
        return SpacedRepetition.newCard(
            prompt: "This \(procedure) case logged \(record.viewsObtained.count) views — which standard view is missing from this list?",
            answer: missing.displayName,
            options: ([missing.displayName] + Array(distractors.prefix(3))),
            caseLogID: record.id,
            questionType: .missedView
        )
    }

    /// "After ME bicaval, what is the next protocol view?" Anchor = the
    /// case's last-obtained view in protocol order. Needs ≥ 2 views logged
    /// (a single view has not established a sequence) and a next view to
    /// exist.
    public static func card(nextViewFor record: CaseRecord) -> QuizCardRecord? {
        guard record.viewsObtained.count >= 2 else { return nil }
        let order = protocolViewOrder
        let anchor = record.viewsObtained
            .compactMap { raw in order.firstIndex { $0.rawValue == raw } }
            .max()
        guard let anchorIndex = anchor, anchorIndex + 1 < order.count else { return nil }

        let next = order[anchorIndex + 1]
        let distractors = order
            .filter { $0 != next && $0 != order[anchorIndex] }
            .map(\.displayName)

        return SpacedRepetition.newCard(
            prompt: "After \(order[anchorIndex].displayName), what is the next protocol view?",
            answer: next.displayName,
            options: [next.displayName] + Array(distractors.prefix(3)),
            caseLogID: record.id,
            questionType: .nextView
        )
    }

    /// MCQ derived from the case's actual findings. With a valve finding:
    /// "CABG ×4, EF 35% — what is the most likely recorded finding?" style
    /// stem built from procedure + EF; answer is the recorded finding.
    /// Without valve findings but with an EF, asks the recorded EF grade.
    public static func card(findingRecallFor record: CaseRecord) -> QuizCardRecord? {
        let procedure = ProcedureType(rawValue: record.procedure)?.displayName ?? record.procedure

        // Stem context: EF when present (matches the FEATURES.md example).
        var stem = procedure
        if let pct = record.lvefPercent {
            stem += ", EF \(pct)%"
        }

        if let finding = record.valveFindings.first {
            let answer = findingSummary(finding)
            let distractors = findingDistractorPool
                .filter { $0 != answer }
                .prefix(3)
            return SpacedRepetition.newCard(
                prompt: "\(stem) — what is the most likely recorded finding?",
                answer: answer,
                options: [answer] + Array(distractors),
                caseLogID: record.id,
                questionType: .findingRecall
            )
        }

        if let qualitative = record.lvefQualitative {
            let answer = "EF \(record.lvefPercent.map(String.init) ?? "—")% (\(qualitative))"
            let distractors = ["normal", "mild", "moderate", "severe"]
                .filter { $0 != qualitative }
                .prefix(3)
            return SpacedRepetition.newCard(
                prompt: "\(stem) — how was the LV EF recorded?",
                answer: answer,
                options: [answer] + Array(distractors),
                caseLogID: record.id,
                questionType: .findingRecall
            )
        }

        return nil
    }

    /// Description → grade mapping pulled from a real ValveFinding:
    /// "The mitral regurgitation was graded 2+ — which severity grade is
    /// that?" Needs ≥ 1 valve finding.
    public static func card(severityGradeFor record: CaseRecord) -> QuizCardRecord? {
        guard let finding = record.valveFindings.first else { return nil }
        let grade = finding.severity
        let distractors = SeverityGrade.allCases
            .filter { $0 != grade }
            .map(\.rawValue.capitalized)
        return SpacedRepetition.newCard(
            prompt: "In this case, the \(finding.valve.displayName.lowercased()) \(finding.lesion.displayName.lowercased()) was graded \(grade.plusNotation). Which severity grade is that?",
            answer: grade.rawValue.capitalized,
            options: [grade.rawValue.capitalized] + Array(distractors.prefix(3)),
            caseLogID: record.id,
            questionType: .severityGrade
        )
    }

    // MARK: - Helpers

    /// Readable finding label, e.g. "Mitral regurgitation 2+".
    static func findingSummary(_ finding: ValveFindingRecord) -> String {
        "\(finding.valve.displayName) \(finding.lesion.displayName.lowercased()) \(finding.severity.plusNotation)"
    }

    /// Fixed pool of plausible valve-finding labels used as findingRecall
    /// distractors (deterministic, no randomness).
    static let findingDistractorPool: [String] = [
        "Aortic stenosis 2+",
        "Aortic regurgitation 1+",
        "Mitral regurgitation 2+",
        "Mitral stenosis 1+",
        "Tricuspid regurgitation 2+",
        "Tricuspid stenosis trace",
        "Pulmonic regurgitation 1+",
        "Mitral regurgitation 4+",
        "Aortic regurgitation 4+"
    ]
}
