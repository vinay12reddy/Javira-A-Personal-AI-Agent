import Foundation
import Speech
import AVFoundation

/// Manages on-device voice capture and transcription using AVAudioEngine and SFSpeechRecognizer.
///
/// SAFETY & PRIVACY MANDATE:
/// 1. Uses ONLY on-device speech recognition (requiresOnDeviceRecognition = true).
/// 2. Audio is processed strictly in-memory; raw audio is NEVER uploaded or saved to disk.
/// 3. If on-device recognition is unavailable for the chosen language, an error is displayed
///    rather than silently falling back to cloud transcription.
@MainActor
public final class SpeechRecognitionService: ObservableObject {
    @Published public private(set) var isListening: Bool = false
    @Published public private(set) var currentTranscript: String = ""
    @Published public private(set) var audioLevel: Float = 0.0
    @Published public private(set) var isOnDeviceSupported: Bool = true
    @Published public var errorMessage: String?

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    public var onTranscriptUpdate: ((String, Bool) -> Void)?

    public init(languageCode: String = "en-US") {
        setupRecognizer(languageCode: languageCode)
    }

    /// Configures the speech recognizer for the specified locale and checks on-device capability.
    public func setupRecognizer(languageCode: String) {
        let locale = Locale(identifier: languageCode)
        speechRecognizer = SFSpeechRecognizer(locale: locale)

        if let recognizer = speechRecognizer {
            isOnDeviceSupported = recognizer.supportsOnDeviceRecognition
            if !isOnDeviceSupported {
                errorMessage = "On-device speech recognition is not supported for locale '\(languageCode)'. Local privacy rule requires on-device support."
            } else {
                errorMessage = nil
            }
        } else {
            isOnDeviceSupported = false
            errorMessage = "Speech recognizer could not be initialized for locale '\(languageCode)'."
        }
    }

    /// Starts audio recording and real-time on-device speech recognition.
    public func startListening() throws {
        guard !isListening else { return }

        // Ensure clean state
        stopListening()
        errorMessage = nil
        currentTranscript = ""

        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            let msg = "Speech recognizer is currently unavailable."
            errorMessage = msg
            throw ActionError.executionFailed(msg)
        }

        guard recognizer.supportsOnDeviceRecognition else {
            let msg = "On-device recognition is required but unsupported for this language."
            errorMessage = msg
            throw ActionError.permissionDenied(msg)
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        // Strict privacy requirement: on-device only, never cloud
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true

        self.recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Install tap to stream audio buffers to recognizer and meter audio levels
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            request.append(buffer)
            self?.calculateAudioLevel(from: buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isListening = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result = result {
                    let text = result.bestTranscription.formattedString
                    self.currentTranscript = text
                    self.onTranscriptUpdate?(text, result.isFinal)
                }

                if let error = error {
                    // Ignore normal cancellation errors
                    let nsError = error as NSError
                    if nsError.domain != "kAFAssistantErrorDomain" || nsError.code != 203 {
                        // User cancelled or normal timeout is expected; report other failures
                        if self.isListening {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                    self.stopListening()
                }
            }
        }
    }

    /// Stops audio capture and speech recognition cleanly.
    public func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        isListening = false
        audioLevel = 0.0
    }

    // MARK: - Audio Level Metering

    private nonisolated func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let channelDataValue = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))

        var sum: Float = 0.0
        for sample in channelDataValue {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        // Normalize RMS to a 0.0 ... 1.0 range with logarithmic curve
        let avgPower = 20 * log10(max(rms, 0.0001))
        let level = max(0.0, min(1.0, (avgPower + 50) / 50.0))

        Task { @MainActor [weak self] in
            self?.audioLevel = level
        }
    }
}
