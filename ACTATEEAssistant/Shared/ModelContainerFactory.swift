// ModelContainerFactory.swift — single ModelContainer for app, intents,
// and the widget extension (F1).
//
// The store lives in the shared App Group container so the WidgetKit
// extension can read the same SwiftData store the app writes to. When the
// group is unavailable (development builds without the entitlement), it
// falls back to the app's Application Support directory.
//
// APP TARGET ONLY (SwiftData is Apple-only). Also compiled into the
// ACTATEEWidget extension target (see project.yml).

import Foundation
import SwiftData

enum ModelContainerFactory {
    static let appGroupID = "group.com.actatee"

    /// Shared suite so the app, App Intents, and the widget extension all
    /// read the same preferences (e.g. selectedTrackID).
    static var sharedDefaults: UserDefaults? { UserDefaults(suiteName: appGroupID) }

    static var storeURL: URL {
        let base = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ACTATEEAssistant.store")
    }

    /// One container per process: the app creates it once (ACTATEEAssistantApp), and
    /// App Intents reuse it so no second container opens the same store.
    /// The widget extension process builds its own via `make()`.
    static let shared: ModelContainer = make()

    /// Builds a container over the shared store (app, intents, widget).
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
