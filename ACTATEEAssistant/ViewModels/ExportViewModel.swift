// ExportViewModel.swift — report type, academic-year range, preview, build (§7.5, §8).

import Foundation
import Observation
import ACTATEEAssistantCore

enum ReportType: String, CaseIterable, Identifiable {
    case acgme
    case nbeAdvanced
    case csv
    case pdf

    var id: String { rawValue }

    var title: String {
        switch self {
        case .acgme: "ACGME Case Log"
        case .nbeAdvanced: "NBE Advanced PTEeXAM"
        case .csv: "CSV (full data)"
        case .pdf: "PDF (program summary)"
        }
    }

    var symbol: String {
        switch self {
        case .acgme: "list.bullet.clipboard"
        case .nbeAdvanced: "graduationcap"
        case .csv: "tablecells"
        case .pdf: "doc.richtext"
        }
    }
}

/// Range picker options (§7.5): academic years present in the data,
/// "All dates", or a custom From/To pair.
enum RangeSelection: Hashable {
    case all
    case academicYear(Int) // start year, e.g. 2025 → Jul 1 2025 – Jun 30 2026
    case custom
}

@Observable
final class ExportViewModel {
    var reportType: ReportType = .acgme
    var selection: RangeSelection = .academicYear(ExportViewModel.currentAcademicStartYear())
    var rangeStart: Date
    var rangeEnd: Date
    var cases: [CaseLog] = []

    var previewText = ""
    var exportedFileURL: URL?
    var lastError: String?
    var isPreparing = false

    /// Academic year defaults: Jul 1 – Jun 30 of the current year (§7.5).
    init(now: Date = Date()) {
        let startYear = Self.academicStartYear(for: now)
        let calendar = Calendar(identifier: .gregorian)
        rangeStart = calendar.date(from: DateComponents(year: startYear, month: 7, day: 1)) ?? now
        rangeEnd = calendar.date(from: DateComponents(year: startYear + 1, month: 6, day: 30, hour: 23, minute: 59, second: 59)) ?? now
    }

    // MARK: - Academic year helpers

    /// Academic year containing a date: Jul 1 – Jun 30 (§7.5).
    static func academicStartYear(for date: Date) -> Int {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return month >= 7 ? year : year - 1
    }

    static func currentAcademicStartYear(now: Date = Date()) -> Int {
        academicStartYear(for: now)
    }

    static func academicYearRange(startYear: Int) -> ClosedRange<Date> {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: startYear, month: 7, day: 1)) ?? Date()
        let end = calendar.date(from: DateComponents(year: startYear + 1, month: 6, day: 30, hour: 23, minute: 59, second: 59)) ?? Date()
        return start...end
    }

    static func academicYearLabel(startYear: Int) -> String {
        "\(startYear)–\(String(startYear + 1).suffix(2))"
    }

    /// Start years of all academic years touched by the data, newest first.
    /// Always includes the current year so the default selection is valid.
    func availableAcademicYears() -> [Int] {
        let years = Set(cases.map { Self.academicStartYear(for: $0.examDate) })
        return Array(years.union([Self.currentAcademicStartYear()])).sorted(by: >)
    }

    /// The active range, or nil for "All dates".
    var effectiveRange: ClosedRange<Date>? {
        switch selection {
        case .all: nil
        case .academicYear(let startYear): Self.academicYearRange(startYear: startYear)
        case .custom: rangeStart...rangeEnd
        }
    }

    var rangeSummary: String {
        switch selection {
        case .all: "All dates"
        case .academicYear(let startYear): "Academic year \(Self.academicYearLabel(startYear: startYear))"
        case .custom:
            "\(rangeStart.formatted(date: .abbreviated, time: .omitted)) – \(rangeEnd.formatted(date: .abbreviated, time: .omitted))"
        }
    }

    // MARK: - Filtering

    func cases(in range: ClosedRange<Date>) -> [CaseLog] {
        cases.filter { range.contains($0.examDate) }
    }

    var inRange: [CaseLog] {
        guard let range = effectiveRange else { return cases }
        return cases(in: range)
    }

    // MARK: - Preview / build

    func updatePreview() {
        switch reportType {
        case .csv:
            let csv = ExportService.csv(cases: inRange.map(\.record))
            previewText = String(csv.prefix(4000))
        case .acgme:
            previewText = renderText(ExportService.acgmeReportContent(cases: inRange.map(\.record)))
        case .nbeAdvanced:
            previewText = renderText(ExportService.nbeReportContent(cases: inRange.map(\.record), track: .nbeAdvanced))
        case .pdf:
            previewText = renderText(ExportService.pdfSummaryContent(cases: inRange.map(\.record), track: .nbeAdvanced))
        }
    }

    /// Builds the file for the current report type (temp dir, share-sheet ready).
    func buildExport() throws -> URL {
        isPreparing = true
        defer { isPreparing = false }
        let url: URL
        switch reportType {
        case .csv:
            let text = ExportService.csv(cases: inRange.map(\.record))
            url = FileManager.default.temporaryDirectory
                .appendingPathComponent("TEE-Log-\(stamp()).csv")
            try text.write(to: url, atomically: true, encoding: .utf8)
        case .acgme:
            url = ExportService.acgmeReport(cases: inRange.map(\.record))
        case .nbeAdvanced:
            url = ExportService.nbeReport(cases: inRange.map(\.record), track: .nbeAdvanced)
        case .pdf:
            url = ExportService.pdfSummary(cases: inRange.map(\.record), track: .nbeAdvanced)
        }
        exportedFileURL = url
        return url
    }

    /// Always a PDF — used by "Save PDF to Files" regardless of the
    /// currently selected report type (§7.5).
    func buildPDF() throws -> URL {
        isPreparing = true
        defer { isPreparing = false }
        let url = ExportService.pdfSummary(cases: inRange.map(\.record), track: .nbeAdvanced)
        exportedFileURL = url
        return url
    }

    // MARK: - Plain-text rendering for the native preview (§7.5, no web views)

    private func renderText(_ content: ExportService.ReportContent) -> String {
        var lines: [String] = []
        lines.append(content.title)
        lines.append(content.subtitle)
        lines.append("")
        for row in content.summaryRows {
            lines.append("\(row.label): \(row.value)")
        }
        if !content.categoryRows.isEmpty {
            lines.append("")
            lines.append("Category          count / minimum")
            for row in content.categoryRows {
                lines.append(String(format: "%-16@ %@ / %@ %@", row.category as NSString, row.count, row.minimum, row.met ? "✓" : ""))
            }
        }
        if !content.caseRows.isEmpty {
            lines.append("")
            lines.append("Date        Procedure — attending (role, CPB) — categories")
            for row in content.caseRows.prefix(200) {
                lines.append("\(row.date)  \(row.procedure) — \(row.attending) (\(row.role), \(row.cpb)) — \(row.categories)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmm"
        return f.string(from: Date())
    }
}
