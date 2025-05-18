import SwiftUI

struct DayView: View {
    let date: Date
    let busyBlocks: [BusyBlock]
    
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let timeWidth: CGFloat = 60
    private let hours = Array(7...23) // 7 AM to 11 PM
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }
    
    private var filteredBusyBlocks: [BusyBlock] {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return busyBlocks.filter { block in
            block.start >= startOfDay && block.start < endOfDay
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(dateFormatter.string(from: date))
                .font(.headline)
                .padding()
            
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Time indicators and horizontal lines
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            HStack(spacing: 0) {
                                Text(String(format: "%d:00", hour))
                                    .font(.caption)
                                    .frame(width: timeWidth)
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                            }
                            .frame(height: hourHeight)
                        }
                    }
                    
                    // Current time indicator
                    if calendar.isDateInToday(date) {
                        CurrentTimeIndicator()
                            .offset(y: currentTimeOffset)
                    }
                    
                    // Busy blocks
                    ForEach(filteredBusyBlocks) { block in
                        BusyBlockView(block: block)
                            .offset(x: timeWidth, y: timeOffset(for: block.start))
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private var currentTimeOffset: CGFloat {
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        return CGFloat(hour - hours[0]) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }
    
    private func timeOffset(for date: Date) -> CGFloat {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return CGFloat(hour - hours[0]) * hourHeight + CGFloat(minute) / 60.0 * hourHeight
    }
}

struct CurrentTimeIndicator: View {
    private let timeWidth: CGFloat = 60
    
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(Color.red)
                .frame(height: 1)
        }
        .padding(.leading, timeWidth - 4)
    }
}

struct BusyBlockView: View {
    let block: BusyBlock
    private let calendar = Calendar.current
    
    private var duration: TimeInterval {
        block.end.timeIntervalSince(block.start)
    }
    
    private var height: CGFloat {
        CGFloat(duration / 3600.0) * 60 // Convert hours to points (60 points per hour)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(block.title)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(1)
            
            if let location = block.location {
                Text(location)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Text("\(block.start.formatted(date: .omitted, time: .shortened)) - \(block.end.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(Color.accentColor)
        .cornerRadius(8)
    }
} 