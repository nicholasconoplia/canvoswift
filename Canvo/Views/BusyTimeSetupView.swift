import SwiftUI
import EventKit

@MainActor
struct BusyTimeSetupView: View {
    @Binding var busyBlocks: [BusyBlock]
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var newStart = Date()
    @State private var newEnd = Date().addingTimeInterval(3600)
    
    // Calendar selection
    @State private var selectedCalendarIDs: Set<String> = []
    @State private var availableCalendars: [EKCalendar] = []
    @State private var showCalendarPicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var calendarAccessGranted = false
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your Busy Times")
                    .font(.headline)

                if busyBlocks.isEmpty {
                    Text("No busy times added yet")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(busyBlocks) { block in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Start: \(block.start.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.subheadline)
                                        Text("End: \(block.end.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.subheadline)
                                    }
                                    Spacer()
                                    Button(action: {
                                        if let index = busyBlocks.firstIndex(where: { $0.id == block.id }) {
                                            busyBlocks.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 300)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }

                Divider()
                
                // Calendar Import Section
                VStack(alignment: .leading) {
                    Text("Import from Calendars")
                        .font(.headline)
                    
                    if calendarAccessGranted {
                        if isLoading {
                            ProgressView("Loading calendars...")
                                .padding()
                        } else {
                            HStack {
                                Button("Select Calendars") {
                                    isLoading = true // Show loading indicator
                                    
                                    CalendarImporter.shared.getAllCalendars { calendars in
                                        DispatchQueue.main.async {
                                            self.isLoading = false
                                            self.availableCalendars = calendars
                                            
                                            if calendars.isEmpty {
                                                self.alertMessage = "No calendars found. Please ensure you have calendars set up on your device."
                                                self.showingAlert = true
                                            } else {
                                                self.showCalendarPicker = true
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(isLoading)
                                
                                Spacer()
                                
                                    Button("Import Events") {
                                        importCalendarEvents()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(selectedCalendarIDs.isEmpty || isLoading)
                            }
                            
                            if !selectedCalendarIDs.isEmpty {
                                Text("Selected \(selectedCalendarIDs.count) calendar(s)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        Button("Request Calendar Access") {
                            isLoading = true // Show loading indicator
                            
                            CalendarImporter.shared.requestAccess { granted in
                                DispatchQueue.main.async {
                                    self.isLoading = false
                                    self.calendarAccessGranted = granted
                                    
                                    if granted {
                                        self.alertMessage = "Calendar access granted. You can now select calendars to import."
                                        self.showingAlert = true
                                    } else {
                                        self.alertMessage = "Calendar access denied. Please enable in Settings."
                                        self.showingAlert = true
                                    }
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isLoading)
                    }
                }
                
                Divider()

                // Manual Add Section
                Group {
                    Text("Add New Busy Time")
                        .font(.headline)

                    DatePicker("Start", selection: $newStart)
                    DatePicker("End", selection: $newEnd)

                    Button("Add Busy Block") {
                        if newEnd > newStart {
                            let newBlock = BusyBlock(start: newStart, end: newEnd)
                            busyBlocks.append(newBlock)
                            
                            newStart = newEnd
                            newEnd = newEnd.addingTimeInterval(3600)
                        } else {
                            alertMessage = "End time must be after start time"
                            showingAlert = true
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(themeManager.themeColor)
                }

                Spacer()
            }
            .padding()
            .disabled(isLoading) // Disable the whole view when loading
            .overlay {
                if isLoading {
                    Color.black.opacity(0.1)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView()
                                .scaleEffect(1.5)
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 3)
                        }
                }
            }
        }
        .sheet(isPresented: $showCalendarPicker) {
            CalendarPickerView(selectedCalendars: $selectedCalendarIDs, availableCalendars: availableCalendars)
        }
        .alert("Calendar Import", isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            let status = EKEventStore.authorizationStatus(for: .event)
            calendarAccessGranted = (status == .authorized)
            if status == .denied || status == .restricted {
                alertMessage = "Calendar access is currently denied or restricted. Please check your device Settings."
                showingAlert = true
            }
        }
    }
    
    private func importCalendarEvents() {
        guard calendarAccessGranted else {
            alertMessage = "Calendar access not granted."
            showingAlert = true
            return
        }
        
        if selectedCalendarIDs.isEmpty {
            alertMessage = "Please select at least one calendar first"
            showingAlert = true
            return
        }
        
        isLoading = true // Show loading indicator
        
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 30, to: start)!
        
        // Copy selectedCalendarIDs to avoid capturing self
        let calendarIDs = selectedCalendarIDs
        
        CalendarImporter.shared.fetchEvents(from: calendarIDs, startDate: start, endDate: end) { blocks in
            DispatchQueue.main.async {
                self.isLoading = false
                
                // Avoid duplicates
                var addedCount = 0
                for block in blocks {
                    if !self.busyBlocks.contains(where: { $0.start == block.start && $0.end == block.end }) {
                        self.busyBlocks.append(block)
                        addedCount += 1
                    }
                }
                
                self.alertMessage = "Imported \(addedCount) events from calendar"
                self.showingAlert = true
            }
        }
    }
} 
