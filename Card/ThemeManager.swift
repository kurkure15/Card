//
//  ThemeManager.swift
//  Card
//
//  Created by Ankur Yadav on 26/01/26.
//

import SwiftUI
import Combine

// MARK: - ThemeManager
/// Manages the current theme and persists user preference.
/// This is an ObservableObject so SwiftUI views automatically update when theme changes.
class ThemeManager: ObservableObject {

    /// The currently active theme - when this changes, all views using it will update
    @Published var currentTheme: Theme {
        didSet {
            // Save user's preference whenever theme changes
            saveThemePreference()
        }
    }

    /// Singleton instance for easy access throughout the app
    static let shared = ThemeManager()

    /// UserDefaults key for storing theme preference
    private let themeKey = "selectedTheme"

    // MARK: - Initialization
    init() {
        // Default to dark mode
        self.currentTheme = .dark
    }

    // MARK: - Theme Switching

    /// Toggle between light and dark themes
    func toggleTheme() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = (currentTheme.id == Theme.light.id) ? .dark : .light
        }
    }

    /// Set a specific theme
    func setTheme(_ theme: Theme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }

    /// Check if dark mode is currently active
    var isDarkMode: Bool {
        currentTheme.id == Theme.dark.id
    }

    // MARK: - Persistence

    /// Save current theme to UserDefaults
    private func saveThemePreference() {
        UserDefaults.standard.set(currentTheme.name, forKey: themeKey)
    }
}

// MARK: - Environment Key
/// This allows us to pass the theme through SwiftUI's environment system
struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .light
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - View Extension
/// Convenience modifier to apply theme to a view hierarchy
extension View {
    func themed(_ theme: Theme) -> some View {
        self.environment(\.theme, theme)
    }
}
