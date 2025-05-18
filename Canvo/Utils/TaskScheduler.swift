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
        
        // Get task-specific buffer time
        let bufferTime = preferences.getBufferTime(
            priority: task.priority,
            isAssignment: task.name.lowercased().contains("assignment"),
            isQuiz: task.name.lowercased().contains("quiz")
        )
        
        // Start from tomorrow if deadline is not today, otherwise start after buffer time
        let now = Date()
        let startDate = Calendar.current.isDateInToday(deadline)
            ? now.addingTimeInterval(bufferTime * 60) // Convert minutes to seconds
            : Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 3600))
        
        // Get all possible time slots until deadline
        let availableSlots = findAvailableTimeSlots(
            from: startDate,
            to: deadline,
            sessionDuration: sessionDuration,
            busyBlocks: busyBlocks,
            existingSessions: existingSessions,
            preferences: preferences
        )
        
        // Calculate days between start and deadline
        let daysBetween = Self.daysBetween(startDate, and: deadline)
        
        // Determine distribution strategy
        if preferences.distributionPreferences.preferEvenDistribution {
            // Distribute sessions evenly across available days
            let slotsPerDay = min(
                preferences.maximumSessionsPerDay,
                Int(ceil(Double(numberOfSessions) / Double(daysBetween)))
            )
            
            var currentSlotIndex = 0
            var remainingSessions = numberOfSessions
            var lastSessionDate: Date?
            
            while remainingSessions > 0 && currentSlotIndex < availableSlots.count {
                let slot = availableSlots[currentSlotIndex]
                
                // Check if we haven't exceeded maximum sessions for this day
                let sessionsForDay = scheduledSessions.filter { 
                    Calendar.current.isDate($0.start, inSameDayAs: slot.start)
                }.count
                
                // Check if we're respecting the preferred day spacing
                let respectsDaySpacing = lastSessionDate.map { lastDate in
                    let days = Self.daysBetween(lastDate, and: slot.start)
                    return days >= preferences.distributionPreferences.preferredDaySpacing
                } ?? true
                
                if sessionsForDay < slotsPerDay && respectsDaySpacing {
                    // Check for overlaps with existing sessions and task slot limits
                    let hasOverlap = scheduledSessions.contains { existingSession in
                        let sessionEnd = slot.start.addingTimeInterval(sessionDuration)
                        let existingEnd = existingSession.start.addingTimeInterval(existingSession.duration)
                        return (slot.start < existingEnd && sessionEnd > existingSession.start)
                    }
                    
                    let tasksInTimeSlot = scheduledSessions.filter { session in
                        let calendar = Calendar.current
                        let slotStartHour = calendar.component(.hour, from: slot.start)
                        let slotStart = calendar.date(bySettingHour: slotStartHour, minute: 0, second: 0, of: slot.start) ?? slot.start
                        let slotEnd = calendar.date(byAdding: .hour, value: 1, to: slotStart) ?? slot.start
                        return session.start >= slotStart && session.start < slotEnd
                    }.count
                    
                    if !hasOverlap && tasksInTimeSlot < preferences.distributionPreferences.maximumTasksPerTimeSlot {
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
                        lastSessionDate = slot.start
                        remainingSessions -= 1
                    }
                }
                
                currentSlotIndex += 1
            }
        } else if preferences.distributionPreferences.frontLoadTasks {
            // Front-load tasks to earlier available slots
            scheduleWithBias(frontLoad: true)
        } else if preferences.distributionPreferences.backLoadTasks {
            // Back-load tasks to later available slots
            scheduleWithBias(frontLoad: false)
        }
        
        return scheduledSessions
        
        // Helper function for biased scheduling
        func scheduleWithBias(frontLoad: Bool) {
            let slots = frontLoad ? availableSlots : Array(availableSlots.reversed())
            var remainingSessions = numberOfSessions
            var lastSessionDate: Date?
            
            for slot in slots {
                guard remainingSessions > 0 else { break }
                
                let sessionsForDay = scheduledSessions.filter { 
                    Calendar.current.isDate($0.start, inSameDayAs: slot.start)
                }.count
                
                let respectsDaySpacing = lastSessionDate.map { lastDate in
                    let days = Self.daysBetween(lastDate, and: slot.start)
                    return days >= preferences.distributionPreferences.preferredDaySpacing
                } ?? true
                
                if sessionsForDay < preferences.maximumSessionsPerDay && respectsDaySpacing {
                    let hasOverlap = scheduledSessions.contains { existingSession in
                        let sessionEnd = slot.start.addingTimeInterval(sessionDuration)
                        let existingEnd = existingSession.start.addingTimeInterval(existingSession.duration)
                        return (slot.start < existingEnd && sessionEnd > existingSession.start)
                    }
                    
                    let tasksInTimeSlot = scheduledSessions.filter { session in
                        let calendar = Calendar.current
                        let slotStartHour = calendar.component(.hour, from: slot.start)
                        let slotStart = calendar.date(bySettingHour: slotStartHour, minute: 0, second: 0, of: slot.start) ?? slot.start
                        let slotEnd = calendar.date(byAdding: .hour, value: 1, to: slotStart) ?? slot.start
                        return session.start >= slotStart && session.start < slotEnd
                    }.count
                    
                    if !hasOverlap && tasksInTimeSlot < preferences.distributionPreferences.maximumTasksPerTimeSlot {
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
                        lastSessionDate = slot.start
                        remainingSessions -= 1
                    }
                }
            }
        }
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
                let startHour = calendar.component(.hour, from: preferences.workingHours.startTime)
                let startMinute = calendar.component(.minute, from: preferences.workingHours.startTime)
                let endHour = calendar.component(.hour, from: preferences.workingHours.endTime)
                let endMinute = calendar.component(.minute, from: preferences.workingHours.endTime)
                
                let dayStart = calendar.date(
                    bySettingHour: startHour,
                    minute: startMinute,
                    second: 0,
                    of: currentDate
                ) ?? currentDate
                
                let dayEnd = calendar.date(
                    bySettingHour: endHour,
                    minute: endMinute,
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