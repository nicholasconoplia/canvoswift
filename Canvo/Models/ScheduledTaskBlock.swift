import Foundation

struct ScheduledTaskBlock: Identifiable, Codable {
    let id: UUID
    var taskId: UUID
    var start: Date
    var end: Date

    init(id: UUID = UUID(), taskId: UUID, start: Date, end: Date) {
        self.id = id
        self.taskId = taskId
        self.start = start
        self.end = end
    }
} 