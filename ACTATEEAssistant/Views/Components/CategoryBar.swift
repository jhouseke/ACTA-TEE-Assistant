// CategoryBar.swift — one requirement target: name, filled bar colored by
// pace (green ≥ 75%, orange behind, red critical; §5.2), count/minimum, ✓
// when met. Color-blind-safe: the ✓ and gap text carry the meaning (§11).

import SwiftUI
import ACTATEEAssistantCore

struct CategoryBar: View {
    let progress: CategoryProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(progress.category.displayName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if progress.isMet {
                    Label("\(progress.count)/\(progress.minimum)", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                        .accessibilityLabel("\(progress.category.displayName), complete, \(progress.count) of \(progress.minimum)")
                } else {
                    Text("\(progress.count)/\(progress.minimum)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if progress.gap > 0 {
                        Text("\(progress.gap) to go")
                            .font(.caption)
                            .foregroundStyle(barColor)
                    }
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(uiColor: .systemFill))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(geo.size.width * progress.percent, 0))
                }
            }
            .frame(height: 8)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(progress.category.displayName), \(progress.count) of \(progress.minimum) required, \(Int(progress.percent * 100)) percent"
            )
        }
    }

    private var barColor: Color {
        switch PaceLevel(percent: progress.percent) {
        case .onTrack: .green
        case .behindPace: .orange
        case .criticalGap: .red
        }
    }
}
