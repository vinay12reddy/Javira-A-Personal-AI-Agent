import Foundation
import Combine
import SwiftUI

/// High-contrast status labels for the assistant UI.
public enum AssistantStatusState: String, Sendable {
    case idle = "Idle"
    case listening = "Listening"
    case processing = "Processing"
    case awaitingConfirmation = "Awaiting Confirmation"
    case completed = "Completed"
    case blocked = "Blocked"
    case error = "Error"

    public var badgeColor: Color {
        switch self {
        case .idle: return .secondary
        case .listening: return .indigo
        case .processing: return .purple
        case .awaitingConfirmation: return .orange
        case .completed: return .green
        case .blocked: return .red
        case .error: return .pink
        }
    }

    public var systemIcon: String {
        switch self {
        case .idle: return "waveform"
        case .listening: return "waveform.badge.mic"
        case .processing: return "gearshape.2.fill"
        case .awaitingConfirmation: return "exclamationmark.triangle.fill"
        case .completed: return "checkmark.circle.fill"
        case .blocked: return "hand.raised.fill"
        case .error: return "xmark.octagon.fill"
        }
    }
}

/// Central state coordinator for Javira Assistant.
@MainActor
public final class AssistantViewModel: ObservableObject {
    @Published public var statusState: AssistantStatusState = .idle
    @Published public var statusMessage: String = "Ready. Click 'Start Listening' or run a typed command."
    @Published public var recognizedTranscript: String = ""
    @Published public var lastParsedIntent: AssistantIntent?
    @Published public var approvalState: ApprovalState = .idle
    @Published public var actionHistory: [ActionRecord] = []
    @Published public var typedCommandText: String = ""
    @Published public var configuration: AppConfiguration {
        didSet {
            configuration.save()
            speechRecognition.setupRecognizer(languageCode: configuration.selectedLanguage)
        }
    }
    @Published public var confirmationSecondsRemaining: Int = 0

    // Services
    public let speechRecognition: SpeechRecognitionService
    public let speechSynthesis: SpeechSynthesisService
    public let permissionManager: PermissionManager
    public let commandParser: CommandParser
    public let commandExecutor: CommandExecutor

    private var confirmationTimer: AnyCancellable?
    private var stopListeningWorkItem: DispatchWorkItem?

    public var isListening: Bool {
        speechRecognition.isListening
    }

    public var audioLevel: Float {
        speechRecognition.audioLevel
    }

    public init(
        configuration: AppConfiguration = AppConfiguration.load(),
        speechRecognition: SpeechRecognitionService? = nil,
        speechSynthesis: SpeechSynthesisService? = nil,
        permissionManager: PermissionManager? = nil,
        commandParser: CommandParser = CommandParser(),
        commandExecutor: CommandExecutor = CommandExecutor()
    ) {
        self.configuration = configuration
        self.speechRecognition = speechRecognition ?? SpeechRecognitionService(languageCode: configuration.selectedLanguage)
        self.speechSynthesis = speechSynthesis ?? SpeechSynthesisService()
        self.permissionManager = permissionManager ?? PermissionManager()
        self.commandParser = commandParser
        self.commandExecutor = commandExecutor

        setupRecognitionHandler()
    }

    // MARK: - Voice Listening Control

    public func toggleListening() {
        if isListening {
            stopListening()
        } else {
            startListening()
        }
    }

    public func startListening() {
        permissionManager.refreshStatuses()

        guard permissionManager.allPermissionsGranted else {
            statusState = .error
            statusMessage = "Microphone or Speech Recognition permission required. Check Permissions."
            Task {
                let granted = await permissionManager.requestAllPermissions()
                if granted {
                    self.startListening()
                }
            }
            return
        }

        cancelScheduledListeningStop()

        do {
            try speechRecognition.startListening()
            statusState = .listening
            statusMessage = "Listening for \"Hey Javira\"..."
            recognizedTranscript = ""
        } catch {
            statusState = .error
            statusMessage = "Could not start microphone: \(error.localizedDescription)"
        }
    }

    public func stopListening() {
        cancelScheduledListeningStop()
        speechRecognition.stopListening()
        if statusState == .listening {
            statusState = .idle
            statusMessage = "Ready."
        }
    }

