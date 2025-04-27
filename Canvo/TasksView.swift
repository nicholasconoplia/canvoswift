//
//  ContentView.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI

struct TasksView: View {
    // Binding to parent state
    @Binding var showingSettings: Bool
    @Binding var taskLists: [TaskList]
    @Binding var isAddTaskExpanded: Bool
    @Binding var contextMenuTask: Task? 
    @Binding var contextMenuTaskListID: UUID?
    @Binding var showingContextMenu: Bool

    // State local to TasksView
    @State private var newListName: String = ""
    @State private var expandedListIDs: Set<UUID> = [] // Initialize here or in onAppear

    // Custom initializer to handle initial expanded state if needed (can be simplified)
    init(showingSettings: Binding<Bool>, 
         taskLists: Binding<[TaskList]>,
         isAddTaskExpanded: Binding<Bool>,
         contextMenuTask: Binding<Task?>,
         contextMenuTaskListID: Binding<UUID?>,
         showingContextMenu: Binding<Bool>) {
        self._showingSettings = showingSettings
        self._taskLists = taskLists
        self._isAddTaskExpanded = isAddTaskExpanded
        self._contextMenuTask = contextMenuTask
        self._contextMenuTaskListID = contextMenuTaskListID
        self._showingContextMenu = showingContextMenu
        // Initialize expanded state based on the initial lists passed in
        _expandedListIDs = State(initialValue: Set(taskLists.wrappedValue.map { $0.id }))
    }

    // --- Body ---
    var body: some View {
        ZStack {
            // Main content: List input and Task List Area
            VStack(alignment: .leading, spacing: 0) {
                addListInputArea // Stays here
                taskListArea     // Stays here
            } // End Main VStack
             // Removed sheet modifiers - handled in ContentView

            // Floating Add Button (in bottom right) - Stays here
            VStack {
                Spacer() // Push to bottom
                HStack {
                    Spacer() // Push to right
                    floatingAddButton
                }
                .padding()
            }
            .ignoresSafeArea(.keyboard) // Keep button visible when keyboard appears

             // Removed Dimmed Background Overlay - handled in ContentView
             // Removed Context Menu View - handled in ContentView
             // Removed Notes Editor Overlay - handled in ContentView
             // Removed Priority Picker Overlays - handled in ContentView
             // Removed Add Task Form Overlay - handled in ContentView
        }
         // Removed .onAppear / .onDisappear related to moved logic
         // Removed .onChange(of: taskLists) - handled in ContentView
         // Removed animation modifiers for overlays - handled in ContentView
    }

    // MARK: - Computed View Properties (Local to TasksView)

