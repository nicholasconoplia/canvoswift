//  CanvasIntegrationView.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI
import Security

// MARK: - University Model
struct University: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let url: String
}

// MARK: - Predefined Universities
let UNIVERSITIES: [University] = [
    University(name: "University of Technology Sydney (UTS)", url: "https://canvas.uts.edu.au"),
    University(name: "University of Sydney (USyd)", url: "https://canvas.sydney.edu.au"),
    University(name: "Macquarie University", url: "https://ilearn.mq.edu.au"),
    University(name: "Western Sydney University", url: "https://vuws.westernsydney.edu.au"),
    University(name: "Australian Catholic University", url: "https://canvas.acu.edu.au"),
    University(name: "UNSW Sydney", url: "https://moodle.telt.unsw.edu.au"),
    University(name: "University of Melbourne", url: "https://canvas.lms.unimelb.edu.au"),
    University(name: "Monash University", url: "https://lms.monash.edu"),
    University(name: "Queensland University of Technology", url: "https://canvas.qut.edu.au"),
    University(name: "University of Queensland", url: "https://learn.uq.edu.au"),
    University(name: "RMIT University", url: "https://canvas.rmit.edu.au"),
    University(name: "La Trobe University", url: "https://lms.latrobe.edu.au"),
    University(name: "Deakin University", url: "https://d2l.deakin.edu.au"),
    University(name: "Curtin University", url: "https://lms.curtin.edu.au"),
    University(name: "University of Western Australia", url: "https://lms.uwa.edu.au"),
    University(name: "University of Adelaide", url: "https://myuni.adelaide.edu.au"),
    University(name: "Flinders University", url: "https://flo.flinders.edu.au"),
    University(name: "University of Tasmania", url: "https://mylo.utas.edu.au"),
    University(name: "Charles Sturt University", url: "https://interact2.csu.edu.au"),
    University(name: "University of New England", url: "https://moodle.une.edu.au"),
    University(name: "Custom University", url: "") // Represents the custom option
]

