import Foundation
import LocalAuthentication
import Observation

/// Optional Touch ID (or password) gate in front of the vault.
@Observable
final class VaultLock {
    static let enabledKey = "requireTouchID"

    private(set) var isLocked: Bool
    private(set) var message: String?

    init() {
        isLocked = UserDefaults.standard.bool(forKey: Self.enabledKey)
    }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Self.enabledKey) }

    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    func unlock() async {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = error?.localizedDescription ?? "This Mac can't verify your identity."
            return
        }
        do {
            if try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "unlock your family documents") {
                isLocked = false
                message = nil
            }
        } catch {
            message = nil
        }
    }
}
