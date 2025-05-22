import Foundation
import UserNotifications
import UIKit

class StreakService: ObservableObject {
    // MARK: - Properties
    @Published private(set) var streakModel: StreakModel
    private let userDefaults = UserDefaults.standard
    private let streakKey = "userStreakData"
    
    // MARK: - Initialization
    init() {
        if let data = userDefaults.data(forKey: streakKey),
           let decodedModel = try? JSONDecoder().decode(StreakModel.self, from: data) {
            self.streakModel = decodedModel
        } else {
            self.streakModel = StreakModel()
        }
        
        // Setup notification observers
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    func checkAndUpdateDailyStreak() {
        streakModel.updateDailyStreak()
        saveStreak()
        scheduleStreakNotifications()
    }
    
    func checkAndUpdateWeeklyStudyStreak() {
        streakModel.updateWeeklyStudyStreak()
        saveStreak()
        scheduleStreakNotifications()
    }
    
    // MARK: - Private Methods
    private func saveStreak() {
        if let encoded = try? JSONEncoder().encode(streakModel) {
            userDefaults.set(encoded, forKey: streakKey)
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(handleLevelUp),
                                            name: .didLevelUpDailyStreak,
                                            object: nil)
        
        NotificationCenter.default.addObserver(self,
                                            selector: #selector(handleLevelUp),
                                            name: .didLevelUpWeeklyStreak,
                                            object: nil)
    }
    
    @objc private func handleLevelUp(notification: Notification) {
        // Show confetti animation via notification
        NotificationCenter.default.post(name: .showConfetti, object: nil)
        
        // Play haptic feedback
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }
    
    private func scheduleStreakNotifications() {
        let center = UNUserNotificationCenter.current()
        
        // Remove existing notifications
        center.removeAllPendingNotificationRequests()
        
        // Schedule daily streak notification
        let dailyContent = UNMutableNotificationContent()
        dailyContent.title = "Keep Your Streak Going! 🔥"
        dailyContent.body = "Don't break your \(streakModel.dailyStreak) day streak. Open Canvo today!"
        dailyContent.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = 20 // 8 PM
        let dailyTrigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let dailyRequest = UNNotificationRequest(identifier: "dailyStreak",
                                               content: dailyContent,
                                               trigger: dailyTrigger)
        
        // Schedule weekly study streak notification
        let weeklyContent = UNMutableNotificationContent()
        weeklyContent.title = "Weekly Study Check 📚"
        weeklyContent.body = "Complete any task this week to maintain your study streak!"
        weeklyContent.sound = .default
        
        dateComponents.weekday = 5 // Friday
        dateComponents.hour = 16 // 4 PM
        let weeklyTrigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let weeklyRequest = UNNotificationRequest(identifier: "weeklyStreak",
                                                content: weeklyContent,
                                                trigger: weeklyTrigger)
        
        // Schedule notifications
        center.add(dailyRequest)
        center.add(weeklyRequest)
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showConfetti = Notification.Name("showConfetti")
} 
