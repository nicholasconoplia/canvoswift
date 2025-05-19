import SwiftUI

struct TaskTimeAllocationView: View {
    let tasks: [Task]
    let busyBlocks: [BusyBlock]
    @Binding var taskSessions: [TaskSession]
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var selectedTaskId: UUID?
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isEditing = false
    @State private var showingScheduleForm = false
    
    private var tasksWithSessions: [(task: Task, sessions: [TaskSession])] {
        tasks.map { task in
            let sessions = taskSessions.filter { $0.taskId == task.id }
            return (task: task, sessions: sessions.sorted { $0.start < $1.start })
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(tasks) { task in
                        TaskScheduleCard(
                            task: task,
                            sessions: taskSessions.filter { $0.taskId == task.id }
                                .sorted { $0.start < $1.start },
                            isEditing: isEditing,
                            themeColor: themeManager.themeColor,
                            onDelete: { sessionId in
                                taskSessions.removeAll { $0.id == sessionId }
                            },
                            onAddSessions: {
                                selectedTaskId = task.id
                                showingScheduleForm = true
                            }
                        )
                    }
                    
                    if tasks.isEmpty {
                        Text("No tasks to schedule")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Schedule Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Done" : "Edit") {
                        isEditing.toggle()
                    }
                }
                
                if !isEditing {
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink("Preferences") {
                            UserPreferencesView()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingScheduleForm) {
                if let taskId = selectedTaskId, let task = tasks.first(where: { $0.id == taskId }) {
                    NavigationView {
                        ScheduleFormView(
                            task: task,
                            existingSessions: taskSessions.filter { $0.taskId == task.id },
                            busyBlocks: busyBlocks,
                            onSchedule: { newSessions in
                                // Remove existing sessions for this task
                                taskSessions.removeAll { $0.taskId == task.id }
                                // Add new sessions
                                taskSessions.append(contentsOf: newSessions)
                                showingScheduleForm = false
                            },
                            allTaskSessions: $taskSessions
                        )
                    }
                }
            }
            .alert("Scheduling Result", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
}

struct TaskScheduleCard: View {
    let task: Task
    let sessions: [TaskSession]
    let isEditing: Bool
    let themeColor: Color
    let onDelete: (UUID) -> Void
    let onAddSessions: () -> Void
    
    private var groupedSessions: [(date: Date, sessions: [TaskSession])] {
        let grouped = Dictionary(grouping: sessions) { session in
            Calendar.current.startOfDay(for: session.start)
        }
        return grouped.map { (date: $0.key, sessions: $0.value) }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Task info
            VStack(alignment: .leading, spacing: 8) {
                Text(task.name)
                    .font(.headline)
                
                if let dueDate = task.dueDate {
                    Text("Due: \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            if !sessions.isEmpty {
                Text("Scheduled Sessions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                ForEach(groupedSessions, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        ForEach(group.sessions) { session in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Session \(session.sessionNumber)/\(session.totalSessions)")
                                        .font(.subheadline)
                                    Text(session.start.formatted(date: .omitted, time: .shortened))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if isEditing {
                                    Button(action: { onDelete(session.id) }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            
            if isEditing {
                Button(action: onAddSessions) {
                    HStack {
                        Image(systemName: sessions.isEmpty ? "calendar.badge.plus" : "plus.circle")
                        Text(sessions.isEmpty ? "Schedule Sessions" : "Add More Sessions")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(themeColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct ScheduleFormView: View {
    let task: Task
    let existingSessions: [TaskSession]
    let busyBlocks: [BusyBlock]
    let onSchedule: ([TaskSession]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var totalHours: Double = 1
    @State private var sessionMinutes: Double = 30
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var preferences = UserPreferences.load()
    
    // Get all task sessions from parent view
    @Binding var allTaskSessions: [TaskSession]
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Task: \(task.name)")
                    .font(.headline)
                
                if let dueDate = task.dueDate {
                    Text("Due: \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            VStack(spacing: 15) {
                Text("How much total time do you need?")
                    .font(.headline)
                
                Stepper(value: $totalHours, in: 0.5...24, step: 0.5) {
                    Text("\(totalHours, specifier: "%.1f") hours")
                }
                .padding()
                
                Text("How long should each session be?")
                    .font(.headline)
                
                Stepper(value: $sessionMinutes, in: 15...120, step: 15) {
                    Text("\(Int(sessionMinutes)) minutes")
                }
                .padding()
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Schedule Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Schedule") {
                    scheduleTask()
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .alert("Scheduling Result", isPresented: $showingAlert) {
            Button("OK") { 
                if !alertMessage.contains("Could not find") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func scheduleTask() {
        guard let dueDate = task.dueDate else { return }
        
        let totalDuration = totalHours * 3600
        let sessionDuration = sessionMinutes * 60
        
        let sessions = TaskScheduler.scheduleSessions(
            for: task,
            totalDuration: totalDuration,
            sessionDuration: sessionDuration,
            busyBlocks: busyBlocks,
            deadline: dueDate,
            existingSessions: allTaskSessions,
            preferences: preferences
        )
        
        if sessions.isEmpty {
            alertMessage = "Could not find suitable time slots. Try shorter sessions or check your schedule."
            showingAlert = true
        } else {
            onSchedule(sessions)
            alertMessage = "Successfully scheduled \(sessions.count) sessions for '\(task.name)'"
            showingAlert = true
        }
    }
} 