import Foundation

/// Result of extracting a command from speech input.
public struct WakeWordResult: Equatable, Sendable {
    public let hasWakeWord: Bool
    public let extractedCommand: String
}

/// Deterministic, non-LLM command parser for Javira.
/// Parses spoken transcripts and typed input safely without arbitrary code execution.
public struct CommandParser: Sendable {
    public static let wakePhrases = ["hey javira", "hey yavira", "hey javiera", "javira"]

    public init() {}

    /// Extracts the command body after the wake phrase.
    /// Returns `hasWakeWord: false` if no wake word was found and `requireWakeWord` is true.
    public func extractCommand(from rawText: String, requireWakeWord: Bool) -> WakeWordResult {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WakeWordResult(hasWakeWord: false, extractedCommand: "")
        }

        // Match wake phrases like "Hey Javira", "Hey, Javira", "Javira", "Hey Yavira" with optional leading/intervening punctuation
        let pattern = #"^(hey\s*[,.]?\s*)?(javira|yavira|javiera)\b[:,\s-]*"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
           let match = regex.firstMatch(in: trimmed, options: [], range: NSRange(trimmed.startIndex..., in: trimmed)),
           match.range.location == 0,
           let matchedRange = Range(match.range, in: trimmed) {
            var afterWake = String(trimmed[matchedRange.upperBound...])
            afterWake = afterWake.trimmingCharacters(in: .whitespacesAndNewlines)
            return WakeWordResult(hasWakeWord: true, extractedCommand: afterWake)
        }

        // If wake phrase is optional (e.g. typed command field or confirmation flow)
        if !requireWakeWord {
            return WakeWordResult(hasWakeWord: false, extractedCommand: trimmed)
        }

