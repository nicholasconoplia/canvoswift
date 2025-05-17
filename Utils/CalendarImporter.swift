import EventKit

class CalendarImporter {
    let eventStore: EKEventStore
    let selectedCalendars: [EKCalendar]

    init(eventStore: EKEventStore, selectedCalendars: [EKCalendar]) {
        self.eventStore = eventStore
        self.selectedCalendars = selectedCalendars
    }

    func importEvents(from startDate: Date, to endDate: Date, completion: @escaping ([BusyBlock]) -> Void) {
        let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
        let events = self.eventStore.events(matching: predicate)
        
        // Convert to BusyBlock with title
        let busyBlocks = events.map { event in
            BusyBlock(start: event.startDate, end: event.endDate, title: event.title)
        }
        
        // Use our safe delivery method
        self.deliverCompletion(completion, with: busyBlocks)
    }

    private func deliverCompletion(_ completion: @escaping ([BusyBlock]) -> Void, with busyBlocks: [BusyBlock]) {
        // Implementation of the safe delivery method
    }
} 