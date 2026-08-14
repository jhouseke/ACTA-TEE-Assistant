// DashboardView.swift — Home (§7.1).

import SwiftUI
import SwiftData
import TEELogCore

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaseLog.examDate, order: .reverse) private var cases: [CaseLog]

    @AppStorage("selectedTrackID", store: ModelContainerFactory.sharedDefaults) private var trackIDRaw = TrackID.nbeAdvanced.rawValue
    @AppStorage("profileName") private var profileName = "R. Chen"
    @AppStorage("profileTitle") private var profileTitle = "CT Fellow, PGY-6"

    @State private var viewModel = DashboardViewModel()
    @State private var isLoggingCase = false
    @State private var isShowingSettings = false

    private var trackID: TrackID { TrackID(rawValue: trackIDRaw) ?? .nbeAdvanced }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    progressCard

                    if !viewModel.behindPace.isEmpty {
                        gapAlert
                    }

                    primaryCTA

                    recentCases
                }
                .padding()
            }
            .navigationTitle("TEE Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    avatar
                }
            }
            .onAppear { viewModel.update(cases: cases, trackID: trackID) }
            .onChange(of: cases.count) { _, _ in viewModel.update(cases: cases, trackID: trackID) }
            .onChange(of: trackIDRaw) { _, _ in viewModel.update(cases: cases, trackID: trackID) }
            .sheet(isPresented: $isLoggingCase) {
                QuickLogView()
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(profileName)
                .font(.title2.weight(.bold))
            Text(profileTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var avatar: some View {
        Text(initials)
            .font(.subheadline.weight(.bold))
            .frame(width: 36, height: 36)
            .background(Color.accentColor.opacity(0.2), in: Circle())
            .accessibilityLabel("Profile: \(profileName), \(profileTitle)")
    }

    private var initials: String {
        let parts = profileName.split(separator: " ")
        return parts.prefix(2).compactMap(\.first).map(String.init).joined()
    }

    // MARK: - Progress card

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ProgressRing(percent: viewModel.overallPercent)
                    .frame(width: 96, height: 96)
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.track.name)
                        .font(.headline)
                    Text("\(viewModel.total)/\(viewModel.track.totalMinimum) cases")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                    onTrackPill
                }
                Spacer()
            }
            Text("\(viewModel.track.totalMinimum - viewModel.total) to go")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var onTrackPill: some View {
        let onTrack = viewModel.overallPercent >= 0.75
        return Text(onTrack ? "On track" : "Behind pace")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background((onTrack ? Color.green : Color.orange).opacity(0.2), in: Capsule())
            .foregroundStyle(onTrack ? .green : .orange)
    }

    // MARK: - Gap alert

    private var gapAlert: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Categories behind pace", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            ForEach(viewModel.behindPace.prefix(4), id: \.category) { cp in
                Text("• \(cp.category.displayName): \(cp.count)/\(cp.minimum) (\(cp.gap) to go)")
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - CTA

    private var primaryCTA: some View {
        Button {
            isLoggingCase = true
        } label: {
            Label("Log a case · ~40 sec", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Opens the three-step quick log flow")
    }

    // MARK: - Recent cases

    private var recentCases: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent cases")
                .font(.headline)
            if viewModel.recentCases.isEmpty {
                Text("No cases yet — log your first case with the button above.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.recentCases) { caseLog in
                    recentRow(caseLog)
                }
            }
        }
    }

    private func recentRow(_ caseLog: CaseLog) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(caseLog.procedureType?.displayName ?? caseLog.procedure)
                    .font(.subheadline.weight(.semibold))
                Text("\(caseLog.examDate.formatted(date: .abbreviated, time: .omitted)) · \(caseLog.attendingName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            FlowLayout(spacing: 4) {
                ForEach(caseLog.categoryTypes.prefix(3), id: \.self) { category in
                    TagChip(title: category.displayName)
                }
            }
            .frame(maxWidth: 160)
        }
        .padding(.vertical, 4)
    }
}
