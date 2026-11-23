import Foundation

/// Represents the state of explicit user approval for consequential actions (such as putting the Mac to sleep).
public enum ApprovalState: Equatable, Sendable {
    case idle
    case pending(intent: AssistantIntent, expiresAt: Date, secondsRemaining: Int)
    case confirmed(intent: AssistantIntent)
    case cancelled(reason: String)
    case timedOut

    public var isPending: Bool {
        if case .pending = self { return true }
        return false
    }

    public var pendingIntent: AssistantIntent? {
        if case .pending(let intent, _, _) = self {
            return intent
        }
        return nil
    }

    public var secondsRemaining: Int {
        if case .pending(_, _, let secs) = self {
            return max(0, secs)
        }
        return 0
    }
}
