// QuickLogViewModel.swift — drives the 3-step capture flow (§7.2).

import Foundation
import Observation
import ACTATEEAssistantCore

/// Step 1–2 selections carried into the Findings step and onto the saved
/// CaseLog. FindingsViewModel owns step-3 state.
struct CaseDraft: Equatable {
    var procedure: ProcedureType?
    var attendingName: String
    var examDate: Date
    var indications: Set<IndicationType>
    var participationLevel: ParticipationLevel
    var cardiopulmonaryBypass: Bool
    var offPumpOrHybrid: Bool

    static let empty = CaseDraft(
        procedure: nil,
        attendingName: "",
        examDate: Date(),
        indications: [],
        participationLevel: .performed,
        cardiopulmonaryBypass: false,
        offPumpOrHybrid: false
    )
}

@Observable
final class QuickLogViewModel {
    // Flow
    var step = 1

    // Step 1 — Procedure
    var procedure: ProcedureType?
    var attendingName = ""
    var examDate = Date()

    // Step 2 — Indication
    var indications: Set<IndicationType> = []

    // Participation (step 1 extras)
    var participationLevel: ParticipationLevel = .performed
    var cardiopulmonaryBypass = false
    var offPumpOrHybrid = false

    /// Attendings from previous cases, for the picker (§7.2 step 1).
    var recentAttendings: [String] = []

    var canProceedFromStep1: Bool { procedure != nil }

    /// Step 3 reuses FindingsView via a FindingsViewModel built from this.
    var draft: CaseDraft {
        CaseDraft(
            procedure: procedure,
            attendingName: attendingName,
            examDate: examDate,
            indications: indications,
            participationLevel: participationLevel,
            cardiopulmonaryBypass: cardiopulmonaryBypass,
            offPumpOrHybrid: offPumpOrHybrid
        )
    }

    func update(recentAttendings: [String]) {
        self.recentAttendings = recentAttendings
    }

    /// Apply a field-scoped dictation result to steps 1–2 (mode A).
    func apply(_ result: DictationResult, field: DictationField) {
        switch field {
        case .procedure:
            if let p = result.procedure { procedure = p }
        case .indication:
            indications.formUnion(result.indications)
        default:
            break // steps 1–2 only own procedure + indication
        }
    }

    func reset() {
        step = 1
        procedure = nil
        attendingName = ""
        examDate = Date()
        indications = []
        participationLevel = .performed
        cardiopulmonaryBypass = false
        offPumpOrHybrid = false
    }
}
