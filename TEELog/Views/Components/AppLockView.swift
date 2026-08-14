// AppLockView.swift — Face ID / passcode gate (§10, P6).
//
// LocalAuthentication, toggleable in Settings. The gate shows on launch and
// whenever the app returns to the foreground while locked. If the device has
// no passcode / Face ID configured, it explains why and offers to turn the
// lock off rather than trapping the user behind an unlockable gate.

import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @Binding var isUnlocked: Bool
    @AppStorage("appLockEnabled") private var appLockEnabled = false

    @State private var canAuthenticate = true

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("TEE Log is locked")
                .font(.headline)

            if canAuthenticate {
                Button("Unlock") {
                    Task { await Self.authenticate(isUnlocked: $isUnlocked) }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Authenticate with Face ID or passcode to view your case log")
            } else {
                Text("No passcode or Face ID is set on this device, so the lock can't be opened. Add one in Settings → Face ID & Passcode, or turn the app lock off.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Turn off app lock") {
                    appLockEnabled = false
                    isUnlocked = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
        .task { canAuthenticate = Self.canAuthenticate() }
    }

    /// Whether the device can evaluate the Face ID / passcode policy at all.
    static func canAuthenticate() -> Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// LAContext biometric (or device passcode) evaluation.
    @MainActor
    static func authenticate(isUnlocked: Binding<Bool>) async {
        let context = LAContext()
        let policy: LAPolicy = .deviceOwnerAuthentication // Face ID w/ passcode fallback
        var error: NSError?
        guard context.canEvaluatePolicy(policy, error: &error) else { return }
        let ok = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            context.evaluatePolicy(policy, localizedReason: "Unlock your case log") { success, _ in
                cont.resume(returning: success)
            }
        }
        if ok { isUnlocked.wrappedValue = true }
    }

    /// Confirmation prompt used when enabling the lock in Settings — returns
    /// whether the user actually authenticated (cancelled → don't enable).
    @MainActor
    static func confirmAuthentication() async -> Bool {
        let context = LAContext()
        let policy: LAPolicy = .deviceOwnerAuthentication
        guard context.canEvaluatePolicy(policy, error: nil) else { return false }
        return await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            context.evaluatePolicy(policy, localizedReason: "Confirm app lock") { success, _ in
                cont.resume(returning: success)
            }
        }
    }
}
