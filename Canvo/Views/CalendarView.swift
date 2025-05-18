import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var taskLists: [TaskList]
    
    @State private var selectedDate: Date? = nil
    @State private var currentMonth: Date = Date()
    
    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Calendar header
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(themeManager.themeColor)
                    }
                    
                    Spacer()
                    
                    Text(monthYearString(from: currentMonth))
                        .font(.title2)
                        .bold()
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(themeManager.themeColor)
                    }
                }
                .padding(.horizontal)
                
                // Days of week header
                HStack {
                    ForEach(daysOfWeek, id: \.self) { day in
                        Text(day)
                            .frame(maxWidth: .infinity)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Calendar grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                    ForEach(daysInMonth(), id: \.id) { day in
                        if let date = day.date {
                            CalendarDayCell(date: date,
                                   isSelected: calendar.isDate(date, inSameDayAs: selectedDate ?? Date()),
                                   hasEvents: hasTasksDueOn(date: date))
                                .onTapGesture {
                                    if selectedDate != nil && calendar.isDate(date, inSameDayAs: selectedDate!) {
                                        selectedDate = nil // Deselect if tapping the same date
                                    } else {
                                        selectedDate = date
                                    }
                                }
                        } else {
                            Color.clear
                                .aspectRatio(1, contentMode: .fill)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Tasks section
                VStack(alignment: .leading, spacing: 15) {
                    if let selectedDate = selectedDate {
                        HStack {
                            Text("Tasks for \(dateString(from: selectedDate))")
                                .font(.headline)
                            
                            Spacer()
                            
                            Button(action: { self.selectedDate = nil }) {
                                Text("View All")
                                    .foregroundColor(themeManager.themeColor)
                            }
                        }
                        .padding(.horizontal)
                        
                        if tasksForSelectedDate().isEmpty {
                            Text("No tasks due on this date")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            ForEach(tasksForSelectedDate()) { task in
                                TaskRow(task: task)
                                    .padding(.horizontal)
                            }
                        }
                    } else {
                        Text("All Tasks")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(allTasksSorted()) { task in
                            TaskRow(task: task)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
    }
    
    // Helper methods
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func dateString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d, yyyy"
        return formatter.string(from: date)
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func daysInMonth() -> [(id: Int, date: Date?)] {
        var days = [(id: Int, date: Date?)]()
        var dayCounter = 0
        
        // Get start of the month
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth) else {
            return []
        }
        
        // Calculate first weekday of month (0 = Sunday)
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        
        // Add empty cells for days before the start of month
        for _ in 1..<firstWeekday {
            days.append((id: dayCounter, date: nil))
            dayCounter += 1
        }
        
        // Add all days of the month
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append((id: dayCounter, date: date))
                dayCounter += 1
            }
        }
        
        // Add empty cells to complete the last week if needed
        while days.count % 7 != 0 {
            days.append((id: dayCounter, date: nil))
            dayCounter += 1
        }
        
        return days
    }
    
    private func hasTasksDueOn(date: Date) -> Bool {
        return taskLists.flatMap { $0.tasks }.contains { task in
            guard let taskDueDate = task.dueDate else { return false }
            return calendar.isDate(taskDueDate, inSameDayAs: date)
        }
    }
    
    private func tasksForSelectedDate() -> [Task] {
        guard let selectedDate = selectedDate else { return [] }
        return taskLists.flatMap { $0.tasks }.filter { task in
            guard let taskDueDate = task.dueDate else { return false }
            return calendar.isDate(taskDueDate, inSameDayAs: selectedDate)
        }
    }
    
    private func allTasksSorted() -> [Task] {
        return taskLists.flatMap { $0.tasks }
            .filter { $0.dueDate != nil }
            .sorted { ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture) }
    }
}

// MARK: - Supporting Views
struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let hasEvents: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .opacity(0.2)
            
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .foregroundColor(isSelected ? .accentColor : .primary)
                
                if hasEvents {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 4, height: 4)
                }
            }
        }
        .aspectRatio(1, contentMode: .fill)
    }
} 