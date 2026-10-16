import Carbon.HIToolbox
import Foundation

enum InterfaceLanguage: String, CaseIterable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case russian = "ru"

    func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> ResolvedLanguage {
        switch self {
        case .english:
            return .english
        case .simplifiedChinese:
            return .simplifiedChinese
        case .russian:
            return .russian
        case .system:
            for language in preferredLanguages {
                let language = language.lowercased()
                if language.hasPrefix("zh") { return .simplifiedChinese }
                if language.hasPrefix("ru") { return .russian }
                if language.hasPrefix("en") { return .english }
            }
            return .english
        }
    }
}

enum ResolvedLanguage: String {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case russian = "ru"

    var locale: Locale { Locale(identifier: rawValue) }
}

enum ApplicationSortOrder: String, CaseIterable {
    case manual
    case name
    case creationDate
    case modificationDate
}

/// A screen corner that opens GridOS when the pointer rests in it.
enum HotCorner: String, CaseIterable {
    case none
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum GestureFingerCount: Int, CaseIterable {
    case three = 3
    case four = 4
}

struct HotKeyConfiguration: Codable, Equatable {
    static let allowedModifiers = UInt32(cmdKey | optionKey | controlKey | shiftKey)
    static let defaultConfiguration = HotKeyConfiguration(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(controlKey | shiftKey)
    )

    let keyCode: UInt32
    let modifiers: UInt32

    var isValid: Bool {
        guard modifiers & ~Self.allowedModifiers == 0 else { return false }
        if Self.functionKeyNames[keyCode] != nil { return true }
        return modifiers & UInt32(cmdKey | optionKey | controlKey) != 0
            && Self.keyNames[keyCode] != nil
    }

    var displayName: String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        value += Self.functionKeyNames[keyCode] ?? Self.keyNames[keyCode] ?? "#\(keyCode)"
        return value
    }

    static func legacy(named rawName: String) -> HotKeyPreference? {
        switch rawName.lowercased() {
        case "control-shift-space", "ctrl-shift-space":
            return .configured(.defaultConfiguration)
        case "control-option-l", "ctrl-option-l", "ctrl-alt-l":
            return .configured(HotKeyConfiguration(
                keyCode: UInt32(kVK_ANSI_L),
                modifiers: UInt32(controlKey | optionKey)
            ))
        case "disabled", "off", "none":
            return .disabled
        default:
            return nil
        }
    }

    @MainActor
    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        preferences: LunchpadPreferences? = nil
    ) -> HotKeyConfiguration? {
        if let override = HotKeyEnvironmentOverride(environment: environment) {
            return override.preference.configuration
        }
        return (preferences ?? LunchpadPreferences()).hotKey.configuration
    }

    private static let functionKeyNames: [UInt32: String] = [
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_F13): "F13", UInt32(kVK_F14): "F14", UInt32(kVK_F15): "F15",
        UInt32(kVK_F16): "F16", UInt32(kVK_F17): "F17", UInt32(kVK_F18): "F18",
        UInt32(kVK_F19): "F19", UInt32(kVK_F20): "F20",
    ]

    private static let keyNames: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9", UInt32(kVK_Space): "Space", UInt32(kVK_Return): "↩",
        UInt32(kVK_Tab): "⇥", UInt32(kVK_Delete): "⌫", UInt32(kVK_ForwardDelete): "⌦",
        UInt32(kVK_LeftArrow): "←", UInt32(kVK_RightArrow): "→",
        UInt32(kVK_UpArrow): "↑", UInt32(kVK_DownArrow): "↓",
        UInt32(kVK_Home): "↖", UInt32(kVK_End): "↘",
        UInt32(kVK_PageUp): "⇞", UInt32(kVK_PageDown): "⇟",
        UInt32(kVK_Help): "?",
        UInt32(kVK_ANSI_Equal): "=", UInt32(kVK_ANSI_Minus): "-",
        UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Semicolon): ";", UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_ANSI_Comma): ",", UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/", UInt32(kVK_ANSI_Backslash): "\\",
        UInt32(kVK_ANSI_Grave): "`",
        UInt32(kVK_ANSI_Keypad0): "0", UInt32(kVK_ANSI_Keypad1): "1",
        UInt32(kVK_ANSI_Keypad2): "2", UInt32(kVK_ANSI_Keypad3): "3",
        UInt32(kVK_ANSI_Keypad4): "4", UInt32(kVK_ANSI_Keypad5): "5",
        UInt32(kVK_ANSI_Keypad6): "6", UInt32(kVK_ANSI_Keypad7): "7",
        UInt32(kVK_ANSI_Keypad8): "8", UInt32(kVK_ANSI_Keypad9): "9",
        UInt32(kVK_ANSI_KeypadDecimal): ".", UInt32(kVK_ANSI_KeypadMultiply): "*",
        UInt32(kVK_ANSI_KeypadPlus): "+", UInt32(kVK_ANSI_KeypadClear): "⌧",
        UInt32(kVK_ANSI_KeypadDivide): "/", UInt32(kVK_ANSI_KeypadEnter): "⌤",
        UInt32(kVK_ANSI_KeypadMinus): "-", UInt32(kVK_ANSI_KeypadEquals): "=",
    ]
}

