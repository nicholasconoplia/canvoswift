//
//  ContentView.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI
import Security

struct ContentView: View {
    // State for the Settings modal
    @State private var showingSettings = false
    // State for the collapsible Add Task section
    @State private var isAddTaskExpanded = false
    // State for the new task details
    @State private var newTaskName: String = ""
    @State private var newTaskNotes: String = ""
    // State for selected due date
    @State private var newTaskDueDate: Date? = nil
    // State for selected priority
    @State private var newTaskPriority: Priority? = .medium // Default to medium
    // State to control date picker sheet presentation (for Add Task)
    @State private var showingDatePicker = false
    // State for list selection in Add Task
    @State private var selectedListId: UUID? // Store ID instead of index
    // Load initial data using DataManager
    @State private var taskLists: [TaskList] = DataManager.load()
    // State for context menu
    @State private var showingContextMenu = false
    @State private var contextMenuTask: Task? = nil
    @State private var contextMenuTaskListID: UUID? = nil
    // State to control date picker from context menu
    @State private var showingContextMenuDatePicker = false
    // State to control notes editor from context menu
    @State private var showingNotesEditor = false
    // State to control priority picker from context menu
    @State private var showingPriorityPicker = false
    // State to track selected tab
    @State private var selectedTab: Int = 0

    // MARK: - Environment
    
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject private var themeManager: ThemeManager

