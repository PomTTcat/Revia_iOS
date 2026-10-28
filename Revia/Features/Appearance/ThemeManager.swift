import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

struct ThemeColorPair {
    let light: UInt
    let dark: UInt
    init(_ light: UInt, _ dark: UInt) { self.light = light; self.dark = dark }
}

struct ThemeColors {
    let ink: ThemeColorPair
    let accent: ThemeColorPair
    let muted: ThemeColorPair
    let background: ThemeColorPair
    let surface: ThemeColorPair
    let fresh: ThemeColorPair
    let review: ThemeColorPair
    let border: ThemeColorPair
    let onAccent: ThemeColorPair
    let marker: ThemeColorPair
}

enum AppTheme: String, CaseIterable, Identifiable {
    case forest, ocean, iris, clay
    static let preference = "app.colorTheme"
    static func current(in defaults: UserDefaults = .standard) -> AppTheme {
        defaults.string(forKey: preference).flatMap(Self.init(rawValue:)) ?? .forest
    }
    var id: String { rawValue }
    var title: String { L("color_" + rawValue) }
    var iconName: String? {
        switch self {
        case .forest: return nil
        case .ocean: return "AppIconOcean"
        case .iris: return "AppIconIris"
        case .clay: return "AppIconClay"
        }
    }
    var previewName: String {
        switch self {
        case .forest: return "ThemeForest"
        case .ocean: return "ThemeOcean"
        case .iris: return "ThemeIris"
        case .clay: return "ThemeClay"
        }
    }
    var brandBackground: UInt {
        switch self {
        case .forest: return 0x051711
        case .ocean: return 0x020D25
        case .iris: return 0x190423
        case .clay: return 0x291001
        }
    }
    var glow: UInt {
        switch self {
        case .forest: return 0x8AFFAD
        case .ocean: return 0x80E8FF
        case .iris: return 0xD7ABFF
        case .clay: return 0xFFC18A
        }
    }
    var colors: ThemeColors {
        switch self {
        case .forest:
            return ThemeColors(ink: .init(0x243B33, 0xE3ECE6), accent: .init(0x33755C, 0x8DCEAA),
                               muted: .init(0x526459, 0xA3B3A8), background: .init(0xFAFBF7, 0x0D1511),
                               surface: .init(0xFFFFFF, 0x18221E), fresh: .init(0xE2F0DE, 0x1D3528),
                               review: .init(0xECEEEB, 0x202823), border: .init(0xCDD6CE, 0x3E5145),
                               onAccent: .init(0xFFFFFF, 0x10271B), marker: .init(0x858D87, 0x8E9A92))
        case .ocean:
            return ThemeColors(ink: .init(0x24374D, 0xE0EAF6), accent: .init(0x2E658F, 0x93C6EE),
                               muted: .init(0x506277, 0xA4B6CB), background: .init(0xF7FAFD, 0x0D1520),
                               surface: .init(0xFFFFFF, 0x172330), fresh: .init(0xDFECF8, 0x1B3248),
                               review: .init(0xEAEFF4, 0x202B39), border: .init(0xCAD6E2, 0x3D526A),
                               onAccent: .init(0xFFFFFF, 0x10283D), marker: .init(0x818C99, 0x8C9BAC))
        case .iris:
            return ThemeColors(ink: .init(0x3C304F, 0xECE4F5), accent: .init(0x74518F, 0xCBB0E6),
                               muted: .init(0x685B74, 0xBBAFC8), background: .init(0xFBF8FD, 0x17111E),
                               surface: .init(0xFFFFFF, 0x241C2E), fresh: .init(0xEDE2F5, 0x372744),
                               review: .init(0xF0ECF3, 0x2C2435), border: .init(0xD9CDE2, 0x594568),
                               onAccent: .init(0xFFFFFF, 0x2A183C), marker: .init(0x918797, 0xA295AD))
        case .clay:
            return ThemeColors(ink: .init(0x493329, 0xF3E7DE), accent: .init(0x965138, 0xE8B195),
                               muted: .init(0x735E52, 0xC5B1A4), background: .init(0xFDF9F5, 0x1C1410),
                               surface: .init(0xFFFFFF, 0x2B211B), fresh: .init(0xF7E5D8, 0x422D21),
                               review: .init(0xF3EDE7, 0x332820), border: .init(0xE0CFC3, 0x665044),
                               onAccent: .init(0xFFFFFF, 0x351D12), marker: .init(0x978B82, 0xAE9D90))
        }
    }
}

@MainActor
protocol AppIconChanging {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }
    func changeIcon(to name: String?, completion: @escaping @MainActor (Error?) -> Void)
}

@MainActor
private final class SystemAppIconChanger: AppIconChanging {
#if canImport(UIKit)
    var supportsAlternateIcons: Bool { UIApplication.shared.supportsAlternateIcons }
    var alternateIconName: String? { UIApplication.shared.alternateIconName }
    func changeIcon(to name: String?, completion: @escaping @MainActor (Error?) -> Void) {
        UIApplication.shared.setAlternateIconName(name) { error in
            Task { @MainActor in completion(error) }
        }
    }
#else
    var supportsAlternateIcons: Bool { false }
    var alternateIconName: String? { nil }
    func changeIcon(to name: String?, completion: @escaping @MainActor (Error?) -> Void) { completion(nil) }
#endif
}

/// Owns the saved color choice and serializes user-initiated system icon changes.
@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var selected: AppTheme
    @Published private(set) var changingIcon = false
    @Published var iconError: String?
    private let defaults: UserDefaults
    private let icons: any AppIconChanging
    init(defaults: UserDefaults = .standard, icons: (any AppIconChanging)? = nil) {
        self.defaults = defaults
        self.icons = icons ?? SystemAppIconChanger()
        selected = AppTheme.current(in: defaults)
    }
    func select(_ theme: AppTheme) {
        guard !changingIcon else { return }
        defaults.set(theme.rawValue, forKey: AppTheme.preference)
        selected = theme
        iconError = nil
        guard icons.alternateIconName != theme.iconName else { return }
        guard icons.supportsAlternateIcons else {
            iconError = L("icon_unavailable")
            return
        }
        changingIcon = true
        icons.changeIcon(to: theme.iconName) { [weak self] error in
            guard let self else { return }
            self.changingIcon = false
            if error != nil { self.iconError = L("icon_failed") }
        }
    }
}
