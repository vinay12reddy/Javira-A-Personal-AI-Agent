import SwiftUI

/// Main assistant window view for Javira.
public struct ContentView: View {
    @EnvironmentObject private var viewModel: AssistantViewModel
    @State private var showSettingsSheet = false
    @State private var showPermissionsSheet = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 1. App Header & Privacy Badge
                headerSection

                // 2. Permission Banner (if not granted)
                if !viewModel.permissionManager.allPermissionsGranted {
                    permissionBanner
                }

                // 3. Listening Status & Waveform Visualizer
                listeningVisualizerSection

                // 4. Consequential Action Confirmation Card (Sleep Mac)
                if viewModel.approvalState.isPending {
                    confirmationCard
                }

                // 5. Typed-Command Test Field (Runnable even without microphone)
                typedCommandSection

                // 6. Real-time Transcript & Parsed Intent Cards
                transcriptAndIntentSection

                // 7. Action History
                ActionHistoryView()
                    .padding(.top, 4)

                // 8. Mandatory Privacy Notice
                privacyNoticeFooter
            }
            .padding(20)
        }
        .frame(minWidth: 580, idealWidth: 620, minHeight: 700, idealHeight: 760)
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showPermissionsSheet) {
            PermissionView()
                .environmentObject(viewModel)
        }
    }

    // MARK: - 1. Header Section

    private var headerSection: some View {
        HStack {
            // Javira Brand Icon & Name
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: .indigo.opacity(0.4), radius: 6, x: 0, y: 3)

                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Javira")
                            .font(.title2.bold())
                        Text("MVP")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.indigo.opacity(0.18)))
                            .foregroundColor(.indigo)
                    }

                    Text("Personal Voice Assistant for macOS")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 100% Local Processing Pill
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                Text("100% On-Device")
                    .font(.caption.bold())
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.green.opacity(0.15)))
            .foregroundColor(.green)

            // Settings & Permissions Buttons
            Button(action: { showPermissionsSheet = true }) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 13))
            }
            .help("Permissions & Privacy Settings")
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: { showSettingsSheet = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
            }
            .help("Assistant Settings")
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - 2. Permission Banner

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Microphone / Speech Permissions Required for Voice")
                    .font(.subheadline.bold())
                Text("You can still use typed-command mode below while permissions are pending.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Review Permissions") {
                showPermissionsSheet = true
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.orange)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        )
    }

    // MARK: - 3. Listening Visualizer Section

    private var listeningVisualizerSection: some View {
        VStack(spacing: 12) {
            // Status Pill & Icon
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.statusState.systemIcon)
                        .font(.system(size: 12, weight: .bold))
                    Text(viewModel.statusState.rawValue.uppercased())
                        .font(.caption.bold())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(viewModel.statusState.badgeColor.opacity(0.18)))
                .foregroundColor(viewModel.statusState.badgeColor)

                Spacer()

                if viewModel.isListening {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("MIC ACTIVE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.red)
                    }
                }
            }

            // Audio Waveform / Visualizer
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))

                if viewModel.isListening {
                    HStack(spacing: 4) {
                        ForEach(0..<19) { index in
                            VisualizerBar(level: viewModel.audioLevel, index: index)
                        }
                    }
                    .padding(.horizontal, 20)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "mic.slash")
                            .foregroundColor(.secondary)
                        Text("Microphone idle. Click Start Listening or say \"Hey Javira\".")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(height: 56)

            // Status message
            Text(viewModel.statusMessage)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            // Start / Stop Listening Button
            Button(action: {
                viewModel.toggleListening()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isListening ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 18))
                    Text(viewModel.isListening ? "Stop Listening" : "Start Listening")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isListening ? .red : .indigo)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(viewModel.isListening ? Color.indigo.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1.5)
                )
        )
    }

    // MARK: - 4. Consequential Action Confirmation Card (Sleep Mac)

    private var confirmationCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Confirmation Required: Put Mac to Sleep")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("“Do you want me to put your Mac to sleep? Say confirm or cancel.”")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Countdown badge
                Text("\(viewModel.confirmationSecondsRemaining)s")
                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                    .foregroundColor(.orange)
                    .padding(8)
                    .background(Circle().fill(Color.orange.opacity(0.18)))
            }

            // Progress bar
            ProgressView(value: Double(viewModel.confirmationSecondsRemaining), total: Double(viewModel.configuration.confirmationTimeoutSeconds))
                .tint(.orange)

            HStack(spacing: 12) {
                Button(action: {
                    viewModel.confirmPendingAction()
                }) {
                    Label("Confirm (Sleep Mac)", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .keyboardShortcut(.defaultAction)

                Button(action: {
                    viewModel.cancelPendingAction(reason: "Clicked cancel.")
                }) {
                    Label("Cancel", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.orange.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.4), lineWidth: 1.5))
        )
    }

    // MARK: - 5. Typed-Command Test Field

    private var typedCommandSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Typed Command Test Mode", systemImage: "keyboard")
                .font(.headline)

            HStack(spacing: 8) {
                TextField("Type a command (e.g. \"Hey Javira, open Gmail\" or \"set volume to 40 percent\")...", text: $viewModel.typedCommandText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        viewModel.runTypedCommand()
                    }

                Button(action: {
                    viewModel.runTypedCommand()
                }) {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .disabled(viewModel.typedCommandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            // Preset Test Chips
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Test Presets:")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        PresetChip(title: "Open Gmail", prompt: "Hey Javira, open Gmail")
                        PresetChip(title: "Open Chrome", prompt: "Hey Javira, open Chrome")
                        PresetChip(title: "Open Safari", prompt: "Hey Javira, open Safari")
                        PresetChip(title: "Volume 40%", prompt: "Hey Javira, set volume to 40 percent")
                        PresetChip(title: "Mute", prompt: "Hey Javira, mute")
                        PresetChip(title: "Sleep Mac", prompt: "Hey Javira, sleep my Mac")
                        PresetChip(title: "Test Blocked (Files)", prompt: "Hey Javira, delete my files", isBlocked: true)
                        PresetChip(title: "Test Blocked (Terminal)", prompt: "Hey Javira, open Terminal", isBlocked: true)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
        )
    }

    // MARK: - 6. Transcript & Parsed Intent Section

    private var transcriptAndIntentSection: some View {
        HStack(alignment: .top, spacing: 12) {
            // Recognized Transcript Card
            VStack(alignment: .leading, spacing: 6) {
                Label("Recognized Transcript", systemImage: "quote.bubble")
                    .font(.subheadline.bold())

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))

                    if viewModel.recognizedTranscript.isEmpty {
                        Text("Speak or enter a command above to see recognized transcript.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(10)
                    } else {
                        Text(viewModel.recognizedTranscript)
                            .font(.system(size: 13, design: .rounded))
                            .padding(10)
                    }
                }
                .frame(minHeight: 52)
            }
            .frame(maxWidth: .infinity)

            // Parsed Intent Card
            VStack(alignment: .leading, spacing: 6) {
                Label("Parsed Intent", systemImage: "sparkles")
                    .font(.subheadline.bold())

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))

                    if let intent = viewModel.lastParsedIntent {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(intent.displayName)
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                                // Locality
                                Text(intent.isLocalOnly ? "Fully Local" : "Requires Internet")
                                    .font(.system(size: 9, weight: .semibold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(intent.isLocalOnly ? Color.blue.opacity(0.15) : Color.teal.opacity(0.15)))
                                    .foregroundColor(intent.isLocalOnly ? .blue : .teal)
                            }

                            Text(intent.defaultCategory.rawValue)
                                .font(.caption2.bold())
                                .foregroundColor(categoryColor(for: intent.defaultCategory))
                        }
                        .padding(10)
                    } else {
                        Text("No intent parsed yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(10)
                    }
                }
                .frame(minHeight: 52)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func categoryColor(for cat: PolicyCategory) -> Color {
        switch cat {
        case .allowed: return .green
        case .confirmRequired: return .orange
        case .blocked: return .red
        case .unknown: return .secondary
        }
    }

    // MARK: - 8. Privacy Notice Footer

    private var privacyNoticeFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
                .font(.system(size: 14))

            Text("Privacy Guaranteed: On-device speech recognition. Zero cloud audio. Passwords, terminal execution, and destructive commands are permanently disabled.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
    }
}

// MARK: - Supporting Subviews

struct PresetChip: View {
    @EnvironmentObject private var viewModel: AssistantViewModel
    let title: String
    let prompt: String
    var isBlocked: Bool = false

    var body: some View {
        Button(action: {
            viewModel.runTypedCommand(prompt)
        }) {
            HStack(spacing: 4) {
                if isBlocked {
                    Image(systemName: "shield.slash.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.red)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

struct VisualizerBar: View {
    let level: Float
    let index: Int

    var body: some View {
        let curve: [Float] = [
            0.2, 0.4, 0.6, 0.8, 1.0, 1.3, 1.5, 1.8, 2.0,
            2.2,
            2.0, 1.8, 1.5, 1.3, 1.0, 0.8, 0.6, 0.4, 0.2
        ]
        let factor = curve[index % curve.count]
        let height = max(4.0, CGFloat(level * factor * 42.0))

        RoundedRectangle(cornerRadius: 3)
            .fill(
                LinearGradient(
                    colors: [.indigo, .purple],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 4, height: height)
            .animation(.easeInOut(duration: 0.08), value: level)
    }
}
