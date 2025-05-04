//
//  ContentView.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    // Binding to parent state
    @Binding var showingSettings: Bool
    @Binding var taskLists: [TaskList]
    @Binding var isAddTaskExpanded: Bool
    @Binding var contextMenuTask: Task? 
    @Binding var contextMenuTaskListID: UUID?
    @Binding var showingContextMenu: Bool
    @Binding var showingPriorityPicker: Bool
    @Binding var showingContextMenuDatePicker: Bool

    // State local to TasksView
    @State private var newListName: String = ""
    @State private var expandedListIDs: Set<UUID> = [] // Initialize here or in onAppear
    @State private var deleteHeaderAlert = false
    @State private var listToDelete: TaskList?
    @State private var editMode: EditMode = .inactive

    // Custom initializer to handle initial expanded state if needed (can be simplified)
    init(showingSettings: Binding<Bool>, 
         taskLists: Binding<[TaskList]>,
         isAddTaskExpanded: Binding<Bool>,
         contextMenuTask: Binding<Task?>,
         contextMenuTaskListID: Binding<UUID?>,
         showingContextMenu: Binding<Bool>,
         showingPriorityPicker: Binding<Bool>,
         showingContextMenuDatePicker: Binding<Bool>) {
        self._showingSettings = showingSettings
        self._taskLists = taskLists
        self._isAddTaskExpanded = isAddTaskExpanded
        self._contextMenuTask = contextMenuTask
        self._contextMenuTaskListID = contextMenuTaskListID
        self._showingContextMenu = showingContextMenu
        self._showingPriorityPicker = showingPriorityPicker
        self._showingContextMenuDatePicker = showingContextMenuDatePicker
        // Initialize expanded state based on the initial lists passed in
        _expandedListIDs = State(initialValue: Set(taskLists.wrappedValue.map { $0.id }))
    }

    // --- Body ---
    var body: some View {
        ZStack {
            // Main content: List input and Task List Area
            VStack(alignment: .leading, spacing: 0) {
                addListInputArea
                taskListArea
            }

            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    floatingAddButton
                }
                .padding()
            }
            .ignoresSafeArea(.keyboard)
        }
        .alert("Delete List?", isPresented: $deleteHeaderAlert, presenting: listToDelete) { list in
            Button("Delete", role: .destructive) {
                deleteTaskList(list)
            }
            Button("Cancel", role: .cancel) {}
        } message: { list in
            Text("Are you sure you want to delete the list '\(list.name)'? This cannot be undone.")
        }
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
            .tint(themeManager.themeColor)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// The main list displaying TaskLists and their Tasks.
    private var taskListArea: some View {
        List {
            ForEach($taskLists) { $list in
                let isExpanded = isExpandedBinding(for: list.id)
                Section(header:
                    ListHeaderView(
                        list: $list,
                        editMode: editMode,
                        onDelete: {
                            deleteHeaderAlert = true
                            listToDelete = list
                        },
                        isExpanded: isExpanded
                    )
                ) {
                    if isExpanded.wrappedValue {
                        TaskListContentView(
                            list: $list,
                            taskLists: $taskLists,
                            themeManager: themeManager,
                            contextMenuTask: $contextMenuTask,
                            contextMenuTaskListID: $contextMenuTaskListID,
                            showingContextMenu: $showingContextMenu,
                            showingPriorityPicker: $showingPriorityPicker,
                            showingContextMenuDatePicker: $showingContextMenuDatePicker,
                            editMode: editMode
                        )
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            refreshTaskLists()
            NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
        }
        .onAppear {
            refreshTaskLists()
            initializeExpandedIDs()
        }
        .onChange(of: taskLists) { _ in
            updateExpandedIDs()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
    }

    /// Move a task from one list to another (or within the same list) in edit mode
    private func moveTask(from source: IndexSet, to destination: Int, in listID: UUID) {
        guard let sourceListIdx = taskLists.firstIndex(where: { $0.id == listID }) else { return }
        // Collect the tasks to move
        let movingTasks = source.map { taskLists[sourceListIdx].tasks[$0] }
        // Remove from source (must remove in reverse order to avoid index shifting)
        for index in source.sorted(by: >) {
            taskLists[sourceListIdx].tasks.remove(at: index)
        }
        // Insert at destination
        if editMode == .active {
            if let destListIdx = taskLists.firstIndex(where: { $0.id == listID }) {
                // Insert all moving tasks at the destination index
                for (offset, task) in movingTasks.enumerated() {
                    let insertIndex = min(destination + offset, taskLists[destListIdx].tasks.count)
                    taskLists[destListIdx].tasks.insert(task, at: insertIndex)
                }
            } else {
                // Fallback: insert back to source list
                for (offset, task) in movingTasks.enumerated() {
                    let insertIndex = min(destination + offset, taskLists[sourceListIdx].tasks.count)
                    taskLists[sourceListIdx].tasks.insert(task, at: insertIndex)
                }
            }
        }
        DataManager.save(lists: taskLists)
        NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
    }

    /// A view for the editable list header
    private struct ListHeaderView: View {
        @Binding var list: TaskList
        var editMode: EditMode = .inactive
        var onDelete: (() -> Void)? = nil
        @Binding var isExpanded: Bool
        @State private var isEditing = false
        @State private var editedName: String = ""
        
        var body: some View {
            HStack {
                if isEditing {
                    TextField("List name", text: $editedName, onCommit: {
                        if !editedName.isEmpty {
                            list.name = editedName
                        }
                        isEditing = false
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                    .contentShape(Rectangle())
                    .onTapGesture { }
                } else {
                    if editMode == .active, let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle.fill")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(.red)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                    HStack(spacing: 8) {
                        Text(list.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("\(list.tasks.count)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.7))
                            .cornerRadius(10)
                        Spacer()
                        Button(action: { isExpanded.toggle() }) {
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .foregroundColor(.gray)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isExpanded.toggle()
                    }
                }
            }
            .padding(.leading, 4)
        }
    }

    // New TaskListContentView to handle tasks separately
    private struct TaskListContentView: View {
        @Binding var list: TaskList
        @Binding var taskLists: [TaskList]
        @ObservedObject var themeManager: ThemeManager
        @Binding var contextMenuTask: Task?
        @Binding var contextMenuTaskListID: UUID?
        @Binding var showingContextMenu: Bool
        @Binding var showingPriorityPicker: Bool
        @Binding var showingContextMenuDatePicker: Bool
        var editMode: EditMode

        var body: some View {
            if list.tasks.isEmpty {
                Text("No tasks yet")
                    .foregroundColor(.gray)
                    .padding(.leading)
            } else {
                ForEach(Array(list.tasks.enumerated()), id: \.element.id) { index, _ in
                    if index < list.tasks.count {
                        TaskRowView(
                            task: $list.tasks[index],
                            list: list,
                            taskLists: $taskLists,
                            themeManager: themeManager,
                            contextMenuTask: $contextMenuTask,
                            contextMenuTaskListID: $contextMenuTaskListID,
                            showingContextMenu: $showingContextMenu,
                            showingPriorityPicker: $showingPriorityPicker,
                            showingContextMenuDatePicker: $showingContextMenuDatePicker,
                            editMode: editMode
                        )
                        .padding(.leading)
                        .if(editMode == .active) { view in
                            view.onDrag {
                                let task = list.tasks[index]
                                return NSItemProvider(object: task.id.uuidString as NSString)
                            }
                        }
                    }
                }
                .onMove { indices, newOffset in
                    list.tasks.move(fromOffsets: indices, toOffset: newOffset)
                    DataManager.save(lists: taskLists)
                    NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
                }
                .if(editMode == .active) { view in
                    view.onInsert(of: ["public.text"]) { index, providers in
                        guard let provider = providers.first else { return }
                        _ = provider.loadObject(ofClass: NSString.self) { (object, error) in
                            guard let idString = object as? String, let taskID = UUID(uuidString: idString) else { return }
                            DispatchQueue.main.async {
                                for (listIdx, var srcList) in taskLists.enumerated() {
                                    if let taskIdx = srcList.tasks.firstIndex(where: { $0.id == taskID }) {
                                        let movedTask = srcList.tasks.remove(at: taskIdx)
                                        taskLists[listIdx] = srcList
                                        let insertIndex = min(index, taskLists[listIdx].tasks.count)
                                        taskLists[listIdx].tasks.insert(movedTask, at: insertIndex)
                                        DataManager.save(lists: taskLists)
                                        NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // New TaskRowView to handle individual task rows
    private struct TaskRowView: View {
        @Binding var task: Task
        let list: TaskList
        @Binding var taskLists: [TaskList]
        @ObservedObject var themeManager: ThemeManager
        @Binding var contextMenuTask: Task?
        @Binding var contextMenuTaskListID: UUID?
        @Binding var showingContextMenu: Bool
        @Binding var showingPriorityPicker: Bool
        @Binding var showingContextMenuDatePicker: Bool
        var editMode: EditMode

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(task.isCompleted ? themeManager.themeColor : .gray)
                    .font(.system(size: 20))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleTaskCompletion()
                    }
                    .padding(.leading, -8)
                
                if task.isEditing {
                    TextField("Task name", text: $task.name, onCommit: {
                        task.isEditing = false
                    })
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                } else {
                    Text(task.name)
                        .onTapGesture {
                            task.isEditing = true
                        }
                }
                
                Spacer()
                
                if let priority = task.priority {
                    Text(priority.rawValue.uppercased())
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .foregroundColor(.white)
                        .background(color(for: priority))
                        .cornerRadius(6)
                }
                
                if let dueDate = task.dueDate {
                    Text(format(date: dueDate))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
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
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    deleteTask()
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                Button {
                    contextMenuTask = task
                    contextMenuTaskListID = list.id
                    showingContextMenu = false
                    showingPriorityPicker = true
                } label: {
                    Label("Priority", systemImage: "flag.fill")
                }
                .tint(.orange)
                
                Button {
                    contextMenuTask = task
                    contextMenuTaskListID = list.id
                    showingContextMenu = false
                    showingContextMenuDatePicker = true
                } label: {
                    Label("Date", systemImage: "calendar")
                }
                .tint(.blue)
            }
        }

        private func toggleTaskCompletion() {
            if let listIndex = taskLists.firstIndex(where: { $0.id == list.id }),
               let taskIndex = taskLists[listIndex].tasks.firstIndex(where: { $0.id == task.id }) {
                taskLists[listIndex].tasks[taskIndex].isCompleted.toggle()
                DataManager.save(lists: taskLists)
                NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
            }
        }

        private func deleteTask() {
            if let listIndex = taskLists.firstIndex(where: { $0.id == list.id }) {
                taskLists[listIndex].tasks.removeAll { $0.id == task.id }
                DataManager.save(lists: taskLists)
                NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
            }
        }

        private func color(for priority: Priority) -> Color {
            switch priority {
            case .high: return .red
            case .medium: return .orange
            case .low: return .green
            }
        }

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
    }

    /// Floating Action Button for adding a new task
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
                .background(Circle().fill(themeManager.themeColor))
                .shadow(radius: 4)
        }
    }

    // MARK: - Helper Methods (Local to TasksView)
    
    /// Function to explicitly refresh task lists data from storage
    func refreshTaskLists() {
        print("TasksView: Refreshing task lists from storage")
        
        // Store current expanded state
        let currentExpandedIDs = expandedListIDs
        
        // Load fresh data from DataManager
        let freshLists = DataManager.load()
        
        // Important: Create a deep copy to force SwiftUI to recognize changes
        var updatedLists: [TaskList] = []
        for list in freshLists {
            updatedLists.append(list)
        }
        
        // Update task lists with the new copy
        taskLists = updatedLists
        
        // Restore expanded state
        expandedListIDs = currentExpandedIDs
        
        // If no lists are expanded and there are lists, expand the first one
        if expandedListIDs.isEmpty && !taskLists.isEmpty {
            expandedListIDs.insert(taskLists[0].id)
        }
        
        print("TasksView: Refresh complete - found \(taskLists.count) lists")
    }
    
    /// Initializes or updates the set of expanded list IDs.
    private func initializeExpandedIDs() {
        // If no lists are expanded and there are lists, expand the first one by default
        if expandedListIDs.isEmpty && !taskLists.isEmpty {
            expandedListIDs.insert(taskLists[0].id)
        }
    }
    
    /// Updates expanded IDs when task lists change, preserving current expanded state
    private func updateExpandedIDs() {
        // Get current list IDs
        let currentListIDs = Set(taskLists.map { $0.id })
        
        // Only remove expanded IDs for lists that no longer exist
        expandedListIDs = expandedListIDs.intersection(currentListIDs)
        
        // If all lists are now collapsed and we have lists, expand the first one
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
        
        // Save task lists after adding a new list
        DataManager.save(lists: taskLists)
        
        // Post notification to ensure other views update
        NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
    }
    
    /// Deletes a task list
    private func deleteTaskList(_ list: TaskList) {
        // Remove the list from the array
        taskLists.removeAll { $0.id == list.id }
        
        // Remove the ID from expanded IDs if it exists
        expandedListIDs.remove(list.id)
        
        // Save changes to persistent storage
        DataManager.save(lists: taskLists)
        
        // Post notification to ensure other views update
        NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
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
        @State var showingPriorityPicker = false
        @State var showingContextMenuDatePicker = false

        var body: some View {
            TasksView(
                showingSettings: $showingSettings,
                taskLists: $taskLists,
                isAddTaskExpanded: $isAddTaskExpanded,
                contextMenuTask: $contextMenuTask,
                contextMenuTaskListID: $contextMenuTaskListID,
                showingContextMenu: $showingContextMenu,
                showingPriorityPicker: $showingPriorityPicker,
                showingContextMenuDatePicker: $showingContextMenuDatePicker
            )
        }
    }
    return TasksViewPreviewWrapper()
}

// MARK: - Conditional View Modifier Helper
extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}