import Foundation
import SwiftUI // Needed for Color if we store it directly

// Enum for Task Priority
enum Priority: String, CaseIterable, Identifiable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    var id: String { self.rawValue }
}

// Struct for a single Task
struct Task: Identifiable, Hashable, Codable {
    let id = UUID()
    var name: String
    var notes: String? // Optional notes
    var isCompleted: Bool = false
    var dueDate: Date? // Optional due date
    var priority: Priority? = .medium // Optional priority, default medium
    var isEditing: Bool = false // State for editing mode
    
    // Add CodingKeys to exclude isEditing from encoding
    enum CodingKeys: String, CodingKey {
        case id, name, notes, isCompleted, dueDate, priority
    }
    
    // Custom encode implementation to exclude isEditing
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(dueDate, forKey: .dueDate)
        try container.encodeIfPresent(priority, forKey: .priority)
    }
}

// Struct for a Task List
struct TaskList: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var tasks: [Task] = [] // Array to hold tasks for this list
    
    // Default initializer creates a new UUID
    init(name: String, tasks: [Task] = []) {
        self.id = UUID()
        self.name = name
        self.tasks = tasks
    }
    
    // Custom initializer allowing an existing ID to be passed
    init(id: UUID, name: String, tasks: [Task] = []) {
        self.id = id
        self.name = name
        self.tasks = tasks
    }
} 