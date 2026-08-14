// ExportViewModel.swift — report type, academic-year range, preview, build (§7.5, §8).

import Foundation
import Observation
import TEELogCore

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

@Observable
final class ExportViewModel {
    var reportType: ReportType = .acgme
    var rangeStart: Date
    var rangeEnd: Date
    var cases: [CaseLog] = []

    var previewText = ""
    var exportedFileURL: URL?
    var lastError: String?
    var isPreparing = false

    /// Academic year defaults: Jul 1 – Jun 30 of the current year (§7.5).
    init(now: Date = Date()) {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        let startYear = month >= 7 ? year : year - 1
        rangeStart = calendar.date(from: DateComponents(year: startYear, month: 7, day: 1)) ?? now
        rangeEnd = calendar.date(from: DateComponents(year: startYear + 1, month: 6, day: 30)) ?? now
    }

    func cases(in range: ClosedRange<Date>) -> [CaseLog] {
        cases.filter { range.contains($0.examDate) }
    }

    private var inRange: [CaseLog] {
        cases(in: rangeStart...rangeEnd).map(\.record)
    }

    func updatePreview() {
        switch reportType {
        case .csv:
            let csv = ExportService.csv(cases: inRange)
            previewText = String(csv.prefix(4000))
        case .acgme:
            previewText = renderText(ExportService.acgmeReportContent(cases: inRange))
        case .nbeAdvanced:
            previewText = renderText(ExportService.nbeReportContent(cases: inRange, track: .nbeAdvanced))
        case .pdf:
            previewText = renderText(ExportService.pdfSummaryContent(cases: inRange, track: .nbeAdvanced))
        }
    }

    /// Builds the file for the current report type (temp dir, share-sheet ready).
    func buildExport() throws -> URL {
        isPreparing = true
        defer { isPreparing = false }
        let url: URL
        switch reportType {
        case .csv:
            let text = ExportService.csv(cases: inRange)
            url = FileManager.default.temporaryDirectory
                .appendingPathComponent("TEE-Log-\(stamp()).csv")
            try text.write(to: url, atomically: true, encoding: .utf8)
        case .acgme:
            url = ExportService.acgmeReport(cases: inRange)
        case .nbeAdvanced:
            url = ExportService.nbeReport(cases: inRange, track: .nbeAdvanced)
        case .pdf:
            url = ExportService.pdfSummary(cases: inRange, track: .nbeAdvanced)
        }
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
