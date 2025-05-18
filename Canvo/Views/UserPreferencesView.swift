import SwiftUI

struct UserPreferencesView: View {
    @State private var preferences = UserPreferences.load()
    @Environment(\.dismiss) private var dismiss
    
    private let weekdays = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    var body: some View {
        Form {
            Section(header: Text("Working Hours")) {
                DatePicker(
                    "Start Time",
                    selection: Binding(
                        get: { preferences.workingHours.startTime },
                        set: { preferences.workingHours.startTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                
                DatePicker(
                    "End Time",
                    selection: Binding(
                        get: { preferences.workingHours.endTime },
                        set: { preferences.workingHours.endTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            
            Section(header: Text("Working Days")) {
                ForEach(weekdays, id: \.0) { weekday in
                    Toggle(weekday.1, isOn: Binding(
                        get: { preferences.workingDays.contains(weekday.0) },
                        set: { isOn in
                            if isOn {
                                preferences.workingDays.insert(weekday.0)
                            } else {
                                preferences.workingDays.remove(weekday.0)
                            }
                        }
                    ))
                }
            }
            
            Section(header: Text("Work Time Preferences")) {
                NavigationLink {
                    WorkTimePreferenceView(preferences: $preferences)
                } label: {
                    VStack(alignment: .leading) {
                        Text("Preferred Times")
                        Text(preferredTimesDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section(header: Text("Session Preferences")) {
                Stepper(
                    "Preferred Session Duration: \(Int(preferences.preferredSessionDuration)) min",
                    value: Binding(
                        get: { preferences.preferredSessionDuration },
                        set: { preferences.preferredSessionDuration = $0 }
                    ),
                    in: 15...120,
                    step: 15
                )
                
                Stepper(
                    "Break Between Sessions: \(Int(preferences.minimumBreakBetweenSessions)) min",
                    value: Binding(
                        get: { preferences.minimumBreakBetweenSessions },
                        set: { preferences.minimumBreakBetweenSessions = $0 }
                    ),
                    in: 0...60,
                    step: 5
                )
                
                Stepper(
                    "Maximum Sessions Per Day: \(preferences.maximumSessionsPerDay)",
                    value: Binding(
                        get: { preferences.maximumSessionsPerDay },
                        set: { preferences.maximumSessionsPerDay = $0 }
                    ),
                    in: 1...12
                )
            }
            
            Section(header: Text("Buffer Times")) {
                Group {
                    Stepper(
                        "High Priority Tasks: \(Int(preferences.bufferTimes.highPriority)) min",
                        value: Binding(
                            get: { preferences.bufferTimes.highPriority },
                            set: { preferences.bufferTimes.highPriority = $0 }
                        ),
                        in: 5...60,
                        step: 5
                    )
                    
                    Stepper(
                        "Medium Priority Tasks: \(Int(preferences.bufferTimes.mediumPriority)) min",
                        value: Binding(
                            get: { preferences.bufferTimes.mediumPriority },
                            set: { preferences.bufferTimes.mediumPriority = $0 }
                        ),
                        in: 5...60,
                        step: 5
                    )
                    
                    Stepper(
                        "Low Priority Tasks: \(Int(preferences.bufferTimes.lowPriority)) min",
                        value: Binding(
                            get: { preferences.bufferTimes.lowPriority },
                            set: { preferences.bufferTimes.lowPriority = $0 }
                        ),
                        in: 5...60,
                        step: 5
                    )
                }
                
                Group {
                    Stepper(
                        "Assignments: \(Int(preferences.bufferTimes.assignment)) min",
                        value: Binding(
                            get: { preferences.bufferTimes.assignment },
                            set: { preferences.bufferTimes.assignment = $0 }
                        ),
                        in: 5...60,
                        step: 5
                    )
                    
                    Stepper(
                        "Quizzes: \(Int(preferences.bufferTimes.quiz)) min",
                        value: Binding(
                            get: { preferences.bufferTimes.quiz },
                            set: { preferences.bufferTimes.quiz = $0 }
                        ),
                        in: 5...60,
                        step: 5
                    )
                    
                    Stepper(
                        "General Tasks: \(Int(preferences.bufferTimes.general)) min",
                        value: Binding(
                            get: { preferences.bufferTimes.general },
                            set: { preferences.bufferTimes.general = $0 }
                        ),
                        in: 5...60,
                        step: 5
                    )
                }
            }
            
            Section(header: Text("Task Distribution")) {
                Group {
                    Toggle("Distribute Tasks Evenly", isOn: Binding(
                        get: { preferences.distributionPreferences.preferEvenDistribution },
                        set: { newValue in
                            preferences.distributionPreferences.preferEvenDistribution = newValue
                            if newValue {
                                preferences.distributionPreferences.frontLoadTasks = false
                                preferences.distributionPreferences.backLoadTasks = false
                            }
                        }
                    ))
                    
                    Toggle("Front-load Tasks", isOn: Binding(
                        get: { preferences.distributionPreferences.frontLoadTasks },
                        set: { newValue in
                            preferences.distributionPreferences.frontLoadTasks = newValue
                            if newValue {
                                preferences.distributionPreferences.preferEvenDistribution = false
                                preferences.distributionPreferences.backLoadTasks = false
                            }
                        }
                    ))
                    
                    Toggle("Back-load Tasks", isOn: Binding(
                        get: { preferences.distributionPreferences.backLoadTasks },
                        set: { newValue in
                            preferences.distributionPreferences.backLoadTasks = newValue
                            if newValue {
                                preferences.distributionPreferences.preferEvenDistribution = false
                                preferences.distributionPreferences.frontLoadTasks = false
                            }
                        }
                    ))
                }
                
                Stepper(
                    "Maximum Tasks Per Time Slot: \(preferences.distributionPreferences.maximumTasksPerTimeSlot)",
                    value: Binding(
                        get: { preferences.distributionPreferences.maximumTasksPerTimeSlot },
                        set: { preferences.distributionPreferences.maximumTasksPerTimeSlot = $0 }
                    ),
                    in: 1...5
                )
                
                Stepper(
                    "Minimum Days Between Sessions: \(preferences.distributionPreferences.preferredDaySpacing)",
                    value: Binding(
                        get: { preferences.distributionPreferences.preferredDaySpacing },
                        set: { preferences.distributionPreferences.preferredDaySpacing = $0 }
                    ),
                    in: 0...7
                )
            }
        }
        .navigationTitle("Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    preferences.save()
                    dismiss()
                }
            }
        }
    }
    
    private var preferredTimesDescription: String {
        let times = preferences.workTimePreferences.map { $0.displayText.title }
        return times.isEmpty ? "Not set" : times.joined(separator: ", ")
    }
} 