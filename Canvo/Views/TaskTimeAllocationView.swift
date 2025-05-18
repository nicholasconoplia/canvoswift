import SwiftUI

struct TaskTimeAllocationView: View {
    let tasks: [Task]
    let busyBlocks: [BusyBlock]
    @Binding var taskSessions: [TaskSession]
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentTaskIndex = 0
    @State private var totalHours: Double = 1
    @State private var sessionMinutes: Double = 30
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private var currentTask: Task? {
        guard currentTaskIndex < tasks.count else { return nil }
        return tasks[currentTaskIndex]
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let task = currentTask {
                    // Task info
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Task: \(task.name)")
                            .font(.headline)
                        
                        if let dueDate = task.dueDate {
                            Text("Due: \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    
                    // Time allocation
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
                    
                    // Schedule button
                    Button(action: scheduleCurrentTask) {
                        Text("Schedule Sessions")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .cornerRadius(10)
                    }
                    .padding()
                    
                    Spacer()
                } else {
                    // All tasks scheduled
                    VStack {
                        Text("All tasks have been scheduled!")
                            .font(.headline)
                        
                        Button("Done") {
                            dismiss()
                        }
                        .padding()
                    }
                }
            }
            .padding()
            .navigationTitle("Schedule Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Scheduling Result", isPresented: $showingAlert) {
                Button("OK") {
                    currentTaskIndex += 1
                }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func scheduleCurrentTask() {
        guard let task = currentTask, let dueDate = task.dueDate else { return }
        
        let totalDuration = totalHours * 3600 // Convert hours to seconds
        let sessionDuration = sessionMinutes * 60 // Convert minutes to seconds
        
        let sessions = TaskScheduler.scheduleSessions(
            for: task,
            totalDuration: totalDuration,
            sessionDuration: sessionDuration,
            busyBlocks: busyBlocks,
            deadline: dueDate
        )
        
        if sessions.isEmpty {
            alertMessage = "Could not find suitable time slots. Try shorter sessions or check your schedule."
        } else {
            taskSessions.append(contentsOf: sessions)
            alertMessage = "Successfully scheduled \(sessions.count) sessions for '\(task.name)'"
        }
        
        showingAlert = true
    }
} 