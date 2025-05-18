import SwiftUI

// MARK: - Assignment Card View
struct AssignmentCardView: View {
    let assignment: CanvasKitAssignment
    @ObservedObject var viewModel: CanvasIntegrationViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingAddTaskModal = false
    @State private var offset: CGFloat = 0
    @State private var showingAddButton = false
    
    private var submissionStatus: SubmissionStatus {
        viewModel.submissionStatus(for: assignment)
    }
    
    private func openCanvasURL() {
        if let urlString = assignment.html_url,
           let url = URL(string: urlString) {
            UIApplication.shared.open(url)
        }
    }
    
    var body: some View {
        ZStack {
            // Green background with + button that appears when swiped
            HStack {
                Spacer()
                
                Button {
                    showingAddTaskModal = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.green)
                        .cornerRadius(12)
                }
                .padding(.trailing, 12)
                .opacity(offset < -60 ? 1 : 0)
            }
            
            // Card content
            VStack(alignment: .leading, spacing: 4) {
                // Assignment Title and Type
                HStack {
                    Text(assignment.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // Submission Status Badge
                    SubmissionStatusBadgeView(status: submissionStatus)
                }
                
                // Due Date if available
                if let dueDate = assignment.due_at {
                    HStack {
                        Text("Due: \(formatDueDate(dueDate))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        // Days Left Bubble
                        if let daysLeft = calculateDaysLeft(dueDate),
                           !submissionStatus.state.isCompleted {
                            DaysLeftBubbleView(daysLeft: daysLeft)
                        }
                    }
                }
                
                // Points if available
                if let points = assignment.points_possible {
                    Text("Points: \(Int(points))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Submission details if available
                if let detail = submissionStatus.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // View in Canvas button
                if assignment.html_url != nil {
                    HStack {
                        Spacer()
                        Button(action: openCanvasURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                    .font(.caption)
                                Text("VIEW IN CANVAS")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.themeColor.opacity(0.1))
                            .foregroundColor(themeManager.themeColor)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            .offset(x: offset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        // Only allow left swipe (negative offset)
                        if gesture.translation.width < 0 {
                            // Limit the drag to maximum -80 points
                            offset = max(gesture.translation.width, -80)
                            
                            // Start showing the add button when we've swiped enough
                            if offset < -40 && !showingAddButton {
                                withAnimation {
                                    showingAddButton = true
                                }
                            }
                        }
                    }
                    .onEnded { gesture in
                        // If swiped far enough, keep it open
                        if gesture.translation.width < -60 {
                            withAnimation {
                                offset = -80
                            }
                        } else {
                            // Otherwise, reset position
                            withAnimation {
                                offset = 0
                                showingAddButton = false
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showingAddTaskModal) {
            // Reset the offset after the sheet is dismissed
            withAnimation {
                offset = 0
                showingAddButton = false
            }
        } content: {
            AddToTaskView(assignment: assignment, isPresented: $showingAddTaskModal)
                .environmentObject(themeManager)
        }
        .onAppear {
            addToDueSoonIfNeeded()
        }
    }
    
    private func formatDueDate(_ dateString: String) -> String {
        guard let date = DateFormatter.iso8601Full.date(from: dateString) else {
            return "No due date"
        }
        return DateFormatter.submissionDateFormatter.string(from: date)
    }
    
    private func calculateDaysLeft(_ dateString: String) -> Int? {
        guard let dueDate = DateFormatter.iso8601Full.date(from: dateString) else {
            return nil
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: dueDate)
        return components.day
    }
    
    // MARK: - Auto Due Soon Check
    private func shouldAddToDueSoon() -> Bool {
        guard let dueDate = assignment.due_at,
              let date = DateFormatter.iso8601Full.date(from: dueDate) else {
            return false
        }
        
        // Check if it's due within 7 days
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.day], from: now, to: date)
        guard let daysLeft = components.day else { return false }
        
        // Only add if:
        // 1. Due within 7 days
        // 2. Not already completed
        // 3. Not past due
        // 4. Not submitted or graded
        return daysLeft <= 7 && 
               daysLeft >= 0 && 
               !submissionStatus.state.isCompleted &&
               submissionStatus.state != .submitted &&
               submissionStatus.state != .graded
    }
    
    private func addToDueSoonIfNeeded() {
        guard shouldAddToDueSoon() else { return }
        
        // Load current task lists
        var taskLists = DataManager.load()
        
        // Check if task is already in any list
        let isAlreadyAdded = taskLists.contains { list in
            list.tasks.contains { task in
                task.name == assignment.name
            }
        }
        
        if isAlreadyAdded {
            return
        }
        
        // Find or create "Due Soon" list
        let dueSoonListName = "Due Soon"
        if let dueSoonIndex = taskLists.firstIndex(where: { $0.name == dueSoonListName }) {
            // Add to existing Due Soon list
            let newTask = Task(
                name: assignment.name,
                notes: nil,
                isCompleted: false,
                dueDate: DateFormatter.iso8601Full.date(from: assignment.due_at ?? ""),
                priority: .medium,
                isEditing: false
            )
            taskLists[dueSoonIndex].tasks.append(newTask)
        } else {
            // Create new Due Soon list
            let newTask = Task(
                name: assignment.name,
                notes: nil,
                isCompleted: false,
                dueDate: DateFormatter.iso8601Full.date(from: assignment.due_at ?? ""),
                priority: .medium,
                isEditing: false
            )
            let dueSoonList = TaskList(
                id: UUID(),
                name: dueSoonListName,
                tasks: [newTask]
            )
            taskLists.append(dueSoonList)
        }
        
        // Save updated lists
        DataManager.save(lists: taskLists)
        
        // Notify about the update
        NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
    }
}

// MARK: - Days Left Bubble View
struct DaysLeftBubbleView: View {
    let daysLeft: Int
    
    private var backgroundColor: Color {
        if daysLeft < 0 {
            return .red         // Past due
        } else if daysLeft == 0 {
            return .orange      // Due today
        } else if daysLeft <= 3 {
            return .yellow      // Due soon
        } else {
            return .green       // Due later
        }
    }
    
    private var displayText: String {
        if daysLeft < 0 {
            return "\(abs(daysLeft))d late"
        } else if daysLeft == 0 {
            return "Due today"
        } else if daysLeft == 1 {
            return "1d left"
        } else {
            return "\(daysLeft)d left"
        }
    }
    
    var body: some View {
        Text(displayText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(daysLeft <= 3 ? .black : .white)  // Dark colors get black text
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(8)
    }
}

// MARK: - Submission Status Badge View
struct SubmissionStatusBadgeView: View {
    let status: SubmissionStatus
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var backgroundColor: Color {
        switch status.state {
        case .graded:
            return .green
        case .submitted:
            return themeManager.themeColor
        case .late:
            return .orange
        case .missing:
            return .red
        case .notSubmitted:
            return .gray
        }
    }
    
    var body: some View {
        Text(status.displayText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(8)
    }
}

// Extension to determine if a submission is completed
extension SubmissionStatus.State {
    var isCompleted: Bool {
        switch self {
        case .graded, .submitted:
            return true
        case .notSubmitted, .late, .missing:
            return false
        }
    }
}

// MARK: - Preview
struct AssignmentCardView_Previews: PreviewProvider {
    static var previews: some View {
        AssignmentCardView(
            assignment: CanvasKitAssignment(
                id: 1,
                name: "Sample Assignment",
                due_at: "2024-05-20T23:59:59Z",
                submission_types: ["online_text_entry"],
                points_possible: 100
            ),
            viewModel: CanvasIntegrationViewModel()
        )
        .environmentObject(ThemeManager())
    }
} 