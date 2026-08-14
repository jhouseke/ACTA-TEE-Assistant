// FindingsViewModel.swift — the Findings editor (Quick Log step 3, standalone
// view, and Library edit sheet) (§7.3).

import Foundation
import Observation
import SwiftData
import TEELogCore

@Observable
final class FindingsViewModel {
    // Views
    var viewsObtained: Set<TEEView> = []

    // Ventricular function
    var lvefQualitative: String?    // "normal"/"mild"/"moderate"/"severe"
    var lvefPercent: Int?
    var rvFunction: SeverityGrade?

    // Valve lesions
    var valveFindings: [ValveFindingRecord] = []

    // Complications / quality / notes
    var complications: Set<ComplicationType> = []
    var examQuality: ExamQuality = .adequate
    var notes = ""
    var customViewNotes = ""

    // Context
    private let draft: CaseDraft?
    private let existingCase: CaseLog?

    var isEditingExisting: Bool { existingCase != nil }

    init(caseLog: CaseLog? = nil, draft: CaseDraft? = nil) {
        self.existingCase = caseLog
        self.draft = draft
        if let caseLog {
            viewsObtained = Set(caseLog.viewTypes)
            lvefQualitative = caseLog.lvefQualitative
            lvefPercent = caseLog.lvefPercent
            rvFunction = caseLog.rvGrade
            valveFindings = caseLog.valveFindings.map(\.record)
            complications = Set(caseLog.complicationTypes)
            examQuality = caseLog.quality ?? .adequate
            notes = caseLog.notes
        }
    }

    var viewCounterText: String { "\(viewsObtained.count) / \(TEEView.allCases.count)" }

    /// Live auto-category preview (read-only chips on the Findings screen,
    /// §7.3): shows how the case will count before saving.
    var autoCategories: Set<CaseCategory> {
        AutoCategorizer.categorize(
            procedure: procedureType ?? .other,
            indications: Array(indicationTypes),
            valveFindings: valveFindings,
            lvef: lvefQualitative,
            rv: rvFunction?.rawValue
        )
    }

    private var procedureType: ProcedureType? { draft?.procedure ?? existingCase?.procedureType }
    private var indicationTypes: [IndicationType] {
        if let draft { return Array(draft.indications) }
        return existingCase?.indicationTypes ?? []
    }

    // MARK: - Valve finding editing

    func finding(for valve: Valve) -> ValveFindingRecord? {
        valveFindings.first { $0.valve == valve }
    }

    /// UI rule (§7.3): adds a ValveFinding on any non-zero selection; a
    /// `.none` severity removes it.
    func setFinding(valve: Valve, lesion: LesionType, severity: SeverityGrade) {
        valveFindings.removeAll { $0.valve == valve }
        guard severity != .none else { return }
        valveFindings.append(ValveFindingRecord(valve: valve, lesion: lesion, severity: severity))
    }

    // MARK: - Dictation (mode A field-level, mode B global)

    /// Applies a parsed DictationResult. `field == nil` applies everything
    /// (global dictation); otherwise only that field's updates (§9.3).
    func apply(_ result: DictationResult, field: DictationField? = nil) {
        func applyAll() {
            if let q = result.lvefQualitative { lvefQualitative = q }
            if let pct = result.lvefPercent { lvefPercent = pct }
            if let rv = result.rvFunction { rvFunction = rv }
            for f in result.valveFindings { upsert(f) }
            if !result.complications.isEmpty { complications.formUnion(result.complications) }
            if !result.notes.isEmpty { notes = notes.isEmpty ? result.notes : notes + " " + result.notes }
        }
        guard let field else {
            applyAll()
            viewsObtained.formUnion(result.views)
            return
        }
        switch field {
        case .views: viewsObtained.formUnion(result.views)
        case .lvef: applyAll()
        case .rvFunction: if let rv = result.rvFunction { rvFunction = rv }
        case .valveLesions: for f in result.valveFindings { upsert(f) }
        case .complications: if !result.complications.isEmpty { complications.formUnion(result.complications) }
        case .notes: if !result.notes.isEmpty { notes = notes.isEmpty ? result.notes : notes + " " + result.notes }
        case .procedure, .indication: break // not owned by Findings
        }
    }

    private func upsert(_ finding: ValveFindingRecord) {
        valveFindings.removeAll {
            $0.valve == finding.valve && $0.lesion == finding.lesion
        }
        valveFindings.append(finding)
    }

    // MARK: - Save

    /// Creates (new case) or updates (edit) the CaseLog, runs
    /// AutoCategorizer, and persists. Returns the saved case.
    @discardableResult
    func save(context: ModelContext) -> CaseLog {
        let categories = Array(autoCategories).map(\.rawValue)

        if let existingCase {
            existingCase.procedure = draft?.procedure?.rawValue ?? existingCase.procedure
            existingCase.attendingName = draft?.attendingName ?? existingCase.attendingName
            existingCase.examDate = draft?.examDate ?? existingCase.examDate
            if let draft {
                existingCase.indications = Array(draft.indications).map(\.rawValue)
                existingCase.participationLevel = draft.participationLevel.rawValue
                existingCase.cardiopulmonaryBypass = draft.cardiopulmonaryBypass
                existingCase.offPumpOrHybrid = draft.offPumpOrHybrid
            }
            existingCase.viewsObtained = viewsObtained.map(\.rawValue)
            existingCase.lvefQualitative = lvefQualitative
            existingCase.lvefPercent = lvefPercent
            existingCase.rvFunction = rvFunction?.rawValue
            existingCase.valveFindings = valveFindings.map {
                ValveFinding(valve: $0.valve.rawValue, lesion: $0.lesion.rawValue, severity: $0.severity.rawValue)
            }
            existingCase.complications = complications.map(\.rawValue)
            existingCase.examQuality = examQuality.rawValue
            existingCase.notes = notes
            existingCase.categories = categories
            try? context.save()
            QuizCardEnqueuer.enqueue(for: existingCase, context: context) // F3
            return existingCase
        }

        let caseLog = CaseLog(
            examDate: draft?.examDate ?? Date(),
            procedure: draft?.procedure?.rawValue ?? ProcedureType.other.rawValue,
            cardiopulmonaryBypass: draft?.cardiopulmonaryBypass ?? false,
            offPumpOrHybrid: draft?.offPumpOrHybrid ?? false,
            attendingName: draft?.attendingName ?? "",
            participationLevel: draft?.participationLevel.rawValue ?? ParticipationLevel.performed.rawValue,
            indications: (draft?.indications ?? []).map(\.rawValue),
            viewsObtained: viewsObtained.map(\.rawValue),
            lvefQualitative: lvefQualitative,
            lvefPercent: lvefPercent,
            rvFunction: rvFunction?.rawValue,
            valveFindings: valveFindings.map {
                ValveFinding(valve: $0.valve.rawValue, lesion: $0.lesion.rawValue, severity: $0.severity.rawValue)
            },
            complications: complications.map(\.rawValue),
            examQuality: examQuality.rawValue,
            notes: notes,
            categories: categories
        )
        context.insert(caseLog)
        try? context.save()
        QuizCardEnqueuer.enqueue(for: caseLog, context: context) // F3: auto-generate quiz cards
        return caseLog
    }
}
