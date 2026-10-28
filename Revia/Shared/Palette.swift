import SwiftUI
import UIKit

/// Semantic colors resolve from the central theme and effective light/dark appearance.
enum Palette {
    static var ink: Color { adaptive(AppTheme.current().colors.ink) }
    static var accent: Color { adaptive(AppTheme.current().colors.accent) }
    static var muted: Color { adaptive(AppTheme.current().colors.muted) }
    static var background: Color { adaptive(AppTheme.current().colors.background) }
    static var surface: Color { adaptive(AppTheme.current().colors.surface) }
    static var fresh: Color { adaptive(AppTheme.current().colors.fresh) }
    static var review: Color { adaptive(AppTheme.current().colors.review) }
    static var border: Color { adaptive(AppTheme.current().colors.border) }
    static var onAccent: Color { adaptive(AppTheme.current().colors.onAccent) }
    static var marker: Color { adaptive(AppTheme.current().colors.marker) }
    static var brandBackground: Color { color(AppTheme.current().brandBackground) }
    static var glow: Color { color(AppTheme.current().glow) }

    static func color(_ value: UInt) -> Color { Color(uiColor: uiColor(value)) }
    private static func uiColor(_ value: UInt) -> UIColor {
        UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }
    private static func adaptive(_ pair: ThemeColorPair) -> Color {
        Color(uiColor: UIColor { traits in
            uiColor(traits.userInterfaceStyle == .dark ? pair.dark : pair.light)
        })
    }
}
