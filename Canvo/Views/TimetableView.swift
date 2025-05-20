import SwiftUI

struct TimetableView: View {
    @State private var showingBusyTimeSetup = false
    @State private var showingTaskScheduler = false
    @State private var showingWorkPreference = false
    @State private var selectedDate = Date()
    @State private var busyBlocks: [BusyBlock] = []
    @State private var taskSessions: [TaskSession] = []
    @State private var isFirstPreference: Bool = !UserDefaults.standard.bool(forKey: "HasSetWorkPreference")
    @State private var selectedView = 0 // 0 for Calendar, 1 for Scheduler
    @State private var showAllTasks = false
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var preferences = UserPreferences.load()
    
    // Add taskLists state
    @State private var taskLists: [TaskList] = []
    
    private var allBlocks: [BusyBlock] {
        // Convert TaskSessions to BusyBlocks for display
        let sessionBlocks = taskSessions.map { session in
            BusyBlock(
                id: session.id,
                start: session.start,
                end: session.end,
                title: "\(session.taskTitle) (Session \(session.sessionNumber)/\(session.totalSessions))"
            )
        }
        return busyBlocks + sessionBlocks
    }
    
    private var tasksForSelectedDate: [Task] {
        let calendar = Calendar.current
        return taskLists.flatMap { $0.tasks }.filter { task in
            guard let taskDueDate = task.dueDate else { return false }
            return calendar.isDate(taskDueDate, inSameDayAs: selectedDate)
        }
    }
    
