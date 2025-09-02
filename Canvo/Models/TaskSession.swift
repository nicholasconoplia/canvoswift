import Foundation

struct TaskSession: Identifiable, Codable, Equatable {
    let id: UUID
    let taskId: UUID
    let taskTitle: String
    var start: Date
    var duration: TimeInterval
    var sessionNumber: Int
    var totalSessions: Int
    
    init(id: UUID = UUID(), taskId: UUID, taskTitle: String, start: Date, duration: TimeInterval, sessionNumber: Int, totalSessions: Int) {
        self.id = id
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.start = start
        self.duration = duration
        self.sessionNumber = sessionNumber
        self.totalSessions = totalSessions
    }
    
    var end: Date {
        start.addingTimeInterval(duration)
    }
    
    static func == (lhs: TaskSession, rhs: TaskSession) -> Bool {
        return lhs.id == rhs.id &&
               lhs.taskId == rhs.taskId &&
               lhs.taskTitle == rhs.taskTitle &&
               lhs.start == rhs.start &&
               lhs.duration == rhs.duration &&
               lhs.sessionNumber == rhs.sessionNumber &&
               lhs.totalSessions == rhs.totalSessions
    }
} 