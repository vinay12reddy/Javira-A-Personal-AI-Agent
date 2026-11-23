import Foundation

/// Defines the category of safety policy governing an intent.
public enum PolicyCategory: String, Codable, Equatable, Sendable {
    case allowed = "Allowed"
    case confirmRequired = "Confirmation Required"
    case blocked = "Blocked for Safety"
    case unknown = "Unknown Command"
}

/// Strongly-typed representations of intents understood by Javira.
/// Non-LLM, strictly deterministic model.
public enum AssistantIntent: Equatable, Hashable, Sendable {
    case openGmail
    case openApp(ApprovedApp)
    case setVolume(percentage: Int)
    case increaseVolume(step: Int)
    case decreaseVolume(step: Int)
    case mute
    case unmute
    case sleepMac
    case confirm
    case cancel
    case blocked(reason: String, originalCommand: String)
    case unknown(query: String)

    /// A human-readable display title for the intent.
    public var displayName: String {
        switch self {
        case .openGmail:
            return "Open Gmail"
        case .openApp(let app):
            return "Open \(app.displayName)"
        case .setVolume(let pct):
            return "Set Volume to \(pct)%"
        case .increaseVolume(let step):
            return "Increase Volume (+\(step)%)"
        case .decreaseVolume(let step):
            return "Decrease Volume (-\(step)%)"
        case .mute:
            return "Mute Output"
        case .unmute:
            return "Unmute Output"
        case .sleepMac:
            return "Put Mac to Sleep"
        case .confirm:
            return "Confirm Action"
        case .cancel:
            return "Cancel Action"
        case .blocked(let reason, _):
            return "Blocked: \(reason)"
        case .unknown(let query):
            return "Unknown: \"\(query)\""
        }
    }

    /// Indicates whether the action operates 100% locally or requires network connectivity.
    /// In accordance with privacy rules:
    /// - Opening Gmail requires internet to fetch the web page.
    /// - Volume, App launching, and Sleep Mac are 100% local.
    public var isLocalOnly: Bool {
        switch self {
        case .openGmail:
            // Browser launching is local, but loading mail.google.com requires internet access.
            return false
        default:
            return true
        }
    }

    /// Default baseline policy category for this intent.
    public var defaultCategory: PolicyCategory {
        switch self {
        case .openGmail, .openApp, .setVolume, .increaseVolume, .decreaseVolume, .mute, .unmute, .confirm, .cancel:
            return .allowed
        case .sleepMac:
            return .confirmRequired
        case .blocked:
            return .blocked
        case .unknown:
            return .unknown
        }
    }
}
