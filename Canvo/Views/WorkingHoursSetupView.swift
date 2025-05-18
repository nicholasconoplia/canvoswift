import SwiftUI

struct WorkingHoursSetupView: View {
    @ObservedObject var workingHours: WorkingHours
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach($workingHours.schedules) { $schedule in
                    Section(header: Text(schedule.dayName)) {
                        Toggle("Enabled", isOn: $schedule.isEnabled)
                        
                        if schedule.isEnabled {
                            DatePicker("Start Time", selection: $schedule.startTime, displayedComponents: .hourAndMinute)
                            DatePicker("End Time", selection: $schedule.endTime, displayedComponents: .hourAndMinute)
                        }
                    }
                }
            }
            .navigationTitle("Working Hours")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
} 