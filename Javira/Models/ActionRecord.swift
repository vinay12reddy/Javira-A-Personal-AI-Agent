import Foundation

/// Status of an executed or attempted assistant action.
public enum ActionStatus: String, Codable, Equatable, Sendable {
    case completed = "Completed"
    case pendingConfirmation = "Awaiting Confirmation"
    case blocked = "Blocked"
    case cancelled = "Cancelled"
    case failed = "Failed"
}

/// A privacy-preserving record of an assistant action.
/// Strictly avoids storing raw audio, sensitive keys, or transcripts.
public struct ActionRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let rawCommand: String
    public let intentName: String
    public let category: PolicyCategory
    public let status: ActionStatus
    public let message: String
    public let isLocalOnly: Bool

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        rawCommand: String,
        intentName: String,
        category: PolicyCategory,
        status: ActionStatus,
        message: String,
        isLocalOnly: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.rawCommand = rawCommand
        self.intentName = intentName
        self.category = category
        self.status = status
        self.message = message
        self.isLocalOnly = isLocalOnly
    }
}
