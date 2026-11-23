import SwiftUI

/// Displays chronological history of assistant interactions.
/// Privacy rule: raw audio is never recorded; only minimal event metadata is shown.
public struct ActionHistoryView: View {
    @EnvironmentObject private var viewModel: AssistantViewModel

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Action History", systemImage: "clock.arrow.circlepath")
                    .font(.headline)

                Spacer()

                if !viewModel.actionHistory.isEmpty {
                    Button(role: .destructive, action: {
                        viewModel.clearHistory()
                    }) {
                        Label("Clear History", systemImage: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Permanently clear local history log")
                }
            }

            if viewModel.actionHistory.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary.opacity(0.6))
                        Text("No actions logged yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.actionHistory) { record in
                            ActionRowView(record: record)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
    }
}

struct ActionRowView: View {
    let record: ActionRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Status Icon
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(statusColor)
                .frame(width: 20, height: 20)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.intentName)
                        .font(.system(size: 13, weight: .semibold))

                    Spacer()

                    // Locality Badge
                    Text(record.isLocalOnly ? "Fully Local" : "Requires Internet")
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(record.isLocalOnly ? Color.blue.opacity(0.15) : Color.teal.opacity(0.15))
                        )
                        .foregroundColor(record.isLocalOnly ? .blue : .teal)

                    // Status Badge
                    Text(record.status.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(statusColor.opacity(0.15))
                        )
                        .foregroundColor(statusColor)

                    Text(record.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                if !record.rawCommand.isEmpty {
                    Text("\"\(record.rawCommand)\"")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Text(record.message)
                    .font(.system(size: 11))
                    .foregroundColor(.primary.opacity(0.85))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }

    private var statusColor: Color {
        switch record.status {
        case .completed: return .green
        case .pendingConfirmation: return .orange
        case .blocked: return .red
        case .cancelled: return .gray
        case .failed: return .pink
        }
    }

    private var statusIcon: String {
        switch record.status {
        case .completed: return "checkmark.circle.fill"
        case .pendingConfirmation: return "exclamationmark.circle.fill"
        case .blocked: return "hand.raised.fill"
        case .cancelled: return "xmark.circle"
        case .failed: return "xmark.octagon.fill"
        }
    }
}
