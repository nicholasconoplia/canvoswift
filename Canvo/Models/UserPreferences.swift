import Foundation

struct UserPreferences: Codable {
    enum WorkTimePreference: String, Codable, CaseIterable {
        case morning = "morning"      // 6AM - 12PM
        case afternoon = "afternoon"  // 12PM - 5PM
        case evening = "evening"      // 5PM - 10PM
        case midnight = "midnight"    // 10PM - 2AM
        
        var timeRange: (start: Int, end: Int) {
            switch self {
            case .morning:
                return (6, 12)   // 6 AM to 12 PM
            case .afternoon:
                return (12, 17)  // 12 PM to 5 PM
            case .evening:
                return (17, 22)  // 5 PM to 10 PM
            case .midnight:
                return (22, 2)   // 10 PM to 2 AM
            }
        }
        
        var displayText: (title: String, subtitle: String, icon: String) {
            switch self {
            case .morning:
                return ("Morning", "6 AM - 12 PM", "sunrise")
            case .afternoon:
                return ("Afternoon", "12 PM - 5 PM", "sun.max")
            case .evening:
                return ("Evening", "5 PM - 10 PM", "moon.stars")
            case .midnight:
                return ("Midnight", "10 PM - 2 AM", "moon")
            }
        }
    }
    
    struct WorkingHours: Codable {
        var startTime: Date // Store as minutes from midnight
        var endTime: Date   // Store as minutes from midnight
        
        // Convert to/from minutes for easier calculations
        var startMinutes: Int {
            Calendar.current.component(.hour, from: startTime) * 60 +
            Calendar.current.component(.minute, from: startTime)
        }
        
        var endMinutes: Int {
            Calendar.current.component(.hour, from: endTime) * 60 +
            Calendar.current.component(.minute, from: endTime)
        }
    }
    
    // Task type-specific buffer times (in minutes)
    struct BufferTimes: Codable {
        var highPriority: TimeInterval = 15
        var mediumPriority: TimeInterval = 30
        var lowPriority: TimeInterval = 45
        var assignment: TimeInterval = 30
        var quiz: TimeInterval = 15
        var general: TimeInterval = 30
    }
    
    // Task distribution preferences
    struct DistributionPreferences: Codable {
        var preferEvenDistribution: Bool = true
        var frontLoadTasks: Bool = false
        var backLoadTasks: Bool = false
        var maximumTasksPerTimeSlot: Int = 2
        var preferredDaySpacing: Int = 1 // Minimum days between sessions of the same task
    }
    
    var workingHours: WorkingHours
    var preferredSessionDuration: TimeInterval // in minutes
    var workingDays: Set<Int> // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    var minimumBreakBetweenSessions: TimeInterval // in minutes
    var maximumSessionsPerDay: Int
    var workTimePreferences: Set<WorkTimePreference>
    var bufferTimes: BufferTimes
    var distributionPreferences: DistributionPreferences
    
    static var `default`: UserPreferences {
        let calendar = Calendar.current
        let defaultStart = calendar.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
        let defaultEnd = calendar.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
        
        return UserPreferences(
            workingHours: WorkingHours(startTime: defaultStart, endTime: defaultEnd),
            preferredSessionDuration: 30,
            workingDays: Set(2...6), // Monday to Friday by default
            minimumBreakBetweenSessions: 15,
            maximumSessionsPerDay: 8,
            workTimePreferences: [.morning, .afternoon], // Default to morning and afternoon
            bufferTimes: BufferTimes(),
            distributionPreferences: DistributionPreferences()
        )
    }
    
    func isWithinPreferredTime(_ hour: Int) -> Bool {
        for preference in workTimePreferences {
            let range = preference.timeRange
            if preference == .midnight {
                // Handle midnight case that crosses over to next day
                if hour >= range.start || hour < range.end {
                    return true
                }
            } else {
                if hour >= range.start && hour < range.end {
                    return true
                }
            }
        }
        return false
    }
    
    // Get buffer time based on task type and priority
    func getBufferTime(priority: Priority?, isAssignment: Bool = false, isQuiz: Bool = false) -> TimeInterval {
        if isQuiz {
            return bufferTimes.quiz
        } else if isAssignment {
            return bufferTimes.assignment
        } else if let priority = priority {
            switch priority {
            case .high:
                return bufferTimes.highPriority
            case .medium:
                return bufferTimes.mediumPriority
            case .low:
                return bufferTimes.lowPriority
            }
        }
        return bufferTimes.general
    }
}

// MARK: - UserPreferences Storage
extension UserPreferences {
    private static let storageKey = "user_preferences"
    
    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return .default
        }
        return preferences
    }
    
    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: UserPreferences.storageKey)
    }
} 