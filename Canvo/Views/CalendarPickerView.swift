import SwiftUI
import EventKit

struct CalendarPickerView: View {
    @Binding var selectedCalendars: Set<String>
    var availableCalendars: [EKCalendar]
    @Environment(\.dismiss) private var dismiss
    @State private var isSelectingAll = false
    
    var body: some View {
        NavigationView {
            VStack {
                if availableCalendars.isEmpty {
                    // Show a message if no calendars are available
                    VStack {
                        Spacer()
                        Text("No calendars found")
                            .font(.title2)
                            .foregroundColor(.gray)
                        Text("Add calendars to your device to import events")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                            HStack {
                                Circle()
                                    .fill(Color(cgColor: calendar.cgColor))
                                    .frame(width: 12, height: 12)
                                
                                Text(calendar.title)
                                
                                Spacer()
                                
                                if selectedCalendars.contains(calendar.calendarIdentifier) {
                                    Image(systemName: "checkmark")
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedCalendars.contains(calendar.calendarIdentifier) {
                                    selectedCalendars.remove(calendar.calendarIdentifier)
                                } else {
                                    selectedCalendars.insert(calendar.calendarIdentifier)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Calendars")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !availableCalendars.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(isSelectingAll ? "Deselect All" : "Select All") {
                            if isSelectingAll {
                                // Deselect all
                                selectedCalendars.removeAll()
                            } else {
                                // Select all
                                selectedCalendars = Set(availableCalendars.map(\.calendarIdentifier))
                            }
                            isSelectingAll.toggle()
                        }
                    }
                }
            }
            .onAppear {
                // Update isSelectingAll state based on current selection
                isSelectingAll = selectedCalendars.count == availableCalendars.count && !availableCalendars.isEmpty
            }
        }
    }
} 