import SwiftUI

struct TaskContextMenu: View {
    @Binding var task: Task
    let listID: UUID // ID of the list the task belongs to
    @Binding var taskLists: [TaskList] // To allow moving/deleting
    @Binding var showingContextMenu: Bool
    let onChangeDueDate: () -> Void // Closure to trigger sheet in parent
    let onAddEditNotes: () -> Void // Closure to trigger notes editor in parent
    let onChangePriority: () -> Void // Closure to trigger priority picker in parent
    let onDelete: () -> Void // Closure to trigger deletion in parent

    // State for presenting sub-sheets (kept for future use)
    // @State private var showingMoveSheet = false
    // @State private var showingPrioritySheet = false
    // @State private var showingNotesSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Placeholder Buttons - Actions to be implemented
            contextButton(title: "Move to Header", action: { /* TODO: Implement Move */ })
            Divider()
            contextButton(title: "Change Priority", action: onChangePriority)
            Divider()
            // Call the closure passed from the parent view
            contextButton(title: "Change Due Date", action: onChangeDueDate)
            Divider()
            contextButton(title: "Add/Edit Notes", action: onAddEditNotes)
            Divider()
            contextButton(title: "Delete", isDestructive: true, action: onDelete)
        }
        .background(Color(.systemBackground)) // Use system background for light/dark mode
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(maxWidth: 300) // Limit width
        .padding() // Padding around the VStack
        // REMOVED: .sheet modifier was here
    }

    // Helper for creating menu buttons
    private func contextButton(title: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(isDestructive ? .red : .primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // --- Actions ---

    // TODO: Add functions for Move, Priority, Notes

    // REMOVED: datePickerSheet view was here

    // REMOVED: dismissContextMenu helper was here
}

// Preview Provider (Optional - might need dummy data)
#Preview {
    // Need to create mock bindings and data for preview
    struct PreviewWrapper: View {
        @State var task = Task(name: "Preview Task", dueDate: Date())
        @State var lists = [TaskList(name: "Preview List", tasks: [Task(name: "Preview Task")])]
        @State var showing = true

        var body: some View {
            ZStack {
                Color.gray.opacity(0.4).ignoresSafeArea()
                TaskContextMenu(
                    task: $task,
                    listID: lists[0].id,
                    taskLists: $lists,
                    showingContextMenu: $showing,
                    onChangeDueDate: { print("Change Due Date Tapped in Preview") }, // Placeholder action
                    onAddEditNotes: { print("Add/Edit Notes Tapped in Preview") }, // Placeholder action
                    onChangePriority: { print("Change Priority Tapped in Preview") }, // Placeholder action
                    onDelete: { print("Delete Tapped in Preview") } // Placeholder action
                )
            }
        }
    }
    return PreviewWrapper()
} 