// MARK: - Canvas Integration ViewModel
class CanvasIntegrationViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var courses: [CanvasCourse] = []
    @Published var assignmentsByCourseId: [Int: [CanvasAssignment]] = [:]
    @Published var isApiKeyConnected: Bool = false
    @Published var fetchingAssignments: Set<Int> = [] // Track which courses are being fetched
    
    // University Selection
    @AppStorage("selectedUniversityName") var selectedUniversityName: String = UNIVERSITIES[0].name
    @AppStorage("isCustomUniversitySelected") var isCustomUniversitySelected: Bool = false
    @AppStorage("customUniversityName") var customUniversityName: String = ""
    @AppStorage("customUniversityURL") var customUniversityURL: String = ""
    
    @AppStorage("showOnlyCurrentCourses") var showOnlyCurrentCourses: Bool = true
    
    // Course filtering
    @Published var selectedCourseId: Int? = nil
    
    // Assignment type filtering
    @Published var selectedAssignmentType: String? = nil
    
    // List of possible assignment types
    let assignmentTypes = ["Assignment", "Quiz", "Discussion"]
    
    // Computed property to get filtered courses based on selection
    var filteredCourses: [CanvasCourse] {
        if let courseId = selectedCourseId {
            return courses.filter { $0.id == courseId }
        }
        return courses
    }
    
    // Computed property for the selected university
    var selectedUniversity: University {
        get {
            if let university = UNIVERSITIES.first(where: { $0.name == selectedUniversityName }) {
                return university
            }
            return UNIVERSITIES[0]
        }
        set {
            selectedUniversityName = newValue.name
            isCustomUniversitySelected = (newValue.name == "Custom University")
            if !isCustomUniversitySelected {
                customUniversityName = ""
                customUniversityURL = ""
            }
        }
    }

    // Computed property for the effective Canvas URL
    var effectiveCanvasURL: String {
        let baseURL = isCustomUniversitySelected ? 
            customUniversityURL.trimmingCharacters(in: .whitespacesAndNewlines) :
            selectedUniversity.url
        
        // Remove trailing slashes
        var cleanURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Ensure URL has https:// prefix
        if !cleanURL.lowercased().hasPrefix("http") {
            cleanURL = "https://" + cleanURL
        }
        
        return cleanURL
    }

    init() {
        loadSavedData()
    }
    
    // Load saved API key from keychain and other state from UserDefaults
    func loadSavedData() {
        if let savedApiKey = loadAPIKeyFromKeychain(), !savedApiKey.isEmpty {
            self.apiKey = savedApiKey
            self.isApiKeyConnected = true
            
            // Load courses and assignments from UserDefaults
            if let coursesData = UserDefaults.standard.data(forKey: "savedCourses"),
               let savedCourses = try? JSONDecoder().decode([CanvasCourse].self, from: coursesData) {
                self.courses = savedCourses
            }
            
            if let assignmentsData = UserDefaults.standard.data(forKey: "savedAssignmentsByCourseId"),
               let savedAssignments = try? JSONDecoder().decode([Int: [CanvasAssignment]].self, from: assignmentsData) {
                self.assignmentsByCourseId = savedAssignments
            }
        }
    }
    
    // Save API key to keychain
    func saveAPIKeyToKeychain() {
        // Don't save empty API keys
        guard !apiKey.isEmpty else { return }
        
        let service = "com.canvo.apikey"
        let account = "CanvasAPI"
        
        // Delete any existing key
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Create data from key
        guard let keyData = apiKey.data(using: .utf8) else { return }
        
        // Create query for saving
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save API key to keychain: \(status)")
        }
    }
    
    // Load API key from keychain
    func loadAPIKeyFromKeychain() -> String? {
        let service = "com.canvo.apikey"
        let account = "CanvasAPI"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) {
            return key
        }
        return nil
    }
    
    // Save courses and assignments to UserDefaults
    func saveCanvasData() {
        if let encodedCourses = try? JSONEncoder().encode(self.courses) {
            UserDefaults.standard.set(encodedCourses, forKey: "savedCourses")
        }
        
        if let encodedAssignments = try? JSONEncoder().encode(self.assignmentsByCourseId) {
            UserDefaults.standard.set(encodedAssignments, forKey: "savedAssignmentsByCourseId")
        }
        
        // Also save API connection status
        UserDefaults.standard.set(isApiKeyConnected, forKey: "isApiKeyConnected")
    }
    
    // Clear all saved data (for disconnecting)
    func clearSavedData() {
        apiKey = ""
        courses = []
        assignmentsByCourseId = [:]
        isApiKeyConnected = false
        
        // Remove from keychain
        let service = "com.canvo.apikey"
        let account = "CanvasAPI"
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Remove from UserDefaults
        UserDefaults.standard.removeObject(forKey: "savedCourses")
        UserDefaults.standard.removeObject(forKey: "savedAssignmentsByCourseId")
        UserDefaults.standard.removeObject(forKey: "isApiKeyConnected")
    }

    // MARK: - Fetch Logic
    func fetchCanvasData() {
        guard !apiKey.isEmpty, !effectiveCanvasURL.isEmpty else { 
            self.errorMessage = "Please enter your Canvas API key and select a university."
            return 
        }
        
        isLoading = true
        errorMessage = nil
        courses = [] // Clear existing courses before fetching
        
        // Detailed logging
        print("[Canvas API] Starting fetch with URL: \(effectiveCanvasURL)")
        print("[Canvas API] API Key length: \(apiKey.count) characters")
        print("[Canvas API] Selected University: \(selectedUniversityName)")
        
        // First verify API connectivity with a simple request
        verifyAPIConnection { success in
            if success {
                // If connection is successful, start fetching courses
                self.fetchWithEndpoint("/api/v1/users/self/courses") { success in
                    if success {
                        // After fetching all courses, apply filtering
                        self.processFetchedCourses()
                    } else {
                        // If all course fetching attempts failed, give more specific error
                        self.isLoading = false
                        if self.errorMessage == nil {
                            self.errorMessage = "Could not fetch courses. Please check your Canvas URL and API key. You may need to regenerate your API key."
                        }
                    }
                }
            } else {
                // Connection test failed
                self.isLoading = false
                if self.errorMessage == nil {
                    self.errorMessage = "Could not connect to Canvas. Please verify your API key and Canvas URL."
                }
            }
        }
    }
    
    // Verify the API connection with a simple request
    private func verifyAPIConnection(completion: @escaping (Bool) -> Void) {
        // Use the /api/v1/users/self endpoint which should be consistent across Canvas instances
        let urlString = "\(effectiveCanvasURL)/api/v1/users/self"
        
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid Canvas URL: \(urlString)"
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        print("[Canvas API] Verifying connection to: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server."
                    completion(false)
                    return
                }
                
                // Handle HTTP errors with specific messages
                guard (200...299).contains(httpResponse.statusCode) else {
                    switch httpResponse.statusCode {
                    case 401:
                        self.errorMessage = "Unauthorized. Please check your API key."
                    case 403:
                        self.errorMessage = "Forbidden. Your API key may not have sufficient permissions."
                    case 404:
                        self.errorMessage = "API endpoint not found. Please check your Canvas URL."
                    default:
                        let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(no response body)"
                        self.errorMessage = "API Error (\(httpResponse.statusCode)): \(body.prefix(100))"
                    }
                    print("[Canvas API] Connection test failed with status: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
                
                // Connection successful
                print("[Canvas API] Connection test successful")
                completion(true)
            }
        }.resume()
    }
    
    // Wrapper function to try both endpoints
    private func fetchWithEndpoint(_ endpoint: String, completion: @escaping (Bool) -> Void) {
        fetchAllCourses(endpoint: endpoint) { success in
            if success {
                completion(true)
            } else if endpoint == "/api/v1/users/self/courses" {
                // If the first endpoint fails, try alternative endpoints
                self.fetchAllCourses(endpoint: "/api/v1/courses") { success in
                    if success {
                        completion(true)
                    } else {
                        // Try one more common endpoint pattern used by some universities
                        self.fetchAllCourses(endpoint: "/api/v1/courses?enrollment_state=active") { success in
                            completion(success)
                        }
                    }
                }
            } else {
                completion(false)
            }
        }
    }
    
    // Fetch all courses with pagination
    private func fetchAllCourses(endpoint: String, completion: @escaping (Bool) -> Void) {
        // Build URL - ensure we're following the pattern from the working React implementation
        let baseURL = "\(effectiveCanvasURL)\(endpoint)"
        
        // Looking at the React implementation, use a simpler approach first
        let urlString = "\(baseURL)?per_page=100"
        
        print("[Canvas API] Requesting courses from: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid Canvas URL: \(urlString)"
            completion(false)
            return
        }
        
        fetchCoursesPage(url: url) { success in
            completion(success)
        }
    }
    
    // Recursively fetch course pages
    private func fetchCoursesPage(url: URL, completion: @escaping (Bool) -> Void) {
        // Create a proper request following the React Native implementation
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Don't set Content-Type for GET requests as it's not needed and
        // could cause issues with some Canvas implementations
        
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        
        print("[Canvas API] Making request to: \(url.absoluteString)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Capture the values we need before dispatching to main thread
            let errorToReport = error
            let responseToUse = response
            let dataToUse = data
            
            DispatchQueue.main.async {
                if let error = errorToReport {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    print("[Canvas API] Network error: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = responseToUse as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server."
                    print("[Canvas API] Invalid response type")
                    completion(false)
                    return
                }
                
                print("[Canvas API] Response status code: \(httpResponse.statusCode)")
                
                // Handle HTTP errors with specific messages
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = dataToUse.flatMap { String(data: $0, encoding: .utf8) } ?? "(no response body)"
                    switch httpResponse.statusCode {
                    case 401:
                        self.errorMessage = "Unauthorized. Please check your API key."
                    case 403:
                        self.errorMessage = "Forbidden. Your API key may not have sufficient permissions."
                    case 404:
                        self.errorMessage = "Not Found. The API endpoint doesn't exist."
                    default:
                        self.errorMessage = "API Error (\(httpResponse.statusCode)): \(body.prefix(200))"
                    }
                    print("[Canvas API] Error response: \(body)")
                    completion(false)
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    self.errorMessage = "No data returned from Canvas."
                    print("[Canvas API] Empty data received")
                    completion(false)
                    return
                }
                
                // Following the React Native implementation, try to decode the JSON
                do {
                    let json = try JSONSerialization.jsonObject(with: data)
                    
                    // Print for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        let previewLength = min(200, jsonString.count)
                        let preview = String(jsonString.prefix(previewLength))
                        print("[Canvas API] Response preview: \(preview)...")
                    }
                    
                    // Try to decode as array of courses first
                    if let coursesArray = json as? [[String: Any]] {
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: coursesArray)
                            let decodedCourses = try JSONDecoder().decode([CanvasCourse].self, from: jsonData)
                            self.courses.append(contentsOf: decodedCourses)
                            
                            // Check for pagination
                            if let linkHeader = httpResponse.allHeaderFields["Link"] as? String,
                               let nextPageURL = self.extractNextPageURL(from: linkHeader) {
                                self.fetchCoursesPage(url: nextPageURL) { success in
                                    completion(success)
                                }
                                return
                            }
                            
                            print("[Canvas API] Successfully loaded \(self.courses.count) courses")
                            completion(true)
                            return
                        } catch {
                            print("[Canvas API] Failed to decode courses array: \(error)")
                            // Continue to try other formats
                        }
                    }
                    
                    // If the above fails, try as a dictionary with a courses key
                    if let coursesDict = json as? [String: Any], 
                       let coursesArray = coursesDict["courses"] as? [[String: Any]] {
                        do {
                            let jsonData = try JSONSerialization.data(withJSONObject: coursesArray)
                            let decodedCourses = try JSONDecoder().decode([CanvasCourse].self, from: jsonData)
                            self.courses.append(contentsOf: decodedCourses)
                            print("[Canvas API] Successfully loaded \(decodedCourses.count) courses from nested data")
                            completion(true)
                            return
                        } catch {
                            print("[Canvas API] Failed to decode nested courses: \(error)")
                        }
                    }
                    
                    // If we got here, we couldn't decode in a familiar format
                    // IMPORTANT: React Native implemented a more flexible parsing approach
                    // Let's try a more manual approach for USyd's API
                    if let jsonDict = json as? [String: Any] {
                        print("[Canvas API] Available JSON keys: \(jsonDict.keys.joined(separator: ", "))")
                        
                        // Extract courses data from any potential structure
                        let possibleCourseArrays = self.findCoursesArrayInJson(jsonDict)
                        if !possibleCourseArrays.isEmpty {
                            let coursesArray = possibleCourseArrays[0] // Use the first candidate
                            do {
                                // Create more flexible course objects
                                var simplifiedCourses: [CanvasCourse] = []
                                
                                for courseDict in coursesArray {
                                    if let id = courseDict["id"] as? Int,
                                       let name = courseDict["name"] as? String {
                                        // Create a minimal course object with just required fields
                                        let course = CanvasCourse(
                                            id: id,
                                            name: name,
                                            enrollments: nil,
                                            start_at: courseDict["start_at"] as? String,
                                            end_at: courseDict["end_at"] as? String
                                        )
                                        simplifiedCourses.append(course)
                                    }
                                }
                                
                                if !simplifiedCourses.isEmpty {
                                    self.courses.append(contentsOf: simplifiedCourses)
                                    print("[Canvas API] Manually extracted \(simplifiedCourses.count) courses")
                                    completion(true)
                                    return
                                }
                            } catch {
                                print("[Canvas API] Failed during manual course extraction: \(error)")
                            }
                        }
                    }
                    
                    // If all attempts failed
                    self.errorMessage = "Unable to parse Canvas data. The format is unexpected."
                    completion(false)
                } catch {
                    print("[Canvas API] JSON parsing error: \(error)")
                    self.errorMessage = "Failed to decode Canvas data: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Extract next page URL from Link header
    private func extractNextPageURL(from linkHeader: String) -> URL? {
        // Link header format: <url>; rel="next", <url>; rel="prev"
        let links = linkHeader.components(separatedBy: ",")
        
        for link in links {
            let components = link.components(separatedBy: ";")
            if components.count >= 2 {
                let urlString = components[0].trimmingCharacters(in: CharacterSet(charactersIn: " <>"))
                let rel = components[1].trimmingCharacters(in: .whitespaces)
                
                if rel == "rel=\"next\"", let url = URL(string: urlString) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    // Helper method to recursively search for course arrays in JSON
    private func findCoursesArrayInJson(_ json: [String: Any]) -> [[[String: Any]]] {
        var results: [[[String: Any]]] = []
        
        // Check if this object has any arrays that look like courses
        for (key, value) in json {
            // If we found an array, check if it looks like courses
            if let array = value as? [[String: Any]], !array.isEmpty {
                // Check if the first item has id and name fields
                if let firstItem = array.first, 
                   (firstItem["id"] != nil || firstItem["ID"] != nil) && 
                   (firstItem["name"] != nil || firstItem["NAME"] != nil) {
                    results.append(array)
                }
            }
            
            // Check nested dictionaries
            if let nestedDict = value as? [String: Any] {
                let nestedResults = findCoursesArrayInJson(nestedDict)
                results.append(contentsOf: nestedResults)
            }
        }
        
        return results
    }
    
    // Process the fetched courses (apply filters and fetch assignments)
    private func processFetchedCourses() {
        // First filter to get all student courses that are active
        let studentCourses = self.courses.filter { course in
                        guard let enrollments = course.enrollments else { return false }
            return enrollments.contains(where: { $0.type == "student" })
        }
        
        // Then apply date filter if enabled
        let filteredCourses = self.showOnlyCurrentCourses 
            ? studentCourses.filter { $0.isCurrent } 
            : studentCourses
        
        self.courses = filteredCourses
        
        if !filteredCourses.isEmpty {
                        self.isApiKeyConnected = true
            self.saveAPIKeyToKeychain()
            
            // Fetch assignments for each course
            self.fetchAssignmentsForAllCourses()
                    } else {
                        self.isLoading = false
            self.saveCanvasData()
        }
    }
    
    // Fetch assignments for all courses
    func fetchAssignmentsForAllCourses() {
        guard !courses.isEmpty else {
            isLoading = false
            return
        }
        
        // Reset loading state when starting a new full fetch
        isLoading = true
        
        // Create a group to track all assignment fetch operations
        let group = DispatchGroup()
        
        for course in courses {
            group.enter()
            fetchingAssignments.insert(course.id)
            fetchAssignmentsForCourse(course.id) {
                self.fetchingAssignments.remove(course.id)
                group.leave()
            }
        }
        
        // When all assignments are fetched, update loading state
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.saveCanvasData()
        }
        
        group.notify(queue: .main, work: workItem)
    }

    func fetchAssignmentsForCourse(_ courseID: Int, completion: @escaping () -> Void = {}) {
        // Following the React Native implementation approach
        let urlString = "\(effectiveCanvasURL)/api/v1/courses/\(courseID)/assignments"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid assignments URL for course \(courseID)"
            completion()
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        print("[Canvas API] Fetching assignments for course \(courseID)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Capture the values we need before dispatching to main thread
            let errorToReport = error
            let responseToUse = response
            let dataToUse = data
            
            DispatchQueue.main.async {
                if let error = errorToReport {
                    self.errorMessage = "Error fetching assignments: \(error.localizedDescription)"
                    completion()
                    return
                }
                
                guard let httpResponse = responseToUse as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server."
                    completion()
                    return
                }
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = dataToUse.flatMap { String(data: $0, encoding: .utf8) } ?? "(no response body)"
                    self.errorMessage = "API Error (\(httpResponse.statusCode)): \(body.prefix(100))"
                    print("[Canvas API] Assignment fetch error: \(body)")
                    completion()
                    return
                }
                
                guard let data = dataToUse, !data.isEmpty else {
                    self.errorMessage = "No assignment data returned for course \(courseID)"
                    completion()
                    return
                }
                
                do {
                    // First try standard decoding
                    if let assignments = try? JSONDecoder().decode([CanvasAssignment].self, from: data) {
                        self.assignmentsByCourseId[courseID] = assignments
                        completion()
                        return
                    }
                    
                    // If that fails, try manual parsing of the JSON
                    let json = try JSONSerialization.jsonObject(with: data)
                    
                    if let assignmentsArray = json as? [[String: Any]] {
                        var parsedAssignments: [CanvasAssignment] = []
                        
                        for assignmentDict in assignmentsArray {
                            if let id = assignmentDict["id"] as? Int,
                               let name = assignmentDict["name"] as? String {
                                // Create a minimal valid assignment
                                let assignment = CanvasAssignment(
                                    id: id,
                                    name: name,
                                    due_at: assignmentDict["due_at"] as? String,
                                    submission_types: assignmentDict["submission_types"] as? [String],
                                    has_submitted_submissions: assignmentDict["has_submitted_submissions"] as? Bool,
                                    html_url: assignmentDict["html_url"] as? String
                                )
                                parsedAssignments.append(assignment)
                            }
                        }
                        
                        if !parsedAssignments.isEmpty {
                            self.assignmentsByCourseId[courseID] = parsedAssignments
                            completion()
                            return
                        }
                    }
                    
                    // If we get here, we couldn't parse the assignments
                    self.errorMessage = "Could not parse assignments data for course \(courseID)"
                    completion()
                } catch {
                    print("[Canvas API] Assignment JSON parsing error: \(error)")
                    self.errorMessage = "Failed to decode assignments: \(error.localizedDescription)"
                    completion()
                }
            }
        }.resume()
    }
    
    // Computed property to get filtered assignments based on type selection
    func filteredAssignments(for courseId: Int) -> [CanvasAssignment] {
        let assignments = assignmentsByCourseId[courseId] ?? []
        
        if let type = selectedAssignmentType {
            return assignments.filter { $0.assignmentType == type }
        }
        
        return assignments
    }
}

