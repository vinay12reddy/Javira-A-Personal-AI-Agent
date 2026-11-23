# Javira — macOS Personal Voice Assistant

**Javira** is a native macOS personal voice assistant inspired by Siri, built with **Swift 6, SwiftUI, and AppKit/Foundation** for modern Apple Silicon Macs. It operates **100% locally on-device** for speech recognition, intent parsing, application launching, and volume control, prioritizing safety, transparency, and user privacy.

---

## Key Features & Highlights

- 🔒 **100% On-Device & Private**: Voice transcription uses `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`. Audio is processed strictly in-memory and is **never** sent to any cloud server or third-party service.
- 🛡️ **Zero Arbitrary Execution**: Javira does **not** execute arbitrary shell commands. It uses a deterministic, rule-based intent parser (no opaque cloud LLMs).
- 📋 **Strict Application Allowlist**: Only explicitly pre-approved applications (Google Chrome, Apple Safari, Calendar, Mail, Finder) can be launched using their official bundle identifiers. Terminal, shells, and system modification tools are strictly blocked.
- 🌐 **Clear Locality Indicators**: Every action is clearly labeled in the UI as **`[Fully Local]`** or **`[Requires Internet]`** (e.g., loading `mail.google.com` in the browser).
- ⏳ **Consequential Action Confirmation**: Consequential actions like putting the Mac to sleep require spoken or visual confirmation with an automatic 10-second timeout.
- ⌨️ **Typed-Command Fallback**: Full typed-command testing mode that functions immediately, even before microphone or speech permissions are granted.
- 🎧 **Interactive Waveform Visualizer**: Live audio RMS metering pulses in real time while the microphone is active.
- 🖥️ **Menu Bar & Main Window Modes**: Runs seamlessly as a persistent macOS menu bar app with quick controls and a full assistant window.

---

## Architecture

```text
JAVIRA/
├── Javira.xcodeproj/
│   └── project.pbxproj            # Standard runnable Xcode project
├── Package.swift                  # Swift Package Manager configuration
├── scripts/
│   └── build_app.sh               # Standalone release build & packaging script
├── Javira/
│   ├── JaviraApp.swift            # SwiftUI App entry point with MenuBarExtra & Window
│   ├── Info.plist                 # Permissions usage descriptions & metadata
│   ├── Javira.entitlements        # Sandboxing & audio device entitlements
│   ├── AppState/
│   │   └── AssistantViewModel.swift     # Central State & Event Coordinator
│   ├── UI/
│   │   ├── ContentView.swift            # Main macOS Assistant Window
│   │   ├── MenuBarView.swift            # Compact Menu Bar Popover
│   │   ├── SettingsView.swift           # User Preferences & Policy Toggles
│   │   ├── PermissionView.swift         # Microphone & Speech Guidance
│   │   └── ActionHistoryView.swift      # Privacy-preserving Action Log
│   ├── Speech/
│   │   ├── SpeechRecognitionService.swift # On-Device SFSpeechRecognizer + AVAudioEngine
│   │   ├── SpeechSynthesisService.swift   # Local AVSpeechSynthesizer
│   │   └── PermissionManager.swift        # AVCaptureDevice & SFSpeech Authorization
│   ├── Commands/
│   │   ├── CommandParser.swift          # Deterministic Wake Word & Intent Parser
│   │   ├── AssistantIntent.swift        # Strongly-typed Intent definitions
│   │   ├── CommandPolicy.swift          # Safety Policy enforcement layer
│   │   └── CommandExecutor.swift        # Safe action routing & result coordinator
│   ├── Actions/
│   │   ├── BrowserAction.swift          # Safe Gmail URL handler (no login/read)
│   │   ├── ApplicationAction.swift      # Bundle ID allowlist launcher
│   │   ├── VolumeAction.swift           # Sanitized numeric volume controls
│   │   └── PowerAction.swift            # Sleep Mac (after explicit verification)
│   ├── Models/
│   │   ├── ActionRecord.swift           # Metadata log record (no raw audio)
│   │   ├── ApprovalState.swift          # Consequential confirmation state machine
│   │   └── AppConfiguration.swift       # Minimal UserDefaults storage
│   └── Tests/
│       └── CommandParserTests.swift     # Test suite mirror for Xcode
├── Tests/
│   └── CommandParserTests.swift         # CLI & SPM Unit Test Suite (62 tests)
└── README.md
```

