import Foundation
import AVFoundation
import Speech
import AppKit

public enum PermissionStatus: String, Sendable {
    case notDetermined = "Not Determined"
    case authorized = "Authorized"
    case denied = "Denied"
    case restricted = "Restricted"

    public var isGranted: Bool {
        self == .authorized
    }
}

/// Manages system permissions for Microphone recording and Speech Recognition.
@MainActor
public final class PermissionManager: ObservableObject {
    @Published public private(set) var microphoneStatus: PermissionStatus = .notDetermined
    @Published public private(set) var speechStatus: PermissionStatus = .notDetermined

    public var allPermissionsGranted: Bool {
        microphoneStatus.isGranted && speechStatus.isGranted
    }

    public init() {
        refreshStatuses()
    }

    /// Checks the current authorization state from system frameworks.
    public func refreshStatuses() {
        // Microphone status
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .authorized
        case .denied:
            microphoneStatus = .denied
        case .restricted:
            microphoneStatus = .restricted
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .denied
        }

        // Speech recognition status
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechStatus = .authorized
        case .denied:
            speechStatus = .denied
        case .restricted:
            speechStatus = .restricted
        case .notDetermined:
            speechStatus = .notDetermined
        @unknown default:
            speechStatus = .denied
        }
    }

    /// Requests Microphone access from macOS.
    public func requestMicrophonePermission() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { result in
                continuation.resume(returning: result)
            }
        }
        refreshStatuses()
        return granted
    }

    /// Requests Speech Recognition access from macOS.
    public func requestSpeechRecognitionPermission() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus == .authorized)
            }
        }
        refreshStatuses()
        return granted
    }

    /// Requests both permissions sequentially.
    public func requestAllPermissions() async -> Bool {
        let mic = await requestMicrophonePermission()
        let speech = await requestSpeechRecognitionPermission()
        return mic && speech
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Microphone.
    public func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Opens macOS System Settings directly to Privacy & Security -> Speech Recognition.
    public func openSpeechRecognitionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
    }
}
