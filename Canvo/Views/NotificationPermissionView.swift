import SwiftUI

struct NotificationPermissionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("hasRequestedNotifications") private var hasRequestedNotifications = false
    
    let features = [
        (icon: "bell.badge", title: "Task Due Reminders", description: "Get notified when your tasks are approaching their due dates"),
        (icon: "clock.badge.checkmark", title: "Session Start Alerts", description: "Know exactly when it's time to start working on your scheduled tasks"),
        (icon: "checkmark.circle", title: "Session Completion", description: "Track your progress and reschedule if you need more time"),
        (icon: "calendar.badge.clock", title: "Smart Rescheduling", description: "Automatically find the best time slots if you need to reschedule")
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 15) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(themeManager.themeColor)
                
                Text("Stay on Track with Notifications")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Enable notifications to make the most of Canvo's features:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            
            // Features list
            VStack(alignment: .leading, spacing: 20) {
                ForEach(features, id: \.title) { feature in
                    HStack(spacing: 15) {
                        Image(systemName: feature.icon)
                            .font(.title2)
                            .foregroundColor(themeManager.themeColor)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(feature.title)
                                .font(.headline)
                            Text(feature.description)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 15) {
                Button(action: {
                    NotificationManager.shared.requestPermission { granted, error in
                        DispatchQueue.main.async {
                            hasRequestedNotifications = true
                            if granted {
                                // Schedule notifications for existing tasks
                                let taskLists = DataManager.load()
                                NotificationManager.shared.rescheduleAllNotifications(for: taskLists)
                            }
                            dismiss()
                        }
                    }
                }) {
                    Text("Enable Notifications")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.themeColor)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    hasRequestedNotifications = true
                    dismiss()
                }) {
                    Text("Not Now")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .padding()
    }
} 