    // --- Body ---
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                VStack(spacing: 0) {
                    // Tasks Content
                    if selectedTab == 0 {
                        // Tasks Content
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
                    } else {
                        // Canvas Content
                        CanvasIntegrationView()
                    }
                }
                .navigationTitle("Canvo")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .foregroundColor(themeManager.themeColor)
                        }
                    }
                }
            }
            .tabItem {
                Label("Tasks", systemImage: "checklist")
            }
            .tag(0)
            
            NavigationView {
                VStack(spacing: 0) {
                    if selectedTab == 1 {
                        CanvasIntegrationView()
                    }
                }
                .navigationTitle("Canvas")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { 
                        Button {
                            showingSettings = true
                        } label: {
                            Image(systemName: "gear")
                                .foregroundColor(themeManager.themeColor)
                        }
                    }
                }
            }
            .tabItem {
                Label("Canvas", systemImage: "square.and.pencil")
            }
            .tag(1)
        }
        .tint(themeManager.themeColor) // Set tab bar and navigation tint
            .sheet(isPresented: $showingSettings) {
            SettingsView()
            }
            // Add Task Date Picker Sheet
             .sheet(isPresented: $showingDatePicker) {
                datePickerSheet // Moved from TasksView
            }
            // Context Menu Date Picker Sheet
            .sheet(isPresented: $showingContextMenuDatePicker) {
                // Ensure we still have the task context when sheet appears
                if let task = contextMenuTask, let listID = contextMenuTaskListID {
                    contextMenuDatePickerSheet(taskBinding: taskBinding(taskID: task.id, listID: listID)) // Moved from TasksView
                }
            }

            // --- Overlays ---
            
            // Dimmed Background Overlay (covers everything when overlays are active)
            if showingContextMenu || showingContextMenuDatePicker || showingNotesEditor || showingPriorityPicker || isAddTaskExpanded {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { // Dismiss on tap outside
                        dismissAllOverlays()
                    }
                    .zIndex(1) // Ensure dimming is above main content but below overlays
            }

            // Context Menu View (Conditional)
            if showingContextMenu, let task = contextMenuTask, let listID = contextMenuTaskListID {
                TaskContextMenu(
                    task: taskBinding(taskID: task.id, listID: listID),
                    listID: listID,
                    taskLists: $taskLists,
                    showingContextMenu: $showingContextMenu,
                    onChangeDueDate: { 
                        showingContextMenu = false // Hide the context menu first
                        showingContextMenuDatePicker = true 
                    },
                    onAddEditNotes: { 
                        showingContextMenu = false // Hide the context menu first
                        showingNotesEditor = true 
                    },
                    onChangePriority: { 
                        showingContextMenu = false // Hide the context menu first
                        showingPriorityPicker = true 
                    },
                    onDelete: { 
                        deleteSelectedTask()
                    }
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(2) // Ensure overlay is above dimming
            }

            // Notes Editor Overlay (Conditional)
            if showingNotesEditor, let task = contextMenuTask, let listID = contextMenuTaskListID {
                NotesEditorView(
                    taskNotes: taskBinding(taskID: task.id, listID: listID).notes,
                    showingNotesEditor: $showingNotesEditor,
                    showingContextMenu: $showingContextMenu
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(2) // Ensure overlay is above dimming
            }

            // Priority Picker Overlay (Conditional - Context Menu)
            if showingPriorityPicker, let task = contextMenuTask, let listID = contextMenuTaskListID {
                PriorityPickerView(
                    taskPriority: taskBinding(taskID: task.id, listID: listID).priority,
                    showingPriorityPicker: $showingPriorityPicker,
                    showingContextMenu: $showingContextMenu
                )
                .transition(.scale.combined(with: .opacity))
                .zIndex(2) // Ensure overlay is above dimming
            }
            
            // Add Task Form Overlay (when FAB is tapped)
            if isAddTaskExpanded {
                addTaskFormOverlay // Moved from TasksView
                    .transition(.scale.combined(with: .opacity))
                    .zIndex(2) // Ensure overlay is above dimming
            }
    }

    // MARK: - Setup and Cleanup

    /// Setup any initial view state or observers
    private func setupView() {
        // Add notification observer for task list updates
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TaskListsUpdated"),
            object: nil,
            queue: .main
        ) { _ in
            // Structs don't need weak self - they're value types
            DispatchQueue.main.async {
                self.reloadTaskLists()
            }
        }
        // Ensure TextEditor background is clear for overlay placeholder
        UITextView.appearance().backgroundColor = .clear
        updateSelectedList() // Ensure initial list selection for Add Task
    }
    
    /// Clean up observers when view disappears
    private func cleanupView() {
        // Remove notification observer
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("TaskListsUpdated"),
            object: nil
        )
        // Reset TextEditor background appearance
        UITextView.appearance().backgroundColor = nil
    }
    
    /// Reload task lists from UserDefaults
    private func reloadTaskLists() {
        taskLists = DataManager.load()
    }

    // MARK: - Common UI Elements (Header, Tabs)

    /// Custom navigation title view with subtitle
    private var titleHeaderView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Canvo")
                .font(.title)
                .fontWeight(.bold)
            HStack(spacing: 4) {
                Text("made by")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("@nickconoplia")
                    .font(.caption)
                    .foregroundColor(.purple)
            }
        }
        .padding(.bottom, 8)
    }

    /// Custom tab selector view
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            // Tasks Tab
            Button(action: { selectedTab = 0 }) {
                Text("Tasks")
                    .fontWeight(selectedTab == 0 ? .bold : .regular)
                    .foregroundColor(selectedTab == 0 ? .purple : .gray)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
            
            // Canvas Tab
            Button(action: { selectedTab = 1 }) {
                Text("Canvas")
                    .fontWeight(selectedTab == 1 ? .bold : .regular)
                    .foregroundColor(selectedTab == 1 ? .purple : .gray)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .fixedSize(horizontal: false, vertical: true) // Ensure consistent height
    }
    
    /// Tab indicator underline view
    private var tabIndicatorView: some View {
        GeometryReader { geometry in
            let width = geometry.size.width / 2
            Rectangle()
                .fill(Color.purple)
                .frame(width: width, height: 2)
                .offset(x: selectedTab == 0 ? 0 : width)
                .animation(.spring(), value: selectedTab)
        }
        .frame(height: 2)
    }

    // MARK: - Canvas Tab Content
    
    private var canvasTabContent: some View {
        VStack(spacing: 0) {
            // We use ScrollView to enable scrolling if content exceeds screen height
            ScrollView {
                VStack(spacing: 20) {
                    // Removed CanvasView
                    
                    // Canvas LMS Integration
                    CanvasIntegrationView()
                        .padding(.horizontal)
                }
                .padding(.top, 20) // Add some top padding
                .padding(.bottom, 30)
            }
        }
    }

    // MARK: - Overlay Views (Moved from TasksView)

    /// Overlay for Add Task Form (displays when FAB is tapped)
    private var addTaskFormOverlay: some View {
        VStack(spacing: 20) {
            // Title
            HStack {
                Text("Add New Task")
                    .font(.headline)
                Spacer()
                 // Close button (optional, dismissal is handled by background tap or ADD TASK)
                 Button { isAddTaskExpanded = false } label: {
                     Image(systemName: "xmark.circle.fill")
                         .font(.title2)
                         .foregroundColor(.gray)
                 }
            }
            .padding(.bottom, 5)
            
            // Task Form
            taskFormContent // Extracted below
                .padding(.vertical, 5)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(maxWidth: 350)
        .padding(30) // Padding from screen edges
    }

    /// The form content within the Add Task.
    @ViewBuilder
    private var taskFormContent: some View {
         VStack(spacing: 15) {
             TextField("What needs to be done?", text: $newTaskName)
                 .padding()
                 .background(Color(.secondarySystemBackground)) // Use secondary for slight contrast
                 .cornerRadius(10)

             HStack {
                 listPicker // Extracted below
                 Spacer()
                 dateButton // Extracted below
             }

             priorityPicker // REPLACED priorityButton with priorityPicker
             notesEditor // Extracted below
             addTaskButton // Extracted below
         }
    }

    // MARK: - Form Components (Moved from TasksView)

    /// Picker for selecting the target TaskList.
    private var listPicker: some View {
        Group {
            if !taskLists.isEmpty {
                Picker("Select List", selection: $selectedListId) {
                    ForEach(taskLists) { list in
                        Text(list.name).tag(list.id as UUID?)
                    }
                }
                // Ensure initial selection if needed
                .onAppear { updateSelectedList() }

            } else {
                Text("No lists available.")
                    .foregroundColor(.gray)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 15)
            }
        }
        .pickerStyle(.menu)
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color(.secondarySystemBackground)) // Use secondary for slight contrast
        .cornerRadius(8)
        .accentColor(.primary)
        .onChange(of: taskLists) { // Use new iOS 17+ `onChange` syntax
             updateSelectedList() // Update selection if lists change
        }
    }

    /// Button to select the due date.
    private var dateButton: some View {
        Button { showingDatePicker = true } label: {
            HStack {
                Image(systemName: "calendar")
                if let date = newTaskDueDate {
                    Text(date, style: .date)
                } else {
                    Text("Date")
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color(.secondarySystemBackground)) // Use secondary for slight contrast
        .cornerRadius(8)
        .foregroundColor(.primary)
    }

    /// Picker to select the priority using a menu style.
    private var priorityPicker: some View {
        Picker(selection: $newTaskPriority) {
            // Option for no priority
            Text("Clear Priority").tag(nil as Priority?)
            
            // Options for each priority case
            ForEach(Priority.allCases) { priority in
                HStack {
                    Circle()
                        .fill(color(for: priority))
                        .frame(width: 10, height: 10)
                    Text("\(priority.rawValue) Priority")
                }.tag(priority as Priority?)
            }
        } label: {
            HStack {
                if let priority = newTaskPriority {
                    Circle()
                        .fill(color(for: priority))
                        .frame(width: 10, height: 10)
                    Text("\(priority.rawValue) Priority")
                } else {
                    Text("Select Priority")
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
        }
        .pickerStyle(.menu)
        .padding(.vertical, 10)
        .padding(.horizontal, 15)
        .background(Color(.secondarySystemBackground)) // Use secondary for slight contrast
        .cornerRadius(8)
        .accentColor(.primary)
        .frame(maxWidth: .infinity) // Ensure it takes full width like other controls
    }

    /// TextEditor for adding optional notes.
    private var notesEditor: some View {
        TextEditor(text: $newTaskNotes)
            .frame(height: 80)
            .padding(6)
            .background(Color(.secondarySystemBackground)) // Use secondary for slight contrast
            .cornerRadius(10)
            .overlay(alignment: .topLeading) {
                if newTaskNotes.isEmpty {
                    Text("Add notes (optional)")
                        .foregroundColor(.gray.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }
            }
    }

    /// Button to submit the new task.
    private var addTaskButton: some View {
        Button("ADD TASK") { submitNewTask() }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)
            .font(.headline)
            .disabled(newTaskName.isEmpty || selectedListId == nil)
    }

    // MARK: - Date Picker Sheets (Moved from TasksView)

    /// The content view for the Add Task date picker sheet.
    private var datePickerSheet: some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Due Date",
                    selection: Binding<Date>(
                        get: { self.newTaskDueDate ?? Date() },
                        set: { self.newTaskDueDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        newTaskDueDate = nil
                        showingDatePicker = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingDatePicker = false
                    }
                }
            }
        }
    }

    /// View for the Date Picker presented from the TaskContextMenu.
    private func contextMenuDatePickerSheet(taskBinding: Binding<Task>) -> some View {
        NavigationView {
            VStack {
                DatePicker(
                    "Select Due Date",
                    selection: Binding<Date>(
                        get: { taskBinding.wrappedValue.dueDate ?? Date() },
                        set: { taskBinding.wrappedValue.dueDate = $0 }
                    ),
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()

                Spacer()
            }
            .navigationTitle("Change Due Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear") {
                        taskBinding.wrappedValue.dueDate = nil
                        dismissAllOverlays() // Use central dismiss
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                         dismissAllOverlays() // Use central dismiss
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods (Moved/Adapted from TasksView)

    /// Updates the selected list ID, typically when lists change or on appear.
    private func updateSelectedList() {
        if selectedListId == nil || !taskLists.contains(where: { $0.id == selectedListId }) {
             // Only select the first list if the current selection is invalid or nil
            if let firstListId = taskLists.first?.id {
                 selectedListId = firstListId
            } else {
                 selectedListId = nil // Handle case where there are no lists
            }
        }
    }


    /// Creates and adds a new task to the selected list.
    private func submitNewTask() {
        guard !newTaskName.isEmpty, let targetListId = selectedListId else {
            print("Cannot add task: Name is empty or no list selected")
            return
        }

        if let listIndex = taskLists.firstIndex(where: { $0.id == targetListId }) {
            let newTask = Task(name: newTaskName,
                               notes: newTaskNotes.isEmpty ? nil : newTaskNotes,
                               dueDate: newTaskDueDate,
                               priority: newTaskPriority)
            // Prepend to show new task at the top (optional)
            taskLists[listIndex].tasks.insert(newTask, at: 0)
            print("Added task '\(newTaskName)' to list '\(taskLists[listIndex].name)'")

            // Reset fields and dismiss
            newTaskName = ""
            newTaskNotes = ""
            newTaskDueDate = nil
            newTaskPriority = .medium // Reset to default
            isAddTaskExpanded = false // Dismiss the form
            // selectedListId remains the same for potentially adding another task to the same list
        } else {
            print("Error: Could not find the selected list by ID.")
        }
    }

    /// Creates a Binding<Task> to modify a specific task within the nested structure.
    private func taskBinding(taskID: UUID, listID: UUID) -> Binding<Task> {
        Binding<Task>(
            get: {
                guard let listIndex = taskLists.firstIndex(where: { $0.id == listID }),
                      let taskIndex = taskLists[listIndex].tasks.firstIndex(where: { $0.id == taskID })
                else {
                    fatalError("Task not found for binding!")
                }
                return taskLists[listIndex].tasks[taskIndex]
            },
            set: { updatedTask in
                guard let listIndex = taskLists.firstIndex(where: { $0.id == listID }),
                      let taskIndex = taskLists[listIndex].tasks.firstIndex(where: { $0.id == taskID })
                else {
                    print("Error: Task or List not found during update.")
                    return
                }
                taskLists[listIndex].tasks[taskIndex] = updatedTask
            }
        )
    }

    /// Deletes the task currently stored in the context menu state.
    private func deleteSelectedTask() {
        guard let taskToDelete = contextMenuTask, let listID = contextMenuTaskListID else {
            print("Error: No task selected for deletion.")
            return
        }

        // Clear the context menu state *before* modifying the list
        let taskName = taskToDelete.name // Keep name for log message
        contextMenuTask = nil 
        contextMenuTaskListID = nil

        if let listIndex = taskLists.firstIndex(where: { $0.id == listID }) {
            taskLists[listIndex].tasks.removeAll { $0.id == taskToDelete.id }
            print("Deleted task '\(taskName)' from list '\(taskLists[listIndex].name)'")
        } else {
            print("Error: List not found during deletion.")
        }
        dismissAllOverlays() // Dismiss menu after deletion
    }

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

    /// Dismiss all relevant overlays
    private func dismissAllOverlays() {
        // Use animation to smoothly dismiss
        withAnimation {
            showingContextMenu = false
            showingContextMenuDatePicker = false
            showingNotesEditor = false
            showingPriorityPicker = false
            isAddTaskExpanded = false
        }
        // Reset context task *after* animation if needed, or immediately
        contextMenuTask = nil
        contextMenuTaskListID = nil
    }
}

// --- Preview ---
#Preview {
    ContentView()
}