// MARK: - Canvas API Models
struct CanvasCourse: Codable, Identifiable {
    struct Enrollment: Codable {
        let type: String?
        let enrollment_state: String?
        
        enum CodingKeys: String, CodingKey {
            case type, enrollment_state
            // Handle alternate keys sometimes used
            case role = "role"
            case state = "state"
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            // Try primary keys first
            if let typeValue = try? container.decode(String.self, forKey: .type) {
                type = typeValue
            } else if let roleValue = try? container.decode(String.self, forKey: .role) {
                // Some Canvas instances use "role" instead of "type"
                type = roleValue
            } else {
                type = nil
            }
            
            // Try primary keys first for state
            if let stateValue = try? container.decode(String.self, forKey: .enrollment_state) {
                enrollment_state = stateValue
            } else if let altStateValue = try? container.decode(String.self, forKey: .state) {
                // Some Canvas instances use "state" instead of "enrollment_state"
                enrollment_state = altStateValue
            } else {
                enrollment_state = nil
            }
        }
        
        // Add encode method for Encodable conformance
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(enrollment_state, forKey: .enrollment_state)
        }
    }
    
    let id: Int
    let name: String
    let enrollments: [Enrollment]?
    let start_at: String?
    let end_at: String?
    
    // Add CodingKeys to make the model more flexible
    enum CodingKeys: String, CodingKey {
        case id, name, enrollments, start_at, end_at
    }
    
    // Alternative keys for decoding only
    private enum AlternativeKeys: String, CodingKey {
        case course_id
        case course_name = "course_name"
        case title = "title"
        case start_date = "start_date"
        case end_date = "end_date"
    }
    
    // Custom initializer to handle potential missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alternativeContainer = try? decoder.container(keyedBy: AlternativeKeys.self)
        
        // Try to decode id using multiple potential keys
        if let idValue = try? container.decode(Int.self, forKey: .id) {
            id = idValue
        } else if let courseIdValue = try? alternativeContainer?.decode(Int.self, forKey: .course_id) {
            id = courseIdValue
        } else {
            // This is required, so throw if not found
            throw DecodingError.valueNotFound(Int.self, DecodingError.Context(
                codingPath: [CodingKeys.id], 
                debugDescription: "Course ID not found under any expected key"))
        }
        
        // Try to decode name using multiple potential keys
        if let nameValue = try? container.decode(String.self, forKey: .name) {
            name = nameValue
        } else if let courseNameValue = try? alternativeContainer?.decode(String.self, forKey: .course_name) {
            name = courseNameValue
        } else if let titleValue = try? alternativeContainer?.decode(String.self, forKey: .title) {
            name = titleValue
        } else {
            // This is required, so throw if not found
            throw DecodingError.valueNotFound(String.self, DecodingError.Context(
                codingPath: [CodingKeys.name], 
                debugDescription: "Course name not found under any expected key"))
        }
        
        // Handle optional fields that might be named differently in some Canvas instances
        enrollments = try? container.decode([Enrollment]?.self, forKey: .enrollments)
        
        // Try different date field names
        if let startDate = try? container.decode(String?.self, forKey: .start_at) {
            start_at = startDate
        } else if let altStartDate = try? alternativeContainer?.decode(String?.self, forKey: .start_date) {
            start_at = altStartDate
        } else {
            start_at = nil
        }
        
        if let endDate = try? container.decode(String?.self, forKey: .end_at) {
            end_at = endDate
        } else if let altEndDate = try? alternativeContainer?.decode(String?.self, forKey: .end_date) {
            end_at = altEndDate
        } else {
            end_at = nil
        }
    }
    
    // Add encode method for Encodable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(enrollments, forKey: .enrollments)
        try container.encode(start_at, forKey: .start_at)
        try container.encode(end_at, forKey: .end_at)
    }
    
    init(id: Int, name: String, enrollments: [Enrollment]?, start_at: String?, end_at: String?) {
        self.id = id
        self.name = name
        self.enrollments = enrollments
        self.start_at = start_at
        self.end_at = end_at
    }
    
    var isCurrent: Bool {
        guard let start = start_at, let end = end_at else { 
            // If dates are not available, check for active enrollments
            guard let enrolls = enrollments else { return false }
            return enrolls.contains(where: { $0.enrollment_state == "active" })
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Try with fractional seconds first, then fall back to without if parsing fails
        if let startDate = formatter.date(from: start),
           let endDate = formatter.date(from: end) {
            let currentDate = Date()
            return currentDate >= startDate && currentDate <= endDate
        } else {
            // Try again without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let startDate = formatter.date(from: start),
               let endDate = formatter.date(from: end) {
                let currentDate = Date()
                return currentDate >= startDate && currentDate <= endDate
            }
        }
        
        // If date parsing fails, fall back to enrollment status
        guard let enrolls = enrollments else { return false }
        return enrolls.contains(where: { $0.enrollment_state == "active" })
    }
}

