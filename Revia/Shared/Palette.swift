import SwiftUI
import UIKit

/// Semantic colors follow the effective appearance, including the in-app override.
enum Palette {
    static let ink = adaptive(light: 0x243B33, dark: 0xE3ECE6)
    static let green = adaptive(light: 0x33755C, dark: 0x8DCEAA)
    static let muted = adaptive(light: 0x526459, dark: 0xA3B3A8)
    static let background = adaptive(light: 0xFAFBF7, dark: 0x0D1511)
    static let surface = adaptive(light: 0xFFFFFF, dark: 0x18221E)
    static let fresh = adaptive(light: 0xE2F0DE, dark: 0x1D3528)
    static let review = adaptive(light: 0xECEEEB, dark: 0x202823)
    static let border = adaptive(light: 0xCDD6CE, dark: 0x3E5145)
    static let onAccent = adaptive(light: 0xFFFFFF, dark: 0x10271B)
    static let marker = adaptive(light: 0x858D87, dark: 0x8E9A92)

    private static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                           green: CGFloat((value >> 8) & 0xFF) / 255,
                           blue: CGFloat(value & 0xFF) / 255, alpha: 1)
        })
    }
}