    // MARK: - Speech Transcription Processing

    private func setupRecognitionHandler() {
        speechRecognition.onTranscriptUpdate = { [weak self] transcript, isFinal in
            guard let self = self else { return }
            self.handleSpokenTranscript(transcript, isFinal: isFinal)
        }
    }

    private func handleSpokenTranscript(_ text: String, isFinal: Bool) {
        recognizedTranscript = text

        // If currently waiting for user confirmation (e.g. for sleep)
        if case .pending = approvalState {
            let extracted = commandParser.extractCommand(from: text, requireWakeWord: false)
            let intent = commandParser.parse(command: extracted.extractedCommand)
            if intent == .confirm {
                confirmPendingAction()
                return
            } else if intent == .cancel {
                cancelPendingAction(reason: "Spoken cancellation received.")
                return
            }
            return
        }

        // Standard command listening: strictly requires "Hey Javira"
        let wakeResult = commandParser.extractCommand(from: text, requireWakeWord: true)
        guard wakeResult.hasWakeWord else {
            // Rule 6: Ignore text that does not contain the wake phrase
            return
        }

        let commandBody = wakeResult.extractedCommand
        guard !commandBody.isEmpty else {
            statusState = .listening
            statusMessage = "Hey Javira detected! Say your command..."
            return
        }

        // Process recognized command
        processCommandText(commandBody, rawUtterance: text)
    }

    // MARK: - Command Processing (Voice & Typed)

    public func runTypedCommand(_ overrideText: String? = nil) {
        let text = (overrideText ?? typedCommandText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        typedCommandText = ""
        recognizedTranscript = text

        // In typed mode, "Hey Javira" prefix is optional
        let extractResult = commandParser.extractCommand(from: text, requireWakeWord: false)
        processCommandText(extractResult.extractedCommand, rawUtterance: text)
    }

    private func processCommandText(_ commandText: String, rawUtterance: String) {
        // If awaiting confirmation and user types confirm or cancel
        if case .pending = approvalState {
            let intent = commandParser.parse(command: commandText)
            if intent == .confirm {
                confirmPendingAction()
                return
            } else if intent == .cancel {
                cancelPendingAction(reason: "User cancelled.")
                return
            }
        }

        let intent = commandParser.parse(command: commandText)
        lastParsedIntent = intent

        switch intent {
        case .sleepMac:
            requestSleepConfirmation(rawUtterance: rawUtterance)

        case .confirm:
            if case .pending = approvalState {
                confirmPendingAction()
            } else {
                statusState = .idle
                statusMessage = "No pending action to confirm."
            }

        case .cancel:
            if case .pending = approvalState {
                cancelPendingAction(reason: "User cancelled.")
            } else {
                statusState = .idle
                statusMessage = "No pending action to cancel."
            }

        case .blocked(let reason, _):
            statusState = .blocked
            statusMessage = reason
            speakFeedback("Command blocked for your safety.")
            recordAction(
                raw: rawUtterance,
                intentName: intent.displayName,
                category: .blocked,
                status: .blocked,
                message: reason,
                isLocal: intent.isLocalOnly
            )
            scheduleListeningStop()

        case .unknown(let query):
            statusState = .error
            let msg = query.isEmpty ? "No command detected." : "Javira does not support \"\(query)\" yet."
            statusMessage = msg
            speakFeedback("I don't support that command yet.")
            recordAction(
                raw: rawUtterance,
                intentName: intent.displayName,
                category: .unknown,
                status: .failed,
                message: msg,
                isLocal: intent.isLocalOnly
            )
            scheduleListeningStop()

        default:
            executeAllowedIntent(intent, rawUtterance: rawUtterance)
        }
    }

    private func executeAllowedIntent(_ intent: AssistantIntent, rawUtterance: String) {
        statusState = .processing
        statusMessage = "Executing \(intent.displayName)..."

        Task {
            let result = await commandExecutor.execute(intent: intent, config: configuration)

            self.statusState = result.status == .completed ? .completed : .error
            self.statusMessage = result.displayMessage

            if self.configuration.speechFeedbackEnabled {
                self.speechSynthesis.speak(result.spokenResponse, language: self.configuration.selectedLanguage)
            }

            self.recordAction(
                raw: rawUtterance,
                intentName: intent.displayName,
                category: intent.defaultCategory,
                status: result.status,
                message: result.displayMessage,
                isLocal: result.isLocalOnly
            )

            if self.configuration.stopListeningAfterAction {
                self.scheduleListeningStop()
            }
        }
    }

    // MARK: - Consequential Action Confirmation (Mac Sleep)

    private func requestSleepConfirmation(rawUtterance: String) {
        guard configuration.isSleepEnabled else {
            statusState = .blocked
            statusMessage = "Power management (Sleep) is disabled in Javira Settings."
            speakFeedback("Sleep is disabled in your Javira settings.")
            recordAction(
                raw: rawUtterance,
                intentName: AssistantIntent.sleepMac.displayName,
                category: .blocked,
                status: .blocked,
                message: "Sleep is disabled in settings.",
                isLocal: true
            )
            return
        }

        let timeoutSeconds = configuration.confirmationTimeoutSeconds
        let prompt = "Do you want me to put your Mac to sleep? Say confirm or cancel."

        approvalState = .pending(
            intent: .sleepMac,
            expiresAt: Date().addingTimeInterval(TimeInterval(timeoutSeconds)),
            secondsRemaining: timeoutSeconds
        )
        confirmationSecondsRemaining = timeoutSeconds

        statusState = .awaitingConfirmation
        statusMessage = prompt
        speakFeedback(prompt)

        // Start 10-second automatic cancellation timer
        confirmationTimer?.cancel()
        confirmationTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.confirmationSecondsRemaining > 1 {
                    self.confirmationSecondsRemaining -= 1
                    if case .pending(let intent, let expires, _) = self.approvalState {
                        self.approvalState = .pending(intent: intent, expiresAt: expires, secondsRemaining: self.confirmationSecondsRemaining)
                    }
                } else {
                    self.cancelPendingAction(reason: "Confirmation timed out after \(timeoutSeconds) seconds.")
                }
            }
    }

