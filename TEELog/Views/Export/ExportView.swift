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
    @State private var isExportingPDF = false

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
            .onChange(of: viewModel.rangeStart) { _, _ in viewModel.updatePreview() }
            .onChange(of: viewModel.rangeEnd) { _, _ in viewModel.updatePreview() }
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
            }
        }
    }

    // MARK: - Range (§7.5: academic year, Jul 1 – Jun 30)

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date range")
                .font(.headline)
            HStack {
                DatePicker("From", selection: $viewModel.rangeStart, displayedComponents: .date)
                DatePicker("To", selection: $viewModel.rangeEnd, displayedComponents: .date)
            }
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Native preview (no web rendering, §7.5)

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.headline)
            ScrollView {
                Text(viewModel.previewText.isEmpty ? "No cases in range." : viewModel.previewText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .frame(maxHeight: 260)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
            .disabled(viewModel.cases.isEmpty)

            Button {
                preparePDFForFiles()
            } label: {
                Label("Save PDF to Files", systemImage: "folder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.cases.isEmpty)

            if let error = viewModel.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            // ShareLink hands the generated file to AirDrop/Mail/Files (§8).
            if let url = viewModel.exportedFileURL {
                ShareLink(item: url) {
                    Label("Share \(viewModel.reportType.title)", systemImage: "square.and.arrow.up")
                }
                .font(.subheadline)
            }
        }
        .fileExporter(
            isPresented: $isExportingPDF,
            document: ExportDocument(data: pdfDataForFiles()),
            contentType: .pdf,
            defaultFilename: "TEE-Log-Program-Summary"
        ) { result in
            if case .failure(let error) = result {
                viewModel.lastError = error.localizedDescription
            }
        }
    }

    private func prepareForShare() {
        do {
            _ = try viewModel.buildExport()
        } catch {
            viewModel.lastError = error.localizedDescription
        }
    }

    private func preparePDFForFiles() {
        viewModel.reportType = .pdf
        viewModel.updatePreview()
        isExportingPDF = true
    }

    private func pdfDataForFiles() -> Data? {
        guard let url = try? viewModel.buildExport() else { return nil }
        return try? Data(contentsOf: url)
    }
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
