import Foundation

class TaskScheduler {
    static func findFreeTimeSlots(
        between startDate: Date,
        and endDate: Date,
        busyBlocks: [BusyBlock],
        duration: TimeInterval,
        preferences: UserPreferences = UserPreferences.load()
    ) -> [Date] {
        let calendar = Calendar.current
        var currentDate = startDate
        var freeSlots: [Date] = []
        
        while currentDate < endDate {
            let potentialEndTime = currentDate.addingTimeInterval(duration)
            let hour = calendar.component(.hour, from: currentDate)
            
            // Check if this time slot is within preferred hours
            let isWithinPreferredHours = preferences.isWithinPreferredTime(hour)
            
            // Check if this time slot overlaps with any busy blocks
            let isOverlapping = busyBlocks.contains { block in
                let blockStart = block.start
                let blockEnd = block.end
                return (currentDate >= blockStart && currentDate < blockEnd) ||
                       (potentialEndTime > blockStart && potentialEndTime <= blockEnd) ||
                       (currentDate <= blockStart && potentialEndTime >= blockEnd)
            }
            
            // If no overlap and within preferred hours, add to free slots
            if !isOverlapping {
                // Add all available slots, but mark preferred ones
                freeSlots.append(currentDate)
            }
            
            // Move to next 30-minute slot
            currentDate = calendar.date(byAdding: .minute, value: 30, to: currentDate) ?? endDate
        }
        
        // Sort slots by preference (slots in preferred time ranges get priority)
        return freeSlots.sorted { date1, date2 in
            let hour1 = calendar.component(.hour, from: date1)
            let hour2 = calendar.component(.hour, from: date2)
            
            let isPreferred1 = preferences.isWithinPreferredTime(hour1)
            let isPreferred2 = preferences.isWithinPreferredTime(hour2)
            
            // If both are preferred or both are not preferred, keep chronological order
            if isPreferred1 == isPreferred2 {
                return date1 < date2
            }
            
            // Prioritize preferred times
            return isPreferred1
        }
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