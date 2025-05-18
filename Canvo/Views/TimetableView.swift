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
                                    
                                    DayView(date: selectedDate, busyBlocks: allBlocks)
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
                    WorkTimePreferenceView(preferences: $preferences)
                }
                .onDisappear {
                    UserDefaults.standard.set(true, forKey: "HasSetWorkPreference")
                    isFirstPreference = false
                }
            }
            .sheet(isPresented: $showingBusyTimeSetup) {
                NavigationView {
                    BusyTimeSetupView(busyBlocks: $busyBlocks)
                        .navigationTitle("Add Busy Time")
                        .navigationBarItems(
                            trailing: Button("Done") {
                                showingBusyTimeSetup = false
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
            }
        }
        .onAppear {
            if isFirstPreference {
                showingWorkPreference = true
            }
            // Load task lists
            taskLists = DataManager.load()
        }
        // Listen for task list updates
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("TaskListsUpdated"))) { _ in
            taskLists = DataManager.load()
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
} 