// DictationSheet.swift — field-level (mode A) and global (mode B) dictation
// capture (§9.3, §9.5).
//
// Flow: permission check → live transcript while listening (with chip fill —
// recognized values stream in as the transcript grows) → on "Done",
// DictationMapper.resolve → confirmation diff ("Added: … · Missed: —") with
// the ability to cancel → onApply(result).

import SwiftUI
import ACTATEEAssistantCore

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

    /// Live parse of the streaming transcript — drives the chip fill while
    /// listening (§9.5: "the parsed field chips fill in real time").
    @State private var liveResult: DictationResult?

    private var title: String {
        guard let field else { return "Dictate" }
        switch field {
        case .procedure: return "Dictate procedure"
        case .indication: return "Dictate indication"
        case .views: return "Dictate views"
        case .lvef: return "Dictate LV EF"
        case .rvFunction: return "Dictate RV function"
        case .valveLesions: return "Dictate valve findings"
        case .complications: return "Dictate complications"
        case .notes: return "Dictate notes"
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
            .onChange(of: controller.transcript) { _, newTranscript in
                // Re-parse as the transcript streams so chips fill live (§9.5).
                liveResult = DictationMapper.resolve(newTranscript, field: field)
            }
            .onDisappear { controller.stop() }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Listening

    private var listeningView: some View {
        VStack(spacing: 16) {
            Text(controller.transcript.isEmpty ? "Listening…" : controller.transcript)
                .font(.title3)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel(controller.transcript.isEmpty ? "Listening" : "Transcript: \(controller.transcript)")

            if let live = liveResult {
                liveChips(live)
            }

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

    /// Chip fill while listening (§9.5): recognized values stream in as the
    /// transcript grows, scoped to the active field (or all fields, global).
    @ViewBuilder
    private func liveChips(_ live: DictationResult) -> some View {
        let values = liveValues(live)
        if !values.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recognized")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                FlowLayout(spacing: 6) {
                    ForEach(values, id: \.self) { value in
                        TagChip(title: value)
                    }
                }
                .accessibilityLabel("Recognized so far: \(values.joined(separator: ", "))")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Human-readable values from a (live or final) parse, e.g.
    /// ["ME 4C", "TG mid SAX"] for a views dictation.
    private func liveValues(_ result: DictationResult) -> [String] {
        var out: [String] = []
        if let p = result.procedure { out.append(p.displayName) }
        out.append(contentsOf: result.indications.map(\.displayName).sorted())
        out.append(contentsOf: result.views.map(\.displayName).sorted())
        if let q = result.lvefQualitative {
            out.append("EF \(q)\(result.lvefPercent.map { " \($0)%" } ?? "")")
        } else if let pct = result.lvefPercent {
            out.append("EF \(pct)%")
        }
        if let rv = result.rvFunction { out.append("RV \(rv.plusNotation)") }
        out.append(contentsOf: result.valveFindings.map(\.summary))
        out.append(contentsOf: result.complications.map(\.displayName).sorted())
        return out
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
            Text(summaryLine(result))
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("Added: \(addedSummary(result)). Missed: \(missedText(result))")

            Text("Added")
                .font(.headline)
            addedList(result)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()
            Text("Missed")
                .font(.headline)
            Text(missedText(result))
                .font(.subheadline)
                .foregroundStyle(result.notes.isEmpty ? Color.secondary : Color.orange)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }
    }

    /// One-line diff, e.g. "Added: ME 4C, TG mid SAX · Missed: —".
    /// Single touched field → its values; several → field names.
    private func summaryLine(_ result: DictationResult) -> String {
        "Added: \(addedSummary(result)) · Missed: \(missedText(result))"
    }

    private func addedSummary(_ result: DictationResult) -> String {
        let lines = diffLines(result)
        guard !lines.isEmpty else { return "—" }
        if lines.count == 1 {
            let value = lines[0].split(separator: ":", maxSplits: 1).last.map(String.init) ?? lines[0]
            return value.trimmingCharacters(in: .whitespaces)
        }
        return lines
            .map { String($0.split(separator: ":", maxSplits: 1).first ?? Substring($0)) }
            .joined(separator: ", ")
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
