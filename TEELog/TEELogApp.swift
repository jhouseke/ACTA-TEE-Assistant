// TEELogApp.swift — @main entry, ModelContainer, lock state (§3).

import SwiftUI
import SwiftData

@main
struct TEELogApp: App {
    private let container: ModelContainer

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @State private var isUnlocked = false

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .overlay {
                    if appLockEnabled && !isUnlocked {
                        AppLockView(isUnlocked: $isUnlocked)
                    }
                }
                .task {
                    // P6: Face ID gate on launch when enabled (§10).
                    guard appLockEnabled, !isUnlocked else { return }
                    await AppLockView.authenticate(isUnlocked: $isUnlocked)
                }
        }
    }

    init() {
        do {
            container = try ModelContainer(for: CaseLog.self, ValveFinding.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
