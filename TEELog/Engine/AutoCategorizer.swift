// AutoCategorizer.swift — deterministic procedure/indication/findings → categories.
//
// Pure function, no side effects, runs on every save (and on demand after
// edits). Fully unit-tested. Pure Swift (Foundation only) — compiles on
// Linux as part of TEELogCore.
//
// IMPLEMENTATION.md §6

import Foundation

public enum AutoCategorizer {

    public static func categorize(
        procedure: ProcedureType,
        indications: [IndicationType],
        valveFindings: [ValveFindingRecord],
        lvef: String?,
        rv: String?
    ) -> Set<CaseCategory> {
        var out: Set<CaseCategory> = []

        let valvularProcedures: Set<ProcedureType> = [.avr, .mvr, .tvr, .pvr, .mitraclip, .tmvr, .tricuspidClip, .myectomy]
        let structuralProcedures: Set<ProcedureType> = [.tavr, .mitraclip, .tmvr, .tricuspidClip, .laao]
        let mcsProcedures: Set<ProcedureType> = [.lvad, .rvad, .ecmo, .iabp]
        let aorticProcedures: Set<ProcedureType> = [.aorticRoot, .ascendingAorta, .typeADissection]
        let transplantProcedures: Set<ProcedureType> = [.heartTransplant, .lungTransplant]

        if valvularProcedures.contains(procedure) { out.insert(.valvular) }
        if structuralProcedures.contains(procedure) { out.insert(.structural) }
        if mcsProcedures.contains(procedure) { out.insert(.mcs) }
        if aorticProcedures.contains(procedure) { out.insert(.aorticPathology) }
        if transplantProcedures.contains(procedure) { out.insert(.transplant) }

        if indications.contains(.valvular) || !valveFindings.isEmpty { out.insert(.valvular) }
        if indications.contains(.structural) { out.insert(.structural) }
        if indications.contains(.aorticPathology) { out.insert(.aorticPathology) }
        if indications.contains(.hemodynamic) { out.insert(.hemodynamic) }
        if indications.contains(.ventricularFunction) { out.insert(.ventricular) }
        if indications.contains(.cardiacMass) { out.insert(.mass) }
        if indications.contains(.endocarditis) { out.insert(.endocarditis) }
        if indications.contains(.pericardial) { out.insert(.pericardial) }
        if indications.contains(.congenital) { out.insert(.congenital) }
        if indications.contains(.ischemia) { out.insert(.ischemia) }

        // Abnormal ventricular function → ventricular category
        if let e = lvef, ["moderate", "severe"].contains(e) { out.insert(.ventricular) }
        if let r = rv, ["moderate", "severe"].contains(r) { out.insert(.ventricular) }

        return out
    }
}