---

## Safety and Privacy Guarantees

1. **Microphone Isolation**: Audio buffers captured by `AVAudioEngine` are fed solely to `SFSpeechAudioBufferRecognitionRequest` configured with `requiresOnDeviceRecognition = true`.
2. **On-Device Requirement**: If on-device speech recognition is unsupported for the chosen locale, Javira displays an error rather than silently falling back to Apple cloud recognition.
3. **No Credential Harvesting**: Javira never requests, collects, saves, displays, or autofills passwords, OTPs, session cookies, API tokens, or private messages.
4. **Gmail Security Constraint**: "Open Gmail" exclusively opens `https://mail.google.com` in your chosen browser. Javira does not interact with the DOM, cannot access web cookies, and never reads or sends email.
5. **Volume Control Sanitization**: All volume values are strictly clamped integers (`0...100`). System calls use fixed internal AppleScript strings with numeric values; spoken text is never concatenated into scripts.
6. **No Terminal or Destruction**: Commands containing `terminal`, `sudo`, `delete`, `rm`, `kill`, `chmod`, `shutdown`, etc. are blocked at the parser level with clear refusal feedback.
7. **Minimal Persistence**: Only essential user preferences are stored via `UserDefaults`: selected language, approved apps, preferred browser, and toggles. No voice recordings or private transcripts are ever stored.

---

## Permissions Setup

Javira requires two macOS permissions for voice functionality:

| Permission | Purpose | System Settings Location |
|---|---|---|
| **Microphone** | Capture live voice input for wake phrase and commands | **System Settings → Privacy & Security → Microphone** |
| **Speech Recognition** | Transcribe speech locally on Apple Silicon | **System Settings → Privacy & Security → Speech Recognition** |

### Granting Permissions
1. Launch Javira.
2. Click **Start Listening** or tap the **Shield** icon in the header to open the Permissions sheet.
3. Click **Request Access** for both Microphone and Speech Recognition.
4. When prompted by macOS, click **Allow**.
5. If previously denied, click **Open Settings** to navigate directly to the appropriate macOS System Settings pane.

> [!NOTE]
> **Typed-Command Mode** is always available even if permissions have not yet been granted. You can test any command by typing it into the test field in the main window.

---

## Supported Commands

Commands can be triggered by voice (prefixed with **“Hey Javira”**) or entered into the typed test field (where the prefix is optional).

### 1. Allowed Safe Actions

| Spoken Phrase | Extracted Intent | Behavior | Locality |
|---|---|---|---|
| `Hey Javira, open Gmail` | `.openGmail` | Opens `https://mail.google.com` in default or preferred browser | **Requires Internet** |
| `Hey Javira, open Chrome` | `.openApp(.chrome)` | Launches Google Chrome via bundle ID `com.google.Chrome` | **Fully Local** |
| `Hey Javira, open Safari` | `.openApp(.safari)` | Launches Safari via bundle ID `com.apple.Safari` | **Fully Local** |
| `Hey Javira, open Calendar` | `.openApp(.calendar)` | Launches Calendar via bundle ID `com.apple.iCal` | **Fully Local** |
| `Hey Javira, open Mail` | `.openApp(.mail)` | Launches Apple Mail via bundle ID `com.apple.mail` | **Fully Local** |
| `Hey Javira, open Finder` | `.openApp(.finder)` | Activates macOS Finder via `com.apple.finder` | **Fully Local** |
| `Hey Javira, set volume to 40 percent` | `.setVolume(40)` | Sets system output volume to 40% (validated 0–100) | **Fully Local** |
| `Hey Javira, increase volume` | `.increaseVolume(10)` | Steps output volume up by +10% | **Fully Local** |
| `Hey Javira, decrease volume` | `.decreaseVolume(10)` | Steps output volume down by -10% | **Fully Local** |
| `Hey Javira, mute` | `.mute` | Mutes audio output | **Fully Local** |
| `Hey Javira, unmute` | `.unmute` | Unmutes audio output | **Fully Local** |

### 2. Confirmation-Required Actions

| Spoken Phrase | Prompt | Confirmation Required | Locality |
|---|---|---|---|
| `Hey Javira, sleep my Mac` | *“Do you want me to put your Mac to sleep? Say confirm or cancel.”* | Spoken: *"confirm"* / *"cancel"*<br>OR UI Button: *Confirm (Sleep Mac)* / *Cancel*<br>(Auto-cancels after 10s) | **Fully Local** |