enum HotKeyPreference: Equatable {
    case configured(HotKeyConfiguration)
    case disabled

    var configuration: HotKeyConfiguration? {
        guard case .configured(let configuration) = self else { return nil }
        return configuration
    }
}

struct HotKeyEnvironmentOverride: Equatable {
    let rawValue: String
    let preference: HotKeyPreference

    init?(environment: [String: String] = ProcessInfo.processInfo.environment) {
        guard let rawValue = environment["LUNCHPAD_HOTKEY"], !rawValue.isEmpty else {
            return nil
        }
        self.rawValue = rawValue
        preference = HotKeyConfiguration.legacy(named: rawValue)
            ?? .configured(.defaultConfiguration)
    }
}

enum LunchpadPreferenceChange: Equatable {
    case interfaceLanguage
    case applicationSortOrder
    case hotKey
    case gestureEnabled
    case gestureFingerCount
    case gridDimensions
    case hotCorner
    case appCustomizations
    case applicationSources
}

/// Opens Lunchpad's preference domain. The packaged app owns the domain as its standard defaults;
/// passing its own bundle identifier as a suite name is rejected by CFPreferences with a console
/// warning. The unbundled development executable has no bundle identifier and opens the suite.
enum LunchpadDefaults {
    static func make(
        domain: String = LunchpadPreferences.domain,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier
    ) -> UserDefaults {
        if bundleIdentifier == domain {
            return .standard
        }
        return UserDefaults(suiteName: domain) ?? .standard
    }
}

@MainActor
final class LunchpadPreferences {
    nonisolated static let domain = "com.gridos.GridOS"

    private enum Key {
        static let interfaceLanguage = "interfaceLanguage"
        static let applicationSortOrder = "applicationSortOrder"
        static let globalHotKey = "globalHotKey"
        // Keep the existing storage key so upgrades preserve the user's enabled state.
        static let gestureEnabled = "fourFingerPinchEnabled"
        static let gestureFingerCount = "gestureFingerCount"
        static let gridColumns = "gridColumns"
        static let gridRows = "gridRows"
        static let hotCorner = "hotCorner"
        static let hiddenApplications = "hiddenApplicationIdentifiers"
        static let customNames = "customApplicationNames"
        static let additionalFolders = "additionalApplicationFolders"
    }

    nonisolated static let defaultGridColumns = 7
    nonisolated static let defaultGridRows = 5
    nonisolated static let gridColumnRange = 4...12
    nonisolated static let gridRowRange = 3...9

    private struct HotKeyPayload: Codable {
        let version: Int
        let enabled: Bool
        let configuration: HotKeyConfiguration?
    }

