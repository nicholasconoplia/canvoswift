import SwiftUI

struct TaskDurationSetupView: View {
    @Binding var taskLists: [TaskList]
    @Environment(\.dismiss) private var dismiss
    @State private var taskDurations: [UUID: TimeInterval] = [:]
    @State private var showingSchedulePreview = false
    
    private var allTasks: [(task: Task, listName: String)] {
        var tasks: [(task: Task, listName: String)] = []
        for list in taskLists {
            tasks.append(contentsOf: list.tasks.map { ($0, list.name) })
        }
        return tasks.sorted { ($0.task.dueDate ?? .distantFuture) < ($1.task.dueDate ?? .distantFuture) }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What are you working on this week?")
                            .font(.title2)
                            .bold()
                        
                        Text("Add estimated durations to get the most out of scheduling.")
                            .foregroundColor(.secondary)
                        Text("The more accurate your estimates, the better we can help you plan!")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // Tasks section
                    VStack(spacing: 16) {
                        ForEach(allTasks, id: \.task.id) { taskInfo in
                            TaskDurationRow(
                                task: taskInfo.task,
                                listName: taskInfo.listName,
                                duration: Binding(
                                    get: { taskDurations[taskInfo.task.id] ?? 1800 }, // Default 30 min
                                    set: { taskDurations[taskInfo.task.id] = $0 }
                                )
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    // Quick suggestions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Add")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["15 min", "30 min", "1 hour", "2 hours", "4 hours"], id: \.self) { duration in
                                    Button(action: {
                                        // Add new task with this duration
                                    }) {
                                        Text(duration)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Task Durations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        showingSchedulePreview = true
                    }
                    .disabled(taskDurations.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingSchedulePreview) {
            SchedulePreviewView(taskLists: $taskLists, taskDurations: taskDurations)
        }
    }
}

struct TaskDurationRow: View {
    let task: Task
    let listName: String
    @Binding var duration: TimeInterval
    
    private let durations: [(label: String, seconds: TimeInterval)] = [
        ("15m", 900),
        ("30m", 1800),
        ("1h", 3600),
        ("2h", 7200),
        ("4h", 14400),
        ("8h", 28800)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Task name and list
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                
                HStack {
                    Text(listName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let dueDate = task.dueDate {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Duration picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(durations, id: \.seconds) { durationOption in
                        Button(action: {
                            duration = durationOption.seconds
                        }) {
                            Text(durationOption.label)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(duration == durationOption.seconds ? Color.accentColor : Color(.systemGray6))
                                .foregroundColor(duration == durationOption.seconds ? .white : .primary)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

#Preview {
    TaskDurationSetupView(taskLists: .constant([
        TaskList(name: "Work", tasks: [
            Task(name: "Create presentation", dueDate: Date().addingTimeInterval(86400)),
            Task(name: "Review documents", dueDate: Date().addingTimeInterval(172800))
        ])
    ]))
} 