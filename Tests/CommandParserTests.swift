import Foundation

/// Lightweight test assertion framework compatible with command line Swift and Xcode.
public struct TestRunner {
    public private(set) var passedCount = 0
    public private(set) var failedCount = 0
    public private(set) var failureMessages: [String] = []

    public init() {}

    public mutating func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: String = #file, line: Int = #line) {
        if actual == expected {
            passedCount += 1
        } else {
            failedCount += 1
            let failMsg = "❌ Failed: expected [\(expected)], got [\(actual)] - \(message) (\(file):\(line))"
            failureMessages.append(failMsg)
            print(failMsg)
        }
    }

    public mutating func assertTrue(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        if condition {
            passedCount += 1
        } else {
            failedCount += 1
            let failMsg = "❌ Failed: expected true - \(message) (\(file):\(line))"
            failureMessages.append(failMsg)
            print(failMsg)
        }
    }

    public mutating func assertFalse(_ condition: Bool, _ message: String = "", file: String = #file, line: Int = #line) {
        assertTrue(!condition, message, file: file, line: line)
    }
}

@main
public struct CommandParserTests {
    public static func main() {
        print("==================================================")
        print(" Running Javira Command & Policy Test Suite...")
        print("==================================================")

        var runner = TestRunner()

        testWakePhraseExtraction(&runner)
        testAppLaunchParsing(&runner)
        testGmailParsing(&runner)
        testVolumeParsing(&runner)
        testSleepAndConfirmationParsing(&runner)
        testSafetyBlockedCommands(&runner)
        testPolicyEvaluation(&runner)
        testLocalityGuarantees(&runner)

        print("--------------------------------------------------")
        print("Test Results: \(runner.passedCount) PASSED, \(runner.failedCount) FAILED")
        print("==================================================")

        if runner.failedCount > 0 {
            print("❌ Some tests failed:")
            for msg in runner.failureMessages {
                print("  \(msg)")
            }
            exit(1)
        } else {
            print("✅ All \(runner.passedCount) tests passed successfully!")
            exit(0)
        }
    }

    // MARK: - 1. Wake Phrase Extraction

    static func testWakePhraseExtraction(_ r: inout TestRunner) {
        let parser = CommandParser()

        // Exact wake phrase
        let r1 = parser.extractCommand(from: "Hey Javira, open Gmail", requireWakeWord: true)
        r.assertTrue(r1.hasWakeWord, "Should detect 'Hey Javira'")
        r.assertEqual(r1.extractedCommand, "open Gmail", "Should extract 'open Gmail'")

        // Case insensitivity
        let r2 = parser.extractCommand(from: "hey javira open chrome", requireWakeWord: true)
        r.assertTrue(r2.hasWakeWord, "Should detect lowercase 'hey javira'")
        r.assertEqual(r2.extractedCommand, "open chrome", "Should extract 'open chrome'")

        // Punctuation handling
        let r3 = parser.extractCommand(from: "Hey, Javira: mute!", requireWakeWord: true)
        r.assertTrue(r3.hasWakeWord, "Should detect wake phrase with punctuation")
        r.assertEqual(r3.extractedCommand, "mute!", "Should extract 'mute!'")

        // Alternative wake word "Javira"
        let r4 = parser.extractCommand(from: "Javira, open Safari", requireWakeWord: true)
        r.assertTrue(r4.hasWakeWord, "Should detect 'Javira'")
        r.assertEqual(r4.extractedCommand, "open Safari")

        // Reject text without wake phrase when requireWakeWord = true
        let r5 = parser.extractCommand(from: "open Safari right now", requireWakeWord: true)
        r.assertFalse(r5.hasWakeWord, "Should reject text without wake word")
        r.assertEqual(r5.extractedCommand, "", "Extracted command must be empty if wake word missing")

        // Typed mode allows optional wake word
        let r6 = parser.extractCommand(from: "open Safari", requireWakeWord: false)
        r.assertEqual(r6.extractedCommand, "open Safari", "Typed mode should allow command without wake word")

        let r7 = parser.extractCommand(from: "Hey Javira, open Safari", requireWakeWord: false)
        r.assertEqual(r7.extractedCommand, "open Safari", "Typed mode should still strip wake word if present")
    }

