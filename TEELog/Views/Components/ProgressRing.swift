// ProgressRing.swift — SectorMark ring showing overall % (§7.1).
//
// No animation modifiers → Reduce Motion is respected by construction (§11).

import SwiftUI
import Charts

struct ProgressRing: View {
    let percent: Double
    var lineWidth: CGFloat = 16

    var body: some View {
        Chart {
            SectorMark(
                angle: .value("Remaining", max(1 - percent, 0.001) * 360),
                innerRadius: .ratio(0.78),
                angularInset: 2
            )
            .cornerRadius(4)
            .foregroundStyle(Color(uiColor: .systemFill))

            SectorMark(
                angle: .value("Progress", max(percent, 0.001) * 360),
                innerRadius: .ratio(0.78),
                angularInset: 2
            )
            .cornerRadius(4)
            .foregroundStyle(.tint)
        }
        .chartLegend(.hidden)
        .overlay {
            Text("\(Int((percent * 100).rounded()))%")
                .font(.headline.monospacedDigit())
                .accessibilityHidden(true)
        }
        .accessibilityElement()
        .accessibilityLabel("\(Int((percent * 100).rounded())) percent of total case minimum")
        .accessibilityValue("\(Int((percent * 100).rounded())) percent")
    }
}
