import Foundation

/// Policy evaluation outcome determining whether an intent may be executed.
public struct PolicyDecision: Equatable, Sendable {
    public let category: PolicyCategory
    public let isPermitted: Bool
    public let explanation: String

    public init(category: PolicyCategory, isPermitted: Bool, explanation: String) {
        self.category = category
        self.isPermitted = isPermitted
        self.explanation = explanation
    }

    public static let allowed = PolicyDecision(
        category: .allowed,
        isPermitted: true,
        explanation: "Permitted by safety policy."
    )

    public static func confirmRequired(reason: String) -> PolicyDecision {
        PolicyDecision(
            category: .confirmRequired,
            isPermitted: false,
            explanation: reason
        )
    }

    public static func blocked(reason: String) -> PolicyDecision {
        PolicyDecision(
            category: .blocked,
            isPermitted: false,
            explanation: reason
        )
    }

    public static let unknown = PolicyDecision(
        category: .unknown,
        isPermitted: false,
        explanation: "Command not recognized or unsupported in MVP."
    )
}

/// Evaluates requested intents against user settings and safety boundaries before execution.
public struct CommandPolicy: Sendable {
    public init() {}

    /// Evaluates an intent against the current application configuration.
    public func evaluate(intent: AssistantIntent, config: AppConfiguration) -> PolicyDecision {
        switch intent {
        case .openGmail:
            guard config.isBrowserOpenEnabled else {
                return .blocked(reason: "Browser navigation is disabled in Javira Settings.")
            }
            return .allowed

        case .openApp(let app):
            guard config.isAppLaunchEnabled else {
                return .blocked(reason: "Application launching is disabled in Javira Settings.")
            }
            guard config.approvedApps.contains(app) else {
                return .blocked(reason: "\(app.displayName) is not approved in Javira Settings.")
            }
            return .allowed

        case .setVolume, .increaseVolume, .decreaseVolume, .mute, .unmute:
            guard config.isVolumeControlEnabled else {
                return .blocked(reason: "Volume control is disabled in Javira Settings.")
            }
            return .allowed

        case .sleepMac:
            guard config.isSleepEnabled else {
                return .blocked(reason: "Power management (Sleep) is disabled in Javira Settings.")
            }
            return .confirmRequired(reason: "Putting your Mac to sleep requires explicit confirmation.")

        case .confirm, .cancel:
            return .allowed

        case .blocked(let reason, _):
            return .blocked(reason: reason)

        case .unknown:
            return .unknown
        }
    }
}
