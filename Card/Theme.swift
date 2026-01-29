//
//  Theme.swift
//  Card
//
//  Created by Ankur Yadav on 26/01/26.
//

import SwiftUI
import UIKit

// MARK: - Theme Definition
/// A Theme defines the color palette for the entire app.
/// This is inspired by Any Distance's Palette system.
struct Theme: Equatable, Identifiable {
    let name: String
    let backgroundColor: UIColor
    let foregroundColor: UIColor
    let secondaryForegroundColor: UIColor
    let accentColor: UIColor

    /// Unique identifier based on theme name
    var id: String {
        name.lowercased().replacingOccurrences(of: " ", with: "_")
    }

    // MARK: - SwiftUI Color Accessors
    /// These convert UIColor to SwiftUI Color for use in views

    var background: Color {
        Color(backgroundColor)
    }

    var foreground: Color {
        Color(foregroundColor)
    }

    var secondaryForeground: Color {
        Color(secondaryForegroundColor)
    }

    var accent: Color {
        Color(accentColor)
    }
}

// MARK: - Built-in Themes
extension Theme {

    /// Dark theme - light text on dark background
    static let dark = Theme(
        name: "Dark",
        backgroundColor: UIColor(hex: "0A0A0A"),      // Near black
        foregroundColor: UIColor.white,                // White text
        secondaryForegroundColor: UIColor(hex: "9A9A9A"), // Gray for subtitles
        accentColor: UIColor(hex: "FFC663")            // Warm gold accent
    )

    /// Light theme - dark text on light background
    static let light = Theme(
        name: "Light",
        backgroundColor: UIColor(hex: "ECECEC"),      // Light gray (your current bg)
        foregroundColor: UIColor(hex: "222222"),       // Dark text
        secondaryForegroundColor: UIColor(hex: "C3C3C3"), // Gray for subtitles
        accentColor: UIColor(hex: "FF6B35")            // Warm orange accent
    )

    /// All available themes
    static let allThemes: [Theme] = [.light, .dark]
}

// MARK: - UIColor Extensions
extension UIColor {

    /// Initialize UIColor from hex string (e.g., "FF5733" or "#FF5733")
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b, a: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, 255)
        case 8: // ARGB (32-bit)
            (r, g, b, a) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF, (int >> 24) & 0xFF)
        default:
            (r, g, b, a) = (128, 128, 128, 255)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }

    /// Convert UIColor to hex string
    func toHexString() -> String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        return String(
            format: "%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }

    /// Check if color is dark (useful for determining text color)
    var isDark: Bool {
        var white: CGFloat = 0
        getWhite(&white, alpha: nil)
        return white < 0.5
    }
}
