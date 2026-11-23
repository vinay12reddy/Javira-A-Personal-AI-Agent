import Foundation

/// Defines supported web browsers for opening web URLs (such as Gmail).
public enum BrowserChoice: String, CaseIterable, Codable, Identifiable, Sendable {
    case defaultBrowser = "System Default"
    case safari = "Safari"
    case chrome = "Google Chrome"

    public var id: String { rawValue }

    public var bundleIdentifier: String? {
        switch self {
        case .defaultBrowser:
            return nil
        case .safari:
            return "com.apple.Safari"
        case .chrome:
            return "com.google.Chrome"
        }
    }
}

/// Fixed allowlist of launchable applications.
/// Javira strictly limits application launching to this predefined list.
public enum ApprovedApp: String, CaseIterable, Codable, Identifiable, Sendable {
    case chrome = "Chrome"
    case safari = "Safari"
    case calendar = "Calendar"
    case mail = "Mail"
    case finder = "Finder"

    public var id: String { rawValue }

    public var bundleIdentifier: String {
        switch self {
        case .chrome:
            return "com.google.Chrome"
        case .safari:
            return "com.apple.Safari"
        case .calendar:
            return "com.apple.iCal"
        case .mail:
            return "com.apple.mail"
        case .finder:
            return "com.apple.finder"
        }
    }

    public var displayName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .safari: return "Safari"
        case .calendar: return "Calendar"
        case .mail: return "Apple Mail"
        case .finder: return "Finder"
        }
    }

    public var iconName: String {
        switch self {
        case .chrome: return "globe"
        case .safari: return "safari"
        case .calendar: return "calendar"
        case .mail: return "envelope"
        case .finder: return "folder"
        }
    }
}

/// Stores minimal user preferences using UserDefaults.
/// Strictly conforms to privacy rules: no credentials, keys, or private data are ever saved.
public struct AppConfiguration: Codable, Equatable, Sendable {
    public var selectedLanguage: String
    public var preferredBrowser: BrowserChoice
    public var approvedApps: [ApprovedApp]
    public var isAppLaunchEnabled: Bool
    public var isVolumeControlEnabled: Bool
    public var isBrowserOpenEnabled: Bool
    public var isSleepEnabled: Bool
    public var speechFeedbackEnabled: Bool
    public var stopListeningAfterAction: Bool
    public var confirmationTimeoutSeconds: Int

    public static let userDefaultsKey = "com.javira.configuration"

    public static let `default` = AppConfiguration(
        selectedLanguage: "en-US",
        preferredBrowser: .defaultBrowser,
        approvedApps: ApprovedApp.allCases,
        isAppLaunchEnabled: true,
        isVolumeControlEnabled: true,
        isBrowserOpenEnabled: true,
        isSleepEnabled: true,
        speechFeedbackEnabled: true,
        stopListeningAfterAction: true,
        confirmationTimeoutSeconds: 10
    )

    public init(
        selectedLanguage: String = "en-US",
        preferredBrowser: BrowserChoice = .defaultBrowser,
        approvedApps: [ApprovedApp] = ApprovedApp.allCases,
        isAppLaunchEnabled: Bool = true,
        isVolumeControlEnabled: Bool = true,
        isBrowserOpenEnabled: Bool = true,
        isSleepEnabled: Bool = true,
        speechFeedbackEnabled: Bool = true,
        stopListeningAfterAction: Bool = true,
        confirmationTimeoutSeconds: Int = 10
    ) {
        self.selectedLanguage = selectedLanguage
        self.preferredBrowser = preferredBrowser
        self.approvedApps = approvedApps
        self.isAppLaunchEnabled = isAppLaunchEnabled
        self.isVolumeControlEnabled = isVolumeControlEnabled
        self.isBrowserOpenEnabled = isBrowserOpenEnabled
        self.isSleepEnabled = isSleepEnabled
        self.speechFeedbackEnabled = speechFeedbackEnabled
        self.stopListeningAfterAction = stopListeningAfterAction
        self.confirmationTimeoutSeconds = confirmationTimeoutSeconds
    }

    public static func load() -> AppConfiguration {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) else {
            return .default
        }
        return config
    }

    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
