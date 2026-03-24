import Foundation

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case apple
    case classicBlue

    var id: Self { self }

    var title: String {
        switch self {
        case .apple:
            return "Apple"
        case .classicBlue:
            return "Classic Blue"
        }
    }

    var subtitle: String {
        switch self {
        case .apple:
            return "Neutral tones with system-accent links."
        case .classicBlue:
            return "Original indigo-heavy Clearance palette."
        }
    }

    var palette: ThemePalette {
        switch self {
        case .apple:
            return ThemePalette(
                light: ThemeVariant(
                    background: "#F5F5F7",
                    surface: "#FFFFFF",
                    surfaceBorder: "#D2D2D788",
                    text: "#1D1D1F",
                    muted: "#86868B",
                    heading: "#1D1D1F",
                    link: "#0A84FF",
                    inlineCodeBackground: "#7878801F",
                    inlineCodeText: "#1D1D1F",
                    codeBackground: "#EDEDF0",
                    codeText: "#1F2937",
                    quote: "#C7C7CC",
                    quoteText: "#6E6E73",
                    rule: "#D2D2D760",
                    tokenComment: "#8E8E93",
                    tokenKeyword: "#A23AA6",
                    tokenString: "#147D64",
                    tokenNumber: "#A35A00",
                    tokenProperty: "#0E5BAF",
                    frontmatter: "#0E7490",
                    listMarker: "#A35A00",
                    selectionBackground: "#0A84FF40",
                    selectionText: "#111111"
                ),
                dark: ThemeVariant(
                    background: "#1C1C1E",
                    surface: "#2C2C2E",
                    surfaceBorder: "#54545866",
                    text: "#F5F5F7",
                    muted: "#98989D",
                    heading: "#F5F5F7",
                    link: "#4DA3FF",
                    inlineCodeBackground: "#7878803D",
                    inlineCodeText: "#F5F5F7",
                    codeBackground: "#111113",
                    codeText: "#E6EAF2",
                    quote: "#48484A",
                    quoteText: "#98989D",
                    rule: "#38383A",
                    tokenComment: "#8E8E93",
                    tokenKeyword: "#C792EA",
                    tokenString: "#7FD8BE",
                    tokenNumber: "#F5B66F",
                    tokenProperty: "#8AB4FF",
                    frontmatter: "#7AD0C8",
                    listMarker: "#F5B66F",
                    selectionBackground: "#4DA3FF59",
                    selectionText: "#F8FAFF"
                )
            )
        case .classicBlue:
            return ThemePalette(
                light: ThemeVariant(
                    background: "#F3F5F9",
                    surface: "#FFFFFF",
                    surfaceBorder: "#61708A42",
                    text: "#1F2733",
                    muted: "#5C697C",
                    heading: "#2C62D6",
                    link: "#2F6FE0",
                    inlineCodeBackground: "#2F6FE024",
                    inlineCodeText: "#2757A8",
                    codeBackground: "#0F172A",
                    codeText: "#D5E2FF",
                    quote: "#4F75BA",
                    quoteText: "#5C697C",
                    rule: "#61708A3D",
                    tokenComment: "#7C8AA0",
                    tokenKeyword: "#7A3FE0",
                    tokenString: "#0B7A65",
                    tokenNumber: "#B05A00",
                    tokenProperty: "#2A6BB5",
                    frontmatter: "#0E7490",
                    listMarker: "#CB7A1A",
                    selectionBackground: "#2F6FE047",
                    selectionText: "#0B1220"
                ),
                dark: ThemeVariant(
                    background: "#0E1118",
                    surface: "#141A23",
                    surfaceBorder: "#90A1BE3D",
                    text: "#D5DEEB",
                    muted: "#97A5BA",
                    heading: "#8CA8FF",
                    link: "#90B2FF",
                    inlineCodeBackground: "#779DDC38",
                    inlineCodeText: "#A6C7FF",
                    codeBackground: "#0A1020",
                    codeText: "#DCE6FF",
                    quote: "#79A9FF",
                    quoteText: "#97A5BA",
                    rule: "#90A1BE42",
                    tokenComment: "#8FA2C2",
                    tokenKeyword: "#B39BFF",
                    tokenString: "#7DD7B8",
                    tokenNumber: "#FFB86B",
                    tokenProperty: "#8CB8FF",
                    frontmatter: "#7AD0C8",
                    listMarker: "#F2B46B",
                    selectionBackground: "#4B62905C",
                    selectionText: "#F3F5F9"
                )
            )
        }
    }
}

