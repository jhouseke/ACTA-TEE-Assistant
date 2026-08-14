// ModelContainerFactory.swift — single ModelContainer for app, intents,
// and the widget extension (F1).
//
// The store lives in the shared App Group container so the WidgetKit
// extension can read the same SwiftData store the app writes to. When the
// group is unavailable (development builds without the entitlement), it
// falls back to the app's Application Support directory.
//
// APP TARGET ONLY (SwiftData is Apple-only). Also compiled into the
// TEEWidget extension target (see project.yml).

import Foundation
import SwiftData

enum ModelContainerFactory {
    static let appGroupID = "group.com.teelog"

    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("TEELog.store")
    }

    /// Shared across the app process, App Intents, and the widget extension
    /// (each process gets its own instance — the URL is what unifies them).
    static func make() -> ModelContainer {
        let configuration = ModelConfiguration(url: storeURL)
        do {
            return try ModelContainer(
                for: CaseLog.self, ValveFinding.self, QuizCard.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
