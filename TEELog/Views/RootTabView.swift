// RootTabView.swift — 5 tabs: Home · Log · Progress · Export · Cases (§7).

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }

            QuickLogView()
                .tabItem { Label("Log", systemImage: "plus.circle.fill") }

            ProgressScreen()
                .tabItem { Label("Progress", systemImage: "chart.bar.fill") }

            ExportView()
                .tabItem { Label("Export", systemImage: "square.and.arrow.up") }

            LibraryView()
                .tabItem { Label("Cases", systemImage: "list.bullet") }
        }
    }
}
