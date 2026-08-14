// Chips.swift — FlowLayout + Chip + single/multi-select chip grids.
//
// Used by Procedure (single-select, §7.2 step 1), Indication (multi-select,
// step 2), views toggle grid, and auto-category tags. Hit targets ≥ 44 pt
// (§9.5, §11).

import SwiftUI

// MARK: - Wrapping layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Chip

struct Chip: View {
    let title: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                    in: Capsule()
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44) // §9.5 / §11 hit target
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Read-only tag chip (auto-categories, §7.3).
struct TagChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.15), in: Capsule())
            .foregroundStyle(Color.accentColor)
            .accessibilityLabel(title)
    }
}

// MARK: - Grids

/// Single-select wrapping chip grid (Procedure, step 1).
struct SingleSelectChipGrid<Value: Hashable>: View {
    let values: [Value]
    let title: (Value) -> String
    @Binding var selection: Value?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \.self) { value in
                Chip(title: title(value), isSelected: selection == value) {
                    selection = value
                }
            }
        }
    }
}

/// Multi-select wrapping chip grid (Indications, views toggle).
struct MultiSelectChipGrid<Value: Hashable>: View {
    let values: [Value]
    let title: (Value) -> String
    @Binding var selection: Set<Value>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(values, id: \.self) { value in
                Chip(title: title(value), isSelected: selection.contains(value)) {
                    if selection.contains(value) {
                        selection.remove(value)
                    } else {
                        selection.insert(value)
                    }
                }
            }
        }
    }
}
