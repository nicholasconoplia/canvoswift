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

    @State private var showingMoveSheet = false
    @State private var selectedHeaderID: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            contextButton(title: "Move to Header", action: { showingMoveSheet = true })
            Divider()
            contextButton(title: "Change Priority", action: onChangePriority)
            Divider()
            contextButton(title: "Change Due Date", action: onChangeDueDate)
            Divider()
            contextButton(title: "Add/Edit Notes", action: onAddEditNotes)
            Divider()
            contextButton(title: "Delete", isDestructive: true, action: onDelete)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(maxWidth: 300)
        .padding()
        .sheet(isPresented: $showingMoveSheet) {
            MoveToHeaderSheet(
                currentListID: listID,
                taskLists: $taskLists,
                onMove: { destListID in
                    moveTaskToHeader(destListID: destListID)
                    showingMoveSheet = false
                    showingContextMenu = false
                }
            )
        }
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

    // Helper for moving the task to another header
    private func moveTaskToHeader(destListID: UUID) {
        guard let sourceListIdx = taskLists.firstIndex(where: { $0.id == listID }),
              let taskIdx = taskLists[sourceListIdx].tasks.firstIndex(where: { $0.id == task.id }),
              let destListIdx = taskLists.firstIndex(where: { $0.id == destListID }) else { return }
        let movingTask = taskLists[sourceListIdx].tasks.remove(at: taskIdx)
        taskLists[destListIdx].tasks.append(movingTask)
        DataManager.save(lists: taskLists)
        NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
    }

    // --- Actions ---

    // TODO: Add functions for Move, Priority, Notes

    // REMOVED: datePickerSheet view was here

    // REMOVED: dismissContextMenu helper was here
}

// Sheet for selecting a header to move the task to
struct MoveToHeaderSheet: View {
    let currentListID: UUID
    @Binding var taskLists: [TaskList]
    let onMove: (UUID) -> Void

    var body: some View {
        NavigationView {
            List {
                ForEach(taskLists.filter { $0.id != currentListID }) { list in
                    Button(list.name) {
                        onMove(list.id)
                    }
                }
            }
            .navigationTitle("Move to Header")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }
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