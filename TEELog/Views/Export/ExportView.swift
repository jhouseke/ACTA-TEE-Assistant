// ExportView.swift — reports (§7.5): type picker, academic-year range,
// native preview (ScrollView + Text — no web views), share sheet + Files.

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import TEELogCore

struct ExportView: View {
    @Query(sort: \CaseLog.examDate, order: .reverse) private var cases: [CaseLog]

    @State private var viewModel = ExportViewModel()
    @State private var isSharing = false
    @State private var shareItems: [Any] = []
    @State private var isExportingPDF = false
    @State private var pdfData: Data?

    private var hasCasesInRange: Bool { !viewModel.inRange.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    reportTypePicker

                    rangePicker

                    previewCard

                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.cases = cases
                viewModel.updatePreview()
            }
            .onChange(of: cases.count) { _, _ in
                viewModel.cases = cases
                viewModel.updatePreview()
            }
            .onChange(of: viewModel.reportType) { _, _ in viewModel.updatePreview() }
            .onChange(of: viewModel.selection) { _, _ in viewModel.updatePreview() }
            .onChange(of: viewModel.rangeStart) { _, _ in viewModel.updatePreview() }
            .onChange(of: viewModel.rangeEnd) { _, _ in viewModel.updatePreview() }
            .sheet(isPresented: $isSharing) {
                ShareSheet(items: shareItems)
            }
        }
    }

    // MARK: - Report type

    private var reportTypePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Report type")
                .font(.headline)
            ForEach(ReportType.allCases) { type in
                Button {
                    viewModel.reportType = type
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: type.symbol)
                            .foregroundStyle(.tint)
                            .frame(width: 24)
                        Text(type.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.reportType == type {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.tint)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(
                        viewModel.reportType == type
                            ? Color.accentColor.opacity(0.12)
                            : Color(uiColor: .secondarySystemBackground),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44) // §11 hit target
            }
        }
    }

    // MARK: - Range (§7.5: academic year, Jul 1 – Jun 30)

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Date range")
                .font(.headline)
            Picker("Date range", selection: $viewModel.selection) {
                ForEach(viewModel.availableAcademicYears(), id: \.self) { startYear in
                    Text(ExportViewModel.academicYearLabel(startYear: startYear))
                        .tag(RangeSelection.academicYear(startYear))
                }
                Text("All dates").tag(RangeSelection.all)
                Text("Custom…").tag(RangeSelection.custom)
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel("Date range")

            if viewModel.selection == .custom {
                HStack {
                    DatePicker("From", selection: $viewModel.rangeStart, displayedComponents: .date)
                    DatePicker("To", selection: $viewModel.rangeEnd, displayedComponents: .date)
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)
            }

            Text(viewModel.rangeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Native preview (no web rendering, §7.5)

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
            if hasCasesInRange {
                ScrollView {
                    Text(viewModel.previewText)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
                .frame(maxHeight: 260)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            } else {
                ContentUnavailableView(
                    "No cases in range",
                    systemImage: "doc.richtext",
                    description: Text("Adjust the date range, or log a case from the Home tab.")
                )
                .frame(maxHeight: 260)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                prepareForShare()
            } label: {
                Label("Export & send to program director", systemImage: "paperplane.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasCasesInRange)

            Button {
                preparePDFForFiles()
            } label: {
                Label("Save PDF to Files", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(!hasCasesInRange)

            if let error = viewModel.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .fileExporter(
            isPresented: $isExportingPDF,
            document: ExportDocument(data: pdfData),
            contentType: .pdf,
            defaultFilename: "TEE-Log-Program-Summary"
        ) { result in
            pdfData = nil
            if case .failure(let error) = result {
                viewModel.lastError = error.localizedDescription
            }
        }
    }

    private func prepareForShare() {
        do {
            let url = try viewModel.buildExport()
            shareItems = [url]
            isSharing = true
        } catch {
            viewModel.lastError = error.localizedDescription
        }
    }

    private func preparePDFForFiles() {
        do {
            let url = try viewModel.buildPDF()
            pdfData = try? Data(contentsOf: url)
            isExportingPDF = true
        } catch {
            viewModel.lastError = error.localizedDescription
        }
    }
}

/// UIActivityViewController wrapper — AirDrop / Mail / Files / Print (§8).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// FileDocument wrapper for the fileExporter (PDF to Files, §7.5).
struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf, .commaSeparatedText] }

    var data: Data?

    init(data: Data?) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data ?? Data())
    }
}
