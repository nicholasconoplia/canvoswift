import Foundation

struct UserPreferences: Codable {
    var hoursPerWeek: Double      // e.g. 10
    var sessionDuration: TimeInterval // e.g. 3600 (1 hour)

    init(hoursPerWeek: Double = 10, sessionDuration: TimeInterval = 3600) {
        self.hoursPerWeek = hoursPerWeek
        self.sessionDuration = sessionDuration
    }
} 