struct CanvasAssignment: Codable, Identifiable {
    let id: Int
    let name: String
    let due_at: String?
    let submission_types: [String]?
    let has_submitted_submissions: Bool?
    let html_url: String?
    
    // Add more flexible coding keys
    enum CodingKeys: String, CodingKey {
        case id, name, due_at, submission_types, has_submitted_submissions, html_url
    }
    
    // Alternative keys for decoding only
    private enum AlternativeKeys: String, CodingKey {
        case assignment_id = "assignment_id"
        case title = "title"
        case due_date = "due_date"
        case submit_types = "submit_types"
        case submitted = "submitted"
        case url = "url"
    }
    
    // Custom initializer to handle variations in field names
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let alternativeContainer = try? decoder.container(keyedBy: AlternativeKeys.self)
        
        // Try different ID keys
        if let idValue = try? container.decode(Int.self, forKey: .id) {
            id = idValue
        } else if let assignmentId = try? alternativeContainer?.decode(Int.self, forKey: .assignment_id) {
            id = assignmentId
        } else {
            throw DecodingError.valueNotFound(Int.self, DecodingError.Context(
                codingPath: [CodingKeys.id], 
                debugDescription: "Assignment ID not found under any expected key"))
        }
        
        // Try different name keys
        if let nameValue = try? container.decode(String.self, forKey: .name) {
            name = nameValue
        } else if let titleValue = try? alternativeContainer?.decode(String.self, forKey: .title) {
            name = titleValue
        } else {
            throw DecodingError.valueNotFound(String.self, DecodingError.Context(
                codingPath: [CodingKeys.name], 
                debugDescription: "Assignment name not found under any expected key"))
        }
        