        return WakeWordResult(hasWakeWord: false, extractedCommand: "")
    }

    /// Parses an extracted command string into a strongly-typed `AssistantIntent`.
    public func parse(command: String) -> AssistantIntent {
        let cleaned = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            return .unknown(query: "")
        }

        let lower = cleaned.lowercased()

        // 1. Safety Checks: Block dangerous or unauthorized requests immediately
        if let blockedIntent = detectBlockedCommand(in: lower, original: cleaned) {
            return blockedIntent
        }

        // 2. Consequential Confirmations (e.g. answering a pending confirmation prompt)
        if isConfirmation(lower) {
            return .confirm
        }
        if isCancellation(lower) {
            return .cancel
        }

        // 3. Gmail navigation (strictly opens mail.google.com in browser)
        if matchesGmail(lower) {
            return .openGmail
        }

        // 4. Approved application launches
        if let app = matchesApprovedApp(lower) {
            return .openApp(app)
        }

        // 5. Volume controls
        if let volumeIntent = matchesVolumeControl(lower) {
            return volumeIntent
        }

        // 6. Consequential Actions (Mac Sleep)
        if matchesSleep(lower) {
            return .sleepMac
        }

        // 7. Fallback: Unknown command
        return .unknown(query: cleaned)
    }

    // MARK: - Safety Block Detection

    private func detectBlockedCommand(in lower: String, original: String) -> AssistantIntent? {
        // Disallowed apps: Terminal, iTerm, Console, Activity Monitor, etc.
        if lower.contains("terminal") || lower.contains("iterm") || lower.contains("bash") || lower.contains("zsh") {
            return .blocked(reason: "Terminal and shell execution are blocked for safety.", originalCommand: original)
        }

        // Arbitrary shell / command execution
        let shellTokens = ["sudo", "rm ", "rmdir", "chmod", "chown", "curl", "wget", "kill", "killall", "exec", "sh "]
        for token in shellTokens {
            if lower.contains(token) {
                return .blocked(reason: "Shell command execution is strictly blocked.", originalCommand: original)
            }
        }

        // File deletion and system destruction
        let destructiveTokens = ["delete", "erase", "trash file", "remove file", "format drive", "wipe disk", "purge"]
        for token in destructiveTokens {
            if lower.contains(token) {
                return .blocked(reason: "File deletion and destructive actions are blocked.", originalCommand: original)
            }
        }

        // Passwords, OTPs, credentials, private tokens
        let credentialTokens = ["password", "passcode", "otp", "keychain", "api key", "secret token", "private key", "credential", "cookie"]
        for token in credentialTokens {
            if lower.contains(token) {
                return .blocked(reason: "Credential and secret access is strictly prohibited.", originalCommand: original)
            }
        }

        // Sending email, money, payments
        let sensitiveActions = ["send email", "compose email", "write email", "send message", "pay", "purchase", "wire money", "transfer money"]
        for action in sensitiveActions {
            if lower.contains(action) {
                return .blocked(reason: "Automated communication and financial transactions are blocked in MVP.", originalCommand: original)
            }
        }

        // Unsupported consequential power commands
        let forbiddenPower = ["shutdown", "restart", "reboot", "lock screen", "lock mac"]
        for power in forbiddenPower {
            if lower.contains(power) {
                return .blocked(reason: "\(power.capitalized) is not supported in the MVP. Only sleep with confirmation is permitted.", originalCommand: original)
            }
        }

        return nil
    }

    // MARK: - Matching Helpers

    private func isConfirmation(_ lower: String) -> Bool {
        let yesTokens = ["confirm", "yes", "proceed", "do it", "sure", "ok", "affirmative", "yep", "confirm sleep"]
        return yesTokens.contains(lower)
    }

    private func isCancellation(_ lower: String) -> Bool {
        let noTokens = ["cancel", "no", "abort", "stop", "don't", "dont", "never mind", "negative", "cancel sleep"]
        return noTokens.contains(lower)
    }

    private func matchesGmail(_ lower: String) -> Bool {
        let patterns = [
            "open gmail", "launch gmail", "go to gmail", "show gmail",
            "open google mail", "launch google mail"
        ]
        return patterns.contains(lower) || lower.hasPrefix("open gmail")
    }

    private func matchesApprovedApp(_ lower: String) -> ApprovedApp? {
        // Strip common command prefixes like "open", "launch", "start"
        var target = lower
        for prefix in ["open ", "launch ", "start ", "show "] {
            if target.hasPrefix(prefix) {
                target = String(target.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        switch target {
        case "chrome", "google chrome":
            return .chrome
        case "safari", "apple safari":
            return .safari
        case "calendar", "apple calendar", "ical":
            return .calendar
        case "mail", "apple mail":
            return .mail
        case "finder", "apple finder", "my files":
            // Note: Finder is safe app, "my files" alone without delete
            if !lower.contains("delete") {
                return .finder
            }
            return nil
        default:
            return nil
        }
    }

    private func matchesVolumeControl(_ lower: String) -> AssistantIntent? {
        if lower == "mute" || lower == "mute volume" || lower == "mute sound" || lower == "mute audio" || lower == "silence" {
            return .mute
        }
        if lower == "unmute" || lower == "unmute volume" || lower == "unmute sound" || lower == "unmute audio" {
            return .unmute
        }
        if lower.contains("increase volume") || lower.contains("volume up") || lower.contains("turn up volume") || lower.contains("raise volume") || lower.contains("louder") {
            return .increaseVolume(step: 10)
        }
        if lower.contains("decrease volume") || lower.contains("volume down") || lower.contains("turn down volume") || lower.contains("lower volume") || lower.contains("quieter") {
            return .decreaseVolume(step: 10)
        }

        // Patterns: "set volume to 40 percent", "set volume to 40", "volume to 40 percent", "turn volume to 40%"
        if lower.contains("volume") {
            let digits = lower.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if let firstDigits = digits.first, let value = Int(firstDigits) {
                // Clamped to 0...100
                let clamped = max(0, min(100, value))
                return .setVolume(percentage: clamped)
            }
        }

        return nil
    }

    private func matchesSleep(_ lower: String) -> Bool {
        let sleepPatterns = [
            "sleep my mac", "sleep mac", "sleep", "put my mac to sleep",
            "put mac to sleep", "mac sleep", "go to sleep"
        ]
        return sleepPatterns.contains(lower)
    }
}
