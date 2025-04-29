//
//  CanvasIntegrationViewModel.swift
//  Canvo
//
//  Created by Nick on 5/19/2024.
//

import Foundation
import SwiftUI
import Security

@MainActor
class CanvasIntegrationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var apiKey: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var courses: [CanvasKitCourse] = []
    @Published var assignmentsByCourseId: [Int: [CanvasKitAssignment]] = [:]
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
    
    // Canvas API client
    private var canvasKit: CanvasKit?
    
    // MARK: - Computed Properties
    
    // Computed property to get filtered courses based on selection
    var filteredCourses: [CanvasKitCourse] {
        if let courseId = selectedCourseId {
            return courses.filter { $0.id == courseId }
        }
        return courses
    }
    
    // Computed property for the selected university
    var selectedUniversity: University {
        get {
            if let university = UNIVERSITIES.first(where: { $0.name == selectedUniversityName }) {
                print("DEBUG: Currently selected university: \(university.name) with URL: \(university.url)")
                return university
            }
            print("DEBUG: Defaulting to first university: \(UNIVERSITIES[0].name)")
            return UNIVERSITIES[0]
        }
        set {
            print("DEBUG: Changing university from \(selectedUniversityName) to \(newValue.name)")
            print("DEBUG: New URL will be: \(newValue.url)")
            selectedUniversityName = newValue.name
            isCustomUniversitySelected = (newValue.name == "Custom University")
            if !isCustomUniversitySelected {
                customUniversityName = ""
                customUniversityURL = ""
            }
            // Clear any previous error message when university changes
            errorMessage = nil
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
        
        print("DEBUG: Effective Canvas URL being used: \(cleanURL)")
        return cleanURL
    }
    
    // MARK: - Initialization
    
    init() {
        loadSavedData()
    }
    
    // MARK: - Data Persistence
    
    // Load saved API key from keychain and other state from UserDefaults
    func loadSavedData() {
        if let savedApiKey = loadAPIKeyFromKeychain(), !savedApiKey.isEmpty {
            self.apiKey = savedApiKey
            self.isApiKeyConnected = true
            
            // Load courses and assignments from UserDefaults
            if let coursesData = UserDefaults.standard.data(forKey: "savedCourses"),
               let savedCourses = try? JSONDecoder().decode([CanvasKitCourse].self, from: coursesData) {
                self.courses = savedCourses
            }
            
            if let assignmentsData = UserDefaults.standard.data(forKey: "savedAssignmentsByCourseId"),
               let savedAssignments = try? JSONDecoder().decode([Int: [CanvasKitAssignment]].self, from: assignmentsData) {
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
    
    // MARK: - Canvas API Integration
    
    // Fetch Canvas data using CanvasKit
    func fetchCanvasData() {
        guard !apiKey.isEmpty, !effectiveCanvasURL.isEmpty else { 
            self.errorMessage = "Please enter your Canvas API key and select a university."
            return 
        }
        
        print("DEBUG: Starting Canvas data fetch with URL: \(effectiveCanvasURL)")
        print("DEBUG: API Key length: \(apiKey.count) characters")
        
        isLoading = true
        errorMessage = nil
        courses = [] // Clear existing courses before fetching
        
        // Initialize CanvasKit with the current URL and API key
        canvasKit = CanvasKit(baseURL: effectiveCanvasURL, apiKey: apiKey)
        
        // First verify the connection using traditional callbacks
        canvasKit?.verifyConnection { [weak self] success, errorMsg in
            // Jump back to main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    print("DEBUG: Connection verified successfully, fetching courses...")
                    // If connection is successful, fetch courses
                    self.fetchCourses()
                } else {
                    print("DEBUG: Connection failed with error: \(errorMsg ?? "Unknown error")")
                    self.isLoading = false
                    self.errorMessage = errorMsg ?? "Could not connect to Canvas. Please verify your API key and Canvas URL."
                }
            }
        }
    }
    
    // Fetch courses using CanvasKit
    private func fetchCourses() {
        print("DEBUG: Fetching courses from \(effectiveCanvasURL)")
        
        canvasKit?.fetchCourses { [weak self] result in
            // Jump back to main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let fetchedCourses):
                    print("DEBUG: Successfully fetched \(fetchedCourses.count) courses")
                    // Process fetched courses in a thread-safe manner
                    self.processFetchedCourses(fetchedCourses)
                case .failure(let error):
                    print("DEBUG: Failed to fetch courses with error: \(error)")
                    if let decodingError = error as? DecodingError {
                        print("DEBUG: Decoding error details: \(decodingError)")
                        switch decodingError {
                        case .dataCorrupted(let context):
                            print("DEBUG: Data corrupted: \(context.debugDescription)")
                        case .keyNotFound(let key, let context):
                            print("DEBUG: Key not found: \(key.stringValue) - \(context.debugDescription)")
                        case .typeMismatch(let type, let context):
                            print("DEBUG: Type mismatch: Expected \(type) - \(context.debugDescription)")
                        case .valueNotFound(let type, let context):
                            print("DEBUG: Value not found: Expected \(type) - \(context.debugDescription)")
                        @unknown default:
                            print("DEBUG: Unknown decoding error")
                        }
                    }
                    self.isLoading = false
                    self.errorMessage = "Error fetching courses: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Process fetched courses
    private func processFetchedCourses(_ fetchedCourses: [CanvasKitCourse]) {
        // Create local copies to avoid data races
        let shouldFilterToCurrent = self.showOnlyCurrentCourses
        
        print("DEBUG: Processing \(fetchedCourses.count) courses, showOnlyCurrentCourses = \(shouldFilterToCurrent)")
        
        // Debug details about the courses
        for (index, course) in fetchedCourses.enumerated() {
            print("DEBUG: Course \(index): \(course.displayName), isCurrent = \(course.isCurrent), start_at = \(course.start_at ?? "nil"), end_at = \(course.end_at ?? "nil")")
            if let enrollments = course.enrollments {
                print("DEBUG:   Enrollments: \(enrollments.count), active = \(enrollments.contains { $0.enrollment_state == "active" })")
            } else {
                print("DEBUG:   Enrollments: nil")
            }
        }
        
        // Filter courses if needed
        let filteredCourses = shouldFilterToCurrent ? 
            fetchedCourses.filter { $0.isCurrent } : 
            fetchedCourses
        
        print("DEBUG: After filtering, \(filteredCourses.count) courses remain")
        
        let sortedCourses = filteredCourses.sorted { $0.displayName < $1.displayName }
        
        // Update on main thread (we're already on main thread from fetchCourses)
        self.courses = sortedCourses
        
        // Now fetch assignments for each course
        self.fetchAssignmentsForAllCourses()
    }
    
    // Fetch assignments for all courses
    private func fetchAssignmentsForAllCourses() {
        guard !courses.isEmpty else {
            print("DEBUG: No courses available to fetch assignments for")
            self.isLoading = false
            self.isApiKeyConnected = true
            self.saveAPIKeyToKeychain()
            self.saveCanvasData()
            return
        }
        
        print("DEBUG: Starting to fetch assignments for \(courses.count) courses")
        
        // Initialize assignments dictionary
        assignmentsByCourseId = [:]
        
        // Create a dispatch group to wait for all fetches
        let dispatchGroup = DispatchGroup()
        
        // Keep track of course IDs to safely access them in the closure
        let courseIds = courses.map { $0.id }
        
        // Fetch assignments for each course
        for courseId in courseIds {
            print("DEBUG: Fetching assignments for course ID: \(courseId)")
            dispatchGroup.enter()
            
            // Mark this course as being fetched
            self.fetchingAssignments.insert(courseId)
            
            // Use traditional callback approach
            canvasKit?.fetchAssignments(forCourseId: courseId) { [weak self] result in
                // Ensure we jump to main thread for SwiftUI updates
                DispatchQueue.main.async {
                    guard let self = self else { 
                        dispatchGroup.leave()
                        return 
                    }
                    
                    switch result {
                    case .success(let assignments):
                        print("DEBUG: Successfully fetched \(assignments.count) assignments for course ID: \(courseId)")
                        self.assignmentsByCourseId[courseId] = assignments
                    case .failure(let error):
                        print("DEBUG: Failed to fetch assignments for course ID: \(courseId), error: \(error.localizedDescription)")
                        self.assignmentsByCourseId[courseId] = [] // Empty array on error
                    }
                    
                    // Remove this course from fetching list and leave dispatch group
                    self.fetchingAssignments.remove(courseId)
                    dispatchGroup.leave()
                }
            }
        }
        
        // When all fetches are complete
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            print("DEBUG: All assignment fetches complete. Got assignments for \(self.assignmentsByCourseId.count) courses")
            
            self.isLoading = false
            
            // Save connection state and data
            self.isApiKeyConnected = true
            self.saveAPIKeyToKeychain()
            self.saveCanvasData()
        }
    }
    
    // Computed property for filtered assignments based on type selection
    func filteredAssignments(for courseId: Int) -> [CanvasKitAssignment] {
        let assignments = assignmentsByCourseId[courseId] ?? []
        
        if let type = selectedAssignmentType {
            return assignments.filter { $0.assignmentType == type }
        }
        
        return assignments
    }
} 