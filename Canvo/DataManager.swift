import Foundation

struct DataManager {
    // MARK: - iCloud Support
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
        let fileURL = iCloudArchiveURL ?? archiveURL
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
        let fileURL = iCloudArchiveURL ?? archiveURL

        // Ensure iCloud Documents directory exists
        if let iCloudDir = iCloudDocumentsDirectory {
            try? FileManager.default.createDirectory(at: iCloudDir, withIntermediateDirectories: true, attributes: nil)
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
} 