import SwiftUI

struct WorkingHoursSetupView: View {
    @ObservedObject var workingHours: WorkingHours
    @Environment(\.dismiss) private var dismiss
    @State private var showingAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Choose your working hours for each day")) {
                    ForEach($workingHours.schedules) { $schedule in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Toggle(schedule.dayName, isOn: $schedule.isEnabled)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Button(action: {
                                    copyToWeekdays(schedule)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                }
                                .buttonStyle(.borderless)
                                .disabled(!schedule.isEnabled)
                            }
                            
                            if schedule.isEnabled {
                                HStack {
                                    DatePicker("Start", selection: $schedule.startTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                    
                                    Text("-")
                                    
                                    DatePicker("End", selection: $schedule.endTime, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                }
                            }
                        }
                    }
                }
                
                Section(footer: Text("You can always adjust these hours later in settings.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Set Working Hours")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        validateAndSave()
                    }
                }
            }
            .alert("Invalid Time Range", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please ensure end time is after start time for all enabled days.")
            }
        }
    }
    
    private func validateAndSave() {
        // Validate times for enabled days
        let hasInvalidTimes = workingHours.schedules
            .filter { $0.isEnabled }
            .contains { $0.endTime <= $0.startTime }
        
        if hasInvalidTimes {
            showingAlert = true
        } else {
            workingHours.save()
            dismiss()
        }
    }
    
    private func copyToWeekdays(_ source: DaySchedule) {
        // Copy the schedule to all weekdays (Monday-Friday)
        for weekday in 2...6 {
            if let index = workingHours.schedules.firstIndex(where: { $0.day == weekday }) {
                workingHours.schedules[index].startTime = source.startTime
                workingHours.schedules[index].endTime = source.endTime
                workingHours.schedules[index].isEnabled = true
            }
        }
    }
}

#Preview {
    WorkingHoursSetupView(workingHours: WorkingHours())
} 