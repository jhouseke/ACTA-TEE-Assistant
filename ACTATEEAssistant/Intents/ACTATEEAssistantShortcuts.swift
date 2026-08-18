// ACTATEEAssistantShortcuts.swift — App Intents for hands-free capture (F1).
//
// Three intents + one AppShortcuts provider:
//   - LogTEECaseIntent:  procedure + attending + date → draft CaseLog,
//                        AutoCategorizer, spoken result with running total
//   - ShowProgressIntent: totals per track incl. the largest gap
//   - QuickFindingsIntent: transcript → DictationMapper against the most
//                        recent draft case → fills findings → saves
//
// APP TARGET ONLY (AppIntents is Apple-only). All reads/writes go through
// the shared ModelContainerFactory container (same store the app and the
// widget extension use) — no network, no cloud (FEATURES.md F1).
//
// FEATURES.md F1 acceptance: phrases work via Siri ("Log a TEE case…"),
// the three intents appear in the Shortcuts app, and a saved case shows up
// in Library + Progress immediately (same store, same query).

import AppIntents
import SwiftData
import WidgetKit
import ACTATEEAssistantCore

// MARK: - App-local intent parameter enums

/// App Intents metadata extraction requires the enum declaration to live in
/// the app module. These wrappers keep the persisted/core enums framework-free.
enum IntentProcedureType: String, AppEnum {
    case cabg, avr, mvr, tvr, pvr, aorticRoot, ascendingAorta, typeADissection
    case heartTransplant, lungTransplant
    case lvad, rvad, ecmo, iabp
    case tavr, tmvr, mitraclip, tricuspidClip, laao
    case myectomy, maze, other

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Procedure")
    static var caseDisplayRepresentations: [IntentProcedureType: DisplayRepresentation] = [
        .cabg: "CABG",
        .avr: "AVR",
        .mvr: "MVR",
        .tvr: "TVR",
        .pvr: "PVR",
        .aorticRoot: "Aortic root",
        .ascendingAorta: "Ascending aorta",
        .typeADissection: "Type A dissection",
        .heartTransplant: "Heart transplant",
        .lungTransplant: "Lung transplant",
        .lvad: "LVAD",
        .rvad: "RVAD",
        .ecmo: "ECMO",
        .iabp: "IABP",
        .tavr: "TAVR",
        .tmvr: "TMVR",
        .mitraclip: "MitraClip",
        .tricuspidClip: "Tricuspid clip",
        .laao: "LAAO",
        .myectomy: "Myectomy",
        .maze: "Maze",
        .other: "Other"
    ]

    var coreValue: ProcedureType {
        ProcedureType(rawValue: rawValue) ?? .other
    }
}

enum IntentTrackID: String, AppEnum {
    case nbeAdvanced, nbeBasic, acgme

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Track")
    static var caseDisplayRepresentations: [IntentTrackID: DisplayRepresentation] = [
        .nbeAdvanced: "NBE Advanced PTEeXAM",
        .nbeBasic: "NBE Basic PTE",
        .acgme: "ACGME"
    ]

    var coreValue: TrackID {
        TrackID(rawValue: rawValue) ?? .nbeAdvanced
    }
}

// MARK: - Shared helpers

/// AppIntents run off the main actor; the container's mainContext is
/// MainActor-isolated, so all perform() methods hop to MainActor.
@MainActor
private func fetchAllCases() -> [CaseLog] {
    let context = ModelContainerFactory.shared.mainContext
    let descriptor = FetchDescriptor<CaseLog>(sortBy: [SortDescriptor(\CaseLog.examDate, order: .reverse)])
    return (try? context.fetch(descriptor)) ?? []
}

/// A "draft" case: saved but with no findings captured yet.
private extension CaseLog {
    var isDraft: Bool {
        viewsObtained.isEmpty
            && valveFindings.isEmpty
            && notes.isEmpty
            && lvefQualitative == nil
            && lvefPercent == nil
            && rvFunction == nil
    }
}

// MARK: - LogTEECaseIntent

