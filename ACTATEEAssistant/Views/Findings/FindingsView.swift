// FindingsView.swift — findings editor (§7.3), reused by Quick Log step 3,
// the standalone view, and the Library edit sheet.

import SwiftUI
import SwiftData
import ACTATEEAssistantCore

struct FindingsView: View {
    @Bindable var viewModel: FindingsViewModel
    var onSave: (CaseLog) -> Void
    var saveTitle = "Save case"

    @Environment(\.modelContext) private var modelContext
    @State private var isDictating = false
    @State private var isDictatingViews = false
    @State private var isDictatingLVEF = false
    @State private var isDictatingRV = false
    @State private var isDictatingValves = false
    @State private var isDictatingNotes = false
    @State private var expandedValve: Valve?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                viewsSection
                ventricularSection
                valveSection
                complicationsSection
                autoCategorySection
                notesSection
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                let saved = viewModel.save(context: modelContext)
                onSave(saved)
            } label: {
                Text(saveTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $isDictating) {
            DictationSheet(field: nil) { result in
                viewModel.apply(result)
            }
        }
        .sheet(isPresented: $isDictatingViews) {
            DictationSheet(field: .views) { result in
                viewModel.apply(result, field: .views)
            }
        }
        .sheet(isPresented: $isDictatingLVEF) {
            DictationSheet(field: .lvef) { result in
                viewModel.apply(result, field: .lvef)
            }
        }
        .sheet(isPresented: $isDictatingRV) {
            DictationSheet(field: .rvFunction) { result in
                viewModel.apply(result, field: .rvFunction)
            }
        }
        .sheet(isPresented: $isDictatingValves) {
            DictationSheet(field: .valveLesions) { result in
                viewModel.apply(result, field: .valveLesions)
            }
        }
        .sheet(isPresented: $isDictatingNotes) {
            DictationSheet(field: .notes) { result in
                viewModel.apply(result, field: .notes)
            }
        }
    }

    // MARK: - Section header with field-level mic (§9.3A)

    private func sectionHeader(_ title: String, mic: (title: String, action: () -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            if let mic {
                Button(action: mic.action) {
                    Image(systemName: "mic.fill")
                        .frame(width: 44, height: 44) // ≥ 44 pt (§9.5)
                }
                .accessibilityLabel(mic.title)
            }
        }
    }

    // MARK: - Views obtained

    private var viewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Views obtained", mic: ("Dictate views", { isDictatingViews = true }))

            HStack {
                Text(viewModel.viewCounterText)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("+ Add") {
                    // Custom view note appended to notes.
                    viewModel.notes = viewModel.notes.isEmpty
                        ? viewModel.customViewNotes
                        : viewModel.notes + " " + viewModel.customViewNotes
                }
                .font(.subheadline)
            }

            MultiSelectChipGrid(
                values: TEEView.allCases,
                title: \.displayName,
                selection: $viewModel.viewsObtained
            )
        }
    }

    // MARK: - Ventricular function

    private var ventricularSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Ventricular function", mic: ("Dictate LV EF", { isDictatingLVEF = true }))

            VStack(alignment: .leading, spacing: 6) {
                Text("LV EF")
                    .font(.subheadline.weight(.medium))
                Picker("LV EF", selection: $viewModel.lvefQualitative) {
                    Text("N").tag(String?.none).accessibilityLabel("Normal")
                    Text("Mi").tag(String?.some("mild")).accessibilityLabel("Mildly depressed")
                    Text("Mo").tag(String?.some("moderate")).accessibilityLabel("Moderately depressed")
                    Text("Se").tag(String?.some("severe")).accessibilityLabel("Severely depressed")
                }
                .pickerStyle(.segmented)
                HStack {
                    Text("EF %")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g. 45", text: Binding(
                        get: { viewModel.lvefPercent.map(String.init) ?? "" },
                        set: { viewModel.lvefPercent = Int($0) }
                    ))
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("RV function")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    // Per-field mic (§9.3 mode A): scoped to .rvFunction.
                    Button {
                        isDictatingRV = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .frame(width: 44, height: 44) // ≥ 44 pt (§9.5, §11)
                    }
                    .accessibilityLabel("Dictate RV function")
                }
                Picker("RV function", selection: $viewModel.rvFunction) {
                    Text("N").tag(SeverityGrade?.none).accessibilityLabel("Normal")
                    Text("Mi").tag(SeverityGrade?.some(.mild)).accessibilityLabel("Mild dysfunction")
                    Text("Mo").tag(SeverityGrade?.some(.moderate)).accessibilityLabel("Moderate dysfunction")
                    Text("Se").tag(SeverityGrade?.some(.severe)).accessibilityLabel("Severe dysfunction")
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Valve lesions

    private var valveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Valve lesions", mic: ("Dictate valve findings", { isDictatingValves = true }))

            ForEach(Valve.allCases, id: \.self) { valve in
                valveRow(valve)
            }
        }
    }

    private func valveRow(_ valve: Valve) -> some View {
        let finding = viewModel.finding(for: valve)
        let lesion = finding?.lesion ?? .regurgitation
        let severity = finding?.severity ?? .none

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(valve.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if finding != nil {
                    Text(finding!.summary)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Image(systemName: expandedValve == valve ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation { expandedValve = expandedValve == valve ? nil : valve }
            }

            if expandedValve == valve {
                Picker("Lesion", selection: Binding(
                    get: { lesion },
                    set: { viewModel.setFinding(valve: valve, lesion: $0, severity: severity) }
                )) {
                    ForEach(LesionType.allCases, id: \.self) { l in
                        Text(l.displayName).tag(l)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 2)

                SeverityStepper(
                    label: "\(valve.displayName) \(lesion.displayName.lowercased())",
                    severity: Binding(
                        get: { severity },
                        set: { viewModel.setFinding(valve: valve, lesion: lesion, severity: $0) }
                    )
                )
            }
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(valve.displayName) valve")
    }

    // MARK: - Complications / quality

    private var complicationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Complications")
                .font(.title3.weight(.bold))

            MultiSelectChipGrid(
                values: ComplicationType.allCases,
                title: \.displayName,
                selection: $viewModel.complications
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Exam quality")
                    .font(.subheadline.weight(.medium))
                Picker("Exam quality", selection: $viewModel.examQuality) {
                    ForEach(ExamQuality.allCases, id: \.self) { q in
                        Text(q.displayName).tag(q)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    // MARK: - Auto-categorized (read-only, §7.3)

    private var autoCategorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Auto-categorized")
                .font(.title3.weight(.bold))
            if viewModel.autoCategories.isEmpty {
                Text("No categories yet — this case won't count toward any requirement.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(Array(viewModel.autoCategories).sorted { $0.displayName < $1.displayName }, id: \.self) { category in
                        TagChip(title: category.displayName)
                    }
                }
            }
            Text("How this case counts toward your track — updated live.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Notes")
                    .font(.title3.weight(.bold))
                Spacer()
                Button {
                    isDictatingNotes = true
                } label: {
                    Image(systemName: "mic.fill")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Dictate notes")
            }
            TextField("Free text — dictation lands here", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
        }
    }
}
