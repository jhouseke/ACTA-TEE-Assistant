// ExportService.swift — CSV writer + ACGME/NBE/PDF report content builders.
//
// Everything here is pure Swift (Foundation only) and compiles on Linux:
// the CSV writer is fully implemented, and the three report builders produce
// a structured `ReportContent` model that the app-side renderer draws.
// The Apple-only rendering (UIGraphicsPDFRenderer / PDFKit) lives in
// ACTATEEAssistant/Engine/ExportService+PDF.swift (app target) — isolated here so the
// core stays testable.
//
// IMPLEMENTATION.md §8

import Foundation

public enum ExportService {

    // MARK: - CSV

    /// RFC-4180-style CSV: header + one row per case, fields quoted when
    /// they contain a comma, quote, or newline (quotes doubled).
    /// Columns (§8): examDate, procedure, attending, participationLevel,
    /// indications, viewsObtained, lvefQualitative, lvefPercent, rvFunction,
    /// valveFindings ("AV:2+;MR:1+"), complications, examQuality, notes,
    /// categories, isSignedOff, cardiopulmonaryBypass, offPumpOrHybrid.
    public static func csv(cases: [CaseRecord]) -> String {
        let header = [
            "examDate", "procedure", "attending", "participationLevel",
            "indications", "viewsObtained", "lvefQualitative", "lvefPercent",
            "rvFunction", "valveFindings", "complications", "examQuality",
            "notes", "categories", "isSignedOff", "cardiopulmonaryBypass",
            "offPumpOrHybrid"
        ]
        var lines = [header.map(quote).joined(separator: ",")]
        let formatter = isoDateFormatter()
        for c in cases {
            let row: [String] = [
                formatter.string(from: c.examDate),
                c.procedure,
                c.attendingName,
                c.participationLevel,
                c.indications.joined(separator: "; "),
                c.viewsObtained.joined(separator: "; "),
                c.lvefQualitative ?? "",
                c.lvefPercent.map(String.init) ?? "",
                c.rvFunction ?? "",
                valveFindingsSummary(c.valveFindings),
                c.complications.joined(separator: "; "),
                c.examQuality,
                c.notes,
                c.categories.joined(separator: "; "),
                c.isSignedOff ? "true" : "false",
                c.cardiopulmonaryBypass ? "true" : "false",
                c.offPumpOrHybrid ? "true" : "false"
            ]
            lines.append(row.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// "AV:2+;MR:1+" (§8).
    public static func valveFindingsSummary(_ findings: [ValveFindingRecord]) -> String {
        findings.map(\.summary).joined(separator: ";")
    }

    private static func quote(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    // MARK: - Report content model

    /// A structured report the app-side renderer draws (native, no HTML).
    public struct ReportContent: Equatable, Sendable {
        public var title: String
        public var subtitle: String
        public var summaryRows: [ReportSummaryRow]
        public var categoryRows: [ReportCategoryRow]
        public var caseRows: [ReportCaseRow]

        public init(
            title: String,
            subtitle: String,
            summaryRows: [ReportSummaryRow] = [],
            categoryRows: [ReportCategoryRow] = [],
            caseRows: [ReportCaseRow] = []
        ) {
            self.title = title
            self.subtitle = subtitle
            self.summaryRows = summaryRows
            self.categoryRows = categoryRows
            self.caseRows = caseRows
        }
    }

    public struct ReportSummaryRow: Equatable, Sendable {
        public let label: String
        public let value: String
        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    public struct ReportCategoryRow: Equatable, Sendable {
        public let category: String
        public let count: String
        public let minimum: String
        public let met: Bool
        public init(category: String, count: String, minimum: String, met: Bool) {
            self.category = category
            self.count = count
            self.minimum = minimum
            self.met = met
        }
    }

    public struct ReportCaseRow: Equatable, Sendable {
        public let date: String
        public let procedure: String
        public let attending: String
        public let role: String
        public let cpb: String
        public let categories: String
        public init(date: String, procedure: String, attending: String, role: String, cpb: String, categories: String) {
            self.date = date
            self.procedure = procedure
            self.attending = attending
            self.role = role
            self.cpb = cpb
            self.categories = categories
        }
    }

    // MARK: - Report builders

    /// ACGME case-log format: rows of (case, role, CPB/off-pump, category).
    public static func acgmeReportContent(cases: [CaseRecord], rangeStart: Date? = nil, rangeEnd: Date? = nil) -> ReportContent {
        let formatter = isoDateFormatter()
        let sorted = cases.sorted { $0.examDate < $1.examDate }
        return ReportContent(
            title: "ACGME Case Log",
            subtitle: "TEE examinations — \(formatter.string(from: sorted.first?.examDate ?? Date())) to \(formatter.string(from: sorted.last?.examDate ?? Date()))",
            summaryRows: [
                .init(label: "Total cases", value: "\(sorted.count)")
            ],
            caseRows: sorted.map { c in
                ReportCaseRow(
                    date: formatter.string(from: c.examDate),
                    procedure: c.procedure,
                    attending: c.attendingName,
                    role: c.participationLevel,
                    cpb: c.cardiopulmonaryBypass ? "CPB" : (c.offPumpOrHybrid ? "Off-pump/hybrid" : "—"),
                    categories: c.categories.joined(separator: ", ")
                )
            }
        )
    }

    /// NBE Advanced/Basic layout: total + per-category counts vs minima.
    public static func nbeReportContent(cases: [CaseRecord], track: Track) -> ReportContent {
        let progress = RequirementsEngine.progress(cases: cases, track: track)
        let formatter = isoDateFormatter()
        let sorted = cases.sorted { $0.examDate < $1.examDate }
        return ReportContent(
            title: track.name,
            subtitle: "Case-minimum tracking — \(formatter.string(from: sorted.first?.examDate ?? Date())) to \(formatter.string(from: sorted.last?.examDate ?? Date()))",
            summaryRows: [
                .init(label: "Total cases", value: "\(progress.total) / \(track.totalMinimum)"),
                .init(label: "Overall progress", value: "\(Int(progress.overallPercent * 100))%")
            ],
            categoryRows: progress.categories.map { cp in
                ReportCategoryRow(
                    category: cp.category.displayName,
                    count: "\(cp.count)",
                    minimum: "\(cp.minimum)",
                    met: cp.isMet
                )
            }
        )
    }

    /// PDF (program summary): header + totals + category table + case log.
    public static func pdfSummaryContent(cases: [CaseRecord], track: Track) -> ReportContent {
        let progress = RequirementsEngine.progress(cases: cases, track: track)
        let formatter = isoDateFormatter()
        let sorted = cases.sorted { $0.examDate < $1.examDate }
        return ReportContent(
            title: "ACTA TEE Assistant — Program Summary",
            subtitle: "\(track.name) · \(formatter.string(from: sorted.first?.examDate ?? Date())) to \(formatter.string(from: sorted.last?.examDate ?? Date()))",
            summaryRows: [
                .init(label: "Total cases", value: "\(progress.total) / \(track.totalMinimum)"),
                .init(label: "Overall progress", value: "\(Int(progress.overallPercent * 100))%"),
                .init(label: "Categories met", value: "\(progress.categories.filter(\.isMet).count) / \(progress.categories.count)")
            ],
            categoryRows: progress.categories.map { cp in
                ReportCategoryRow(
                    category: cp.category.displayName,
                    count: "\(cp.count)",
                    minimum: "\(cp.minimum)",
                    met: cp.isMet
                )
            },
            caseRows: sorted.map { c in
                ReportCaseRow(
                    date: formatter.string(from: c.examDate),
                    procedure: c.procedure,
                    attending: c.attendingName,
                    role: c.participationLevel,
                    cpb: c.cardiopulmonaryBypass ? "CPB" : (c.offPumpOrHybrid ? "Off-pump/hybrid" : "—"),
                    categories: c.categories.joined(separator: ", ")
                )
            }
        )
    }

    // MARK: - Helpers

    private static func isoDateFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }
}