    // MARK: - 2. Application Launch Parsing

    static func testAppLaunchParsing(_ r: inout TestRunner) {
        let parser = CommandParser()

        r.assertEqual(parser.parse(command: "open chrome"), .openApp(.chrome))
        r.assertEqual(parser.parse(command: "launch google chrome"), .openApp(.chrome))
        r.assertEqual(parser.parse(command: "open safari"), .openApp(.safari))
        r.assertEqual(parser.parse(command: "launch safari"), .openApp(.safari))
        r.assertEqual(parser.parse(command: "open calendar"), .openApp(.calendar))
        r.assertEqual(parser.parse(command: "open mail"), .openApp(.mail))
        r.assertEqual(parser.parse(command: "open finder"), .openApp(.finder))
    }

    // MARK: - 3. Gmail Parsing

    static func testGmailParsing(_ r: inout TestRunner) {
        let parser = CommandParser()

        r.assertEqual(parser.parse(command: "open gmail"), .openGmail)
        r.assertEqual(parser.parse(command: "launch gmail"), .openGmail)
        r.assertEqual(parser.parse(command: "go to gmail"), .openGmail)
        r.assertEqual(parser.parse(command: "open google mail"), .openGmail)
    }

    // MARK: - 4. Volume Parsing

    static func testVolumeParsing(_ r: inout TestRunner) {
        let parser = CommandParser()

        // Exact percentage
        r.assertEqual(parser.parse(command: "set volume to 40 percent"), .setVolume(percentage: 40))
        r.assertEqual(parser.parse(command: "set volume to 0 percent"), .setVolume(percentage: 0))
        r.assertEqual(parser.parse(command: "set volume to 100 percent"), .setVolume(percentage: 100))

        // Clamping bounds
        r.assertEqual(parser.parse(command: "set volume to 150 percent"), .setVolume(percentage: 100), "Should clamp to 100")

        // Relative volume
        r.assertEqual(parser.parse(command: "increase volume"), .increaseVolume(step: 10))
        r.assertEqual(parser.parse(command: "volume up"), .increaseVolume(step: 10))
        r.assertEqual(parser.parse(command: "decrease volume"), .decreaseVolume(step: 10))
        r.assertEqual(parser.parse(command: "volume down"), .decreaseVolume(step: 10))

        // Mute / Unmute
        r.assertEqual(parser.parse(command: "mute"), .mute)
        r.assertEqual(parser.parse(command: "silence"), .mute)
        r.assertEqual(parser.parse(command: "unmute"), .unmute)
    }

    // MARK: - 5. Sleep & Confirmation Parsing

    static func testSleepAndConfirmationParsing(_ r: inout TestRunner) {
        let parser = CommandParser()

        r.assertEqual(parser.parse(command: "sleep my mac"), .sleepMac)
        r.assertEqual(parser.parse(command: "sleep mac"), .sleepMac)
        r.assertEqual(parser.parse(command: "sleep"), .sleepMac)
        r.assertEqual(parser.parse(command: "put my mac to sleep"), .sleepMac)

        // Confirmation keywords
        r.assertEqual(parser.parse(command: "confirm"), .confirm)
        r.assertEqual(parser.parse(command: "yes"), .confirm)
        r.assertEqual(parser.parse(command: "proceed"), .confirm)

        // Cancellation keywords
        r.assertEqual(parser.parse(command: "cancel"), .cancel)
        r.assertEqual(parser.parse(command: "no"), .cancel)
        r.assertEqual(parser.parse(command: "abort"), .cancel)
    }

    // MARK: - 6. Safety Blocked Commands

