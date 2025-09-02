import SwiftUI

struct MonthView: View {
    @Binding var selectedDate: Date
    let busyBlocks: [BusyBlock]
    let taskSessions: [TaskSession]
    @EnvironmentObject private var themeManager: ThemeManager
    let taskLists: [TaskList]
    
    private let calendar = Calendar.current
    private let daysInWeek = ["M", "Tu", "W", "Th", "F", "Sa", "Su"]
    
    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }
    
    private var daysInMonth: [[Date?]] {
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        
        guard let firstDayOfMonth = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let range = calendar.range(of: .day, in: .month, for: firstDayOfMonth) else {
            return []
        }
        
        // Get the weekday of the first day (1 = Sunday, 2 = Monday, ..., 7 = Saturday)
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        
        // Calculate padding for Monday start
        // Convert Sunday from 1 to 7 for easier calculation
        let adjustedFirstWeekday = firstWeekday == 1 ? 7 : firstWeekday - 1
        // Now Monday = 1, Tuesday = 2, ..., Sunday = 7
        let paddingDays = adjustedFirstWeekday - 1
        
        // Create array with padding
        var days: [Date?] = Array(repeating: nil, count: paddingDays)
        
        // Add all days of the month
        for day in 1...range.count {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(date)
            }
        }
        
        // Add padding at the end to complete the last week
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        // Split into weeks
        return days.chunked(into: 7)
    }
    
    private func hasBusyBlock(on date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return busyBlocks.contains { block in
            block.start >= startOfDay && block.start < endOfDay
        }
    }
    
    private func hasTasksDue(on date: Date) -> Bool {
        return taskLists.flatMap { $0.tasks }.contains { task in
            guard let taskDueDate = task.dueDate else { return false }
            return calendar.isDate(taskDueDate, inSameDayAs: date)
        }
    }
    
    private func hasScheduledSessions(on date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return taskSessions.contains { session in
            session.start >= startOfDay && session.start < endOfDay
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(themeManager.themeColor)
                }
                
                Spacer()
                
                Text(monthTitle)
                    .font(.headline)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(themeManager.themeColor)
                }
            }
            .padding(.horizontal)
            
            // Days of week header
            HStack {
                ForEach(daysInWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            VStack(spacing: 0) {
                ForEach(daysInMonth.indices, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(0..<7) { dayIndex in
                            if let date = daysInMonth[week][dayIndex] {
                                DayCell(
                                    date: date,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                    hasBusyBlock: hasBusyBlock(on: date),
                                    hasTasksDue: hasTasksDue(on: date),
                                    hasScheduledSessions: hasScheduledSessions(on: date)
                                )
                                .onTapGesture {
                                    selectedDate = date
                                }
                            } else {
                                Color.clear
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            selectedDate = newDate
        }
    }
}

// MARK: - Day Cell
struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasBusyBlock: Bool
    let hasTasksDue: Bool
    let hasScheduledSessions: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    private let calendar = Calendar.current
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            // Background circle for selection
            Circle()
                .fill(isSelected ? themeManager.themeColor : Color.clear)
                .opacity(0.2)
            
            // Current day circle
            if isToday {
                Circle()
                    .stroke(themeManager.themeColor, lineWidth: 2)
            }
            
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .foregroundColor(isSelected ? themeManager.themeColor : (isToday ? themeManager.themeColor : .primary))
                    .font(isToday ? .body.bold() : .body)
                
                HStack(spacing: 4) {
                    if hasBusyBlock {
                        Circle()
                            .fill(themeManager.themeColor)
                            .frame(width: 4, height: 4)
                    }
                    if hasTasksDue {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 4, height: 4)
                    }
                    if hasScheduledSessions {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
} 