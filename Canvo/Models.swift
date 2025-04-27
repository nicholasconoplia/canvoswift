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
    // Add other properties as needed, e.g., creationDate
}

// Struct for a Task List
struct TaskList: Identifiable, Hashable, Codable {
    let id = UUID()
    var name: String
    var tasks: [Task] = [] // Array to hold tasks for this list
} 