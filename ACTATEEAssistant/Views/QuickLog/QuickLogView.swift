// QuickLogView.swift — 3-step capture flow: Procedure → Indication →
// Findings (NavigationStack + stepper header, §7.2).

import SwiftUI
import SwiftData
import ACTATEEAssistantCore

struct QuickLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaseLog.examDate, order: .reverse) private var cases: [CaseLog]

    @State private var viewModel = QuickLogViewModel()
    @State private var findingsViewModel: FindingsViewModel?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepHeader
                    .padding(.horizontal)
                    .padding(.top, 8)

                Group {
                    switch viewModel.step {
                    case 1:
                        ProcedureStepView(viewModel: viewModel)
                    case 2:
                        IndicationStepView(viewModel: viewModel)
                    default:
                        if let findingsViewModel {
                            FindingsView(
                                viewModel: findingsViewModel,
                                onSave: { _ in dismiss() },
                                saveTitle: "Save case"
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Quick Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                viewModel.update(recentAttendings: Array(Set(cases.map(\.attendingName))).sorted())
            }
            .onChange(of: viewModel.step) { _, newStep in
                if newStep == 3 {
                    findingsViewModel = FindingsViewModel(draft: viewModel.draft)
                }
            }
        }
        .interactiveDismissDisabled() // prevent accidental loss of a half-logged case
    }

    // MARK: - Stepper header (1 · 2 · 3)

    private var stepHeader: some View {
        HStack(spacing: 12) {
            stepDot(index: 1, title: "Procedure")
            stepLine
            stepDot(index: 2, title: "Indication")
            stepLine
            stepDot(index: 3, title: "Findings")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(viewModel.step) of 3")
    }

    private func stepDot(index: Int, title: String) -> some View {
        let isCurrent = viewModel.step == index
        let isDone = viewModel.step > index
        return VStack(spacing: 4) {
            Text("\(index)")
                .font(.footnote.weight(.bold).monospacedDigit())
                .frame(width: 26, height: 26)
                .background(
                    isCurrent || isDone ? Color.accentColor : Color(uiColor: .systemFill),
                    in: Circle()
                )
                .foregroundStyle(isCurrent || isDone ? Color.white : Color.secondary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
        }
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private var stepLine: some View {
        Rectangle()
            .fill(Color(uiColor: .systemFill))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Step 1: Procedure (§7.2)

struct ProcedureStepView: View {
    @Bindable var viewModel: QuickLogViewModel
    @State private var isDictating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                sectionHeader("Procedure", micField: .procedure)

                SingleSelectChipGrid(
                    values: ProcedureType.allCases,
                    title: \.displayName,
                    selection: $viewModel.procedure
                )

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Supervising physician")
                        .font(.subheadline.weight(.semibold))
                    Picker("Supervising physician", selection: $viewModel.attendingName) {
                        Text("—").tag("")
                        ForEach(viewModel.recentAttendings, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    TextField("Or type a name", text: $viewModel.attendingName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Exam date")
                        .font(.subheadline.weight(.semibold))
                    DatePicker("Exam date", selection: $viewModel.examDate, displayedComponents: .date)
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Participation")
                        .font(.subheadline.weight(.semibold))
                    Picker("Participation", selection: $viewModel.participationLevel) {
                        ForEach(ParticipationLevel.allCases, id: \.self) { level in
                            Text(level.displayName).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Cardiopulmonary bypass", isOn: $viewModel.cardiopulmonaryBypass)
                Toggle("Off-pump / hybrid", isOn: $viewModel.offPumpOrHybrid)
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation { viewModel.step = 2 }
            } label: {
                Text("Next — Indication")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.canProceedFromStep1)
            .padding()
            .background(.bar)
        }
    }

    private func sectionHeader(_ title: String, micField: DictationField) -> some View {
        HStack {
            Text(title)
                .font(.title3.weight(.bold))
            Spacer()
            micButton(for: micField)
        }
    }

    private func micButton(for field: DictationField) -> some View {
        Button {
            isDictating = true
        } label: {
            Image(systemName: "mic.fill")
                .frame(width: 44, height: 44) // ≥ 44 pt (§9.5)
        }
        .accessibilityLabel("Dictate procedure")
        .sheet(isPresented: $isDictating) {
            DictationSheet(field: .procedure) { result in
                viewModel.apply(result, field: .procedure)
            }
        }
    }
}

// MARK: - Step 2: Indication (§7.2)

struct IndicationStepView: View {
    @Bindable var viewModel: QuickLogViewModel
    @State private var isDictating = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Indications")
                        .font(.title3.weight(.bold))
                    Spacer()
                    Button {
                        isDictating = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Dictate indications")
                }

                Text("Select all that apply — dictation also works.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                MultiSelectChipGrid(
                    values: IndicationType.allCases,
                    title: \.displayName,
                    selection: $viewModel.indications
                )
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation { viewModel.step = 3 }
            } label: {
                Text("Next — Findings")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding()
            .background(.bar)
        }
        .sheet(isPresented: $isDictating) {
            DictationSheet(field: .indication) { result in
                viewModel.apply(result, field: .indication)
            }
        }
    }
}
