import Foundation

struct TaskScheduler {
    static func scheduleSessions(
        for task: Task,
        totalDuration: TimeInterval,
        sessionDuration: TimeInterval,
        busyBlocks: [BusyBlock],
        deadline: Date,
        existingSessions: [TaskSession],
        preferences: UserPreferences = UserPreferences.load()
    ) -> [TaskSession] {
        let numberOfSessions = Int(ceil(totalDuration / sessionDuration))
        var scheduledSessions: [TaskSession] = []
        
        // Start from tomorrow if deadline is not today
        let startDate = Calendar.current.isDateInToday(deadline) 
            ? Date() 
            : Calendar.current.startOfDay(for: Date())
        
        // Get all possible time slots until deadline
        let availableSlots = findAvailableTimeSlots(
            from: startDate,
            to: deadline,
            sessionDuration: sessionDuration,
            busyBlocks: busyBlocks,
            existingSessions: existingSessions,
            preferences: preferences
        )
        
        // Try to distribute sessions evenly across available days
        let slotsPerDay = min(
            preferences.maximumSessionsPerDay,
            Int(ceil(Double(numberOfSessions) / Double(daysBetween(startDate, and: deadline))))
        )
        
        var currentSlotIndex = 0
        var remainingSessions = numberOfSessions
        
        while remainingSessions > 0 && currentSlotIndex < availableSlots.count {
            let slot = availableSlots[currentSlotIndex]
            
            // Check if we haven't exceeded maximum sessions for this day
            let sessionsForDay = scheduledSessions.filter { 
                Calendar.current.isDate($0.start, inSameDayAs: slot.start)
            }.count
            
            if sessionsForDay < slotsPerDay {
                let session = TaskSession(
                    id: UUID(),
                    taskId: task.id,
                    taskTitle: task.name,
                    start: slot.start,
                    duration: sessionDuration,
                    sessionNumber: numberOfSessions - remainingSessions + 1,
                    totalSessions: numberOfSessions
                )
                scheduledSessions.append(session)
                remainingSessions -= 1
            }
            
            currentSlotIndex += 1
        }
        
        return scheduledSessions
    }
    
    private static func findAvailableTimeSlots(
        from startDate: Date,
        to endDate: Date,
        sessionDuration: TimeInterval,
        busyBlocks: [BusyBlock],
        existingSessions: [TaskSession],
        preferences: UserPreferences
    ) -> [TimeSlot] {
        var availableSlots: [TimeSlot] = []
        let calendar = Calendar.current
        var currentDate = startDate
        
        while currentDate <= endDate {
            // Check if it's a working day
            let weekday = calendar.component(.weekday, from: currentDate)
            if preferences.workingDays.contains(weekday) {
                // Get start and end of working hours for this day
                let dayStart = calendar.date(
                    bySettingHour: calendar.component(.hour, from: preferences.workingHours.startTime),
                    minute: calendar.component(.minute, from: preferences.workingHours.startTime),
                    second: 0,
                    of: currentDate
                ) ?? currentDate
                
                let dayEnd = calendar.date(
                    bySettingHour: calendar.component(.hour, from: preferences.workingHours.endTime),
                    minute: calendar.component(.minute, from: preferences.workingHours.endTime),
                    second: 0,
                    of: currentDate
                ) ?? currentDate
                
                // Start from current time if it's today
                var timePointer = calendar.isDateInToday(currentDate) 
                    ? max(Date(), dayStart)
                    : dayStart
                
                while timePointer.addingTimeInterval(sessionDuration) <= dayEnd {
                    let hour = calendar.component(.hour, from: timePointer)
                    
                    // Only consider slots within preferred time ranges
                    if preferences.isWithinPreferredTime(hour) {
                        let potentialSlotEnd = timePointer.addingTimeInterval(sessionDuration)
                        
                        // Check if slot conflicts with busy blocks or existing sessions
                        let hasConflict = busyBlocks.contains(where: { block in
                            timePointer < block.end && potentialSlotEnd > block.start
                        }) || existingSessions.contains(where: { session in
                            timePointer < session.start.addingTimeInterval(session.duration) &&
                            potentialSlotEnd > session.start
                        })
                        
                        if !hasConflict {
                            availableSlots.append(TimeSlot(start: timePointer, end: potentialSlotEnd))
                        }
                    }
                    
                    // Move to next potential slot, considering minimum break
                    timePointer = timePointer.addingTimeInterval(
                        preferences.minimumBreakBetweenSessions * 60
                    )
                }
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return availableSlots
    }
    
    private static func daysBetween(_ start: Date, and end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(1, components.day ?? 1)
    }
}

// MARK: - Supporting Types
struct TimeSlot {
    let start: Date
    let end: Date
} 