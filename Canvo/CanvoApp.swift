//
//  CanvoApp.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI
import UserNotifications
import EventKit

@main
struct CanvoApp: App {
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var streakService = StreakService()
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("hasRequestedNotifications") private var hasRequestedNotifications = false
    @State private var showWelcome = true
    @State private var showNotificationPermission = false
    
    // Initialize UNUserNotificationCenter delegate
    init() {
        // Set up notification delegate first
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        } else {
            // For iOS 15 and below, use a different approach
            setupLegacyNotificationDelegate()
        }
        
        // Don't request permission immediately on init
        // Instead, we'll request it after the app is fully loaded
        // This prevents potential crashes during app launch
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
                            // Show notification permission request after welcome screen
                            if !hasRequestedNotifications && enableNotifications {
                                NotificationManager.shared.requestPermission { granted, error in
                                    // Since we're modifying @AppStorage, ensure we're on main thread
                                    DispatchQueue.main.async { [self] in
                                        hasRequestedNotifications = true
                                        if granted {
                                            // Schedule notifications for all tasks
                                            let taskLists = DataManager.load()
                                            NotificationManager.shared.rescheduleAllNotifications(for: taskLists)
                                        }
                                    }
                                }
                            }
                        }
                } else {
                    ContentView()
                        .environmentObject(themeManager)
                        .environmentObject(streakService)
                        .preferredColorScheme(themeManager.useSystemAppearance ? nil : (themeManager.isDarkMode ? .dark : .light))
                        .onAppear {
                            // Update daily streak when app opens
                            streakService.checkAndUpdateDailyStreak()
                            
                            // Schedule notifications for all tasks when the app appears (if enabled)
                            let taskLists = DataManager.load()
                            NotificationManager.shared.rescheduleAllNotifications(for: taskLists)
                        }
                        .onChange(of: enableNotifications) { newValue in
                            // Handle changes to notification settings
                            let taskLists = DataManager.load()
                            if newValue {
                                // Show permission request if not already shown
                                if !hasRequestedNotifications {
                                    showNotificationPermission = true
                                } else {
                                    // Re-request permission and schedule notifications
                                    NotificationManager.shared.requestPermission { granted, _ in
                                        if granted {
                                            NotificationManager.shared.rescheduleAllNotifications(for: taskLists)
                                        }
                                    }
                                }
                            } else {
                                // Remove all pending notifications
                                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                            }
                        }
                        .sheet(isPresented: $showNotificationPermission) {
                            NotificationPermissionView()
                                .environmentObject(themeManager)
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

