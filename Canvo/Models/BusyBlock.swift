import Foundation

struct BusyBlock: Identifiable, Codable {
    let id: UUID
    var start: Date
    var end: Date
    var title: String
    
    init(id: UUID = UUID(), start: Date, end: Date, title: String = "Busy") {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
    }
} 