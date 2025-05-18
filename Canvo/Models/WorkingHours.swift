import Foundation

class WorkingHours: ObservableObject {
    @Published var schedules: [DaySchedule]
    
    init() {
        self.schedules = (1...7).map { day in
            DaySchedule(
                dayOfWeek: day,
                isEnabled: true,
                startTime: Calendar.current.date(from: DateComponents(hour: 9)) ?? Date(),
                endTime: Calendar.current.date(from: DateComponents(hour: 17)) ?? Date()
            )
        }
    }
    
    static func load() -> WorkingHours {
        // TODO: Load from persistent storage
        return WorkingHours()
    }
}

struct DaySchedule: Identifiable {
    let id = UUID()
    let dayOfWeek: Int // 1 = Sunday, 2 = Monday, ..., 7 = Saturday
    var isEnabled: Bool
    var startTime: Date
    var endTime: Date
    
    var dayName: String {
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[dayOfWeek - 1]
    }
} 