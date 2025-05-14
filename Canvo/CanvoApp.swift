//
//  CanvoApp.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI
import UserNotifications

@main
struct CanvoApp: App {
    @StateObject private var themeManager = ThemeManager()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @State private var showWelcome = true
    
    // Initialize UNUserNotificationCenter delegate
    init() {
        // Set up notification delegate
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        } else {
            // For iOS 15 and below, use a different approach
            setupLegacyNotificationDelegate()
        }
        
        // Request notification permission only if enabled
        if UserDefaults.standard.bool(forKey: "enableNotifications") {
            NotificationManager.shared.requestPermission()
        }
    }
    
    // Setup notification delegate for iOS 15 and below
    private func setupLegacyNotificationDelegate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = LegacyNotificationDelegate()
    }
    
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
                        .onAppear {
                            // Schedule notifications for all tasks when the app appears (if enabled)
                            let taskLists = DataManager.load()
                            NotificationManager.shared.rescheduleAllNotifications(for: taskLists)
                        }
                        .onChange(of: enableNotifications) { newValue in
                            // Handle changes to notification settings
                            let taskLists = DataManager.load()
                            if newValue {
                                // Re-request permission and schedule notifications
                                NotificationManager.shared.requestPermission()
                                NotificationManager.shared.rescheduleAllNotifications(for: taskLists)
                            } else {
                                // Remove all pending notifications
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                }
            }
        }
    }
}

// UNUserNotificationCenterDelegate implementation for iOS 16+
@available(iOS 16.0, *)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationDelegate()
    
    // Show notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationManager.shared.handleNotificationResponse(response, completion: completionHandler)
    }
}

// Legacy UNUserNotificationCenterDelegate implementation for iOS 15 and below
class LegacyNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    // Show notifications when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               willPresent notification: UNNotification, 
                               withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the notification even when the app is in the foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                               didReceive response: UNNotificationResponse, 
                               withCompletionHandler completionHandler: @escaping () -> Void) {
        NotificationManager.shared.handleNotificationResponse(response, completion: completionHandler)
    }
}