    public func confirmPendingAction() {
        guard case .pending(let intent, _, _) = approvalState else { return }
        confirmationTimer?.cancel()
        confirmationTimer = nil

        approvalState = .confirmed(intent: intent)

        if intent == .sleepMac {
            statusState = .completed
            statusMessage = "Putting your Mac to sleep now."
            speakFeedback("Putting your Mac to sleep now.")

            recordAction(
                raw: "confirm",
                intentName: intent.displayName,
                category: .confirmRequired,
                status: .completed,
                message: "Mac sleep confirmed and executed.",
                isLocal: true
            )

            // Execute verified sleep
            let sleepResult = commandExecutor.executeConfirmedSleep()
            self.statusMessage = sleepResult.displayMessage

            stopListening()
        }
    }

    public func cancelPendingAction(reason: String = "User cancelled.") {
        confirmationTimer?.cancel()
        confirmationTimer = nil

        approvalState = .cancelled(reason: reason)
        statusState = .idle
        statusMessage = "Sleep cancelled."
        speakFeedback("Sleep cancelled.")

        recordAction(
            raw: "cancel",
            intentName: AssistantIntent.sleepMac.displayName,
            category: .confirmRequired,
            status: .cancelled,
            message: reason,
            isLocal: true
        )

        scheduleListeningStop()
    }

    // MARK: - Action History & Privacy

    private func recordAction(raw: String, intentName: String, category: PolicyCategory, status: ActionStatus, message: String, isLocal: Bool) {
        let record = ActionRecord(
            rawCommand: raw,
            intentName: intentName,
            category: category,
            status: status,
            message: message,
            isLocalOnly: isLocal
        )
        actionHistory.insert(record, at: 0)
    }

    public func clearHistory() {
        actionHistory.removeAll()
    }

    // MARK: - Helpers

    private func speakFeedback(_ text: String) {
        guard configuration.speechFeedbackEnabled else { return }
        speechSynthesis.speak(text, language: configuration.selectedLanguage)
    }

    private func scheduleListeningStop() {
        stopListeningWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.stopListening()
        }
        stopListeningWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func cancelScheduledListeningStop() {
        stopListeningWorkItem?.cancel()
        stopListeningWorkItem = nil
    }
}
