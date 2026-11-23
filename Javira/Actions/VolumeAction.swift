import Foundation

/// Controls system output volume and mute status safely.
///
/// SAFETY MANDATE:
/// All inputs are strictly checked and clamped numeric values (0...100).
/// Fixed, internally constructed AppleScripts are used; voice input is NEVER concatenated into scripts.
public struct VolumeAction: Sendable {
    public init() {}

    /// Retrieves current system output volume (0 to 100).
    public func getCurrentVolume() -> Int? {
        let script = "output volume of (get volume settings)"
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var errorDict: NSDictionary?
        let output = appleScript.executeAndReturnError(&errorDict)
        if errorDict == nil {
            return Int(output.int32Value)
        }
        return nil
    }

    /// Retrieves current system mute state.
    public func isMuted() -> Bool? {
        let script = "output muted of (get volume settings)"
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var errorDict: NSDictionary?
        let output = appleScript.executeAndReturnError(&errorDict)
        if errorDict == nil {
            return output.booleanValue
        }
        return nil
    }

    /// Sets system volume to an exact percentage (clamped to 0...100).
    public func setVolume(percentage: Int) -> Result<Int, ActionError> {
        let clamped = max(0, min(100, percentage))
        // Fixed script template using sanitized integer
        let script = "set volume output volume \(clamped)"
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(.executionFailed("Could not initialize volume AppleScript."))
        }

        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let desc = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            return .failure(.executionFailed("Volume adjustment failed: \(desc)"))
        }

        return .success(clamped)
    }

    /// Adjusts volume relatively by a given step (positive or negative).
    public func adjustVolume(by step: Int) -> Result<Int, ActionError> {
        let current = getCurrentVolume() ?? 50
        let target = max(0, min(100, current + step))
        return setVolume(percentage: target)
    }

    /// Sets system mute state.
    public func setMuted(_ muted: Bool) -> Result<Bool, ActionError> {
        let script = muted ? "set volume with output muted" : "set volume without output muted"
        guard let appleScript = NSAppleScript(source: script) else {
            return .failure(.executionFailed("Could not initialize mute AppleScript."))
        }

        var errorDict: NSDictionary?
        appleScript.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let desc = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
            return .failure(.executionFailed("Mute change failed: \(desc)"))
        }

        return .success(muted)
    }
}