        // Try different due date keys
        if let dueAtValue = try? container.decode(String?.self, forKey: .due_at) {
            due_at = dueAtValue
        } else if let dueDateValue = try? alternativeContainer?.decode(String?.self, forKey: .due_date) {
            due_at = dueDateValue
        } else {
            due_at = nil
        }
        
        // Try different submission types keys
        if let submissionTypesValue = try? container.decode([String]?.self, forKey: .submission_types) {
            submission_types = submissionTypesValue
        } else if let submitTypesValue = try? alternativeContainer?.decode([String]?.self, forKey: .submit_types) {
            submission_types = submitTypesValue
        } else {
            submission_types = nil
        }
        
        // Try different submission status keys
        if let submittedValue = try? container.decode(Bool?.self, forKey: .has_submitted_submissions) {
            has_submitted_submissions = submittedValue
        } else if let altSubmittedValue = try? alternativeContainer?.decode(Bool?.self, forKey: .submitted) {
            has_submitted_submissions = altSubmittedValue
        } else {
            has_submitted_submissions = nil
        }
        
        // Try different URL keys
        if let htmlUrlValue = try? container.decode(String?.self, forKey: .html_url) {
            html_url = htmlUrlValue
        } else if let urlValue = try? alternativeContainer?.decode(String?.self, forKey: .url) {
            html_url = urlValue
        } else {
            html_url = nil
        }
    }
    
    // Add encode method for Encodable conformance
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(due_at, forKey: .due_at)
        try container.encode(submission_types, forKey: .submission_types)
        try container.encode(has_submitted_submissions, forKey: .has_submitted_submissions)
        try container.encode(html_url, forKey: .html_url)
    }
    
    // Existing initializer
    init(id: Int, name: String, due_at: String?, submission_types: [String]?, has_submitted_submissions: Bool?, html_url: String?) {
        self.id = id
        self.name = name
        self.due_at = due_at
        self.submission_types = submission_types
        self.has_submitted_submissions = has_submitted_submissions
        self.html_url = html_url
    }
    
    // Computed properties for UI display
    var formattedDueDate: String {
        guard let dueAtString = due_at else { return "No due date" }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let dueDate = formatter.date(from: dueAtString) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "d MMM 'at' HH:mm"
            return "Due: \(dateFormatter.string(from: dueDate))"
        } else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let dueDate = formatter.date(from: dueAtString) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "d MMM 'at' HH:mm"
                return "Due: \(dateFormatter.string(from: dueDate))"
            }
        }
        
        return "Due date unavailable"
    }
    
    var isDueToday: Bool {
        guard let dueAtString = due_at else { return false }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let dueDate = formatter.date(from: dueAtString) {
            return Calendar.current.isDateInToday(dueDate)
        } else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let dueDate = formatter.date(from: dueAtString) {
                return Calendar.current.isDateInToday(dueDate)
            }
        }
        
        return false
    }
    
    var assignmentType: String {
        if let types = submission_types, !types.isEmpty {
            if types.contains("online_upload") || types.contains("online_text_entry") {
                return "Assignment"
            } else if types.contains("online_quiz") {
                return "Quiz"
            } else if types.contains("discussion_topic") {
                return "Discussion"
            }
        }
        return "Assignment"
    }
    
    var submissionStatus: (String, Color) {
        if let submitted = has_submitted_submissions {
            return submitted ? ("Submitted", Color.green) : ("NOT SUBMITTED", Color(hex: "b892ff"))
        }
        return ("Unknown", Color.gray)
    }
}

