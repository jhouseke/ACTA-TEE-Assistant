// SettingsView.swift — app settings: profile, app lock, default track
// (§7.1 profile card, §10 app lock). Reachable from the Dashboard gear.

import SwiftUI
import TEELogCore

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("profileName") private var profileName = "R. Chen"
    @AppStorage("profileTitle") private var profileTitle = "CT Fellow, PGY-6"
    @AppStorage("appLockEnabled") private var appLockEnabled = false
    @AppStorage("selectedTrackID") private var trackIDRaw = TrackID.nbeAdvanced.rawValue

    /// True when the device can't evaluate the Face ID / passcode policy.
    @State private var lockUnavailable = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    TextField("Name", text: $profileName)
                        .accessibilityLabel("Profile name")
                    TextField("Title", text: $profileTitle)
                        .accessibilityLabel("Profile title")
                }

                Section("Security") {
                    Toggle("Lock with Face ID / passcode", isOn: $appLockEnabled)
                        .accessibilityHint("Re-locks whenever the app leaves the foreground")

                    if lockUnavailable {
                        Label(
                            "No passcode or Face ID is set on this device. Add one in Settings → Face ID & Passcode to use the lock.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote)
                        .foregroundStyle(.orange)
                    } else {
                        Text("Requires Face ID or a device passcode. Your case log is re-locked whenever the app leaves the foreground.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Default requirement track") {
                    Picker("Track", selection: $trackIDRaw) {
                        ForEach(TrackID.allCases, id: \.rawValue) { trackID in
                            Text(trackID.displayName).tag(trackID.rawValue)
                        }
                    }
                    .accessibilityLabel("Default requirement track")
                }

                Section {
                    Text("De-identified by design: only age, sex, and BSA are ever stored. All data stays on this device; exports go out only through the share sheet (§10).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                lockUnavailable = appLockEnabled && !AppLockView.canAuthenticate()
            }
            .onChange(of: appLockEnabled) { _, enabled in
                if enabled {
                    // Enabling the lock needs a working auth policy; confirm
                    // immediately so the fellow knows the flow works. A
                    // cancelled prompt reverts the toggle.
                    guard AppLockView.canAuthenticate() else {
                        lockUnavailable = true
                        appLockEnabled = false
                        return
                    }
                    lockUnavailable = false
                    Task {
                        let ok = await AppLockView.confirmAuthentication()
                        if !ok { appLockEnabled = false }
                    }
                }
            }
        }
    }
}
