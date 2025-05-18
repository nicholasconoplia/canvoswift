import Foundation
import EventKit

// Make EKCalendar conform to Sendable (we ensure thread safety ourselves)
extension EKCalendar: @unchecked Sendable {}

// Also make BusyBlock conform to Sendable explicitly
// Using @unchecked since we're adding conformance in a different file than where BusyBlock is defined
extension BusyBlock: @unchecked Sendable {}

// A more robust calendar importer with explicit queue management
// We use @unchecked Sendable because we manually manage thread safety with our dedicated queue
extension CalendarImporter: @unchecked Sendable {}

class CalendarImporter {
    // Thread-safe singleton implemented through dedicated dispatch queue
    static let shared = CalendarImporter()
    
    // We'll use a dedicated serial queue for ALL EventKit operations
    private let eventKitQueue = DispatchQueue(label: "com.canvo.eventKitQueue", qos: .userInitiated)
    
    // The event store will be created lazily and only accessed on eventKitQueue
    private var _eventStore: EKEventStore?
    private var eventStore: EKEventStore {
        if let store = _eventStore {
            return store
        }
        
        // Lazy initialization on our dedicated queue
        let store = EKEventStore()
        _eventStore = store
        return store
    }
    
    // Helper method to safely deliver completions to the main thread
    // We constrain T to Sendable to ensure the result is safe to send across threads
    private nonisolated func deliverCompletion<T: Sendable>(_ completion: @Sendable @escaping (T) -> Void, with result: T) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
    
    // Request access using our dedicated queue pattern
    func requestAccess(completion: @Sendable @escaping (Bool) -> Void) {
        // First check current status on main thread
        let currentStatus = EKEventStore.authorizationStatus(for: .event)
        print("CalendarImporter: Current authorization status before request: \(currentStatus.rawValue)")
        
        // If already authorized or denied, don't bother with the request
        if currentStatus == .authorized {
            deliverCompletion(completion, with: true)
            return
        } else if currentStatus == .denied || currentStatus == .restricted {
            deliverCompletion(completion, with: false)
            return
        }
        
        // If status is .notDetermined, we need to request access
        // We'll do this on our dedicated queue
        eventKitQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.eventStore.requestAccess(to: .event) { granted, error in
                if let error = error {
                    print("CalendarImporter: Error requesting access: \(error.localizedDescription)")
                }
                
                print("CalendarImporter: Access request completed. Granted: \(granted)")
                
                // Use our safe delivery method
                self.deliverCompletion(completion, with: granted)
            }
        }
    }
    
    // Fetch all available calendars using our dedicated queue
    func getAllCalendars(completion: @Sendable @escaping ([EKCalendar]) -> Void) {
        eventKitQueue.async { [weak self] in
            guard let self = self else { 
                self?.deliverCompletion(completion, with: [])
                return 
            }
            
            // Double-check authorization on our dedicated queue
            let authStatus = EKEventStore.authorizationStatus(for: .event)
            guard authStatus == .authorized else {
                print("CalendarImporter: Cannot get calendars, authorization status: \(authStatus.rawValue)")
                self.deliverCompletion(completion, with: [])
                return
            }
            
            let calendars = self.eventStore.calendars(for: .event)
            print("CalendarImporter: Found \(calendars.count) calendars")
            
            // Use our safe delivery method
            self.deliverCompletion(completion, with: calendars)
        }
    }
    
    // Fetch events from all calendars
    func fetchEvents(startDate: Date, endDate: Date, completion: @Sendable @escaping ([BusyBlock]) -> Void) {
        eventKitQueue.async { [weak self] in
            guard let self = self else { 
                self?.deliverCompletion(completion, with: [])
                return 
            }
            
            // Double-check authorization
            let authStatus = EKEventStore.authorizationStatus(for: .event)
            guard authStatus == .authorized else {
                print("CalendarImporter: Cannot fetch events, authorization status: \(authStatus.rawValue)")
                self.deliverCompletion(completion, with: [])
                return
            }
            
            let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
            let events = self.eventStore.events(matching: predicate)
            
            // Convert to BusyBlock with title and location
            let busyBlocks = events.map { event in
                BusyBlock(
                    start: event.startDate,
                    end: event.endDate,
                    title: event.title,
                    location: event.location
                )
            }
            
            // Use our safe delivery method
            self.deliverCompletion(completion, with: busyBlocks)
        }
    }
    
    // Fetch events from specific calendars
    func fetchEvents(from calendarIDs: Set<String>, startDate: Date, endDate: Date, completion: @Sendable @escaping ([BusyBlock]) -> Void) {
        eventKitQueue.async { [weak self] in
            guard let self = self else { 
                self?.deliverCompletion(completion, with: [])
                return 
            }
            
            // Double-check authorization
            let authStatus = EKEventStore.authorizationStatus(for: .event)
            guard authStatus == .authorized else {
                print("CalendarImporter: Cannot fetch selected events, authorization status: \(authStatus.rawValue)")
                self.deliverCompletion(completion, with: [])
                return
            }
            
            let allCalendars = self.eventStore.calendars(for: .event)
            let selectedCalendars = allCalendars.filter { calendarIDs.contains($0.calendarIdentifier) }
            
            let predicate = self.eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: selectedCalendars)
            let events = self.eventStore.events(matching: predicate)
            
            // Convert to BusyBlock with title and location
            let busyBlocks = events.map { event in
                BusyBlock(
                    start: event.startDate,
                    end: event.endDate,
                    title: event.title,
                    location: event.location
                )
            }
            
            // Use our safe delivery method
            self.deliverCompletion(completion, with: busyBlocks)
        }
    }
} 