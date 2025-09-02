import Foundation

struct DaySchedule: Identifiable, Codable {
    let id: UUID
    var day: Int // 1 = Sunday, 2 = Monday, etc. (matches Calendar.Component.weekday)
    var isEnabled: Bool
    var startTime: Date
    var endTime: Date
    
    init(id: UUID = UUID(), day: Int, isEnabled: Bool = false, startTime: Date = Date(), endTime: Date = Date()) {
        self.id = id
        self.day = day
        self.isEnabled = isEnabled
        self.startTime = startTime
        self.endTime = endTime
    }
    
    var dayName: String {
        switch day {
        case 1: return "Sunday"
        case 2: return "Monday"
        case 3: return "Tuesday"
        case 4: return "Wednesday"
        case 5: return "Thursday"
        case 6: return "Friday"
        case 7: return "Saturday"
        default: return "Unknown"
        }
    }
}

class WorkingHours: ObservableObject, Codable {
    @Published var schedules: [DaySchedule]
    
    enum CodingKeys: String, CodingKey {
        case schedules
    }
    
    init() {
        // Initialize with default schedule (Mon-Fri, 9-5)
        self.schedules = (1...7).map { day in
            let isWeekday = (2...6).contains(day)
            let defaultStart = Calendar.current.date(from: DateComponents(hour: 9, minute: 0)) ?? Date()
            let defaultEnd = Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date()
            return DaySchedule(day: day, isEnabled: isWeekday, startTime: defaultStart, endTime: defaultEnd)
        }
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schedules = try container.decode([DaySchedule].self, forKey: .schedules)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schedules, forKey: .schedules)
    }
    
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "WorkingHours")
        }
    }
    
    static func load() -> WorkingHours {
        if let data = UserDefaults.standard.data(forKey: "WorkingHours"),
           let decoded = try? JSONDecoder().decode(WorkingHours.self, from: data) {
            return decoded
        }
        return WorkingHours()
    }
} 