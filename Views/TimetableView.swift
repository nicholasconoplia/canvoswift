import SwiftUI

struct TimeBlock: Identifiable {
    let id = UUID()
    let title: String
    let startTime: Date
    let endTime: Date
    let subtitle: String?
}

struct TimetableView: View {
    @StateObject private var workingHours = WorkingHours.load()
    @State private var showingWorkingHoursSetup = false
    @State private var isFirstLaunch: Bool = !UserDefaults.standard.bool(forKey: "HasSetWorkingHours")
    @State private var selectedTab = 0 // 0 for Calendar, 1 for Scheduler
    
    // Sample time blocks - replace with actual data source
    private var timeBlocks: [TimeBlock] = [
        TimeBlock(title: "Portfolio (Session 1/4)", startTime: Calendar.current.date(from: DateComponents(hour: 8, minute: 45)) ?? Date(), endTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 15)) ?? Date(), subtitle: "8:45 am - 9:15 am"),
        TimeBlock(title: "Portfolio (Session 2/4)", startTime: Calendar.current.date(from: DateComponents(hour: 9, minute: 45)) ?? Date(), endTime: Calendar.current.date(from: DateComponents(hour: 10, minute: 15)) ?? Date(), subtitle: "9:45 am - 10:15 am"),
        TimeBlock(title: "Portfolio (Session 3/4)", startTime: Calendar.current.date(from: DateComponents(hour: 10, minute: 45)) ?? Date(), endTime: Calendar.current.date(from: DateComponents(hour: 11, minute: 15)) ?? Date(), subtitle: "10:45 am - 11:15 am"),
        TimeBlock(title: "Busy Time - Special Event", startTime: Calendar.current.date(from: DateComponents(hour: 11, minute: 51)) ?? Date(), endTime: Calendar.current.date(from: DateComponents(hour: 14, minute: 51)) ?? Date(), subtitle: "11:51 am - 2:51 pm"),
        TimeBlock(title: "Portfolio (Session 4/4)", startTime: Calendar.current.date(from: DateComponents(hour: 15, minute: 45)) ?? Date(), endTime: Calendar.current.date(from: DateComponents(hour: 16, minute: 15)) ?? Date(), subtitle: "3:45 pm - 4:15 pm")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("View Mode", selection: $selectedTab) {
                Text("Calendar").tag(0)
                Text("Scheduler").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            // Main content
            ScrollView {
                VStack(spacing: 0) {
                    if selectedTab == 0 {
                        // Calendar View
                        ZStack(alignment: .topLeading) {
                            // Hour lines
                            VStack(spacing: 16) {
                                ForEach(6...17, id: \.self) { hour in
                                    HStack {
                                        Text("\(hour):00")
                                            .frame(width: 60, alignment: .trailing)
                                            .foregroundColor(.secondary)
                                        
                                        Rectangle()
                                            .fill(Color(.systemGray5))
                                            .frame(height: 1)
                                    }
                                }
                            }
                            
                            // Time blocks
                            ForEach(timeBlocks) { block in
                                TimeBlockView(block: block)
                            }
                        }
                        .padding()
                    } else {
                        // Scheduler View
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Working Hours")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(workingHours.schedules.filter(\.isEnabled)) { schedule in
                                HStack {
                                    Text(schedule.dayName)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(schedule.startTime.formatted(date: .omitted, time: .shortened)) - \(schedule.endTime.formatted(date: .omitted, time: .shortened))")
                                }
                                .padding(.horizontal)
                            }
                            
                            Button(action: {
                                showingWorkingHoursSetup = true
                            }) {
                                Label("Edit Working Hours", systemImage: "clock")
                            }
                            .padding()
                        }
                        .padding(.vertical)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                        .padding()
                        
                        // Busy times setup
                        BusyTimeSetupView(busyBlocks: .constant([]))
                            .padding()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full screen usage
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full screen usage
        .sheet(isPresented: $showingWorkingHoursSetup) {
            WorkingHoursSetupView(workingHours: workingHours)
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

struct TimeBlockView: View {
    let block: TimeBlock
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(block.title)
                .font(.system(size: 14, weight: .medium))
            if let subtitle = block.subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray5))
        .cornerRadius(8)
        .padding(.leading, 60) // Align with hour markers
    }
}

#Preview {
    TimetableView()
} 