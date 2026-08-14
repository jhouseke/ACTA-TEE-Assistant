// TEEProgressWidget.swift — WidgetKit complication: total/totalMinimum
// (e.g. "247/300") with tap-through to the Quick Log flow (F1).
//
// Reads the same SwiftData store the app writes to (shared App Group
// container via ModelContainerFactory), so it always reflects the live
// case count. The app calls WidgetCenter.shared.reloadAllTimelines() on
// every case save; the timeline also refreshes every 30 minutes as a
// backstop.
//
// supportedFamilies: systemSmall (Home Screen) plus the accessory
// rectangular/circular families — the compact complication forms on the
// Lock Screen / watch face.
//
// FEATURES.md F1 — native WidgetKit only, no network.

import WidgetKit
import SwiftUI
import SwiftData
import TEELogCore

// MARK: - Entry

struct TEEProgressEntry: TimelineEntry {
    let date: Date
    let total: Int
    let totalMinimum: Int
    let trackName: String
}

// MARK: - Provider

struct TEEProgressProvider: TimelineProvider {
    func placeholder(in context: Context) -> TEEProgressEntry {
        TEEProgressEntry(
            date: .now,
            total: 247,
            totalMinimum: Track.nbeAdvanced.totalMinimum,
            trackName: Track.nbeAdvanced.name
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TEEProgressEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TEEProgressEntry>) -> Void) {
        // One entry; reload on every case save (WidgetCenter) + 30 min backstop.
        completion(Timeline(entries: [loadEntry()], policy: .after(Date.now.addingTimeInterval(30 * 60))))
    }

    /// Reads the shared store on a background context (the provider runs
    /// off the main actor; ModelContext created here is used only on this
    /// call).
    private func loadEntry() -> TEEProgressEntry {
        let track = Track.track(id: selectedTrackID())
        let context = ModelContext(ModelContainerFactory.make())
        let total = (try? context.fetchCount(FetchDescriptor<CaseLog>())) ?? 0
        return TEEProgressEntry(date: .now, total: total, totalMinimum: track.totalMinimum, trackName: track.name)
    }

    /// Track selection persists via AppStorage in the shared app-group
    /// suite (ProgressScreen / Settings / Dashboard write it there).
    private func selectedTrackID() -> TrackID {
        let raw = ModelContainerFactory.sharedDefaults?.string(forKey: "selectedTrackID")
        return TrackID(rawValue: raw ?? "") ?? .nbeAdvanced
    }
}

// MARK: - View

struct TEEProgressWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TEEProgressEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("\(entry.total)/\(entry.totalMinimum)")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.trackName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .containerBackground(for: .widget) { Color.clear }

        case .accessoryCircular:
            Gauge(value: Double(entry.total), in: 0...Double(max(entry.totalMinimum, 1))) {
                Text("TEE")
            } currentValueLabel: {
                Text("\(entry.total)")
                    .font(.caption2)
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(for: .widget) { Color.clear }

        default: // systemSmall
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.text.square.fill")
                        .foregroundStyle(.tint)
                    Text("TEE Log")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text("\(entry.total)/\(entry.totalMinimum)")
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                Text(entry.trackName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Label("Log case", systemImage: "plus.circle.fill")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tint)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
        }
    }
}

// MARK: - Widget

struct TEEProgressWidget: Widget {
    static let kind = "TEEProgress"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: TEEProgressProvider()) { entry in
            TEEProgressWidgetView(entry: entry)
                .widgetURL(URL(string: "teelog://quicklog")) // tap-through → Quick Log
        }
        .configurationDisplayName("TEE Progress")
        .description("Your logged TEE cases against the track minimum.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryCircular])
    }
}

// MARK: - Bundle

@main
struct TEEWidgetBundle: WidgetBundle {
    var body: some Widget {
        TEEProgressWidget()
    }
}
