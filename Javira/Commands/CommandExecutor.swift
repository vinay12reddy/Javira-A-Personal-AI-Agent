import Foundation

/// The outcome of executing an assistant intent.
public struct ExecutionResult: Equatable, Sendable {
    public let status: ActionStatus
    public let spokenResponse: String
    public let displayMessage: String
    public let isLocalOnly: Bool

    public init(status: ActionStatus, spokenResponse: String, displayMessage: String, isLocalOnly: Bool) {
        self.status = status
        self.spokenResponse = spokenResponse
        self.displayMessage = displayMessage
        self.isLocalOnly = isLocalOnly
    }
}

/// Coordinates intent validation through policies and routes commands to appropriate action modules.
public struct CommandExecutor: Sendable {
    private let policy = CommandPolicy()
    private let browserAction = BrowserAction()
    private let applicationAction = ApplicationAction()
    private let volumeAction = VolumeAction()
    private let powerAction = PowerAction()

    public init() {}

    /// Evaluates policy and executes the given intent.
    @MainActor
    public func execute(intent: AssistantIntent, config: AppConfiguration) async -> ExecutionResult {
        let decision = policy.evaluate(intent: intent, config: config)

        switch decision.category {
        case .blocked:
            return ExecutionResult(
                status: .blocked,
                spokenResponse: "Command blocked for your safety.",
                displayMessage: decision.explanation,
                isLocalOnly: true
            )

        case .unknown:
            if case .unknown(let query) = intent {
                let display = query.isEmpty ? "Please specify a command." : "Javira does not support \"\(query)\" yet."
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "I don't support that command yet. Check the supported phrases.",
                    displayMessage: display,
                    isLocalOnly: true
                )
            }
            return ExecutionResult(
                status: .failed,
                spokenResponse: "Command not recognized.",
                displayMessage: "Command not recognized.",
                isLocalOnly: true
            )

        case .confirmRequired:
            return ExecutionResult(
                status: .pendingConfirmation,
                spokenResponse: "Do you want me to put your Mac to sleep? Say confirm or cancel.",
                displayMessage: "Do you want me to put your Mac to sleep? Say confirm or cancel.",
                isLocalOnly: true
            )

        case .allowed:
            return await performAllowedIntent(intent, config: config)
        }
    }

    /// Executes consequential Mac sleep after confirmation has been approved.
    public func executeConfirmedSleep() -> ExecutionResult {
        let result = powerAction.sleepMac()
        switch result {
        case .success(let msg):
            return ExecutionResult(
                status: .completed,
                spokenResponse: "Putting your Mac to sleep now.",
                displayMessage: msg,
                isLocalOnly: true
            )
        case .failure(let err):
            return ExecutionResult(
                status: .failed,
                spokenResponse: "Failed to put Mac to sleep.",
                displayMessage: err.localizedDescription,
                isLocalOnly: true
            )
        }
    }

    @MainActor
    private func performAllowedIntent(_ intent: AssistantIntent, config: AppConfiguration) async -> ExecutionResult {
        switch intent {
        case .openGmail:
            let result = browserAction.openGmail(preferredBrowser: config.preferredBrowser)
            switch result {
            case .success(let msg):
                return ExecutionResult(
                    status: .completed,
                    spokenResponse: "Opening Gmail in your browser.",
                    displayMessage: msg,
                    isLocalOnly: false
                )
            case .failure(let err):
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "Unable to open Gmail.",
                    displayMessage: err.localizedDescription,
                    isLocalOnly: false
                )
            }

        case .openApp(let app):
            let result = applicationAction.launch(app: app)
            switch result {
            case .success(let msg):
                return ExecutionResult(
                    status: .completed,
                    spokenResponse: "Opening \(app.displayName).",
                    displayMessage: msg,
                    isLocalOnly: true
                )
            case .failure(let err):
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "Could not open \(app.displayName).",
                    displayMessage: err.localizedDescription,
                    isLocalOnly: true
                )
            }

        case .setVolume(let percentage):
            let result = volumeAction.setVolume(percentage: percentage)
            switch result {
            case .success(let val):
                return ExecutionResult(
                    status: .completed,
                    spokenResponse: "Volume set to \(val) percent.",
                    displayMessage: "Volume set to \(val)%.",
                    isLocalOnly: true
                )
            case .failure(let err):
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "Unable to change volume.",
                    displayMessage: err.localizedDescription,
                    isLocalOnly: true
                )
            }

        case .increaseVolume(let step):
            let result = volumeAction.adjustVolume(by: step)
            switch result {
            case .success(let newVol):
                return ExecutionResult(
                    status: .completed,
                    spokenResponse: "Volume increased to \(newVol) percent.",
                    displayMessage: "Volume increased to \(newVol)%.",
                    isLocalOnly: true
                )
            case .failure(let err):
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "Unable to adjust volume.",
                    displayMessage: err.localizedDescription,
                    isLocalOnly: true
                )
            }

        case .decreaseVolume(let step):
            let result = volumeAction.adjustVolume(by: -step)
            switch result {
            case .success(let newVol):
                return ExecutionResult(
                    status: .completed,
                    spokenResponse: "Volume decreased to \(newVol) percent.",
                    displayMessage: "Volume decreased to \(newVol)%.",
                    isLocalOnly: true
                )
            case .failure(let err):
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "Unable to adjust volume.",
                    displayMessage: err.localizedDescription,
                    isLocalOnly: true
                )
            }

        case .mute:
            let result = volumeAction.setMuted(true)
            switch result {
            case .success:
                return ExecutionResult(
                    status: .completed,
                    spokenResponse: "Audio muted.",
                    displayMessage: "Muted system output.",
                    isLocalOnly: true
                )
            case .failure(let err):
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "Unable to mute audio.",
                    displayMessage: err.localizedDescription,
                    isLocalOnly: true
                )
            }

        case .unmute:
            let result = volumeAction.setMuted(false)
            switch result {
            case .success:
                return ExecutionResult(
                    status: .completed,
                    spokenResponse: "Audio unmuted.",
                    displayMessage: "Unmuted system output.",
                    isLocalOnly: true
                )
            case .failure(let err):
                return ExecutionResult(
                    status: .failed,
                    spokenResponse: "Unable to unmute audio.",
                    displayMessage: err.localizedDescription,
                    isLocalOnly: true
                )
            }

        case .confirm, .cancel:
            return ExecutionResult(
                status: .completed,
                spokenResponse: "No pending action to resolve.",
                displayMessage: "No action pending.",
                isLocalOnly: true
            )

        default:
            return ExecutionResult(
                status: .failed,
                spokenResponse: "Unsupported action.",
                displayMessage: "Action not supported.",
                isLocalOnly: true
            )
        }
    }
}
