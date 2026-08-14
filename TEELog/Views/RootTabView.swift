// RootTabView.swift — 5 tabs: Home · Log · Progress · Export · Cases (§7).
//
// Owns tab selection so the widget complication tap-through
// (teelog://quicklog → Quick Log flow) can switch tabs programmatically
// (F1).

import SwiftUI

struct RootTabView: View {
    @AppStorage("quickLogRequested") private var quickLogRequested = false // F1
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            QuickLogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }
                .tag(1)

            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }
                .tag(2)

            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }
                .tag(3)

            LibraryView()
                .tabItem { Label("Cases", systemImage: "list.bullet") }
                .tag(4)
        }
        .onChange(of: quickLogRequested) { _, requested in
            guard requested else { return }
            selectedTab = 1 // Quick Log flow
            quickLogRequested = false
        }
    }
}