### 3. Blocked Dangerous Actions

| Attempted Phrase | Policy Outcome | Assistant Response |
|---|---|---|
| `Hey Javira, delete my files` | **Blocked for Safety** | *“Command blocked for your safety. File deletion and destructive actions are blocked.”* |
| `Hey Javira, open Terminal` | **Blocked for Safety** | *“Command blocked for your safety. Terminal and shell execution are blocked for safety.”* |
| `Hey Javira, sudo rm -rf /` | **Blocked for Safety** | *“Command blocked for your safety. Shell command execution is strictly blocked.”* |
| `Hey Javira, what is my password` | **Blocked for Safety** | *“Command blocked for your safety. Credential and secret access is strictly prohibited.”* |
| `Hey Javira, send email to...` | **Blocked for Safety** | *“Command blocked for your safety. Automated communication is blocked in MVP.”* |
| `Hey Javira, shutdown` | **Blocked for Safety** | *“Command blocked for your safety. Shutdown is not supported in the MVP.”* |

---

## Building and Running

### Option A: Using Xcode
1. Open `Javira.xcodeproj` in Xcode:
   ```bash
   open Javira.xcodeproj
   ```
2. Select the `Javira` scheme and target device **My Mac (Mac Catalyst or Mac)**.
3. Press **Cmd + R** to build and run.

### Option B: Using the Build Script (Standalone `.app` Bundle)
A release packaging script is included:
```bash
./scripts/build_app.sh
open Javira.app
```
This builds an optimized binary, packages the bundle layout with `Info.plist`, applies the local entitlements, and code-signs the `.app` bundle.

### Option C: Swift Command Line
Run directly via Swift:
```bash
swift run Javira
```

---

## Running Unit Tests

The test suite contains **62 deterministic test cases** verifying wake-word parsing, intent extraction, volume clamping, confirmation flows, safety blocking, policy categories, and locality assertions.

Run tests via the Swift CLI test runner:
```bash
swift run JaviraTests
```

Expected output:
```text
==================================================
 Running Javira Command & Policy Test Suite...
==================================================
--------------------------------------------------
Test Results: 62 PASSED, 0 FAILED
==================================================
✅ All 62 tests passed successfully!
```

---

## Final Verification Checklist

| Scenario | Tested Input | Expected Result | Status |
|---|---|---|---|
| 1. Open Gmail | `Hey Javira, open Gmail` | Opens `https://mail.google.com` in preferred/default browser; labeled `[Requires Internet]` | ✅ Verified |
| 2. Volume to 40% | `Hey Javira, set volume to 40 percent` | Volume adjusted to 40%; brief spoken reply; labeled `[Fully Local]` | ✅ Verified |
| 3. Mute Audio | `Hey Javira, mute` | Audio muted; spoken confirmation; labeled `[Fully Local]` | ✅ Verified |
| 4. Consequential Sleep | `Hey Javira, sleep my Mac` | Prompts *“Do you want me to put your Mac to sleep? Say confirm or cancel.”*; 10-second countdown; confirms or cancels safely | ✅ Verified |
| 5. Block File Deletion | `Hey Javira, delete my files` | Blocked immediately with safety badge and audio refusal; zero file access | ✅ Verified |
| 6. Block Terminal | `Hey Javira, open Terminal` | Blocked immediately; refusal explanation displayed; Terminal is never launched | ✅ Verified |
| 7. Typed Fallback | Any command in text field | Executes immediately with full policy enforcement before mic permission | ✅ Verified |
| 8. Strict Privacy | Audio processing | Zero telemetry, zero cloud uploads, strictly on-device `SFSpeechRecognizer` | ✅ Verified |

---

## Troubleshooting

- **"Microphone idle" / "Permission required"**:
  Open **System Settings → Privacy & Security → Microphone** and toggle Javira **ON**.
- **"On-device speech recognition is not supported for locale"**:
  Go to **System Settings → Keyboard → Dictation** and ensure on-device dictation models are downloaded for your preferred language, or switch language to `en-US` in Javira Settings.
- **Volume control does not respond**:
  Ensure Javira has permission to execute Apple Events under **System Settings → Privacy & Security → Automation**.