    /// Input field and button for adding a new TaskList.
    private var addListInputArea: some View {
        HStack {
            TextField("Enter new list name", text: $newListName)
                .textFieldStyle(.roundedBorder)
            Button("Add") {
                addList()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// The main list displaying TaskLists and their Tasks.
    private var taskListArea: some View {
        List {
            // Use the binding $taskLists
            ForEach($taskLists) { $list in 
                DisclosureGroup(isExpanded: isExpandedBinding(for: list.id)) {
                    if list.tasks.isEmpty {
                        Text("No tasks yet")
                            .foregroundColor(.gray)
                            .padding(.leading)
                    } else {
                        // Iterate over task indices to allow deletion/modification if needed
                        // Or simply display tasks if direct modification isn't needed here
                        ForEach(list.tasks) { task in 
                            taskRow(for: task, in: list)
                                .padding(.leading) 
                        }
                    }
                } label: {
                    Text(list.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 15, bottom: 8, trailing: 15))
            }
            // Optional: Add .onDelete and .onMove modifiers here if list/task reordering is desired within this view
        }
        .listStyle(.plain)
         // Initialize expanded IDs when taskLists are loaded or change
         .onAppear { initializeExpandedIDs() }
         .onChange(of: taskLists) { initializeExpandedIDs() } 
    }

    /// A row representing a single Task in the list.
    private func taskRow(for task: Task, in list: TaskList) -> some View {
         HStack {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .gray)
                .onTapGesture {
                     toggleTaskCompletion(taskID: task.id, listID: list.id)
                 }
            Text(task.name)
            Spacer()
            // Display Priority Bubble (if set)
            if let priority = task.priority {
                Text(priority.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .foregroundColor(.white)
                    .background(color(for: priority))
                    .cornerRadius(6)
            }
            // Display Due Date
            if let dueDate = task.dueDate {
                Text(format(date: dueDate))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            // Context Menu Button - Sets state in ContentView via binding
            Button {
                contextMenuTask = task
                contextMenuTaskListID = list.id
                showingContextMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
                    .padding(.leading, 5)
            }
            .buttonStyle(.borderless)
        }
    }

    /// Floating Action Button for adding a new task - Toggles state in ContentView
    private var floatingAddButton: some View {
        Button {
            withAnimation {
                isAddTaskExpanded.toggle()
            }
        } label: {
            Image(systemName: isAddTaskExpanded ? "xmark" : "plus")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Circle().fill(Color.purple))
                .shadow(radius: 4)
        }
    }

    // MARK: - Helper Methods (Local to TasksView)
    
    /// Initializes or updates the set of expanded list IDs.
    private func initializeExpandedIDs() {
         // Keep existing expanded lists expanded if they still exist
         let currentListIDs = Set(taskLists.map { $0.id })
         expandedListIDs = expandedListIDs.intersection(currentListIDs)
         // Optionally, expand new lists by default:
         // let newLists = currentListIDs.subtracting(expandedListIDs)
         // expandedListIDs.formUnion(newLists)
         // Or ensure at least one is expanded if list is not empty:
         if expandedListIDs.isEmpty && !taskLists.isEmpty {
             expandedListIDs.insert(taskLists[0].id)
         }
    }

    /// Adds a new list to the taskLists binding.
    private func addList() {
        guard !newListName.isEmpty else { return }
        let newList = TaskList(name: newListName)
        taskLists.append(newList)
        // Optionally expand the new list
        expandedListIDs.insert(newList.id)
        newListName = "" // Clear input
    }
    
    /// Toggles the completion state of a task using its ID.
    private func toggleTaskCompletion(taskID: UUID, listID: UUID) {
         if let listIndex = taskLists.firstIndex(where: { $0.id == listID }),
            let taskIndex = taskLists[listIndex].tasks.firstIndex(where: { $0.id == taskID }) {
             // Mutate the binding
             taskLists[listIndex].tasks[taskIndex].isCompleted.toggle()
         }
     }

    /// Creates a Binding<Bool> to check/modify if a listID is in the local expanded set.
    private func isExpandedBinding(for listID: UUID) -> Binding<Bool> {
        Binding<Bool>(
            get: { self.expandedListIDs.contains(listID) },
            set: { isExpanding in
                if isExpanding {
                    self.expandedListIDs.insert(listID)
                } else {
                    self.expandedListIDs.remove(listID)
                }
            }
        )
    }

    // MARK: - Formatting/Color Helpers (Can be moved to extensions or kept here if only used here)

    /// Returns the color associated with a priority level.
    private func color(for priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    /// Formats the due date for display.
    private func format(date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDueDate = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDueDate)
        guard let days = components.day else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
        if days == 0 { return "Due Today" }
        else if days == 1 { return "Due Tomorrow" }
        else if days > 1 { return "in \(days) days" }
        else if days == -1 { return "Due Yesterday" }
        else { return "\(abs(days)) days ago" }
    }
    
    // Removed methods related to overlays: submitNewTask, taskBinding, contextMenuDatePickerSheet, datePickerSheet, deleteSelectedTask, dismissAllOverlays, updateSelectedList
}

// --- Preview ---
// Preview needs significant updates to provide necessary bindings
#Preview {
    // Create a wrapper view to provide state for the preview
    struct TasksViewPreviewWrapper: View {
        @State var showingSettings = false
        @State var taskLists = [TaskList(name: "Preview List", tasks: [Task(name: "Task 1", priority: .high), Task(name: "Task 2")])]
        @State var isAddTaskExpanded = false
        @State var contextMenuTask: Task? = nil
        @State var contextMenuTaskListID: UUID? = nil
        @State var showingContextMenu = false

        var body: some View {
            TasksView(
                showingSettings: $showingSettings,
                taskLists: $taskLists,
                isAddTaskExpanded: $isAddTaskExpanded,
                contextMenuTask: $contextMenuTask,
                contextMenuTaskListID: $contextMenuTaskListID,
                showingContextMenu: $showingContextMenu
            )
        }
    }
    return TasksViewPreviewWrapper()
}
