import SwiftUI
import AppKit

/// Compact popover menu bar interface for quick status and listening toggles.
public struct MenuBarView: View {
    @EnvironmentObject private var viewModel: AssistantViewModel
    @Environment(\.openWindow) private var openWindow

    public init() {}

    public var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Circle()
                    .fill(viewModel.statusState.badgeColor)
                    .frame(width: 8, height: 8)
                Text("Javira Assistant")
                    .font(.headline)
                Spacer()
                Text(viewModel.statusState.rawValue)
                    .font(.caption)
                    .foregroundColor(viewModel.statusState.badgeColor)
            }

            // Waveform / Listening Visualizer
            if viewModel.isListening {
                VStack(spacing: 6) {
                    HStack(spacing: 3) {
                        ForEach(0..<9) { index in
                            WaveformBar(level: viewModel.audioLevel, index: index)
                        }
                    }
                    .frame(height: 24)
                    Text("Listening for \"Hey Javira\"...")
                        .font(.caption2)
                        .foregroundColor(.indigo)
                }
                .padding(.vertical, 4)
            }

            // Quick Status
            Text(viewModel.statusMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .lineLimit(2)

            // Primary Action Button
            Button(action: {
                viewModel.toggleListening()
            }) {
                HStack {
                    Image(systemName: viewModel.isListening ? "stop.fill" : "mic.fill")
                    Text(viewModel.isListening ? "Stop Listening" : "Start Listening")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isListening ? .red : .indigo)

            Divider()

            // Footer Actions
            HStack {
                Button("Open Assistant") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "main")
                }
                .buttonStyle(.borderless)
                .font(.caption)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }
}

struct WaveformBar: View {
    let level: Float
    let index: Int

    var body: some View {
        let multipliers: [Float] = [0.4, 0.7, 1.0, 1.3, 1.6, 1.3, 1.0, 0.7, 0.4]
        let height = max(4.0, CGFloat(level * multipliers[index % multipliers.count] * 22.0))

        RoundedRectangle(cornerRadius: 2)
            .fill(Color.indigo)
            .frame(width: 3, height: height)
            .animation(.easeInOut(duration: 0.1), value: level)
    }
}
