import Foundation

struct DataManager {
    // Static property for the file URL
    static let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    static let archiveURL = documentsDirectory.appendingPathComponent("taskLists").appendingPathExtension("json")

    // Load TaskLists from the JSON file
    static func load() -> [TaskList] {
        guard let data = try? Data(contentsOf: archiveURL) else {
            print("Couldn't load data, returning default.")
            return [TaskList(name: "Sample List")] // Return a default if no file exists
        }

        let decoder = JSONDecoder()
        if let decodedLists = try? decoder.decode([TaskList].self, from: data) {
            print("Data loaded successfully from \(archiveURL)")
            return decodedLists
        } else {
            print("Couldn't decode data, returning default.")
            return [TaskList(name: "Sample List")] // Return default on decoding error
        }
    }

    // Save TaskLists to the JSON file
    static func save(lists: [TaskList]) {
        let encoder = JSONEncoder()
        // Use prettyPrinted for easier debugging if needed, remove for production
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(lists)
            try data.write(to: archiveURL, options: [.atomicWrite, .completeFileProtection])
            print("Data saved successfully to \(archiveURL)")
        } catch {
            print("Error saving data: \(error.localizedDescription)")
        }
    }
} 