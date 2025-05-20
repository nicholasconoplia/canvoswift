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
        
        // Start from now + buffer time if deadline is today, otherwise start from tomorrow
        let now = Date()
        let startDate = Calendar.current.isDateInToday(deadline)
            ? now.addingTimeInterval(bufferTime * 60) // Convert minutes to seconds
            : Calendar.current.startOfDay(for: now.addingTimeInterval(24 * 3600))
        
        // Get all possible time slots until deadline
        var availableSlots = findAvailableTimeSlots(
            from: startDate,
            to: deadline,
            sessionDuration: sessionDuration,
            busyBlocks: busyBlocks,
            existingSessions: existingSessions + scheduledSessions, // Include already scheduled sessions
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
                let sessionsForDay = (existingSessions + scheduledSessions).filter { 
                    Calendar.current.isDate($0.start, inSameDayAs: slot.start)
                }.count
                
                // Check if we're respecting the preferred day spacing
                let respectsDaySpacing = lastSessionDate.map { lastDate in
                    let days = Self.daysBetween(lastDate, and: slot.start)
                    return days >= preferences.distributionPreferences.preferredDaySpacing
                } ?? true
                
                if sessionsForDay < slotsPerDay && respectsDaySpacing {
                    // Check for overlaps with all sessions (existing + already scheduled)
                    let hasOverlap = (existingSessions + scheduledSessions).contains { session in
                        let sessionEnd = slot.start.addingTimeInterval(sessionDuration)
                        let existingEnd = session.start.addingTimeInterval(session.duration)
                        
                        // Check for direct overlap
                        let directOverlap = slot.start < existingEnd && sessionEnd > session.start
                        
                        // Check for minimum break violation
                        let minimumBreak = preferences.minimumBreakBetweenSessions * 60
                        let breakStartTime = session.start.addingTimeInterval(session.duration)
                        let breakEndTime = breakStartTime.addingTimeInterval(minimumBreak)
                        let violatesBreak = slot.start >= session.start && slot.start < breakEndTime
                        
                        return directOverlap || violatesBreak
                    }
                    
                    let tasksInTimeSlot = (existingSessions + scheduledSessions).filter { session in
                        let calendar = Calendar.current
                        let slotStartHour = calendar.component(.hour, from: slot.start)
                        let sessionStartHour = calendar.component(.hour, from: session.start)
                        return slotStartHour == sessionStartHour &&
                               calendar.isDate(slot.start, inSameDayAs: session.start)
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
                        
                        // Recalculate available slots with the new session included
                        if remainingSessions > 0 {
                            availableSlots = findAvailableTimeSlots(
                                from: startDate,
                                to: deadline,
                                sessionDuration: sessionDuration,
                                busyBlocks: busyBlocks,
                                existingSessions: existingSessions + scheduledSessions,
                                preferences: preferences
                            )
                            currentSlotIndex = 0
                            continue
                        }
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
            var remainingSessions = numberOfSessions
            var lastSessionDate: Date?
            var currentSlots = frontLoad ? availableSlots : Array(availableSlots.reversed())
            
            while remainingSessions > 0 && !currentSlots.isEmpty {
                let slot = currentSlots[0]
                currentSlots.removeFirst()
                
                let sessionsForDay = (existingSessions + scheduledSessions).filter { 
                    Calendar.current.isDate($0.start, inSameDayAs: slot.start)
                }.count
                
                let respectsDaySpacing = lastSessionDate.map { lastDate in
                    let days = Self.daysBetween(lastDate, and: slot.start)
                    return days >= preferences.distributionPreferences.preferredDaySpacing
                } ?? true
                
                if sessionsForDay < preferences.maximumSessionsPerDay && respectsDaySpacing {
                    let hasOverlap = (existingSessions + scheduledSessions).contains { session in
                        let sessionEnd = slot.start.addingTimeInterval(sessionDuration)
                        let existingEnd = session.start.addingTimeInterval(session.duration)
                        
                        // Check for direct overlap
                        let directOverlap = slot.start < existingEnd && sessionEnd > session.start
                        
                        // Check for minimum break violation
                        let minimumBreak = preferences.minimumBreakBetweenSessions * 60
                        let breakStartTime = session.start.addingTimeInterval(session.duration)
                        let breakEndTime = breakStartTime.addingTimeInterval(minimumBreak)
                        let violatesBreak = slot.start >= session.start && slot.start < breakEndTime
                        
                        return directOverlap || violatesBreak
                    }
                    
                    let tasksInTimeSlot = (existingSessions + scheduledSessions).filter { session in
                        let calendar = Calendar.current
                        let slotStartHour = calendar.component(.hour, from: slot.start)
                        let sessionStartHour = calendar.component(.hour, from: session.start)
                        return slotStartHour == sessionStartHour &&
                               calendar.isDate(slot.start, inSameDayAs: session.start)
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
                        
                        // Recalculate available slots with the new session included
                        if remainingSessions > 0 {
                            availableSlots = findAvailableTimeSlots(
                                from: startDate,
                                to: deadline,
                                sessionDuration: sessionDuration,
                                busyBlocks: busyBlocks,
                                existingSessions: existingSessions + scheduledSessions,
                                preferences: preferences
                            )
                            currentSlots = frontLoad ? availableSlots : Array(availableSlots.reversed())
                        }
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
        
        // Convert existing sessions to busy blocks for easier conflict checking
        let sessionBlocks = existingSessions.map { session in
            BusyBlock(
                id: UUID(),
                start: session.start,
                end: session.start.addingTimeInterval(session.duration),
                title: session.taskTitle
            )
        }
        
        // Combine all busy blocks and sort them by start time
        let allBusyBlocks = (busyBlocks + sessionBlocks).sorted { $0.start < $1.start }
        
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
                
                // Find all available slots for this day
                while timePointer.addingTimeInterval(sessionDuration) <= dayEnd {
                    let hour = calendar.component(.hour, from: timePointer)
                    
                    // Only consider slots within preferred time ranges
                    if preferences.isWithinPreferredTime(hour) {
                        let potentialSlotEnd = timePointer.addingTimeInterval(sessionDuration)
                        
                        // Check if this time slot overlaps with any busy blocks
                        let hasConflict = allBusyBlocks.contains { block in
                            // Check for direct overlap
                            let directOverlap = timePointer < block.end && potentialSlotEnd > block.start
                            
                            // Check for minimum break violation
                            let minimumBreak = preferences.minimumBreakBetweenSessions * 60
                            let breakStartTime = block.end
                            let breakEndTime = block.end.addingTimeInterval(minimumBreak)
                            let violatesBreak = timePointer >= block.start && timePointer < breakEndTime
                            
                            // Check for same hour conflict
                            let sameHourConflict = calendar.isDate(timePointer, equalTo: block.start, toGranularity: .hour)
                            
                            return directOverlap || violatesBreak || sameHourConflict
                        }
                        
                        if !hasConflict {
                            // Check if there are any tasks already scheduled in this hour
                            let tasksInSameHour = allBusyBlocks.filter { block in
                                calendar.component(.hour, from: block.start) == hour &&
                                calendar.isDate(block.start, inSameDayAs: timePointer)
                            }
                            
                            if tasksInSameHour.isEmpty {
                            availableSlots.append(TimeSlot(start: timePointer, end: potentialSlotEnd))
                            }
                        }
                    }
                    
                    // Move to next potential slot, considering minimum break
                    timePointer = timePointer.addingTimeInterval(
                        max(sessionDuration, preferences.minimumBreakBetweenSessions * 60)
                    )
                }
            }
            
            // Move to next day
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? endDate
        }
        
        return availableSlots.sorted { $0.start < $1.start }
    }
    
    private static func daysBetween(_ start: Date, and end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(1, components.day ?? 1)
    }
    
    static func rescheduleSession(taskID: UUID, sessionID: UUID, duration: TimeInterval = 0) {
        var taskLists = DataManager.load()
        
        // Find the task and its previous session
        for taskList in taskLists {
            if let task = taskList.tasks.first(where: { $0.id == taskID }) {
                // Get all sessions for this task
                let (sessions, busyBlocks) = TimetableDataManager.load()
                guard let previousSession = sessions.first(where: { $0.id == sessionID }) else { return }
                
                // Calculate start time for tomorrow
                let calendar = Calendar.current
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                let startTime = calendar.date(bySettingHour: calendar.component(.hour, from: previousSession.start),
                                            minute: calendar.component(.minute, from: previousSession.start),
                                            second: 0,
                                            of: tomorrow) ?? tomorrow
                
                // If duration is 0, we'll show UI for custom duration
                if duration == 0 {
                    // Post notification to show duration selection UI
                    NotificationCenter.default.post(
                        name: Notification.Name("ShowSessionDurationUI"),
                        object: nil,
                        userInfo: [
                            "taskID": taskID,
                            "sessionID": sessionID,
                            "previousDuration": previousSession.duration
                        ]
                    )
                    return
                }
                
                // Schedule new session
                let newSessions = scheduleSessions(
                    for: task,
                    totalDuration: duration,
                    sessionDuration: duration,
                    busyBlocks: busyBlocks,
                    deadline: task.dueDate ?? calendar.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
                    existingSessions: sessions
                )
                
                if let newSession = newSessions.first {
                    var updatedSessions = sessions
                    updatedSessions.append(newSession)
                    TimetableDataManager.save(taskSessions: updatedSessions, busyBlocks: busyBlocks)
                    NotificationManager.shared.scheduleSessionNotifications(for: newSession)
                    
                    // Post notification that session was rescheduled
                    NotificationCenter.default.post(
                        name: Notification.Name("SessionRescheduled"),
                        object: nil,
                        userInfo: [
                            "taskID": taskID,
                            "oldSessionID": sessionID,
                            "newSessionID": newSession.id
                        ]
                    )
                }
                
                break
            }
        }
    }
}

// MARK: - Supporting Types
struct TimeSlot {
    let start: Date
    let end: Date
}