// SeverityStepper.swift — 0 · 1+ · 2+ · 3+ · 4+ stepper (§7.3, §4 note).
//
// Five slots map onto the canonical SeverityGrade enum: 0→none, 1+→mild,
// 2+/3+→moderate, 4+→severe ("trace" is reachable via dictation). VoiceOver
// reads "Aortic regurgitation, 3 plus" (§11).

import SwiftUI
import ACTATEEAssistantCore

struct SeverityStepper: View {
    let label: String
    @Binding var severity: SeverityGrade

    /// §7.3 literal scale: "0 · 1+ · 2+ · 3+ · 4+".
    private static let slots: [(notation: String, grade: SeverityGrade, spoken: String)] = [
        ("0", .none, "zero"),
        ("1+", .mild, "1 plus"),
        ("2+", .moderate, "2 plus"),
        ("3+", .moderate, "3 plus"),
        ("4+", .severe, "4 plus")
    ]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Self.slots, id: \.notation) { slot in
                Button {
                    severity = slot.grade
                } label: {
                    Text(slot.notation)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            severity == slot.grade ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(severity == slot.grade ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44) // §11 hit target
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(spokenSeverity)")
        .accessibilityValue(spokenSeverity)
    }

    private var spokenSeverity: String {
        Self.slots.first { $0.grade == severity }?.spoken ?? "zero"
    }
}
