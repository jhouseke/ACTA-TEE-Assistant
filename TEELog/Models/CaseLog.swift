// CaseLog.swift — SwiftData root entity (§4.2).
//
// De-identified by design: age / sex / BSA only. NO name, MRN, DOB, or
// hospital fields exist on the model — enforced at the model level, not by
// convention (§10).
//
// APP TARGET ONLY (SwiftData is Apple-only). The pure-Swift engine works
// against `CaseRecord` (TEELogCore) — `record` maps this entity to it.

import Foundation
import SwiftData
import TEELogCore

@Model
final class CaseLog {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var examDate: Date

    // De-identified patient (age/sex/BSA only — NEVER name/MRN/DOB)
    var ageYears: Int?
    var sex: String?               // "M" / "F" / nil
    var bsa: Double?               // m²

    // Procedure
    var procedure: String          // ProcedureType rawValue
    var cardiopulmonaryBypass: Bool
    var offPumpOrHybrid: Bool

    // Participation
    var attendingName: String
    var participationLevel: String // ParticipationLevel rawValue

    // Indications
    var indications: [String]      // [IndicationType rawValue]

    // Findings
    var viewsObtained: [String]    // [TEEView rawValue]
    var lvefQualitative: String?   // "normal"/"mild"/"moderate"/"severe"
    var lvefPercent: Int?          // 0–100
    var rvFunction: String?        // SeverityGrade rawValue (dysfunction)
    @Relationship(deleteRule: .cascade, inverse: \ValveFinding.caseLog)
    var valveFindings: [ValveFinding]
    var complications: [String]    // [ComplicationType rawValue]
    var examQuality: String        // ExamQuality rawValue
    var notes: String              // free-text dictation target

    // Derived (auto-populated by AutoCategorizer on save)
    var categories: [String]       // [CaseCategory rawValue]

    // Sign-off
    var isSignedOff: Bool
    var pdSignOffDate: Date?

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        examDate: Date = Date(),
        ageYears: Int? = nil,
        sex: String? = nil,
        bsa: Double? = nil,
        procedure: String = ProcedureType.other.rawValue,
        cardiopulmonaryBypass: Bool = false,
        offPumpOrHybrid: Bool = false,
        attendingName: String = "",
        participationLevel: String = ParticipationLevel.performed.rawValue,
        indications: [String] = [],
        viewsObtained: [String] = [],
        lvefQualitative: String? = nil,
        lvefPercent: Int? = nil,
        rvFunction: String? = nil,
        valveFindings: [ValveFinding] = [],
        complications: [String] = [],
        examQuality: String = ExamQuality.adequate.rawValue,
        notes: String = "",
        categories: [String] = [],
        isSignedOff: Bool = false,
        pdSignOffDate: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.examDate = examDate
        self.ageYears = ageYears
        self.sex = sex
        self.bsa = bsa
        self.procedure = procedure
        self.cardiopulmonaryBypass = cardiopulmonaryBypass
        self.offPumpOrHybrid = offPumpOrHybrid
        self.attendingName = attendingName
        self.participationLevel = participationLevel
        self.indications = indications
        self.viewsObtained = viewsObtained
        self.lvefQualitative = lvefQualitative
        self.lvefPercent = lvefPercent
        self.rvFunction = rvFunction
        self.valveFindings = valveFindings
        self.complications = complications
        self.examQuality = examQuality
        self.notes = notes
        self.categories = categories
        self.isSignedOff = isSignedOff
        self.pdSignOffDate = pdSignOffDate
    }

    // MARK: - Typed accessors

    var procedureType: ProcedureType? { ProcedureType(rawValue: procedure) }
    var participation: ParticipationLevel? { ParticipationLevel(rawValue: participationLevel) }
    var quality: ExamQuality? { ExamQuality(rawValue: examQuality) }
    var indicationTypes: [IndicationType] { indications.compactMap(IndicationType.init(rawValue:)) }
    var viewTypes: [TEEView] { viewsObtained.compactMap(TEEView.init(rawValue:)) }
    var categoryTypes: [CaseCategory] { categories.compactMap(CaseCategory.init(rawValue:)) }
    var rvGrade: SeverityGrade? { rvFunction.flatMap(SeverityGrade.init(rawValue:)) }
    var complicationTypes: [ComplicationType] { complications.compactMap(ComplicationType.init(rawValue:)) }

    /// Mapping to the pure engine record (TEELogCore).
    var record: CaseRecord {
        CaseRecord(
            id: id,
            createdAt: createdAt,
            examDate: examDate,
            ageYears: ageYears,
            sex: sex,
            bsa: bsa,
            procedure: procedure,
            cardiopulmonaryBypass: cardiopulmonaryBypass,
            offPumpOrHybrid: offPumpOrHybrid,
            attendingName: attendingName,
            participationLevel: participationLevel,
            indications: indications,
            viewsObtained: viewsObtained,
            lvefQualitative: lvefQualitative,
            lvefPercent: lvefPercent,
            rvFunction: rvFunction,
            valveFindings: valveFindings.map(\.record),
            complications: complications,
            examQuality: examQuality,
            notes: notes,
            categories: categories,
            isSignedOff: isSignedOff,
            pdSignOffDate: pdSignOffDate
        )
    }
}

// The engine only needs `categories` — CaseLog already stores it, so
// conformance is free and RequirementsEngine can take [CaseLog] directly.
extension CaseLog: CaseRecordProtocol {}
