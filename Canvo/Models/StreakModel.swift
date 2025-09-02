import Foundation

struct StreakModel: Codable {
    // MARK: - Properties
    var dailyStreak: Int
    var weeklyStudyStreak: Int
    var dailyStreakLastUpdate: Date
    var weeklyStudyStreakLastUpdate: Date
    var dailyStreakLevel: Int
    var weeklyStudyStreakLevel: Int
    var totalDailyStreakDays: Int
    var totalWeeklyStudyWeeks: Int
    
    // MARK: - Computed Properties
    var dailyStreakProgress: Double {
        return calculateProgress(forStreak: dailyStreak, atLevel: dailyStreakLevel)
    }
    
    var weeklyStudyStreakProgress: Double {
        return calculateProgress(forStreak: weeklyStudyStreak, atLevel: weeklyStudyStreakLevel)
    }
    
    // MARK: - Initialization
    init() {
        self.dailyStreak = 0
        self.weeklyStudyStreak = 0
        self.dailyStreakLastUpdate = Date()
        self.weeklyStudyStreakLastUpdate = Date()
        self.dailyStreakLevel = 1
        self.weeklyStudyStreakLevel = 1
        self.totalDailyStreakDays = 0
        self.totalWeeklyStudyWeeks = 0
    }
    
    // MARK: - Level Calculation
    private func calculateStreaksForNextLevel(at level: Int) -> Int {
        switch level {
        case 1...10: return 1
        case 11...30: return 2 + ((level - 11) / 10)
        case 31...60: return 4 + ((level - 31) / 10)
        case 61...90: return 7 + ((level - 61) / 10)
        case 91...100: return 10 + ((level - 91) / 3)
        default: return 15
        }
    }
    
    private func calculateProgress(forStreak streak: Int, atLevel level: Int) -> Double {
        let streaksNeeded = calculateStreaksForNextLevel(at: level)
        return Double(streak) / Double(streaksNeeded)
    }
    
    // MARK: - Streak Management
    mutating func updateDailyStreak() {
        let calendar = Calendar.current
        let today = Date()
        
        // Check if last update was yesterday
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
           calendar.isDate(dailyStreakLastUpdate, inSameDayAs: yesterday) {
            dailyStreak += 1
            totalDailyStreakDays += 1
            checkAndUpdateDailyLevel()
        } else if !calendar.isDate(dailyStreakLastUpdate, inSameDayAs: today) {
            // Reset streak if more than a day has passed
            dailyStreak = 1
            totalDailyStreakDays += 1
        }
        
        dailyStreakLastUpdate = today
    }
    
    mutating func updateWeeklyStudyStreak() {
        let calendar = Calendar.current
        let today = Date()
        let currentWeek = calendar.component(.weekOfYear, from: today)
        let lastUpdateWeek = calendar.component(.weekOfYear, from: weeklyStudyStreakLastUpdate)
        let currentYear = calendar.component(.year, from: today)
        let lastUpdateYear = calendar.component(.year, from: weeklyStudyStreakLastUpdate)
        
        if currentYear == lastUpdateYear {
            if currentWeek == lastUpdateWeek {
                // Already updated this week
                return
            } else if currentWeek == lastUpdateWeek + 1 {
                // Consecutive week
                weeklyStudyStreak += 1
                totalWeeklyStudyWeeks += 1
                checkAndUpdateWeeklyLevel()
            } else {
                // Non-consecutive week
                weeklyStudyStreak = 1
                totalWeeklyStudyWeeks += 1
            }
        } else if currentYear == lastUpdateYear + 1 {
            // Check for week continuity across years
            let lastDayOfLastYear = calendar.date(from: DateComponents(year: lastUpdateYear, month: 12, day: 31))!
            let lastWeekOfLastYear = calendar.component(.weekOfYear, from: lastDayOfLastYear)
            if currentWeek == 1 && lastUpdateWeek == lastWeekOfLastYear {
                weeklyStudyStreak += 1
                totalWeeklyStudyWeeks += 1
                checkAndUpdateWeeklyLevel()
            } else {
                weeklyStudyStreak = 1
                totalWeeklyStudyWeeks += 1
            }
        } else {
            // Reset for any other case
            weeklyStudyStreak = 1
            totalWeeklyStudyWeeks += 1
        }
        
        weeklyStudyStreakLastUpdate = today
    }
    
    private mutating func checkAndUpdateDailyLevel() {
        let streaksNeeded = calculateStreaksForNextLevel(at: dailyStreakLevel)
        if dailyStreak >= streaksNeeded && dailyStreakLevel < 100 {
            dailyStreak = 0
            dailyStreakLevel += 1
            NotificationCenter.default.post(name: .didLevelUpDailyStreak, object: nil)
        }
    }
    
    private mutating func checkAndUpdateWeeklyLevel() {
        let streaksNeeded = calculateStreaksForNextLevel(at: weeklyStudyStreakLevel)
        if weeklyStudyStreak >= streaksNeeded && weeklyStudyStreakLevel < 100 {
            weeklyStudyStreak = 0
            weeklyStudyStreakLevel += 1
            NotificationCenter.default.post(name: .didLevelUpWeeklyStreak, object: nil)
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let didLevelUpDailyStreak = Notification.Name("didLevelUpDailyStreak")
    static let didLevelUpWeeklyStreak = Notification.Name("didLevelUpWeeklyStreak")
} 