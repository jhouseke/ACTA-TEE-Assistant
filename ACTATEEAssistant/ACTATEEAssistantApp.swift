// ACTATEEAssistantApp.swift — @main entry, ModelContainer, lock state (§3, §10).

import SwiftUI
import SwiftData

@main
struct ACTATEEAssistantApp: App {
    private let container: ModelContainer

    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("quickLogRequested") private var quickLogRequested = false // F1: widget tap-through
    @State private var isUnlocked = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .modelContainer(container)
                .onOpenURL { url in
                    // F1: actatee://quicklog — widget complication tap-through.
                    guard url.scheme == "actatee", url.host == "quicklog" else { return }
                    quickLogRequested = true
                }
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
                .onChange(of: scenePhase) { _, phase in
                    // Re-lock whenever the app leaves the foreground and
                    // prompt again on return (§10). Only .background, not
                    // .inactive — .inactive also fires while the Face ID
                    // prompt is up and would cause an auth loop.
                    switch phase {
                    case .background:
                        if appLockEnabled { isUnlocked = false }
                    case .active:
                        if appLockEnabled && !isUnlocked {
                            Task { await AppLockView.authenticate(isUnlocked: $isUnlocked) }
                        }
                    default:
                        break
                    }
                }
        }
    }

    init() {
        // One shared container (app group store) for the app, App Intents,
        // and the widget extension — see ModelContainerFactory (F1).
        container = ModelContainerFactory.shared
    }
}