struct LogTEECaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log TEE case"
    static var description = IntentDescription(
        "Creates a draft case entry for a procedure you performed TEE on, then reports your running total."
    )
    static var parameterSummary: some ParameterSummary {
        Summary("Log a \(\.$procedure) TEE case") {
            \.$attending
            \.$examDate
        }
    }

    @Parameter(title: "Procedure") var procedure: IntentProcedureType
    @Parameter(title: "Attending") var attending: String?
    @Parameter(title: "Exam date") var examDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let context = ModelContainerFactory.shared.mainContext
        let procedureType = procedure.coreValue

        let caseLog = CaseLog(
            examDate: examDate ?? .now,
            procedure: procedureType.rawValue,
            attendingName: attending ?? ""
        )
        caseLog.categories = AutoCategorizer.categorize(
            procedure: procedureType,
            indications: [],
            valveFindings: [],
            lvef: nil,
            rv: nil
        ).map(\.rawValue)
        context.insert(caseLog)
        try context.save()

        QuizCardEnqueuer.enqueue(for: caseLog, context: context)
        WidgetCenter.shared.reloadAllTimelines()

        let total = fetchAllCases().count
        return .result(
            dialog: "Logged \(procedureType.displayName) case — \(total) of \(Track.nbeAdvanced.totalMinimum)"
        )
    }
}

// MARK: - ShowProgressIntent

struct ShowProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Show progress"
    static var description = IntentDescription(
        "Reports your current case totals against the selected requirement track."
    )

    @Parameter(title: "Track") var track: IntentTrackID?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let trackID = track?.coreValue ?? .nbeAdvanced
        let track = Track.track(id: trackID)
        let progress = RequirementsEngine.progress(cases: fetchAllCases(), track: track)

        var text = "You are at \(progress.total) of \(track.totalMinimum) for \(track.name)"
        if let gap = RequirementsEngine.largestGap(progress.categories) {
            text += ", \(gap.gap) \(gap.category.displayName.lowercased()) to go"
        }
        return .result(dialog: "\(text)")
    }
}

// MARK: - QuickFindingsIntent

struct QuickFindingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Add findings"
    static var description = IntentDescription(
        "Dictates findings into your most recent draft case and saves it."
    )

    @Parameter(title: "Transcript") var transcript: String

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let parsed = DictationMapper.resolve(transcript)
        let context = ModelContainerFactory.shared.mainContext
        let cases = fetchAllCases()

        guard let target = cases.first(where: \.isDraft) ?? cases.first else {
            return .result(dialog: "No case to attach findings to — log a case first.")
        }

        // Same merge semantics as FindingsViewModel.apply(_:field: nil).
        target.viewsObtained = Array(Set(target.viewTypes).union(parsed.views)).map(\.rawValue)
        if let q = parsed.lvefQualitative { target.lvefQualitative = q }
        if let pct = parsed.lvefPercent { target.lvefPercent = pct }
        if let rv = parsed.rvFunction { target.rvFunction = rv.rawValue }
        for finding in parsed.valveFindings {
            target.valveFindings.removeAll {
                $0.valve == finding.valve.rawValue && $0.lesion == finding.lesion.rawValue
            }
            target.valveFindings.append(
                ValveFinding(valve: finding.valve.rawValue, lesion: finding.lesion.rawValue, severity: finding.severity.rawValue)
            )
        }
        if !parsed.complications.isEmpty {
            target.complications = Array(Set(target.complicationTypes).union(parsed.complications)).map(\.rawValue)
        }
        if !parsed.notes.isEmpty {
            target.notes = target.notes.isEmpty ? parsed.notes : target.notes + " " + parsed.notes
        }

        // Re-run categorization so the updated findings count correctly.
        target.categories = AutoCategorizer.categorize(
            procedure: target.procedureType ?? .other,
            indications: target.indicationTypes,
            valveFindings: target.valveFindings.map(\.record),
            lvef: target.lvefQualitative,
            rv: target.rvFunction
        ).map(\.rawValue)

        try context.save()
        WidgetCenter.shared.reloadAllTimelines()

        let name = target.procedureType?.displayName ?? "case"
        return .result(dialog: "Findings added to \(name) case.")
    }
}

// MARK: - AppShortcuts provider

struct ACTATEEAssistantShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogTEECaseIntent(),
            phrases: [
                "Log a \(\.$procedure) TEE case in \(.applicationName)",
                "Log a TEE case in \(.applicationName)"
            ],
            shortTitle: "Log TEE case",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: ShowProgressIntent(),
            phrases: [
                "How many TEE cases in \(.applicationName)",
                "Show my \(.applicationName) progress"
            ],
            shortTitle: "Show progress",
            systemImageName: "chart.bar.fill"
        )
        AppShortcut(
            intent: QuickFindingsIntent(),
            phrases: [
                "Add TEE findings in \(.applicationName)"
            ],
            shortTitle: "Add findings",
            systemImageName: "waveform"
        )
    }
}
