import Foundation

struct DataManager {
    // MARK: - iCloud Support
    static var useCloudKitSync: Bool {
        UserDefaults.standard.bool(forKey: "useCloudKitSync")
    }

    static var iCloudDocumentsDirectory: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents")
    }

    static var iCloudArchiveURL: URL? {
        iCloudDocumentsDirectory?.appendingPathComponent("taskLists").appendingPathExtension("json")
    }

    static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    static let archiveURL = documentsDirectory.appendingPathComponent("taskLists").appendingPathExtension("json")

    // MARK: - Load TaskLists from the JSON file (iCloud first, fallback to local)
    static func load() -> [TaskList] {
        let fileURL: URL
        if useCloudKitSync, let iCloudURL = iCloudArchiveURL {
            fileURL = iCloudURL
        } else {
            fileURL = archiveURL
        }
        guard let data = try? Data(contentsOf: fileURL) else {
            print("Couldn't load data, returning default.")
            return [TaskList(name: "Sample List")] // Return a default if no file exists
        }

        let decoder = JSONDecoder()
        if let decodedLists = try? decoder.decode([TaskList].self, from: data) {
            print("Data loaded successfully from \(fileURL)")
            return decodedLists
        } else {
            print("Couldn't decode data, returning default.")
            return [TaskList(name: "Sample List")] // Return default on decoding error
        }
    }

    // MARK: - Save TaskLists to the JSON file (iCloud first, fallback to local)
    static func save(lists: [TaskList]) {
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
            let data = try encoder.encode(lists)
            try data.write(to: fileURL, options: [.atomicWrite])
            print("Data saved successfully to \(fileURL)")
        } catch {
            print("Error saving data: \(error.localizedDescription)")
        }
    }

    // MARK: - iCloud Sync Observer
    @MainActor
    private static var metadataQuery: NSMetadataQuery?

    @MainActor
    static func startObservingICloudChanges() {
        guard useCloudKitSync else { return }
        guard metadataQuery == nil else { return } // Only start once
        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, "taskLists.json")
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: .main) { _ in
            NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
        }
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: .main) { _ in
            NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
        }
        query.start()
        metadataQuery = query
    }
    
    // MARK: - CloudKit Data Backup
    
    /// Load data directly from CloudKit (without checking useCloudKitSync flag)
    static func loadFromCloudKit() -> [TaskList]? {
        guard let iCloudURL = iCloudArchiveURL else {
            print("CloudKit URL not available")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: iCloudURL)
            let decoder = JSONDecoder()
            let decodedLists = try decoder.decode([TaskList].self, from: data)
            print("CloudKit data loaded successfully")
            return decodedLists
        } catch {
            print("Error loading CloudKit data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Load data directly from local storage (without checking useCloudKitSync flag)
    static func loadFromLocalStorage() -> [TaskList]? {
        do {
            let data = try Data(contentsOf: archiveURL)
            let decoder = JSONDecoder()
            let decodedLists = try decoder.decode([TaskList].self, from: data)
            print("Local data loaded successfully")
            return decodedLists
        } catch {
            print("Error loading local data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Backup CloudKit data to local storage
    static func backupCloudKitDataToLocal() -> Bool {
        guard let cloudKitData = loadFromCloudKit() else {
            print("No CloudKit data available to backup")
            return false
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(cloudKitData)
            try data.write(to: archiveURL, options: [.atomicWrite])
            print("CloudKit data successfully backed up to local storage")
            return true
        } catch {
            print("Error backing up CloudKit data: \(error.localizedDescription)")
            return false
        }
    }
} 