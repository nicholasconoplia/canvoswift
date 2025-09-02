import SwiftUI

struct DayView: View {
    let date: Date
    let busyBlocks: [BusyBlock]
    let onBlockUpdate: (BusyBlock, Int) -> Void
    let onBlockDelete: (BusyBlock) -> Void
    let onBlockSave: (BusyBlock) -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var draggingBlockId: UUID?
    @State private var dragOffset: CGFloat = 0
    @State private var selectedBlock: BusyBlock?
    
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let timeWidth: CGFloat = 60
    private let hours = Array(6...23) // 6 AM to 11 PM
    private let minuteSnap: CGFloat = 15 // Snap to 15-minute intervals
    
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
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Time indicators and horizontal lines
                VStack(spacing: 0) {
                    ForEach(hours, id: \.self) { hour in
                        VStack(spacing: 0) {
                            // Main hour line
                            HStack(spacing: 0) {
                                Text(String(format: "%d:00", hour))
                                    .font(.caption)
                                    .frame(width: timeWidth)
                                
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 1)
                            }
                            
                            // 15-minute markers
                            ForEach([15, 30, 45], id: \.self) { minute in
                                HStack(spacing: 0) {
                                    Text("")
                                        .frame(width: timeWidth)
                                    
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 1)
                                }
                                .frame(height: hourHeight / 4)
                            }
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
                    BusyBlockView(block: block, isDragging: draggingBlockId == block.id)
                        .offset(x: timeWidth, y: timeOffset(for: block.start) + (draggingBlockId == block.id ? snapToGrid(dragOffset) : 0))
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    draggingBlockId = block.id
                                    dragOffset = value.translation.height
                                }
                                .onEnded { value in
                                    if let id = draggingBlockId {
                                        // Convert snapped drag offset to minutes
                                        let snappedOffset = snapToGrid(dragOffset)
                                        let minutesOffset = Int(snappedOffset / (hourHeight / 60))
                                        if minutesOffset != 0 {
                                            onBlockUpdate(block, minutesOffset)
                                        }
                                    }
                                    draggingBlockId = nil
                                    dragOffset = 0
                                }
                        )
                        .onTapGesture {
                            selectedBlock = block
                        }
                }
            }
            .frame(minHeight: CGFloat(hours.count) * hourHeight)
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(item: $selectedBlock) { block in
            TaskDetailView(
                block: block,
                onDelete: {
                    onBlockDelete(block)
                },
                onUpdate: { updatedBlock in
                    onBlockSave(updatedBlock)
                }
            )
        }
    }
    
    private func snapToGrid(_ offset: CGFloat) -> CGFloat {
        let minuteHeight = hourHeight / 60
        let snapHeight = minuteHeight * minuteSnap
        return round(offset / snapHeight) * snapHeight
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
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(themeManager.themeColor)
                .frame(width: 8, height: 8)
            
            Rectangle()
                .fill(themeManager.themeColor)
                .frame(height: 1)
        }
        .padding(.leading, timeWidth - 4)
    }
}

struct BusyBlockView: View {
    let block: BusyBlock
    let isDragging: Bool
    @EnvironmentObject private var themeManager: ThemeManager
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
                .foregroundColor(.primary)
                .lineLimit(1)
            
            if let location = block.location {
                Text(location)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Text("\(block.start.formatted(date: .omitted, time: .shortened)) - \(block.end.formatted(date: .omitted, time: .shortened))")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height)
        .background(Color.gray.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .scaleEffect(isDragging ? 1.02 : 1.0)
        .animation(.spring(response: 0.3), value: isDragging)
    }
} 