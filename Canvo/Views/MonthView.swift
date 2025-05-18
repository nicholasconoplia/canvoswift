import SwiftUI

struct MonthView: View {
    @Binding var selectedDate: Date
    let busyBlocks: [BusyBlock]
    
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
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let numberOfDays = range.count
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 2) // -2 because we start from Monday
        
        for day in 1...numberOfDays {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days.chunked(into: 7)
    }
    
    private func hasBusyBlock(on date: Date) -> Bool {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return busyBlocks.contains { block in
            block.start >= startOfDay && block.start < endOfDay
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month and Year
            HStack {
                Text(monthTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                HStack(spacing: 20) {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Days of week
            HStack(spacing: 0) {
                ForEach(daysInWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            
            // Calendar grid
            VStack(spacing: 0) {
                ForEach(daysInMonth.indices, id: \.self) { week in
                    HStack(spacing: 0) {
                        ForEach(0..<7) { dayIndex in
                            if let date = daysInMonth[week][dayIndex] {
                                DayCell(
                                    date: date,
                                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                                    hasBusyBlock: hasBusyBlock(on: date)
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

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let hasBusyBlock: Bool
    
    private let calendar = Calendar.current
    
    private var dayNumber: String {
        String(calendar.component(.day, from: date))
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.accentColor : Color.clear)
                .overlay(
                    Circle()
                        .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 1)
                )
            
            VStack(spacing: 2) {
                Text(dayNumber)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if hasBusyBlock {
                    Circle()
                        .fill(isSelected ? .white : Color.accentColor)
                        .frame(width: 4, height: 4)
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