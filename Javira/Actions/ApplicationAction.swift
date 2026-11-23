import Foundation
import AppKit

/// Handles launching approved applications from a fixed allowlist.
///
/// SAFETY MANDATE:
/// Only launches explicitly approved apps using their bundle identifiers.
/// Never launches Terminal, shells, or arbitrary third-party executables.
public struct ApplicationAction: Sendable {
    public init() {}

    /// Launches an approved application by its bundle identifier.
    @MainActor
    public func launch(app: ApprovedApp) -> Result<String, ActionError> {
        let bundleID = app.bundleIdentifier

        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return .failure(.applicationNotFound("\(app.displayName) is not installed on this Mac."))
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        var launchError: Error?
        let semaphore = DispatchSemaphore(value: 0)

        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { _, error in
            launchError = error
            semaphore.signal()
        }

        _ = semaphore.wait(timeout: .now() + 2.0)

        if let error = launchError {
            return .failure(.executionFailed("Failed to launch \(app.displayName): \(error.localizedDescription)"))
        }

        return .success("Launched \(app.displayName).")
    }
}
