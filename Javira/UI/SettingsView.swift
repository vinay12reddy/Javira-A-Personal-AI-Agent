import SwiftUI

/// Settings management view for Javira preferences.
public struct SettingsView: View {
    @EnvironmentObject private var viewModel: AssistantViewModel

    public init() {}

    public var body: some View {
        Form {
            Section(header: Text("General & Speech").font(.headline)) {
                Picker("Language (Speech Recognition):", selection: $viewModel.configuration.selectedLanguage) {
                    Text("English (United States)").tag("en-US")
                    Text("English (United Kingdom)").tag("en-GB")
                    Text("English (Canada)").tag("en-CA")
                    Text("English (Australia)").tag("en-AU")
                }
                .help("Select locale for on-device speech recognition.")

                Picker("Preferred Browser for Web URLs:", selection: $viewModel.configuration.preferredBrowser) {
                    ForEach(BrowserChoice.allCases) { choice in
                        Text(choice.rawValue).tag(choice)
                    }
                }
                .help("Browser to open Gmail (https://mail.google.com).")

                Toggle("Spoken Feedback (Voice Responses)", isOn: $viewModel.configuration.speechFeedbackEnabled)
                    .help("When enabled, Javira speaks brief voice responses using AVSpeechSynthesizer.")

                Toggle("Stop Listening After Executing Action", isOn: $viewModel.configuration.stopListeningAfterAction)
                    .help("Automatically release microphone after command completion.")
            }

            Section(header: Text("Action Policies & Permissions").font(.headline)) {
                Text("Enable or disable specific categories of actions.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Allow Application Launching (Approved List Only)", isOn: $viewModel.configuration.isAppLaunchEnabled)
                Toggle("Allow Volume Controls (0–100%, Mute/Unmute)", isOn: $viewModel.configuration.isVolumeControlEnabled)
                Toggle("Allow Browser Navigation (Open Gmail)", isOn: $viewModel.configuration.isBrowserOpenEnabled)
                Toggle("Allow Mac Sleep (Requires Explicit Confirmation)", isOn: $viewModel.configuration.isSleepEnabled)
            }

            Section(header: Text("Approved Applications").font(.headline)) {
                Text("Fixed allowlist of launchable apps. Terminal and command shells are strictly excluded.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(ApprovedApp.allCases) { app in
                    HStack {
                        Image(systemName: app.iconName)
                            .frame(width: 20)
                            .foregroundColor(.indigo)
                        Text(app.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text(app.bundleIdentifier)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(header: Text("Safety & Confirmation").font(.headline)) {
                Stepper(value: $viewModel.configuration.confirmationTimeoutSeconds, in: 5...30) {
                    Text("Confirmation Auto-Cancel Timeout: \(viewModel.configuration.confirmationTimeoutSeconds) seconds")
                }
                .help("How long Javira waits for confirmation before cancelling consequential actions.")
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 460)
    }
}
