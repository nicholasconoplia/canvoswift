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
    University(name: "Custom University", url: "") // Represents the custom option;[]
    
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
        if isCustomUniversitySelected {
            return customUniversityURL.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return selectedUniversity.url
        }
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
        guard !apiKey.isEmpty, !effectiveCanvasURL.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        courses = [] // Clear existing courses before fetching
        
        // Detailed logging
        print("[Canvas API] Starting fetch with URL: \(effectiveCanvasURL)")
        print("[Canvas API] API Key length: \(apiKey.count) characters")
        print("[Canvas API] Selected University: \(selectedUniversityName)")
        
        // Try direct endpoint for all known Canvas instances
        fetchWithEndpoint("/api/v1/users/self/courses") { success in
            if success {
                // After fetching all courses, apply filtering
                self.processFetchedCourses()
            } else {
                // If that failed, try alternative endpoint
                print("[Canvas API] First endpoint failed, trying alternative...")
                self.fetchWithEndpoint("/api/v1/courses") { success in
                    if success {
                        self.processFetchedCourses()
                    } else {
            self.isLoading = false
                        // If all attempts fail, give more specific error
                        self.errorMessage = "Could not fetch courses. Please check your Canvas URL and API key. You may need to regenerate your API key."
                    }
                }
            }
        }
    }
    
    // Wrapper function to try both endpoints
    private func fetchWithEndpoint(_ endpoint: String, completion: @escaping (Bool) -> Void) {
        fetchAllCourses(endpoint: endpoint) { success in
            completion(success)
        }
    }
    
    // Fetch all courses with pagination
    private func fetchAllCourses(endpoint: String, completion: @escaping (Bool) -> Void) {
        // Build URL with minimal parameters for maximum compatibility
        let baseURL = "\(effectiveCanvasURL)\(endpoint)"
        // Remove include[] parameters for simplicity, as they might cause issues
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
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Content-Type is generally not needed for GET requests, but keep it for now
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") 
        request.httpMethod = "GET"
        request.timeoutInterval = 30 // Increase timeout
        
        print("[Canvas API] Making request to: \(url.absoluteString)")
        print("[Canvas API] With headers: \(request.allHTTPHeaderFields ?? [:])")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    print("[Canvas API] Network error: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response from server."
                    print("[Canvas API] Invalid response type")
                    completion(false)
                    return
                }
                
                print("[Canvas API] Response status code: \(httpResponse.statusCode)")
                print("[Canvas API] Response headers: \(httpResponse.allHeaderFields)")
                
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "(no response body)"
                    // Provide more specific error based on status code
                    switch httpResponse.statusCode {
                    case 401: // Unauthorized
                        self.errorMessage = "Unauthorized (401). Please check your API key or regenerate it."
                    case 403: // Forbidden
                        self.errorMessage = "Forbidden (403). Your API key may lack permissions for this request."
                    case 404: // Not Found
                        self.errorMessage = "API endpoint not found (404). The Canvas URL or path might be incorrect."
                    default:
                        self.errorMessage = "API Error (\(httpResponse.statusCode)): \(body.prefix(200))"
                    }
                    print("[Canvas API] Error response (\(httpResponse.statusCode)): \(body)")
                    completion(false)
                    return
                }
                
                guard let data = data, !data.isEmpty else {
                    self.errorMessage = "Received empty data from Canvas."
                    print("[Canvas API] Empty data received")
                    completion(false)
                    return
                }
                
                // Print complete response data for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[Canvas API] Full response: \(jsonString)")
                }
                
                // Try multiple decoding approaches
                do {
                    // Attempt 1: Try to decode as array first
                    if let fetchedCourses = try? JSONDecoder().decode([CanvasCourse].self, from: data) {
                        print("[Canvas API] Successfully decoded \(fetchedCourses.count) courses as array")
                        self.courses.append(contentsOf: fetchedCourses)
                        // ... (pagination logic remains the same)
                        if let linkHeader = httpResponse.allHeaderFields["Link"] as? String {
                            if let nextPageURL = self.extractNextPageURL(from: linkHeader) {
                                self.fetchCoursesPage(url: nextPageURL) { success in
                                    completion(success)
                                }
                                return
                            }
                        }
                        print("[Canvas API] Completed fetching \(self.courses.count) courses")
                        completion(true)
                        return
                    }
                    
                    // Attempt 2: Try to decode as object with courses array
                    do {
                        let json = try JSONSerialization.jsonObject(with: data)
                        print("[Canvas API] JSON structure type: \(type(of: json))")
                        if let jsonObject = json as? [String: Any] {
                            print("[Canvas API] Available JSON keys: \(jsonObject.keys.joined(separator: ", "))")
                            if let coursesData = jsonObject["courses"] as? [[String: Any]],
                               let repackagedData = try? JSONSerialization.data(withJSONObject: coursesData),
                               let fetchedCourses = try? JSONDecoder().decode([CanvasCourse].self, from: repackagedData) {
                                print("[Canvas API] Successfully decoded \(fetchedCourses.count) courses from 'courses' object")
                                self.courses.append(contentsOf: fetchedCourses)
                                // Add pagination check for this format if needed based on logs
                                completion(true)
                                return
                            }
                        }
                    } catch {
                        print("[Canvas API] JSON parsing for object structure failed: \(error)")
                    }
                    
                    // If decoding fails after trying both formats
                    let preview = String(data: data, encoding: .utf8)?.prefix(500) ?? "(invalid data)"
                    print("[Canvas API] Failed to decode response with known formats. Preview: \(preview)...")
                    self.errorMessage = "Could not parse the response from Canvas. The data format might be unexpected."
                    completion(false)
                    
                } catch {
                    // This catch block might be redundant now due to the above handling,
                    // but kept as a safeguard.
                    print("[Canvas API] Unhandled decoding error: \(error)")
                    self.errorMessage = "Failed to decode courses: \(error.localizedDescription)"
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
        group.notify(queue: .main) {
            self.isLoading = false
            self.saveCanvasData()
        }
    }

    func fetchAssignmentsForCourse(_ courseID: Int, completion: @escaping () -> Void = {}) {
        let urlString = "\(effectiveCanvasURL)/api/v1/courses/\(courseID)/assignments"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid assignments URL for course \(courseID)"
            completion()
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error fetching assignments for course \(courseID): \(error.localizedDescription)"
                    completion()
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data returned for assignments in course \(courseID)"
                    completion()
                    return
                }
                do {
                    let fetchedAssignments = try JSONDecoder().decode([CanvasAssignment].self, from: data)
                    self.assignmentsByCourseId[courseID] = fetchedAssignments
                    completion()
                } catch {
                    let raw = String(data: data, encoding: .utf8) ?? "<invalid>"
                    print("[Canvas API] Raw assignments JSON for course \(courseID): \(raw)")
                    self.errorMessage = "Failed to decode assignments for course \(courseID): \(error.localizedDescription)"
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
    }
    let id: Int
    let name: String
    let enrollments: [Enrollment]?
    let start_at: String?
    let end_at: String?
    
    // Add CodingKeys to make the model more flexible
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case enrollments
        case start_at
        case end_at
    }
    
    // Custom initializer to handle potential missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        
        // Handle optional fields that might be missing in some Canvas instances
        enrollments = try? container.decode([Enrollment]?.self, forKey: .enrollments)
        start_at = try? container.decode(String?.self, forKey: .start_at)
        end_at = try? container.decode(String?.self, forKey: .end_at)
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
