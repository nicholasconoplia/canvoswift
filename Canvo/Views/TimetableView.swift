import SwiftUI

struct TimetableView: View {
    @StateObject private var workingHours = WorkingHours.load()
    @State private var showingWorkingHoursSetup = false
    @State private var showingBusyTimeSetup = false
    @State private var selectedDate = Date()
    @State private var busyBlocks: [BusyBlock] = []
    @State private var isFirstLaunch: Bool = !UserDefaults.standard.bool(forKey: "HasSetWorkingHours")
    @State private var selectedView = 0 // 0 for Calendar, 1 for Scheduler
    
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
                            MonthView(selectedDate: $selectedDate, busyBlocks: busyBlocks)
                                .padding(.horizontal)
                            
                            // Day view
                            DayView(date: selectedDate, busyBlocks: busyBlocks)
                                .padding(.horizontal)
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
                        }
                        
                        Button(action: { showingWorkingHoursSetup = true }) {
                            Label("Edit Working Hours", systemImage: "clock")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingWorkingHoursSetup) {
                WorkingHoursSetupView(workingHours: workingHours)
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