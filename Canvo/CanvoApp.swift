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
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var showWelcome = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if !hasSeenWelcome {
                    WelcomeAnimationView(showWelcome: $showWelcome)
                        .environmentObject(themeManager)
                        .onDisappear {
                            hasSeenWelcome = true
                        }
                } else {
                    ContentView()
                        .environmentObject(themeManager)
                        .preferredColorScheme(themeManager.useSystemAppearance ? nil : (themeManager.isDarkMode ? .dark : .light))
                }
            }
        }
    }
}
