// ExportService+PDF.swift — Apple-only PDF rendering for ExportService (§8).
//
// APP TARGET ONLY (UIGraphicsPDFRenderer / PDFKit are Apple-only; the pure
// content builders live in TEELogCore's ExportService).
//
// Layout (US Letter, 612×792 pt, 40 pt margins):
//   page 1 — title header + rule, summary rows, category table
//   page 2+ — case log table (column header repeats on page breaks)
//   every page — "Page N" footer.
// Text wraps within columns; rows never split awkwardly across pages.

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

    // MARK: - Renderer

    private enum Layout {
        static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        static let margin: CGFloat = 40
        static let contentWidth = pageRect.width - margin * 2              // 532
        static let top: CGFloat = 36
        static let bottom: CGFloat = 48
        static let columnGap: CGFloat = 16
        /// Right-aligned totals column (category counts).
        static let totalsX = pageRect.width - margin - 160
        static let totalsWidth: CGFloat = 160
        /// Case table: date column + wrapped detail column.
        static let dateColumnWidth: CGFloat = 76
        static let caseDetailX = margin + dateColumnWidth + columnGap
        static let caseDetailWidth = contentWidth - dateColumnWidth - columnGap
    }

    private static func render(content: ReportContent) -> URL {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextTitle as String: content.title,
            kCGPDFContextAuthor as String: "TEE Log"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: Layout.pageRect, format: format)

        let data = renderer.pdfData { ctx in
            var page = 0
            var y: CGFloat = 0

            func beginPage() {
                ctx.beginPage()
                page += 1
                y = Layout.top
            }

            /// Footer for the page we are leaving, then start a new one.
            func newPage() {
                pageNumber(page)
                beginPage()
            }

            /// Start a new page if `needed` points doesn't fit below y.
            func ensure(_ needed: CGFloat) {
                if y + needed > Layout.pageRect.height - Layout.bottom {
                    newPage()
                }
            }

            func pageNumber(_ number: Int) {
                let text = "Page \(number)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let size = text.size(withAttributes: attrs)
                text.draw(
                    at: CGPoint(x: (Layout.pageRect.width - size.width) / 2, y: Layout.pageRect.height - 32),
                    withAttributes: attrs
                )
            }

            beginPage()
            y = drawHeader(title: content.title, subtitle: content.subtitle, at: y, ctx: ctx)
            y += 14

            // Summary rows
            for row in content.summaryRows {
                ensure(22)
                y = drawLabelValue(label: row.label, value: row.value, at: y)
                y += 5
            }
            if !content.summaryRows.isEmpty { y += 8 }

            // Category table (NBE + PDF reports)
            if !content.categoryRows.isEmpty {
                ensure(28)
                y = drawTableHeader(left: "Category", right: "count / minimum", at: y)
                y += 4
                for row in content.categoryRows {
                    let check = row.met ? " ✓" : ""
                    let pageBefore = page
                    ensure(20)
                    if page != pageBefore {
                        // Fresh page: repeat the column header.
                        y = drawTableHeader(left: "Category", right: "count / minimum", at: y)
                        y += 4
                    }
                    drawSeparator(at: y - 2, ctx: ctx)
                    y = drawTableRow(
                        left: row.category,
                        right: "\(row.count) / \(row.minimum)\(check)",
                        at: y,
                        rightColor: row.met ? UIColor.systemGreen : UIColor.label
                    )
                    y += 3
                }
                y += 10
            }

            // Case log table (ACGME + PDF reports)
            if !content.caseRows.isEmpty {
                ensure(32)
                y = drawSectionTitle("Case log", at: y)
                y += 8
                y = drawCaseHeader(at: y)
                y += 4
                for row in content.caseRows {
                    let text = "\(row.procedure) — \(row.attending) (\(row.role), \(row.cpb)) — \(row.categories)"
                    let needed = height(of: text, width: Layout.caseDetailWidth, font: bodyFont)
                    let pageBefore = page
                    ensure(needed + 8)
                    if page != pageBefore {
                        // Fresh page: repeat the column header.
                        y = drawCaseHeader(at: y)
                        y += 4
                    }
                    drawSeparator(at: y - 2, ctx: ctx)
                    y = drawCaseRow(date: row.date, detail: text, at: y)
                    y += 6
                }
            } else if content.summaryRows.isEmpty, content.categoryRows.isEmpty {
                ensure(24)
                y = drawText("No cases in range.", at: y, font: bodyFont, color: .secondaryLabel)
            }

            pageNumber(page)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(content.title.replacingOccurrences(of: " ", with: "-"))-\(UUID().uuidString.prefix(8)).pdf")
        try? data.write(to: url)
        return url
    }

    // MARK: - Drawing primitives

    private static let titleFont = UIFont.boldSystemFont(ofSize: 20)
    private static let subtitleFont = UIFont.systemFont(ofSize: 12)
    private static let sectionFont = UIFont.boldSystemFont(ofSize: 14)
    private static let headerFont = UIFont.boldSystemFont(ofSize: 11)
    private static let bodyFont = UIFont.systemFont(ofSize: 11)

    /// Title + subtitle + rule; returns the y below the rule.
    private static func drawHeader(title: String, subtitle: String, at y: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var cursor = drawText(title, at: CGPoint(x: Layout.margin, y: y), font: titleFont, color: .label)
        cursor += 2
        cursor = drawText(subtitle, at: CGPoint(x: Layout.margin, y: cursor), font: subtitleFont, color: .secondaryLabel)
        cursor += 8
        drawSeparator(at: cursor, ctx: ctx)
        return cursor + 10
    }

    /// "label: value" on one line; value wraps if long. Returns the y below.
    private static func drawLabelValue(label: String, value: String, at y: CGFloat) -> CGFloat {
        let labelWidth: CGFloat = 170
        let labelY = drawText(label, at: CGPoint(x: Layout.margin, y: y), font: headerFont, color: .label)
        let valueRect = CGRect(
            x: Layout.margin + labelWidth,
            y: y,
            width: Layout.contentWidth - labelWidth,
            height: .greatestFiniteMagnitude
        )
        let valueHeight = drawWrapped(value, in: valueRect, font: bodyFont, color: .label)
        return max(labelY, y + valueHeight)
    }

    /// Category table header row.
    private static func drawTableHeader(left: String, right: String, at y: CGFloat) -> CGFloat {
        let leftHeight = drawText(left, at: CGPoint(x: Layout.margin, y: y), font: headerFont, color: .label)
        let rightRect = CGRect(x: Layout.totalsX, y: y, width: Layout.totalsWidth, height: .greatestFiniteMagnitude)
        let rightHeight = drawRight(right, in: rightRect, font: headerFont, color: .secondaryLabel)
        return max(leftHeight, y + rightHeight)
    }

    private static func drawTableRow(left: String, right: String, at y: CGFloat, rightColor: UIColor) -> CGFloat {
        let leftHeight = drawText(left, at: CGPoint(x: Layout.margin, y: y), font: bodyFont, color: .label)
        let rightRect = CGRect(x: Layout.totalsX, y: y, width: Layout.totalsWidth, height: .greatestFiniteMagnitude)
        let rightHeight = drawRight(right, in: rightRect, font: bodyFont, color: rightColor)
        return max(leftHeight, y + rightHeight)
    }

    /// Case log table: "Date" + "Procedure — attending (role, CPB) — categories".
    private static func drawCaseHeader(at y: CGFloat) -> CGFloat {
        let leftHeight = drawText("Date", at: CGPoint(x: Layout.margin, y: y), font: headerFont, color: .label)
        let detailRect = CGRect(x: Layout.caseDetailX, y: y, width: Layout.caseDetailWidth, height: .greatestFiniteMagnitude)
        let rightHeight = drawWrapped(
            "Procedure — attending (role, CPB) — categories",
            in: detailRect, font: headerFont, color: .secondaryLabel
        )
        return max(leftHeight, y + rightHeight)
    }

    private static func drawCaseRow(date: String, detail: String, at y: CGFloat) -> CGFloat {
        let dateHeight = drawText(date, at: CGPoint(x: Layout.margin, y: y), font: bodyFont, color: .label)
        let detailRect = CGRect(x: Layout.caseDetailX, y: y, width: Layout.caseDetailWidth, height: .greatestFiniteMagnitude)
        let detailHeight = drawWrapped(detail, in: detailRect, font: bodyFont, color: .label)
        return max(dateHeight, y + detailHeight)
    }

    private static func drawSectionTitle(_ title: String, at y: CGFloat) -> CGFloat {
        drawText(title, at: CGPoint(x: Layout.margin, y: y), font: sectionFont, color: .label)
    }

    /// Single-line text at a point; returns the y below the line.
    @discardableResult
    private static func drawText(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        (text as NSString).draw(at: point, withAttributes: attrs)
        return point.y + font.lineHeight
    }

    /// Word-wrapped text in a rect; returns the height used.
    private static func drawWrapped(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        (text as NSString).draw(with: rect, options: options, attributes: attrs, context: nil)
        return height(of: text, width: rect.width, font: font)
    }

    /// Right-aligned wrapped text (totals column).
    private static func drawRight(_ text: String, in rect: CGRect, font: UIFont, color: UIColor) -> CGFloat {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
        let options: NSStringDrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
        (text as NSString).draw(with: rect, options: options, attributes: attrs, context: nil)
        return height(of: text, width: rect.width, font: font)
    }

    /// Wrapped height of a text at a given width.
    private static func height(of text: String, width: CGFloat, font: UIFont) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let bounds = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        return ceil(bounds.height)
    }

    /// Hairline separator across the content width.
    private static func drawSeparator(at y: CGFloat, ctx: UIGraphicsPDFRendererContext) {
        let cg = ctx.cgContext
        cg.setStrokeColor(UIColor.systemGray4.cgColor)
        cg.setLineWidth(0.5)
        cg.move(to: CGPoint(x: Layout.margin, y: y))
        cg.addLine(to: CGPoint(x: Layout.pageRect.width - Layout.margin, y: y))
        cg.strokePath()
    }
}
