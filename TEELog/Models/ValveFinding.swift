// ValveFinding.swift — SwiftData child entity (§4.2).
//
// APP TARGET ONLY (SwiftData is Apple-only). The pure engine works against
// `ValveFindingRecord` (TEELogCore); `record` maps this entity to it.

import Foundation
import SwiftData
import TEELogCore

@Model
final class ValveFinding {
    var valve: String        // Valve rawValue
    var lesion: String       // LesionType rawValue
    var severity: String     // SeverityGrade rawValue
    var caseLog: CaseLog?    // inverse relationship

    init(valve: String, lesion: String, severity: String) {
        self.valve = valve
        self.lesion = lesion
        self.severity = severity
    }

    // MARK: - Typed accessors

    var valveType: Valve? { Valve(rawValue: valve) }
    var lesionType: LesionType? { LesionType(rawValue: lesion) }
    var severityGrade: SeverityGrade? { SeverityGrade(rawValue: severity) }

    /// "AV:2+" style summary used in exports (§8).
    var summary: String {
        "\(valveType?.shortCode ?? valve):\(severityGrade?.exportNotation ?? severity)"
    }

    /// Mapping to the pure engine record (TEELogCore).
    var record: ValveFindingRecord {
        ValveFindingRecord(
            valve: valveType ?? .aortic,
            lesion: lesionType ?? .regurgitation,
            severity: severityGrade ?? .none
        )
    }
}
