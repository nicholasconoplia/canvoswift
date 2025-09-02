import SwiftUI

struct UserPreferencesView: View {
    @State private var preferences = UserPreferences.load()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var streakService: StreakService
    @EnvironmentObject private var themeManager: ThemeManager
    
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
            // Working Hours Section
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
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    preferences.save()
                    dismiss()
                }
                .foregroundColor(themeManager.themeColor)
            }
        }
        .onChange(of: preferences) { _ in
            preferences.save()
        }
    }
    
    private var preferredTimesDescription: String {
        let preferences = preferences.workTimePreferences
            .map { $0.displayText.title }
            .sorted()
            .joined(separator: ", ")
        return preferences.isEmpty ? "Not set" : preferences
    }
}

#Preview {
    NavigationView {
        UserPreferencesView()
            .environmentObject(StreakService())
            .environmentObject(ThemeManager())
    }
} 