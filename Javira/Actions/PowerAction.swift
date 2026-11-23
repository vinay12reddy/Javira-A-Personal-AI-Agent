import Foundation

/// Handles consequential power management actions for macOS.
///
/// SAFETY MANDATE:
/// Only executes after explicit, verified user approval (spoken or clicked).
/// Automatically cancels if no confirmation is received within 10 seconds.
/// Does NOT implement shutdown, restart, screen locking, wipe, or erase.
public struct PowerAction: Sendable {
    public init() {}

    /// Puts the host Mac into system sleep.
    /// MUST only be invoked after explicit approval verification.
    public func sleepMac() -> Result<String, ActionError> {
        let script = "tell application \"System Events\" to sleep"
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(.executionFailed("Could not initialize sleep script."))
        }

        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let desc = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            return .failure(.executionFailed("Sleep command failed: \(desc)"))
        }

        return .success("Mac is going to sleep.")
    }
}
