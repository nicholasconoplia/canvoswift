import Foundation

class TaskScheduler {
    static func findFreeTimeSlots(between startDate: Date, and endDate: Date, busyBlocks: [BusyBlock], duration: TimeInterval) -> [Date] {
        let calendar = Calendar.current
        var currentDate = startDate
        var freeSlots: [Date] = []
        
        while currentDate < endDate {
            let potentialEndTime = currentDate.addingTimeInterval(duration)
            
            // Check if this time slot overlaps with any busy blocks
            let isOverlapping = busyBlocks.contains { block in
                let blockStart = block.start
                let blockEnd = block.end
                return (currentDate >= blockStart && currentDate < blockEnd) ||
                       (potentialEndTime > blockStart && potentialEndTime <= blockEnd) ||
                       (currentDate <= blockStart && potentialEndTime >= blockEnd)
            }
            
            // If no overlap and within working hours (8 AM to 8 PM), add to free slots
            if !isOverlapping {
                let hour = calendar.component(.hour, from: currentDate)
                if hour >= 8 && hour < 20 {
                    freeSlots.append(currentDate)
                }
            }
            
            // Move to next 30-minute slot
            currentDate = calendar.date(byAdding: .minute, value: 30, to: currentDate) ?? endDate
        }
        
        return freeSlots
    }
    
    static func scheduleSessions(for task: Task, totalDuration: TimeInterval, sessionDuration: TimeInterval, busyBlocks: [BusyBlock], deadline: Date) -> [TaskSession] {
        let numberOfSessions = Int(ceil(totalDuration / sessionDuration))
        let startDate = Date()
        let freeSlots = findFreeTimeSlots(between: startDate, and: deadline, busyBlocks: busyBlocks, duration: sessionDuration)
        
        var sessions: [TaskSession] = []
        
        // Try to distribute sessions evenly across available slots
        let slotsPerSession = max(1, freeSlots.count / numberOfSessions)
        
        for sessionIndex in 0..<numberOfSessions {
            let slotIndex = sessionIndex * slotsPerSession
            if slotIndex < freeSlots.count {
                let session = TaskSession(
                    taskId: task.id,
                    taskTitle: task.name,
                    start: freeSlots[slotIndex],
                    duration: sessionDuration,
                    sessionNumber: sessionIndex + 1,
                    totalSessions: numberOfSessions
                )
                sessions.append(session)
            }
        }
        
        return sessions
    }
} 