    var onChange: ((LunchpadPreferenceChange) -> Void)?
    private let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? LunchpadDefaults.make()
    }

    var interfaceLanguage: InterfaceLanguage {
        get {
            guard let value = defaults.string(forKey: Key.interfaceLanguage),
                  let language = InterfaceLanguage(rawValue: value) else {
                return .system
            }
            return language
        }
        set {
            guard newValue != interfaceLanguage else { return }
            defaults.set(newValue.rawValue, forKey: Key.interfaceLanguage)
            onChange?(.interfaceLanguage)
        }
    }

    var applicationSortOrder: ApplicationSortOrder {
        get {
            guard let value = defaults.string(forKey: Key.applicationSortOrder) else {
                return .name
            }
            guard let order = ApplicationSortOrder(rawValue: value) else { return .name }
            return order
        }
        set {
            guard newValue != applicationSortOrder else { return }
            defaults.set(newValue.rawValue, forKey: Key.applicationSortOrder)
            onChange?(.applicationSortOrder)
        }
    }

    var hotKey: HotKeyPreference {
        get { loadHotKey() }
        set {
            guard newValue != loadHotKey() else { return }
            storeHotKey(newValue)
            onChange?(.hotKey)
        }
    }

    var gestureEnabled: Bool {
        get {
            guard defaults.object(forKey: Key.gestureEnabled) != nil else { return true }
            return defaults.bool(forKey: Key.gestureEnabled)
        }
        set {
            guard newValue != gestureEnabled else { return }
            defaults.set(newValue, forKey: Key.gestureEnabled)
            onChange?(.gestureEnabled)
        }
    }

    var gestureFingerCount: GestureFingerCount {
        get {
            guard let stored = defaults.object(forKey: Key.gestureFingerCount) as? NSNumber,
                  let fingerCount = GestureFingerCount(rawValue: stored.intValue) else {
                return .four
            }
            return fingerCount
        }
        set {
            guard newValue != gestureFingerCount else { return }
            defaults.set(newValue.rawValue, forKey: Key.gestureFingerCount)
            onChange?(.gestureFingerCount)
        }
    }

    var gridColumns: Int {
        get { clampedInteger(Key.gridColumns, default: Self.defaultGridColumns, range: Self.gridColumnRange) }
        set {
            let value = min(max(newValue, Self.gridColumnRange.lowerBound), Self.gridColumnRange.upperBound)
            guard value != gridColumns else { return }
            defaults.set(value, forKey: Key.gridColumns)
            onChange?(.gridDimensions)
        }
    }

    var gridRows: Int {
        get { clampedInteger(Key.gridRows, default: Self.defaultGridRows, range: Self.gridRowRange) }
        set {
            let value = min(max(newValue, Self.gridRowRange.lowerBound), Self.gridRowRange.upperBound)
            guard value != gridRows else { return }
            defaults.set(value, forKey: Key.gridRows)
            onChange?(.gridDimensions)
        }
    }

    var hotCorner: HotCorner {
        get {
            guard let value = defaults.string(forKey: Key.hotCorner),
                  let corner = HotCorner(rawValue: value) else {
                return .none
            }
            return corner
        }
        set {
            guard newValue != hotCorner else { return }
            defaults.set(newValue.rawValue, forKey: Key.hotCorner)
            onChange?(.hotCorner)
        }
    }

    /// Application identifiers the user removed from the launcher. The bundles stay on disk.
    var hiddenApplicationIdentifiers: Set<String> {
        Set(defaults.stringArray(forKey: Key.hiddenApplications) ?? [])
    }

    func setApplication(_ identifier: String, hidden: Bool) {
        var hiddenSet = hiddenApplicationIdentifiers
        if hidden {
            guard hiddenSet.insert(identifier).inserted else { return }
        } else {
            guard hiddenSet.remove(identifier) != nil else { return }
        }
        defaults.set(hiddenSet.sorted(), forKey: Key.hiddenApplications)
        onChange?(.appCustomizations)
    }

    func unhideAllApplications() {
        guard !hiddenApplicationIdentifiers.isEmpty else { return }
        defaults.removeObject(forKey: Key.hiddenApplications)
        onChange?(.appCustomizations)
    }

    /// Display names chosen by the user, keyed by application identifier.
    var customApplicationNames: [String: String] {
        (defaults.dictionary(forKey: Key.customNames) as? [String: String]) ?? [:]
    }

    /// Sets a custom display name; nil or a blank name restores the application's own name.
    func setCustomName(_ name: String?, forApplication identifier: String) {
        var names = customApplicationNames
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            guard names.removeValue(forKey: identifier) != nil else { return }
        } else {
            guard names[identifier] != trimmed else { return }
            names[identifier] = trimmed
        }
        defaults.set(names, forKey: Key.customNames)
        onChange?(.appCustomizations)
    }

    func resetCustomNames() {
        guard !customApplicationNames.isEmpty else { return }
        defaults.removeObject(forKey: Key.customNames)
        onChange?(.appCustomizations)
    }

    /// Extra directories scanned for applications in addition to the standard locations.
    var additionalApplicationFolders: [String] {
        get { defaults.stringArray(forKey: Key.additionalFolders) ?? [] }
        set {
            var seen = Set<String>()
            let cleaned = newValue.filter { !$0.isEmpty && seen.insert($0).inserted }
            guard cleaned != additionalApplicationFolders else { return }
            defaults.set(cleaned, forKey: Key.additionalFolders)
            onChange?(.applicationSources)
        }
    }

    private func clampedInteger(_ key: String, default defaultValue: Int, range: ClosedRange<Int>) -> Int {
        guard let stored = defaults.object(forKey: key) as? NSNumber else { return defaultValue }
        return min(max(stored.intValue, range.lowerBound), range.upperBound)
    }

    private func loadHotKey() -> HotKeyPreference {
        if let data = defaults.data(forKey: Key.globalHotKey),
           let payload = try? JSONDecoder().decode(HotKeyPayload.self, from: data),
           payload.version == 1 {
            if !payload.enabled { return .disabled }
            if let configuration = payload.configuration, configuration.isValid {
                return .configured(configuration)
            }
            return .configured(.defaultConfiguration)
        }

        if let legacy = defaults.string(forKey: Key.globalHotKey),
           let preference = HotKeyConfiguration.legacy(named: legacy) {
            storeHotKey(preference)
            return preference
        }

        return .configured(.defaultConfiguration)
    }

    private func storeHotKey(_ preference: HotKeyPreference) {
        let payload: HotKeyPayload
        switch preference {
        case .configured(let configuration):
            payload = HotKeyPayload(version: 1, enabled: true, configuration: configuration)
        case .disabled:
            payload = HotKeyPayload(version: 1, enabled: false, configuration: nil)
        }
        if let data = try? JSONEncoder().encode(payload) {
            defaults.set(data, forKey: Key.globalHotKey)
        }
    }
}
