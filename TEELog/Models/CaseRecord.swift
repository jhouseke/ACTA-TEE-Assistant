// CaseRecord.swift — pure-Swift value mirror of the SwiftData CaseLog entity.
//
// The SwiftData @Model classes (CaseLog / ValveFinding) cannot compile on
// Linux (SwiftData is Apple-only), so the engine layer operates on these
// value types. The app maps its @Model instances to records in one place
// (`CaseLog.record` / `ValveFinding.record`).
//
// IMPLEMENTATION.md §4.2

import Foundation

/// Pure value mirror of the persisted `ValveFinding` @Model.
public struct ValveFindingRecord: Equatable, Hashable, Sendable {
    public var valve: Valve
    public var lesion: LesionType
    public var severity: SeverityGrade

    public init(valve: Valve, lesion: LesionType, severity: SeverityGrade) {
        self.valve = valve
        self.lesion = lesion
        self.severity = severity
    }

    /// Export/UI summary, e.g. "AV:2+" (§8 CSV format).
    public var summary: String { "\(valve.shortCode):\(severity.exportNotation)" }
}

/// Minimal surface the requirements engine needs. `CaseLog` (app target)
/// conforms via `extension CaseLog: CaseRecordProtocol {}` — it already has
/// the stored `categories: [String]`.
public protocol CaseRecordProtocol: Sendable {
    var categories: [String] { get }
}

/// Pure value mirror of the persisted `CaseLog` @Model (de-identified:
/// age / sex / BSA only — no name, MRN, DOB, or hospital; §10).
public struct CaseRecord: Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var examDate: Date

    // De-identified patient
    public var ageYears: Int?
    public var sex: String?               // "M" / "F" / nil
    public var bsa: Double?               // m²

    // Procedure
    public var procedure: String          // ProcedureType rawValue
    public var cardiopulmonaryBypass: Bool
    public var offPumpOrHybrid: Bool

    // Participation
    public var attendingName: String
    public var participationLevel: String // ParticipationLevel rawValue

    // Indications
    public var indications: [String]      // [IndicationType rawValue]

    // Findings
    public var viewsObtained: [String]    // [TEEView rawValue]
    public var lvefQualitative: String?   // "normal"/"mild"/"moderate"/"severe"
    public var lvefPercent: Int?          // 0–100
    public var rvFunction: String?        // SeverityGrade rawValue (dysfunction)
    public var valveFindings: [ValveFindingRecord]
    public var complications: [String]    // [ComplicationType rawValue]
    public var examQuality: String        // ExamQuality rawValue
    public var notes: String

    // Derived (auto-populated by AutoCategorizer on save)
    public var categories: [String]       // [CaseCategory rawValue]

    // Sign-off
    public var isSignedOff: Bool
    public var pdSignOffDate: Date?

    public init(
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
        valveFindings: [ValveFindingRecord] = [],
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
}

extension CaseRecord: CaseRecordProtocol {}
