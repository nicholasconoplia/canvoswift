//
//  CanvoApp.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI

@main
struct CanvoApp: App {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .preferredColorScheme(themeManager.useSystemAppearance ? nil : (themeManager.isDarkMode ? .dark : .light))
        }
    }
}
