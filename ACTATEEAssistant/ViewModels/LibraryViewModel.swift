// LibraryViewModel.swift — case list state (§7.6).

import Foundation
import Observation
import ACTATEEAssistantCore

enum LibraryFilter: Equatable, Hashable {
    case all
    case procedure(ProcedureType)
    case category(CaseCategory)

    var title: String {
        switch self {
        case .all: "All"
        case .procedure(let p): p.displayName
        case .category(let c): c.displayName
        }
    }
}

@Observable
final class LibraryViewModel {
    var cases: [CaseLog] = []
    var searchText = ""
    var filter: LibraryFilter = .all

    /// Static chips (§7.6) plus any category present in the data beyond them.
    static let staticFilters: [LibraryFilter] = [
        .all, .procedure(.cabg), .category(.valvular),
        .category(.aorticPathology), .category(.structural), .category(.transplant)
    ]

    var dynamicFilters: [LibraryFilter] {
        let present = Set(cases.flatMap(\.categoryTypes))
        let staticCats: Set<CaseCategory> = [.valvular, .aorticPathology, .structural, .transplant]
        let extras = present.subtracting(staticCats).sorted { $0.displayName < $1.displayName }
        return extras.map(LibraryFilter.category)
    }

    var filteredCases: [CaseLog] {
        var out = cases
        switch filter {
        case .all: break
        case .procedure(let p): out = out.filter { $0.procedureType == p }
        case .category(let c): out = out.filter { $0.categoryTypes.contains(c) }
        }
        guard !searchText.isEmpty else { return out }
        let q = searchText.lowercased()
        return out.filter { c in
            c.procedureType?.displayName.lowercased().contains(q) == true
                || c.attendingName.lowercased().contains(q)
                || c.notes.lowercased().contains(q)
                || c.viewTypes.contains { $0.displayName.lowercased().contains(q) }
                || c.valveFindings.contains { $0.summary.lowercased().contains(q) }
        }
    }

    var footerText: String {
        guard let first = cases.map(\.examDate).min(),
              let last = cases.map(\.examDate).max() else { return "0 cases" }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return "\(cases.count) cases · \(f.string(from: first)) – \(f.string(from: last))"
    }
}
