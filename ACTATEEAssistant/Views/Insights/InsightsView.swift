// InsightsView.swift — personal pattern insights (F2).
//
// Entered from the Progress tab header. Aggregates are computed on-device
// by InsightsEngine (ACTATEEAssistantCore, unit-tested) from the local SwiftData
// store; each card renders a native Swift Charts chart + a one-line
// takeaway + a tap-through that opens the Library pre-filtered (reusing
// LibraryFilter — Library already has the filters).
//
// FEATURES.md F2 — deterministic, no network, updates immediately after a
// case save (@Query drives recomputation).

import SwiftUI
import SwiftData
import Charts
import ACTATEEAssistantCore

struct InsightsView: View {
    @Query(sort: \CaseLog.examDate, order: .reverse) private var cases: [CaseLog]

    private var report: InsightsEngine.InsightsReport {
        InsightsEngine.report(from: cases.map(\.record))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if cases.isEmpty {
                    ContentUnavailableView(
                        "No cases yet",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Log cases to unlock personal pattern insights.")
                    )
                    .padding(.top, 40)
                } else {
                    viewCoverageCard
                    severityCard
                    rvUndercallCard
                    mismatchCard
                    monthlyMixCard
                }
            }
            .padding()
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: LibraryFilter.self) { filter in
            LibraryView(initialFilter: filter) // tap-through: reuse Library filters
        }
    }

    // MARK: - Chart data (local, chart-only)

    private struct CoverageBar: Identifiable {
        let id = UUID()
        let label: String
        let rate: Double
    }

    private struct SeverityBar: Identifiable {
        let id = UUID()
        let lesion: String
        let grade: String
        let count: Int
    }

    private struct MixBar: Identifiable {
        let id = UUID()
        let month: String
        let procedure: String
        let count: Int
    }

    private struct CountBar: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
    }

    private let palette: [Color] = [.red, .blue, .orange, .purple, .teal, .indigo, .pink, .cyan]

    // MARK: - Cards

    // 1. View coverage — top 5 routinely-skipped views
    private var viewCoverageCard: some View {
        let stats = report.viewCoverage.sorted {
            if $0.skipRate != $1.skipRate { return $0.skipRate > $1.skipRate }
            if $0.procedure != $1.procedure { return $0.procedure.displayName < $1.procedure.displayName }
            return $0.view.displayName < $1.view.displayName
        }
        let bars = stats.prefix(5).map {
            CoverageBar(label: "\($0.view.displayName) · \($0.procedure.displayName)", rate: $0.skipRate)
        }
        let focus = stats.first?.procedure

        return insightCard(
            title: "View coverage",
            systemImage: "rectangle.stack.badge.eye",
            takeaway: report.mostSkippedViewTakeaway,
            filter: focus.map { .procedure($0) }
        ) {
            if bars.isEmpty {
                Text("Every standard view is logged in all cases — nothing skipped.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Skip rate", bar.rate),
                        y: .value("View", bar.label)
                    )
                    .foregroundStyle(.orange)
                }
                .chartXScale(domain: 0...1)
                .chartXAxisLabel("Skip rate")
                .frame(height: 180)
            }
        }
    }

    // 2. Severity distribution + overcall heuristic
    private var severityCard: some View {
        let dists = report.severityDistributions
        let bars: [SeverityBar] = dists.flatMap { dist in
            SeverityGrade.allCases.compactMap { grade in
                guard let count = dist.counts[grade], count > 0 else { return nil }
                return SeverityBar(
                    lesion: "\(dist.valve.shortCode) \(dist.lesion.displayName)",
                    grade: grade.plusNotation,
                    count: count
                )
            }
        }
        let lesions = dists.map { "\($0.valve.shortCode) \($0.lesion.displayName)" }

        return insightCard(
            title: "Severity distribution",
            systemImage: "waveform.path.ecg",
            takeaway: report.overcallTakeaways.first ?? "No valve graded 2+/4+ in more than 25% of cases — distributions look reasonable.",
            filter: .category(.valvular)
        ) {
            if bars.isEmpty {
                Text("No valve lesions logged yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Severity", bar.grade),
                        y: .value("Cases", bar.count),
                        foregroundStyle: by: .value("Lesion", bar.lesion)
                    )
                }
                .chartForegroundStyleScale(domain: lesions, range: palette.prefix(lesions.count).map { $0 })
                .frame(height: 180)
            }
            if !report.overcallTakeaways.isEmpty {
                ForEach(report.overcallTakeaways, id: \.self) { line in
                    Label(line, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    // 3. RV undercall heuristic
    private var rvUndercallCard: some View {
        let flagged = report.rvUndercalls
        return insightCard(
            title: "RV undercall",
            systemImage: "heart.circle",
            takeaway: report.rvUndercallTakeaway ?? "No RV undercall pattern — RV and LV function are tracked consistently.",
            filter: .category(.ventricular)
        ) {
            Chart {
                BarMark(x: .value("Pattern", "RV undercall"), y: .value("Cases", flagged.count))
                    .foregroundStyle(.red)
            }
            .chartYScale(domain: 0...max(flagged.count, 1))
            .frame(height: 100)
            if !flagged.isEmpty {
                ForEach(flagged.prefix(3), id: \.caseID) { item in
                    Text("\(item.examDate.formatted(date: .abbreviated, time: .omitted)) · \(item.procedure.displayName) — LV \(item.lvefQualitative ?? "—")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // 4. Indication–procedure mismatch
    private var mismatchCard: some View {
        let groups = Dictionary(grouping: report.mismatches, by: \.procedure)
        let bars = groups
            .map { CountBar(label: $0.key.displayName, count: $0.value.count) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                return $0.label < $1.label
            }
        let focus = groups.max { $0.value.count < $1.value.count }?.key

        return insightCard(
            title: "Indication–procedure mismatch",
            systemImage: "arrow.triangle.branch",
            takeaway: report.mismatchTakeaway ?? "No indication–procedure mismatches found.",
            filter: focus.map { .procedure($0) }
        ) {
            if bars.isEmpty {
                Text("Every logged procedure carries an expected indication.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(bars) { bar in
                    BarMark(x: .value("Cases", bar.count), y: .value("Procedure", bar.label))
                        .foregroundStyle(.purple)
                }
                .frame(height: CGFloat(max(bars.count * 28, 60)))
            }
        }
    }

    // 5. Monthly case mix
    private var monthlyMixCard: some View {
        let bars = report.monthlyMix.map {
            MixBar(month: $0.yearMonth, procedure: $0.procedure.displayName, count: $0.count)
        }
        let procedures = Array(Set(bars.map(\.procedure))).sorted()

        return insightCard(
            title: "Monthly case mix",
            systemImage: "calendar.badge.clock",
            takeaway: report.monthlyMixTakeaway,
            filter: .all
        ) {
            if bars.isEmpty {
                Text("No cases logged yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(bars) { bar in
                    BarMark(
                        x: .value("Month", bar.month),
                        y: .value("Cases", bar.count),
                        foregroundStyle: by: .value("Procedure", bar.procedure)
                    )
                }
                .chartForegroundStyleScale(domain: procedures, range: palette.prefix(procedures.count).map { $0 })
                .frame(height: 180)
            }
        }
    }

    // MARK: - Shared card shell

    /// Card with a one-line takeaway; wrapped in NavigationLink(value:) so
    /// tapping pushes the Library pre-filtered (F2 acceptance: every card's
    /// tap-through filters Library correctly).
    @ViewBuilder
    private func insightCard(
        title: String,
        systemImage: String,
        takeaway: String?,
        filter: LibraryFilter?,
        @ViewBuilder chart: () -> some View
    ) -> some View {
        let content = VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            chart()
            if let takeaway {
                Text(takeaway)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title + (takeaway.map { ", \($0)" } ?? ""))

        if let filter {
            NavigationLink(value: filter) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the case list filtered to \(filter.title)")
        } else {
            content
        }
    }
}
