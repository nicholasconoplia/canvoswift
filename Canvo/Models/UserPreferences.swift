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
    
    var hoursPerWeek: Double      // e.g. 10
    var sessionDuration: TimeInterval // e.g. 3600 (1 hour)
    var workTimePreferences: Set<WorkTimePreference>
    
    init(hoursPerWeek: Double = 10, 
         sessionDuration: TimeInterval = 3600,
         workTimePreferences: Set<WorkTimePreference> = [.morning]) {
        self.hoursPerWeek = hoursPerWeek
        self.sessionDuration = sessionDuration
        self.workTimePreferences = workTimePreferences
    }
    
    static func load() -> UserPreferences {
        if let data = UserDefaults.standard.data(forKey: "UserPreferences"),
           let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) {
            return preferences
        }
        return UserPreferences()
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "UserPreferences")
        }
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
} 