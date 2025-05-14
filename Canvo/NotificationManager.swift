import Foundation
import UserNotifications
import SwiftUI

// Main NotificationManager class with proper concurrency support on iOS 16+
final class NotificationManager {
    static let shared = NotificationManager()
    
    // Notification intervals: days before due date when notifications should be shown
    private let notificationIntervals = [0, 1, 4, 7, 10, 14]
    
    // Create a notification category for tasks with actions
    private let taskCategoryIdentifier = "TASK_CATEGORY"
    
    private init() {
        setupNotificationCategories()
    }
    
    // Request notification permission
    func requestPermission(completion: ((Bool, Error?) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let completion = completion {
                completion(granted, error)
            }
            
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Error requesting notification permission: \(error.localizedDescription)")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    // Setup custom notification categories with actions
    private func setupNotificationCategories() {
        // "Complete" action for task notifications
        let completeAction = UNNotificationAction(
            identifier: "COMPLETE_TASK",
            title: "Complete",
            options: .foreground
        )
        
        // Create the task category with actions
        let taskCategory = UNNotificationCategory(
            identifier: taskCategoryIdentifier,
            actions: [completeAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Register the category
        UNUserNotificationCenter.current().setNotificationCategories([taskCategory])
    }
    
    // Check if notifications are enabled in settings
    private func areNotificationsEnabled() -> Bool {
        // Read the AppStorage value directly
        return UserDefaults.standard.bool(forKey: "enableNotifications")
    }
    
    // Schedule notifications for a task
    func scheduleNotifications(for task: Task) {
        // Skip if notifications are disabled in settings
        guard areNotificationsEnabled() else { return }
        
        // Skip if no due date
        guard let dueDate = task.dueDate else { return }
        
        // Remove existing notifications for this task to avoid duplicates
        removeNotifications(for: task)
        
        // Get current date (without time for comparison)
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())
        let taskDueDate = calendar.startOfDay(for: dueDate)
        
        // Calculate days until due date
        let daysUntilDue = calendar.dateComponents([.day], from: now, to: taskDueDate).day ?? 0
        
        // If due date is in the past, don't schedule notifications
        guard daysUntilDue >= 0 else { return }
        
        // Determine which intervals to use based on days until due
        let applicableIntervals = notificationIntervals.filter { $0 <= daysUntilDue }
        
        // Schedule a notification for each applicable interval
        for interval in applicableIntervals {
            scheduleNotification(for: task, daysBeforeDue: interval)
        }
    }
    
    // Schedule a specific notification at the given interval
    private func scheduleNotification(for task: Task, daysBeforeDue interval: Int) {
        // Skip if notifications are disabled in settings
        guard areNotificationsEnabled() else { return }
        
        guard let dueDate = task.dueDate else { return }
        
        let calendar = Calendar.current
        
        // Calculate notification date (interval days before due date)
        guard let notificationDate = calendar.date(byAdding: .day, value: -interval, to: dueDate) else { return }
        
        // Set notification time to 5:00 AM
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: notificationDate)
        dateComponents.hour = 5
        dateComponents.minute = 0
        dateComponents.second = 0
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = interval == 0 
            ? "\(task.name) is due today!"
            : "\(task.name) due in \(interval) day\(interval == 1 ? "" : "s")"
        content.sound = .default
        content.categoryIdentifier = taskCategoryIdentifier
        
        // Add task ID to the user info so we can identify it later
        content.userInfo = ["taskID": task.id.uuidString]
        
        // Create trigger
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // Create request with unique identifier
        let identifier = "task-\(task.id.uuidString)-\(interval)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Schedule notification
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification for task \(task.name): \(error.localizedDescription)")
            }
        }
    }
    