// Helper extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct CanvasIntegrationView: View {
    // Use StateObject for the ViewModel to persist between view lifecycles
    @StateObject private var viewModel = CanvasIntegrationViewModel()
    
    // UI state
    @State private var showingApiGuide: Bool = false
    @State private var showingUniversityPicker: Bool = false // For modal picker
    @State private var showingCourseFilterMenu: Bool = false // For courses filter
    @State private var showingTypeFilterMenu: Bool = false
    
    // Theme properties
    var isDarkMode: Bool = false
    let themeColor = Color.purple

    var body: some View {
        VStack(spacing: 0) {
            // Title section
            Text("Canvas Integration")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(themeColor)
                .foregroundColor(.white)
            // Canvas tab shell: just university picker, API key, and placeholder
            apiSetupView
            Spacer()
            
            if viewModel.courses.isEmpty && !viewModel.isLoading {
            VStack {
                Image(systemName: "rectangle.stack.badge.person.crop")
                    .font(.system(size: 48))
                    .foregroundColor(.gray.opacity(0.4))
                Text("Canvas LMS integration will appear here.")
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            Spacer()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
        // API Key Guide Modal
        .sheet(isPresented: $showingApiGuide) {
            apiGuideModal
        }
        // Keep university picker sheet for UI
        .sheet(isPresented: $showingUniversityPicker) {
            universityPickerSheet
        }
    }
    
    // MARK: - Subviews
    
    private var apiGuideModal: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with close button
                    HStack {
                        Text("How to Get Your Canvas API Key")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: { showingApiGuide = false }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(themeColor)
                                .padding(8)
                        }
                        .accessibilityLabel("Close")
                    }
                    .padding(.top, 10)

                    // Step 1
                    HStack(alignment: .top, spacing: 12) {
                        stepNumberCircle(1)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Go to Canvas Settings")
                                .font(.headline)
                            Text("Visit your Canvas profile settings page")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button(action: {
                                let urlString = viewModel.isCustomUniversitySelected ? viewModel.customUniversityURL : viewModel.selectedUniversity.url
                                if let url = URL(string: urlString + "/profile/settings") {
                                    UIApplication.shared.open(url)
                                }
                            }) {
                                Text("Open Canvas Settings")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 16)
                                    .background(themeColor)
                                    .cornerRadius(8)
                            }
                        }
                    }

                    // Step 2
                    HStack(alignment: .top, spacing: 12) {
                        stepNumberCircle(2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Find Approved Integrations")
                                .font(.headline)
                            Text("Scroll down to the \"Approved Integrations\" section")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Step 3
                    HStack(alignment: .top, spacing: 12) {
                        stepNumberCircle(3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Generate New Token")
                                .font(.headline)
                            Text("Click the \"+ New Access Token\" button and generate a new token")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Step 4
                    HStack(alignment: .top, spacing: 12) {
                        stepNumberCircle(4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Copy and Paste")
                                .font(.headline)
                            Text("Copy the generated token and paste it into the API key field in the app")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Note
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        Text("Note: Make sure to copy your token immediately after generating it, as you won't be able to see it again!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(24)
            }
            .navigationBarHidden(true)
        }
    }

    private func stepNumberCircle(_ number: Int) -> some View {
        ZStack {
            Circle()
                .fill(themeColor)
                .frame(width: 32, height: 32)
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.top, 2)
    }

    private var apiSetupView: some View {
        VStack(spacing: 20) {
            // University Selection Dropdown (only if not connected)
            if !viewModel.isApiKeyConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("University")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Picker("University", selection: $viewModel.selectedUniversity) {
                        ForEach(UNIVERSITIES) { university in
                            Text(university.name).tag(university)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // Custom University Fields (Conditional, only if not connected)
            if viewModel.isCustomUniversitySelected && !viewModel.isApiKeyConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom University Name")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Enter University Name", text: $viewModel.customUniversityName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                    Text("Custom University URL")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Enter Canvas URL", text: $viewModel.customUniversityURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            
            // API Key Input (only if not connected)
            if !viewModel.isApiKeyConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    SecureField("Your Canvas API Key", text: $viewModel.apiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    Button("Where do I find this?") {
                        showingApiGuide = true
                    }
                    .font(.footnote)
                    .foregroundColor(themeColor)
                    .padding(.top, 2)
                    
                    Button(action: {
                        viewModel.fetchCanvasData()
                    }) {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Fetch Canvas Data")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 8)
                    .background(themeColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(viewModel.apiKey.isEmpty || viewModel.effectiveCanvasURL.isEmpty || viewModel.isLoading)
                }
            } else {
                // Canvas Integration Bar when connected
                HStack {
                    Text("Canvas Integration Connected")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        viewModel.clearSavedData()
                    }) {
                        Text("Disconnect")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.bottom, 8)
                
                // Top filter pills
                HStack(spacing: 16) {
                    // Course filter
                    FilterPillButton(
                        title: viewModel.selectedCourseId == nil ? "All Courses" : viewModel.courses.first(where: { $0.id == viewModel.selectedCourseId })?.name ?? "Course",
                        isActive: true
                    ) {
                        showingCourseFilterMenu = true
                    }
                    .actionSheet(isPresented: $showingCourseFilterMenu) {
                        var buttons: [ActionSheet.Button] = [
                            .default(Text("All Courses")) { viewModel.selectedCourseId = nil }
                        ]
                        
                        // Add buttons for each course
                        for course in viewModel.courses {
                            buttons.append(.default(Text(course.name)) { 
                                viewModel.selectedCourseId = course.id 
                            })
                        }
                        
                        buttons.append(.cancel())
                        
                        return ActionSheet(
                            title: Text("Filter by Course"),
                            message: nil,
                            buttons: buttons
                        )
                    }
                    
                    // Assignment type filter
                    FilterPillButton(
                        title: viewModel.selectedAssignmentType == nil ? "All Types" : viewModel.selectedAssignmentType!,
                        isActive: true
                    ) {
                        showingTypeFilterMenu = true
                    }
                    .actionSheet(isPresented: $showingTypeFilterMenu) {
                        var buttons: [ActionSheet.Button] = [
                            .default(Text("All Types")) { viewModel.selectedAssignmentType = nil }
                        ]
                        
                        // Add buttons for each assignment type
                        for type in viewModel.assignmentTypes {
                            buttons.append(.default(Text(type)) { 
                                viewModel.selectedAssignmentType = type 
                            })
                        }
                        
                        buttons.append(.cancel())
                        
                        return ActionSheet(
                            title: Text("Filter by Assignment Type"),
                            message: nil,
                            buttons: buttons
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Show only current courses toggle (moved to settings)
                if viewModel.isLoading {
                    ProgressView("Loading your Canvas data...")
                        .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                        .padding()
                } else if viewModel.courses.isEmpty {
                    Text("No courses found")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    // Course list
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredCourses) { course in
                                CourseCardView(
                                    course: course, 
                                    assignments: viewModel.assignmentsByCourseId[course.id] ?? [], 
                                    isLoading: viewModel.fetchingAssignments.contains(course.id),
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                }
                
                // Refresh button at bottom
                Button(action: {
                    viewModel.fetchCanvasData()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh Data")
                    }
                    .foregroundColor(themeColor)
                    .padding(.vertical, 10)
                }
                .disabled(viewModel.isLoading)
            }

            // Display error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
        }
        .padding()
    }

    // Filter pill button
    struct FilterPillButton: View {
        let title: String
        let isActive: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 24)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
            }
        }
    }

    // University Picker Sheet
    private var universityPickerSheet: some View {
        NavigationView {
            List {
                ForEach(UNIVERSITIES) { university in
                    Button(action: {
                        viewModel.selectedUniversity = university
                        showingUniversityPicker = false
                    }) {
                        HStack {
                            Text(university.name)
                            Spacer()
                            if university.id == viewModel.selectedUniversity.id && !viewModel.isCustomUniversitySelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeColor)
                            } else if university.url.isEmpty && viewModel.isCustomUniversitySelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select University")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                showingUniversityPicker = false
            })
        }
    }
}

// MARK: - Course Card View
struct CourseCardView: View {
    let course: CanvasCourse
    let assignments: [CanvasAssignment]
    let isLoading: Bool
    @ObservedObject var viewModel: CanvasIntegrationViewModel
    
    private let themeColor = Color(hex: "b892ff") // Purple color from the image
    private let lightThemeColor = Color(hex: "e0cfff") // Lighter purple for backgrounds
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Course Header
            Text(course.name)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeColor)
                .cornerRadius(16)
            
            // Assignments
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeColor))
                    Spacer()
                }
                .padding(.vertical, 12)
            } else if assignments.isEmpty {
                Text("No assignments found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.filteredAssignments(for: course.id)) { assignment in
                    AssignmentCardView(assignment: assignment)
                        .padding(.bottom, 16)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Assignment Card View
struct AssignmentCardView: View {
    let assignment: CanvasAssignment
    
    private let themeColor = Color(hex: "b892ff") // Purple color
    private let lightThemeColor = Color(hex: "e0cfff") // Lighter purple
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Assignment name
            Text(assignment.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Tags row
            HStack(spacing: 12) {
                // Assignment type tag
                Text(assignment.assignmentType)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(themeColor)
                    .cornerRadius(16)
                
                // Submission status tag
                let status = assignment.submissionStatus
                Text(status.0)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(status.0 == "Submitted" ? .white : .white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(status.0 == "Submitted" ? Color.green : themeColor)
                    .cornerRadius(16)
            }
            
            // Due date row
            HStack {
                Text(assignment.formattedDueDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if assignment.isDueToday {
                    Text("Due today")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(themeColor)
                        .cornerRadius(16)
                }
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    if let urlString = assignment.html_url, let url = URL(string: urlString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("VIEW IN CANVAS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(themeColor)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(lightThemeColor)
                        .cornerRadius(24)
                }
                
                Button(action: {
                    // Add to list functionality would go here
                }) {
                    Text("ADD TO LIST")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(themeColor)
                        .cornerRadius(24)
                }
            }
        }
    }
}
