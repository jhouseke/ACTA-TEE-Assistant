// ProgressScreen.swift — requirements tracking (§7.4).
//
// Named ProgressScreen (not ProgressView) to avoid clashing with
// SwiftUI.ProgressView.

import SwiftUI
import SwiftData
import TEELogCore

struct ProgressScreen: View {
    @Query(sort: \CaseLog.examDate, order: .reverse) private var cases: [CaseLog]
    // F1: shared suite so the widget + intents see the same track selection
    @AppStorage("selectedTrackID", store: ModelContainerFactory.sharedDefaults) private var trackIDRaw = TrackID.nbeAdvanced.rawValue

    @State private var viewModel = ProgressViewModel()

    private var trackID: TrackID { TrackID(rawValue: trackIDRaw) ?? .nbeAdvanced }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    trackPicker

                    if viewModel.cases.isEmpty {
                        ContentUnavailableView(
                            "No cases yet",
                            systemImage: "chart.bar",
                            description: Text("Logged cases appear here with live progress against your track's minimums.")
                        )
                        .padding(.top, 40)
                    } else {
                        if let focus = viewModel.focus {
                            focusAlert(focus)
                        }

                        categoryCard

                        milestonesCard
                    }
                }
                .padding()
            }
            .navigationTitle("Requirements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // F2: Insights screen entry — Progress tab header
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        InsightsView()
                    } label: {
                        Label("Insights", systemImage: "chart.bar.xaxis")
                    }
                    .accessibilityLabel("Personal pattern insights")
                }
            }
            .onAppear { viewModel.update(cases: cases, trackID: trackID) }
            .onChange(of: cases.count) { _, _ in viewModel.update(cases: cases, trackID: trackID) }
            .onChange(of: trackIDRaw) { _, _ in viewModel.update(cases: cases, trackID: trackID) }
        }
    }

    // MARK: - Track picker

    private var trackPicker: some View {
        Picker("Track", selection: $trackIDRaw) {
            ForEach(TrackID.allCases, id: \.rawValue) { trackID in
                Text(trackID.displayName).tag(trackID.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Requirement track")
    }

    // MARK: - Focus alert (§7.4)

    private func focusAlert(_ focus: CategoryProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Focus: \(focus.category.displayName)", systemImage: "scope")
                .font(.subheadline.weight(.semibold))
            Text("\(focus.gap) cases to the \(focus.minimum)-case minimum.")
                .font(.footnote)
            if !viewModel.focusProcedures.isEmpty {
                Text("Fastest path: \(viewModel.focusProcedures.map(\.displayName).joined(separator: ", ")).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text("Log any case carrying this indication to close it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Category requirements card

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Category requirements")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.total)/\(viewModel.track.totalMinimum)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ForEach(viewModel.categories, id: \.category) { cp in
                CategoryBar(progress: cp)
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Milestones card (§7.4)

    private var milestonesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Milestones")
                .font(.headline)
            if let projected = viewModel.projectedDate {
                Label(
                    "Projected \(projected.formatted(.dateTime.month(.wide).year())) — \(viewModel.monthsLeft) mo ahead",
                    systemImage: "calendar"
                )
                .font(.subheadline)
            } else {
                Text("Log your first case to see a completion projection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("PD mid-year sign-off due: \(defaultSignOffDate.formatted(.dateTime.month(.wide).year()))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    /// PLACEHOLDER: mid-year sign-off date (configure per program, §15.3).
    private var defaultSignOffDate: Date {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: Date())
        return calendar.date(from: DateComponents(year: year, month: 1, day: 15)) ?? Date()
    }
}
