import Foundation

struct TimetableDataManager {
    // MARK: - Storage Keys
    private static let taskSessionsKey = "timetable_task_sessions"
    private static let busyBlocksKey = "timetable_busy_blocks"
    
    // MARK: - iCloud Support
    static var useCloudKitSync: Bool {
        UserDefaults.standard.bool(forKey: "useCloudKitSync")
    }
    
    static var iCloudDocumentsDirectory: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }
    
    static var iCloudArchiveURL: URL? {
        iCloudDocumentsDirectory?.appendingPathComponent("timetable_data").appendingPathExtension("json")
    }
    
    static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    static let archiveURL = documentsDirectory.appendingPathComponent("timetable_data").appendingPathExtension("json")
    
    // MARK: - Data Structure
    struct TimetableData: Codable {
        var taskSessions: [TaskSession]
        var busyBlocks: [BusyBlock]
    }
    
    // MARK: - Save and Load Methods
    
    static func save(taskSessions: [TaskSession], busyBlocks: [BusyBlock]) {
        print("Saving timetable data - Task Sessions: \(taskSessions.count), Busy Blocks: \(busyBlocks.count)")
        
        let timetableData = TimetableData(taskSessions: taskSessions, busyBlocks: busyBlocks)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let fileURL: URL
        if useCloudKitSync, let iCloudURL = iCloudArchiveURL {
            // Ensure iCloud Documents directory exists
            if let iCloudDir = iCloudDocumentsDirectory {
                try? FileManager.default.createDirectory(at: iCloudDir, withIntermediateDirectories: true, attributes: nil)
            }
            fileURL = iCloudURL
        } else {
            fileURL = archiveURL
        }
        
        do {
            let data = try encoder.encode(timetableData)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("✅ Timetable data saved successfully to \(fileURL)")
            
            // Verify the save by reading back
            if let savedData = try? Data(contentsOf: fileURL),
               let savedTimetable = try? JSONDecoder().decode(TimetableData.self, from: savedData) {
                print("✅ Verified save - Task Sessions: \(savedTimetable.taskSessions.count), Busy Blocks: \(savedTimetable.busyBlocks.count)")
            }
        } catch {
            print("❌ Error saving timetable data: \(error.localizedDescription)")
        }
    }
    
    static func load() -> (taskSessions: [TaskSession], busyBlocks: [BusyBlock]) {
        print("Loading timetable data...")
        
        let fileURL: URL
        if useCloudKitSync, let iCloudURL = iCloudArchiveURL {
            fileURL = iCloudURL
        } else {
            fileURL = archiveURL
        }
        
        guard let data = try? Data(contentsOf: fileURL) else {
            print("⚠️ No timetable data found, returning empty arrays")
            return ([], [])
        }
        
        let decoder = JSONDecoder()
        if let timetableData = try? decoder.decode(TimetableData.self, from: data) {
            print("✅ Timetable data loaded successfully - Task Sessions: \(timetableData.taskSessions.count), Busy Blocks: \(timetableData.busyBlocks.count)")
            return (timetableData.taskSessions, timetableData.busyBlocks)
        } else {
            print("❌ Couldn't decode timetable data, returning empty arrays")
            return ([], [])
        }
    }
    
    // MARK: - iCloud Sync Observer
    @MainActor
    private static var metadataQuery: NSMetadataQuery?
    
    @MainActor
    static func startObservingICloudChanges() async throws {
        guard useCloudKitSync else { return }
        guard metadataQuery == nil else { return } // Only start once
        
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, "timetable_data.json")
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { _ in
            NotificationCenter.default.post(name: Notification.Name("TimetableDataUpdated"), object: nil)
        }
        
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
            NotificationCenter.default.post(name: Notification.Name("TimetableDataUpdated"), object: nil)
        }
        
        query.start()
        metadataQuery = query
    }
} 