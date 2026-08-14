// LibraryView.swift — case list (§7.6): search, filter chips, rows, edit sheet.

import SwiftUI
import SwiftData
import TEELogCore

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaseLog.examDate, order: .reverse) private var cases: [CaseLog]

    @State private var viewModel = LibraryViewModel()
    @State private var editingCase: CaseLog?
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                if cases.isEmpty {
                    ContentUnavailableView(
                        "No cases yet",
                        systemImage: "tray",
                        description: Text("Log your first case from the Home tab.")
                    )
                } else if viewModel.filteredCases.isEmpty {
                    if viewModel.searchText.isEmpty {
                        ContentUnavailableView(
                            "No matching cases",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("No cases match the selected filter.")
                        )
                    } else {
                        ContentUnavailableView.search(text: viewModel.searchText)
                    }
                } else {
                    List {
                        ForEach(viewModel.filteredCases) { caseLog in
                            caseRow(caseLog)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    editingCase = caseLog
                                    isEditing = true
                                }
                        }
                        .onDelete(perform: deleteCases)
                    }
                    .listStyle(.plain)
                }

                footer
            }
            .searchable(text: $viewModel.searchText, prompt: "Search procedure, attending, notes…")
            .navigationTitle("Cases")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { viewModel.cases = cases }
            .onChange(of: cases.count) { _, _ in viewModel.cases = cases }
            .sheet(isPresented: $isEditing) {
                if let editingCase {
                    NavigationStack {
                        FindingsView(
                            viewModel: FindingsViewModel(caseLog: editingCase),
                            onSave: { _ in isEditing = false },
                            saveTitle: "Update case"
                        )
                        .navigationTitle("Edit case")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isEditing = false }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filter chips (§7.6)

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LibraryViewModel.staticFilters + viewModel.dynamicFilters, id: \.self) { filter in
                    Chip(title: filter.title, isSelected: viewModel.filter == filter) {
                        viewModel.filter = filter
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Case filters")
    }

    // MARK: - Row

    private func caseRow(_ caseLog: CaseLog) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(categoryColor(caseLog))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title(for: caseLog))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle(for: caseLog))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            FlowLayout(spacing: 4) {
                ForEach(caseLog.categoryTypes.prefix(2), id: \.self) { category in
                    TagChip(title: category.displayName)
                }
            }
            .frame(maxWidth: 120)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title(for: caseLog)), \(subtitle(for: caseLog))")
    }

    /// Title: procedure · key finding (§7.6).
    private func title(for caseLog: CaseLog) -> String {
        let procedure = caseLog.procedureType?.displayName ?? caseLog.procedure
        if let finding = caseLog.valveFindings.first {
            return "\(procedure) · \(finding.summary)"
        }
        if let ef = caseLog.lvefPercent {
            return "\(procedure) · EF \(ef)%"
        }
        return procedure
    }

    private func subtitle(for caseLog: CaseLog) -> String {
        let date = caseLog.examDate.formatted(date: .abbreviated, time: .omitted)
        return "\(date) · \(caseLog.attendingName) · \(caseLog.viewsObtained.count) views"
    }

    private func categoryColor(_ caseLog: CaseLog) -> Color {
        guard let first = caseLog.categoryTypes.first else { return .gray }
        switch first {
        case .valvular: .red
        case .ventricular: .blue
        case .aorticPathology: .orange
        case .structural: .purple
        case .transplant: .teal
        case .mcs: .indigo
        case .ischemia: .pink
        case .hemodynamic: .cyan
        default: .gray
        }
    }

    private var footer: some View {
        Text(viewModel.footerText)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(.bar)
    }

    private func deleteCases(at offsets: IndexSet) {
        for index in offsets {
            let caseLog = viewModel.filteredCases[index]
            modelContext.delete(caseLog)
        }
        try? modelContext.save()
    }
}