    private var allTasksSorted: [Task] {
        return taskLists.flatMap { $0.tasks }
            .filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                // View selector
                Picker("View", selection: $selectedView) {
                    Text("Calendar").tag(0)
                    Text("Scheduler").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                if selectedView == 0 {
                    // Calendar view
                    ScrollView {
                        VStack(spacing: 16) {
                            // Month calendar
                            MonthView(
                                selectedDate: $selectedDate,
                                busyBlocks: allBlocks,
                                taskSessions: taskSessions,
                                taskLists: taskLists
                            )
                            .padding(.horizontal)
                            
                            // Tasks section
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text(showAllTasks ? "All Tasks" : dateFormatter.string(from: selectedDate))
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    Spacer()
                                    
                                    Button(action: { showAllTasks.toggle() }) {
                                        Text(showAllTasks ? "View Day" : "View All")
                                            .foregroundColor(themeManager.themeColor)
                                    }
                                    .padding(.horizontal)
                                }
                                
                                if showAllTasks {
                                    if allTasksSorted.isEmpty {
                                        Text("No tasks found")
                                            .foregroundColor(.gray)
                                            .padding(.horizontal)
                                    } else {
                                        ForEach(allTasksSorted) { task in
                                            TaskRow(task: task)
                                                .padding(.horizontal)
                                        }
                                    }
                                } else {
                                    // Tasks due on selected date
                                    if !tasksForSelectedDate.isEmpty {
                                        Text("Tasks Due")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                        
                                        ForEach(tasksForSelectedDate) { task in
                                            TaskRow(task: task)
                                                .padding(.horizontal)
                                        }
                                    }
                                    
                                    // Schedule for the day
                                    Text("Schedule")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                    
                                    DayView(
                                        date: selectedDate,
                                        busyBlocks: allBlocks,
                                        onBlockUpdate: { block, offsetMinutes in
                                            // Check if it's a busy block or task session
                                            if let index = busyBlocks.firstIndex(where: { $0.id == block.id }) {
                                                updateBlock(block, offsetMinutes: offsetMinutes)
                                            } else if let index = taskSessions.firstIndex(where: { $0.id == block.id }) {
                                                // Directly use the session ID for matching
                                                updateTaskSession(taskSessions[index], offsetMinutes: offsetMinutes)
                                            }
                                        },
                                        onBlockDelete: { block in
                                            // Check if it's a busy block or task session
                                            if let index = busyBlocks.firstIndex(where: { $0.id == block.id }) {
                                                busyBlocks.remove(at: index)
                                                saveTimetableData()
                                            } else if let index = taskSessions.firstIndex(where: { $0.id == block.id }) {
                                                // Directly use the session ID for matching
                                                taskSessions.remove(at: index)
                                                saveTimetableData()
                                            }
                                        },
                                        onBlockSave: { updatedBlock in
                                            // Check if it's a busy block or task session
                                            if let index = busyBlocks.firstIndex(where: { $0.id == updatedBlock.id }) {
                                                busyBlocks[index] = updatedBlock
                                                saveTimetableData()
                                            } else if let index = taskSessions.firstIndex(where: { $0.id == updatedBlock.id }) {
                                                // Update the task session with the new times
                                                taskSessions[index] = TaskSession(
                                                    id: taskSessions[index].id,
                                                    taskId: taskSessions[index].taskId,
                                                    taskTitle: updatedBlock.title.replacingOccurrences(of: " \\(Session \\d+/\\d+\\)", with: "", options: .regularExpression),
                                                    start: updatedBlock.start,
                                                    duration: updatedBlock.end.timeIntervalSince(updatedBlock.start),
                                                    sessionNumber: taskSessions[index].sessionNumber,
                                                    totalSessions: taskSessions[index].totalSessions
                                                )
                                                saveTimetableData()
                                            }
                                        }
                                    )
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                } else {
                    // Scheduler setup
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Your Busy Times")
                                .font(.title)
                                .bold()
                                .padding(.horizontal)
                            
                            BusyTimeSetupView(busyBlocks: $busyBlocks)
                                .padding(.horizontal)
                                .onChange(of: busyBlocks) { newValue in
                                    saveTimetableData()
                                }
                        }
                    }
                }
            }
            .navigationTitle("Timetable")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if selectedView == 0 {
                            Button(action: { showingBusyTimeSetup = true }) {
                                Label("Add Busy Time", systemImage: "plus.circle")
                            }
                            
                            Button(action: { showingTaskScheduler = true }) {
                                Label("Schedule Tasks", systemImage: "calendar.badge.clock")
                            }
                        }
                        
                        Button(action: { showingWorkPreference = true }) {
                            Label("Edit Work Preferences", systemImage: "clock")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingWorkPreference) {
                NavigationView {
                    UserPreferencesView()
                }
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "HasSetWorkPreference")
                    isFirstPreference = false
                    // Reload preferences after dismissal
                    preferences = UserPreferences.load()
                }
            }
            .sheet(isPresented: $showingBusyTimeSetup) {
                NavigationView {
                    BusyTimeSetupView(busyBlocks: $busyBlocks)
                        .navigationTitle("Add Busy Time")
                        .navigationBarItems(
                            trailing: Button("Done") {
                                showingBusyTimeSetup = false
                                saveTimetableData()
                            }
                        )
                }
            }
            .sheet(isPresented: $showingTaskScheduler) {
                TaskTimeAllocationView(
                    tasks: allTasksSorted.filter { !$0.isCompleted },
                    busyBlocks: busyBlocks,
                    taskSessions: $taskSessions
                )
                .onChange(of: taskSessions) { newValue in
                    saveTimetableData()
                }
            }
        }
        .onAppear {
            if isFirstPreference {
                showingWorkPreference = true
            }
            // Load task lists
            taskLists = DataManager.load()
            // Load timetable data
            loadTimetableData()
            // Start observing iCloud changes
            initializeICloudObserver()
        }
        // Listen for task list updates
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TaskListsUpdated"))) { notification in
            taskLists = DataManager.load()
        }
        // Listen for timetable data updates
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TimetableDataUpdated"))) { notification in
            loadTimetableData()
        }
    }
    
    private func initializeICloudObserver() {
        _Concurrency.Task {
            try? await TimetableDataManager.startObservingICloudChanges()
        }
    }
    
    private func saveTimetableData() {
        TimetableDataManager.save(taskSessions: taskSessions, busyBlocks: busyBlocks)
    }
    
    private func loadTimetableData() {
        let data = TimetableDataManager.load()
        taskSessions = data.taskSessions
        busyBlocks = data.busyBlocks
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    // Add function to update block time
    private func updateBlock(_ block: BusyBlock, offsetMinutes: Int) {
        if let index = busyBlocks.firstIndex(where: { $0.id == block.id }) {
            let duration = block.end.timeIntervalSince(block.start)
            let newStart = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: block.start) ?? block.start
            let newEnd = newStart.addingTimeInterval(duration)
            
            busyBlocks[index] = BusyBlock(
                id: block.id,
                start: newStart,
                end: newEnd,
                title: block.title,
                location: block.location
            )
            
            saveTimetableData()
        }
    }
    
    // Add function to update task session
    private func updateTaskSession(_ session: TaskSession, offsetMinutes: Int) {
        if let index = taskSessions.firstIndex(where: { $0.id == session.id }) {
            let newStart = Calendar.current.date(byAdding: .minute, value: offsetMinutes, to: session.start) ?? session.start
            
            let updatedSession = TaskSession(
                id: session.id,
                taskId: session.taskId,
                taskTitle: session.taskTitle,
                start: newStart,
                duration: session.duration,
                sessionNumber: session.sessionNumber,
                totalSessions: session.totalSessions
            )
            
            taskSessions[index] = updatedSession
            saveTimetableData()
            
            // Update notifications for the modified session
            NotificationManager.shared.updateSessionNotifications(for: updatedSession)
        }
    }
} 