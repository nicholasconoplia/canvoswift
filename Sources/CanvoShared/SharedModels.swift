import Foundation

public struct Task: Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var isCompleted: Bool
    public var dueDate: Date?
    
    public init(id: UUID = UUID(), title: String, isCompleted: Bool = false, dueDate: Date? = nil) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.dueDate = dueDate
    }
}

// TaskManager to handle shared data between app and widget
public class TaskManager {
    public static let shared = TaskManager()
    
    private let userDefaults: UserDefaults?
    private let taskKey = "shared_tasks"
    
    public init() {
        // Initialize with the shared app group
        userDefaults = UserDefaults(suiteName: "group.com.nick.Canvo")
    }
    
    public func saveTasks(_ tasks: [Task]) {
        guard let encoded = try? JSONEncoder().encode(tasks) else { return }
        userDefaults?.set(encoded, forKey: taskKey)
    }
    
    public func loadTasks() -> [Task] {
        guard let data = userDefaults?.data(forKey: taskKey),
              let tasks = try? JSONDecoder().decode([Task].self, from: data) else {
            return []
        }
        return tasks
    }
    
    public func toggleTask(withId id: UUID) {
        var tasks = loadTasks()
        if let index = tasks.firstIndex(where: { $0.id == id }) {
            tasks[index].isCompleted.toggle()
            saveTasks(tasks)
        }
    }
} 