    static func testSafetyBlockedCommands(_ r: inout TestRunner) {
        let parser = CommandParser()

        // Terminal & Shell block
        if case .blocked(let reason, _) = parser.parse(command: "open terminal") {
            r.assertTrue(reason.contains("Terminal"), "Should block terminal app")
        } else {
            r.assertTrue(false, "Expected 'open terminal' to be blocked")
        }

        if case .blocked = parser.parse(command: "sudo rm -rf /") {
            r.assertTrue(true, "Should block sudo command")
        } else {
            r.assertTrue(false, "Expected 'sudo' to be blocked")
        }

        // File deletion block
        if case .blocked = parser.parse(command: "delete my files") {
            r.assertTrue(true, "Should block 'delete my files'")
        } else {
            r.assertTrue(false, "Expected file deletion to be blocked")
        }

        if case .blocked = parser.parse(command: "erase hard drive") {
            r.assertTrue(true, "Should block 'erase hard drive'")
        } else {
            r.assertTrue(false, "Expected drive wipe to be blocked")
        }

        // Credential & password block
        if case .blocked = parser.parse(command: "what is my password") {
            r.assertTrue(true, "Should block credential access")
        } else {
            r.assertTrue(false, "Expected password request to be blocked")
        }

        // Unsupported consequential power commands
        if case .blocked = parser.parse(command: "shutdown my computer") {
            r.assertTrue(true, "Should block shutdown in MVP")
        } else {
            r.assertTrue(false, "Expected shutdown to be blocked")
        }

        if case .blocked = parser.parse(command: "restart mac") {
            r.assertTrue(true, "Should block restart in MVP")
        } else {
            r.assertTrue(false, "Expected restart to be blocked")
        }
    }

    // MARK: - 7. Policy Evaluation

    static func testPolicyEvaluation(_ r: inout TestRunner) {
        let policy = CommandPolicy()
        var config = AppConfiguration.default

        // Sleep Mac always requires confirmation
        let sleepDecision = policy.evaluate(intent: .sleepMac, config: config)
        r.assertEqual(sleepDecision.category, .confirmRequired, "Sleep Mac must require confirmation")

        // Allowed actions
        let gmailDecision = policy.evaluate(intent: .openGmail, config: config)
        r.assertEqual(gmailDecision.category, .allowed)

        let volDecision = policy.evaluate(intent: .setVolume(percentage: 50), config: config)
        r.assertEqual(volDecision.category, .allowed)

        // Disable volume in config
        config.isVolumeControlEnabled = false
        let disabledVolDecision = policy.evaluate(intent: .setVolume(percentage: 50), config: config)
        r.assertEqual(disabledVolDecision.category, .blocked, "Volume control should be blocked when disabled in settings")

        // Disable app launching in config
        config.isAppLaunchEnabled = false
        let disabledAppDecision = policy.evaluate(intent: .openApp(.safari), config: config)
        r.assertEqual(disabledAppDecision.category, .blocked, "App launch should be blocked when disabled in settings")
    }

    // MARK: - 8. Locality Guarantees

    static func testLocalityGuarantees(_ r: inout TestRunner) {
        // Gmail requires internet to load web page
        r.assertFalse(AssistantIntent.openGmail.isLocalOnly, "Gmail must be labeled as requiring internet access")

        // All other MVP actions are 100% local
        r.assertTrue(AssistantIntent.openApp(.safari).isLocalOnly, "App launching must be local")
        r.assertTrue(AssistantIntent.openApp(.chrome).isLocalOnly, "App launching must be local")
        r.assertTrue(AssistantIntent.setVolume(percentage: 40).isLocalOnly, "Volume control must be local")
        r.assertTrue(AssistantIntent.mute.isLocalOnly, "Muting must be local")
        r.assertTrue(AssistantIntent.sleepMac.isLocalOnly, "Sleep Mac must be local")
    }
}