struct ThemePalette {
    let light: ThemeVariant
    let dark: ThemeVariant
}

struct ThemeVariant {
    let background: String
    let surface: String
    let surfaceBorder: String
    let text: String
    let muted: String
    let heading: String
    let link: String
    let inlineCodeBackground: String
    let inlineCodeText: String
    let codeBackground: String
    let codeText: String
    let quote: String
    let quoteText: String
    let rule: String
    let tokenComment: String
    let tokenKeyword: String
    let tokenString: String
    let tokenNumber: String
    let tokenProperty: String
    let frontmatter: String
    let listMarker: String
    let selectionBackground: String
    let selectionText: String
}

final class AppSettings: ObservableObject {
    @Published var defaultOpenMode: WorkspaceMode {
        didSet {
            userDefaults.set(defaultOpenMode.rawValue, forKey: openModeStorageKey)
        }
    }

    @Published var theme: AppTheme {
        didSet {
            userDefaults.set(theme.rawValue, forKey: themeStorageKey)
        }
    }

    @Published var appearance: AppearancePreference {
        didSet {
            userDefaults.set(appearance.rawValue, forKey: appearanceStorageKey)
        }
    }

    @Published var renderedTextScale: Double {
        didSet {
            userDefaults.set(renderedTextScale, forKey: renderedTextScaleStorageKey)
        }
    }

    private let userDefaults: UserDefaults
    private let openModeStorageKey: String
    private let themeStorageKey: String
    private let appearanceStorageKey: String
    private let renderedTextScaleStorageKey: String
    private let releaseNotesVersionStorageKey: String

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = "defaultOpenMode",
        themeStorageKey: String = "theme",
        appearanceStorageKey: String = "appearance",
        renderedTextScaleStorageKey: String = "renderedTextScale",
        releaseNotesVersionStorageKey: String = "releaseNotesVersion"
    ) {
        self.userDefaults = userDefaults
        self.openModeStorageKey = storageKey
        self.themeStorageKey = themeStorageKey
        self.appearanceStorageKey = appearanceStorageKey
        self.renderedTextScaleStorageKey = renderedTextScaleStorageKey
        self.releaseNotesVersionStorageKey = releaseNotesVersionStorageKey

        if let stored = userDefaults.string(forKey: storageKey),
           let mode = WorkspaceMode(rawValue: stored) {
            defaultOpenMode = mode
        } else {
            defaultOpenMode = .view
        }

        if let storedTheme = userDefaults.string(forKey: themeStorageKey),
           let parsedTheme = AppTheme(rawValue: storedTheme) {
            theme = parsedTheme
        } else {
            theme = .apple
        }

        if let storedAppearance = userDefaults.string(forKey: appearanceStorageKey),
           let parsedAppearance = AppearancePreference(rawValue: storedAppearance) {
            appearance = parsedAppearance
        } else {
            appearance = .system
        }

        let storedTextScale = userDefaults.double(forKey: renderedTextScaleStorageKey)
        if storedTextScale > 0 {
            renderedTextScale = storedTextScale
        } else {
            renderedTextScale = 1.0
        }
    }

    func releaseNotesVersionToPresent(currentVersion: String?) -> String? {
        guard let currentVersion = currentVersion?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !currentVersion.isEmpty else {
            return nil
        }

        let previousVersion = userDefaults.string(forKey: releaseNotesVersionStorageKey)
        userDefaults.set(currentVersion, forKey: releaseNotesVersionStorageKey)

        guard let previousVersion,
              previousVersion != currentVersion else {
            return nil
        }

        return currentVersion
    }
}
