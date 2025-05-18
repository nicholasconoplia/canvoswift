import Foundation

struct BusyBlock: Identifiable, Codable {
    let id: UUID
    var start: Date
    var end: Date
    var title: String
    var location: String?
    
    init(id: UUID = UUID(), start: Date, end: Date, title: String = "Busy", location: String? = nil) {
        self.id = id
        self.start = start
        self.end = end
        self.title = title
        self.location = location
    }
} 