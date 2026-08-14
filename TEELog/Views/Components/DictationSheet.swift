// DictationSheet.swift — field-level (mode A) and global (mode B) dictation
// capture (§9.3, §9.5).
//
// Flow: permission check → live transcript while listening → on "Done",
// DictationMapper.resolve → confirmation diff ("Added: … · Missed: —") with
// the ability to cancel → onApply(result).

import SwiftUI
import TEELogCore

struct DictationSheet: View {
    /// nil = global dictation (parses across all fields, mode B);
    /// otherwise field-scoped (mode A).
    let field: DictationField?
    let onApply: (DictationResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var controller = SpeechController()
    @State private var isConfirming = false
    @State private var result: DictationResult?
    @State private var errorMessage: String?
    @State private var permissionCheckDone = false

    private var title: String {
        guard let field else { return "Dictate" }
        switch field {
        case .procedure: "Dictate procedure"
        case .indication: "Dictate indication"
        case .views: "Dictate views"
        case .lvef: "Dictate LV EF"
        case .rvFunction: "Dictate RV function"
        case .valveLesions: "Dictate valve findings"
        case .complications: "Dictate complications"
        case .notes: "Dictate notes"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorMessage {
                    errorView(errorMessage)
                } else if isConfirming, let result {
                    confirmationView(result)
                } else {
                    listeningView
                }
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { controller.stop(); dismiss() }
                }
                if isConfirming {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            if let result { onApply(result) }
                            controller.stop()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .task {
                await startIfPermitted()
            }
            .onDisappear { controller.stop() }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Listening

    private var listeningView: some View {
        VStack(spacing: 20) {
            Text(controller.transcript.isEmpty ? "Listening…" : controller.transcript)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(controller.transcript.isEmpty ? "Listening" : "Transcript: \(controller.transcript)")

            Button {
                if controller.isListening {
                    finishRecognition()
                } else {
                    try? controller.start()
                }
            } label: {
                Image(systemName: controller.isListening ? "stop.circle.fill" : "mic.fill")
                    .font(.system(size: 36))
                    .frame(width: 72, height: 72) // ≥ 44 pt (§9.5)
                    .background(controller.isListening ? Color.red : Color.accentColor, in: Circle())
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(controller.isListening ? "Stop listening" : "Start listening")

            Text(controller.isListening ? "Tap to stop" : "Tap the mic and speak")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Done") { finishRecognition() }
                .buttonStyle(.borderedProminent)
                .disabled(controller.transcript.isEmpty)
        }
    }

    private func finishRecognition() {
        controller.stop()
        let parsed = DictationMapper.resolve(controller.transcript, field: field)
        result = parsed
        withAnimation { isConfirming = true }
    }

    // MARK: - Confirmation diff (§9.3A step 3)

    private func confirmationView(_ result: DictationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Added")
                .font(.headline)
            addedList(result)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            Text("Missed")
                .font(.headline)
            Text(missedText(result))
                .font(.subheadline)
                .foregroundStyle(result.notes.isEmpty ? .secondary : .orange)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }

    @ViewBuilder
    private func addedList(_ result: DictationResult) -> some View {
        let lines = diffLines(result)
        if lines.isEmpty {
            Text("Nothing recognized — try again or enter manually.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines, id: \.self) { line in
                    Label(line, systemImage: "checkmark.circle")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private func diffLines(_ result: DictationResult) -> [String] {
        var lines: [String] = []
        if let p = result.procedure { lines.append("Procedure: \(p.displayName)") }
        if !result.indications.isEmpty {
            lines.append("Indication: \(result.indications.map(\.displayName).sorted().joined(separator: ", "))")
        }
        if !result.views.isEmpty {
            lines.append("Views: \(result.views.map(\.displayName).sorted().joined(separator: ", "))")
        }
        if let q = result.lvefQualitative {
            lines.append("LV EF: \(q)\(result.lvefPercent.map { " (\($0)%)" } ?? "")")
        } else if let pct = result.lvefPercent {
            lines.append("LV EF: \(pct)%")
        }
        if let rv = result.rvFunction { lines.append("RV function: \(rv.plusNotation)") }
        if !result.valveFindings.isEmpty {
            lines.append("Valve findings: \(result.valveFindings.map(\.summary).joined(separator: ", "))")
        }
        if !result.complications.isEmpty {
            lines.append("Complications: \(result.complications.map(\.displayName).sorted().joined(separator: ", "))")
        }
        if !result.notes.isEmpty { lines.append("Notes: \(result.notes)") }
        return lines
    }

    private func missedText(_ result: DictationResult) -> String {
        result.notes.isEmpty ? "—" : result.notes
    }

    // MARK: - Errors (§9.5: explain + fall back to manual entry)

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.mic")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Enter manually") { dismiss() }
                .buttonStyle(.bordered)
        }
        .padding()
    }

    // MARK: - Permissions

    private func startIfPermitted() async {
        guard !permissionCheckDone else { return }
        permissionCheckDone = true
        let ok = await controller.requestPermissionsIfNeeded()
        guard ok else {
            errorMessage = controller.lastError?.errorDescription ?? "Dictation is unavailable."
            return
        }
        do {
            try controller.start()
        } catch {
            errorMessage = controller.lastError?.errorDescription ?? "Dictation is unavailable."
        }
    }
}
