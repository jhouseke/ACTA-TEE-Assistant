// ReviewSessionView.swift — spaced-repetition quiz session (F3).
//
// Presents the due deck one card at a time: self-assess with
// Show answer / Again / Good / Easy (≥44 pt targets, §11), applies the
// SM-2 update via SpacedRepetition (TEELogCore), then a session summary.
//
// FEATURES.md F3 — no network anywhere in the quiz path.

import SwiftUI
import SwiftData
import TEELogCore

struct ReviewSessionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Due cards, pre-sorted by SpacedRepetition.dueCards ordering.
    let cards: [QuizCard]

    @State private var index = 0
    @State private var revealed = false
    @State private var results: [Int] = [] // SM-2 qualities, in review order
    @State private var finished = false

    /// UI grade mapping (SM-2): Again → 2 (fail, <3), Good → 4, Easy → 5.
    private let againQuality = 2
    private let goodQuality = 4
    private let easyQuality = 5

    var body: some View {
        NavigationStack {
            Group {
                if cards.isEmpty {
                    emptyState
                } else if finished {
                    summary
                } else {
                    currentCard
                }
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    // MARK: - Empty / summary states

    private var emptyState: some View {
        ContentUnavailableView(
            "No cards due",
            systemImage: "checkmark.circle",
            description: Text("Cards from your logged cases will appear here when they're due.")
        )
    }

    private var summary: some View {
        let againCount = results.filter { $0 < 3 }.count
        let passedCount = results.count - againCount
        return VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Session complete")
                .font(.title2.weight(.semibold))
            Text("\(results.count) card\(results.count == 1 ? "" : "s") reviewed — \(passedCount) passed, \(againCount) again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(32)
    }

    // MARK: - Card

    private var currentCard: some View {
        let card = cards[index]
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Card \(index + 1) of \(cards.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(card.questionTypeEnum?.displayName ?? card.questionType)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                }

                Text(card.prompt)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHeading(.h2)

                if let options = card.options {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                            Text("· \(option)")
                                .font(.body)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.top, 4)
                }

                if revealed {
                    answerBlock
                } else {
                    showAnswerButton
                }
            }
            .padding()
        }
    }

    private var answerBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Answer", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.tint)
            Text(cards[index].answer)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Answer: \(cards[index].answer)")

            Text("How well did you recall it?")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            // Again / Good / Easy — all ≥44 pt hit targets (§11)
            HStack(spacing: 10) {
                gradeButton("Again", quality: againQuality, tint: .red)
                gradeButton("Good", quality: goodQuality, tint: .blue)
                gradeButton("Easy", quality: easyQuality, tint: .green)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var showAnswerButton: some View {
        Button {
            withAnimation(.snappy) { revealed = true }
        } label: {
            Text("Show answer")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Reveals the answer, then grades your recall")
    }

    private func gradeButton(_ title: String, quality: Int, tint: Color) -> some View {
        Button {
            grade(quality)
        } label: {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .foregroundStyle(tint)
        }
        .buttonStyle(.bordered)
        .tint(tint)
        .accessibilityLabel("\(title) — reschedules the card")
    }

    // MARK: - Actions

    private func grade(_ quality: Int) {
        let card = cards[index]
        let updated = SpacedRepetition.review(card: card.record, quality: quality, now: .now)
        card.apply(updated)
        try? modelContext.save()
        results.append(quality)

        withAnimation(.snappy) {
            if index + 1 < cards.count {
                index += 1
                revealed = false
            } else {
                finished = true
            }
        }
    }
}
