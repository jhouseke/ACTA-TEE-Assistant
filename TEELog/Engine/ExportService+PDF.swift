// ExportService+PDF.swift — Apple-only PDF rendering for ExportService (§8).
//
// APP TARGET ONLY (UIGraphicsPDFRenderer / PDFKit are Apple-only; the pure
// content builders live in TEELogCore's ExportService).
//
// P5 status: functional skeleton — page 1 renders the header + totals +
// category table, subsequent pages render the case log table. Typography/
// pagination polish is P5 scope.

import Foundation
import UIKit
import TEELogCore

extension ExportService {

    /// PDF (program summary): header + totals + category table, then the
    /// case log table (§8).
    public static func pdfSummary(cases: [CaseRecord], track: Track) -> URL {
        render(content: pdfSummaryContent(cases: cases, track: track))
    }

    /// ACGME case-log format: rows of (case, role, CPB/off-pump, category).
    public static func acgmeReport(cases: [CaseRecord]) -> URL {
        render(content: acgmeReportContent(cases: cases))
    }

    /// NBE Advanced/Basic layout: total + per-category counts vs minima.
    public static func nbeReport(cases: [CaseRecord], track: Track) -> URL {
        render(content: nbeReportContent(cases: cases, track: track))
    }

    // MARK: - Renderer (P5 skeleton)

    private static func render(content: ReportContent) -> URL {
        let format = UIGraphicsPDFRendererFormat()
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0

            ctx.beginPage()
            y = drawHeader(title: content.title, subtitle: content.subtitle, at: y, in: pageRect)

            // Summary rows
            for row in content.summaryRows {
                y = drawLine(left: "\(row.label):  \(row.value)", at: y, in: pageRect, bold: false)
            }
            y += 12

            // Category table
            y = drawLine(left: "Category", right: "count / minimum", at: y, in: pageRect, bold: true)
            for row in content.categoryRows {
                let check = row.met ? " ✓" : ""
                y = drawLine(
                    left: row.category,
                    right: "\(row.count) / \(row.minimum)\(check)",
                    at: y, in: pageRect, bold: false
                )
                if y > pageRect.height - 72 {
                    ctx.beginPage()
                    y = 40
                }
            }

            // Case log table
            y += 12
            y = drawLine(left: "Date", right: "Procedure — attending (role, CPB) — categories", at: y, in: pageRect, bold: true)
            for row in content.caseRows {
                let text = "\(row.procedure) — \(row.attending) (\(row.role), \(row.cpb)) — \(row.categories)"
                y = drawLine(left: row.date, right: text, at: y, in: pageRect, bold: false)
                if y > pageRect.height - 72 {
                    ctx.beginPage()
                    y = 40
                }
            }
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(content.title.replacingOccurrences(of: " ", with: "-"))-\(UUID().uuidString.prefix(8)).pdf")
        try? data.write(to: url)
        return url
    }

    private static func drawHeader(title: String, subtitle: String, at y: CGFloat, in pageRect: CGRect) -> CGFloat {
        var cursor = y + 40
        (title as NSString).draw(
            at: CGPoint(x: 40, y: cursor),
            withAttributes: [.font: UIFont.boldSystemFont(ofSize: 20)]
        )
        cursor += 26
        (subtitle as NSString).draw(
            at: CGPoint(x: 40, y: cursor),
            withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.secondaryLabel]
        )
        return cursor + 16
    }

    private static func drawLine(left: String, right: String = "", at y: CGFloat, in pageRect: CGRect, bold: Bool) -> CGFloat {
        let font = bold ? UIFont.boldSystemFont(ofSize: 11) : UIFont.systemFont(ofSize: 11)
        (left as NSString).draw(
            at: CGPoint(x: 40, y: y),
            withAttributes: [.font: font]
        )
        if !right.isEmpty {
            (right as NSString).draw(
                at: CGPoint(x: 220, y: y),
                withAttributes: [.font: font]
            )
        }
        return y + 16
    }
}
