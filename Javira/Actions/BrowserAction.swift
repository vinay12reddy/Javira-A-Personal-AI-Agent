import Foundation
import AppKit

public enum ActionError: Error, LocalizedError, Equatable {
    case applicationNotFound(String)
    case executionFailed(String)
    case permissionDenied(String)
    case cancelled(String)

    public var errorDescription: String? {
        switch self {
        case .applicationNotFound(let name):
            return "Application not found: \(name)"
        case .executionFailed(let reason):
            return "Execution failed: \(reason)"
        case .permissionDenied(let reason):
            return "Permission denied: \(reason)"
        case .cancelled(let reason):
            return "Cancelled: \(reason)"
        }
    }
}

/// Handles safe browser interactions.
///
/// SAFETY MANDATE:
/// Gmail means ONLY opening `https://mail.google.com` in the chosen browser.
/// Javira never attempts to log in, read mail, compose mail, or send mail.
/// Loading web content requires internet access.
public struct BrowserAction: Sendable {
    public static let gmailURL = URL(string: "https://mail.google.com")!

    public init() {}

    /// Opens Gmail URL in the user's preferred browser or system default.
    @MainActor
    public func openGmail(preferredBrowser: BrowserChoice) -> Result<String, ActionError> {
        let url = Self.gmailURL

        // If a specific browser is requested (e.g. Safari or Google Chrome)
        if let bundleID = preferredBrowser.bundleIdentifier,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true

            var launchError: Error?
            let semaphore = DispatchSemaphore(value: 0)

            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: configuration) { _, error in
                launchError = error
                semaphore.signal()
            }

            // Wait briefly for app launch
            _ = semaphore.wait(timeout: .now() + 2.0)

            if let error = launchError {
                // Fall back to opening with default browser if dedicated launch fails
                let fallbackSuccess = NSWorkspace.shared.open(url)
                if fallbackSuccess {
                    return .success("Opened Gmail in default browser (fallback from \(preferredBrowser.rawValue)).")
                }
                return .failure(.executionFailed("Could not open browser: \(error.localizedDescription)"))
            }
            return .success("Opened Gmail in \(preferredBrowser.rawValue).")
        } else {
            // Open in default browser
            let success = NSWorkspace.shared.open(url)
            if success {
                return .success("Opened Gmail in your default browser.")
            } else {
                return .failure(.executionFailed("Unable to open default browser for Gmail."))
            }
        }
    }
}
