import SwiftUI

/// Displays permission status and guided instructions for Microphone and Speech Recognition.
public struct PermissionView: View {
    @EnvironmentObject private var viewModel: AssistantViewModel
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Privacy & Permissions", systemImage: "hand.raised.square.fill")
                    .font(.title3.bold())
                    .foregroundColor(.indigo)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            Text("Javira processes all voice commands locally on Apple Silicon. To listen and recognize your voice without sending audio to the cloud, Javira requires these macOS permissions:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Divider()

            // Microphone Permission Row
            PermissionRow(
                title: "Microphone Access",
                subtitle: "Captures your audio stream locally for wake-phrase and command analysis.",
                icon: "mic.fill",
                status: viewModel.permissionManager.microphoneStatus,
                onRequest: {
                    Task {
                        _ = await viewModel.permissionManager.requestMicrophonePermission()
                    }
                },
                onOpenSettings: {
                    viewModel.permissionManager.openMicrophoneSettings()
                }
            )

            // Speech Recognition Permission Row
            PermissionRow(
                title: "On-Device Speech Recognition",
                subtitle: "Transcribes spoken phrases into text on your Mac using SFSpeechRecognizer.",
                icon: "waveform.badge.mic",
                status: viewModel.permissionManager.speechStatus,
                onRequest: {
                    Task {
                        _ = await viewModel.permissionManager.requestSpeechRecognitionPermission()
                    }
                },
                onOpenSettings: {
                    viewModel.permissionManager.openSpeechRecognitionSettings()
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Manual Adjustment in macOS Settings:")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text("• System Settings → Privacy & Security → Microphone → Enable Javira")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• System Settings → Privacy & Security → Speech Recognition → Enable Javira")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
            )

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 380)
        .onAppear {
            viewModel.permissionManager.refreshStatuses()
        }
    }
}

struct PermissionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let status: PermissionStatus
    let onRequest: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.indigo)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))

                    Spacer()

                    StatusBadge(status: status)
                }

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    if !status.isGranted {
                        Button("Request Access") {
                            onRequest()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("Open Settings") {
                            onOpenSettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else {
                        Label("Granted", systemImage: "checkmark")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
        )
    }
}

struct StatusBadge: View {
    let status: PermissionStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(badgeColor.opacity(0.18))
            )
            .foregroundColor(badgeColor)
    }

    private var badgeColor: Color {
        switch status {
        case .authorized: return .green
        case .denied: return .red
        case .restricted: return .orange
        case .notDetermined: return .secondary
        }
    }
}
