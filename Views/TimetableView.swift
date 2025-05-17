import SwiftUI

struct TimetableView: View {
    @StateObject private var workingHours = WorkingHours.load()
    @State private var showingWorkingHoursSetup = false
    @State private var isFirstLaunch: Bool = !UserDefaults.standard.bool(forKey: "HasSetWorkingHours")
    
    var body: some View {
        NavigationView {
            VStack {
                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Working hours summary
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Working Hours")
                                .font(.headline)
                            
                            ForEach(workingHours.schedules.filter(\.isEnabled)) { schedule in
                                HStack {
                                    Text(schedule.dayName)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(schedule.startTime.formatted(date: .omitted, time: .shortened)) - \(schedule.endTime.formatted(date: .omitted, time: .shortened))")
                                }
                            }
                            
                            Button(action: {
                                showingWorkingHoursSetup = true
                            }) {
                                Label("Edit Working Hours", systemImage: "clock")
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                        
                        // Busy times setup
                        BusyTimeSetupView(busyBlocks: .constant([]))
                    }
                    .padding()
                }
            }
            .navigationTitle("Timetable")
            .sheet(isPresented: $showingWorkingHoursSetup) {
                WorkingHoursSetupView(workingHours: workingHours)
            }
        }
        .onAppear {
            if isFirstLaunch {
                showingWorkingHoursSetup = true
                UserDefaults.standard.set(true, forKey: "HasSetWorkingHours")
                isFirstLaunch = false
            }
        }
    }
}

#Preview {
    TimetableView()
} 