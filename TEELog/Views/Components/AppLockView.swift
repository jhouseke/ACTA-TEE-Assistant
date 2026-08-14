// AppLockView.swift — Face ID / passcode gate (§10, P6 hardening skeleton).
//
// LocalAuthentication, toggleable via AppStorage("appLockEnabled"). Full
// accessibility + settings polish is P6; the gate itself works now.

import SwiftUI
import LocalAuthentication

struct AppLockView: View {
    @Binding var isUnlocked: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("TEE Log is locked")
                .font(.headline)
            Button("Unlock") {
                Task { await Self.authenticate(isUnlocked: $isUnlocked) }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Authenticate with Face ID or passcode to view your case log")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
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
}