    // Remove notifications for a task
    func removeNotifications(for task: Task) {
        let identifiers = notificationIntervals.map { "task-\(task.id.uuidString)-\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // Reschedule notifications for all tasks in all task lists
    func rescheduleAllNotifications(for taskLists: [TaskList]) {
        // Skip if notifications are disabled in settings
        guard areNotificationsEnabled() else {
            // Remove all pending notifications if notifications are disabled
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }
        
        // First remove all pending notifications
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Then schedule notifications for all tasks with due dates
        for taskList in taskLists {
            for task in taskList.tasks where task.dueDate != nil && !task.isCompleted {
                scheduleNotifications(for: task)
            }
        }
    }
    
    // Handle notification response
    func handleNotificationResponse(_ response: UNNotificationResponse, completion: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // Extract task ID from user info
        guard let taskIDString = userInfo["taskID"] as? String,
              let taskID = UUID(uuidString: taskIDString) else {
            completion()
            return
        }
        
        // Handle "Complete" action
        if response.actionIdentifier == "COMPLETE_TASK" {
            markTaskAsCompleted(taskID: taskID)
        }
        
        completion()
    }
    
    // Mark a task as completed
    private func markTaskAsCompleted(taskID: UUID) {
        // Load task lists
        var taskLists = DataManager.load()
        var taskFound = false
        
        // Find and mark the task as completed
        for listIndex in 0..<taskLists.count {
            if let taskIndex = taskLists[listIndex].tasks.firstIndex(where: { $0.id == taskID }) {
                taskLists[listIndex].tasks[taskIndex].isCompleted = true
                taskFound = true
                break
            }
        }
        
        // Save the updated task lists if a task was found and marked as completed
        if taskFound {
            DataManager.save(lists: taskLists)
            NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
        }
    }
    
    // Debug function to test notifications by scheduling a task with specific time intervals
    func createDebugTaskForNotificationTesting() {
        // Skip if notifications are disabled in settings
        guard areNotificationsEnabled() else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate when the next 5 AM will be
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = 5
        components.minute = 0
        components.second = 0
        
        // If it's already past 5 AM today, set to 5 AM tomorrow
        guard var nextFiveAM = calendar.date(from: components) else { return }
        if nextFiveAM < now {
            nextFiveAM = calendar.date(byAdding: .day, value: 1, to: nextFiveAM) ?? nextFiveAM
        }
        
        // Calculate dueDate for today + notification interval
        // For testing, we'll create tasks that should trigger notifications very soon
        let minutesUntilNextFiveAM = calendar.dateComponents([.minute], from: now, to: nextFiveAM).minute ?? 0
        print("Next 5 AM is in \(minutesUntilNextFiveAM) minutes")
        
        // Create test tasks for each notification interval
        var taskLists = DataManager.load()
        let debugListName = "Debug Notification Tests"
        
        // Find or create debug list
        var debugList: TaskList
        if let existingList = taskLists.first(where: { $0.name == debugListName }) {
            debugList = existingList
            // Clear existing tasks
            let listIndex = taskLists.firstIndex(where: { $0.id == existingList.id })!
            taskLists[listIndex].tasks.removeAll()
        } else {
            debugList = TaskList(name: debugListName)
            taskLists.append(debugList)
        }
        
        let listIndex = taskLists.firstIndex(where: { $0.id == debugList.id })!
        
        // Set due dates that will trigger notifications at the next 5 AM
        // This works by setting due dates that are exactly the right number of days
        // in the future based on our notification intervals
        for interval in notificationIntervals {
            let dueDate = calendar.date(byAdding: .day, value: interval, to: nextFiveAM)!
            let task = Task(
                name: "Test \(interval) day notification",
                notes: "This task should trigger a notification at the next 5 AM",
                dueDate: dueDate
            )
            
            taskLists[listIndex].tasks.append(task)
            print("Created test task due in \(interval) days at \(dueDate)")
        }
        
        // Save tasks and schedule notifications
        DataManager.save(lists: taskLists)
        rescheduleAllNotifications(for: taskLists)
        
        print("Created test tasks. You should receive notifications at the next 5 AM (\(nextFiveAM))")
        
        // Also print all pending notifications for debugging
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("\n===== PENDING NOTIFICATIONS (\(requests.count)) =====")
            for (index, request) in requests.enumerated() {
                if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                    let triggerDate = trigger.nextTriggerDate() ?? Date()
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .medium
                    print("\(index+1). ID: \(request.identifier)")
                    print("   - Will fire at: \(formatter.string(from: triggerDate))")
                    print("   - Content: \(request.content.title) - \(request.content.body)")
                }
            }
            print("==========================================\n")
        }
    }
    
    // Function to check all pending notifications without waiting for them
    func checkPendingNotifications() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            print("\n===== PENDING NOTIFICATIONS (\(requests.count)) =====")
            
            // Group notifications by trigger date
            var notificationsByDate: [String: [(String, String)]] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            
            for request in requests {
                var dateString = "Unknown date"
                
                if let trigger = request.trigger as? UNCalendarNotificationTrigger,
                   let nextTriggerDate = trigger.nextTriggerDate() {
                    dateString = dateFormatter.string(from: nextTriggerDate)
                }
                
                if notificationsByDate[dateString] == nil {
                    notificationsByDate[dateString] = []
                }
                
                notificationsByDate[dateString]?.append((request.content.title, request.content.body))
            }
            
            // Print notifications grouped by date
            for (date, notifications) in notificationsByDate.sorted(by: { $0.key < $1.key }) {
                print("\nNotifications scheduled for \(date):")
                for (index, notification) in notifications.enumerated() {
                    print("  \(index + 1). \(notification.0): \(notification.1)")
                }
            }
            
            print("\n=========================================")
        }
    }
}

// Add Sendable conformance for iOS 16+
@available(iOS 16.0, *)
extension NotificationManager: @unchecked Sendable {} 