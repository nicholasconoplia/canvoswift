//
//  CanvasIntegrationViewModel.swift
//  Canvo
//
//  Created by Nick on 5/19/2024.
//

import Foundation
import SwiftUI
import Security

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
        
        isLoading = true
        errorMessage = nil
        courses = [] // Clear existing courses before fetching
        
        // Initialize CanvasKit with the current URL and API key
        canvasKit = CanvasKit(baseURL: effectiveCanvasURL, apiKey: apiKey)
        
        // First verify the connection
        canvasKit?.verifyConnection { [weak self] success, errorMessage in
            guard let self = self else { return }
            
            if success {
                // If connection is successful, fetch courses
                self.fetchCourses()
            } else {
                self.isLoading = false
                self.errorMessage = errorMessage ?? "Could not connect to Canvas. Please verify your API key and Canvas URL."
            }
        }
    }
    
    // Fetch courses using CanvasKit
    private func fetchCourses() {
        canvasKit?.fetchCourses { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let fetchedCourses):
                // Process fetched courses
                self.processFetchedCourses(fetchedCourses)
            case .failure(let error):
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "Failed to fetch courses: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // Process the fetched courses (apply filters and fetch assignments)
    private func processFetchedCourses(_ fetchedCourses: [CanvasKitCourse]) {
        DispatchQueue.main.async {
            // First filter to get all student courses that are active
            let studentCourses = fetchedCourses.filter { course in
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
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            self.isLoading = false
            self.saveCanvasData()
        }
    }
    
    // Fetch assignments for a specific course
    func fetchAssignmentsForCourse(_ courseID: Int, completion: @escaping () -> Void = {}) {
        canvasKit?.fetchAssignments(forCourseId: courseID) { [weak self] result in
            guard let self = self else { 
                completion()
                return 
            }
            
            DispatchQueue.main.async {
                switch result {
                case .success(let assignments):
                    self.assignmentsByCourseId[courseID] = assignments
                case .failure(let error):
                    print("Failed to fetch assignments for course \(courseID): \(error.localizedDescription)")
                }
                completion()
            }
        }
    }
    
    // Computed property to get filtered assignments based on type selection
    func filteredAssignments(for courseId: Int) -> [CanvasKitAssignment] {
        let assignments = assignmentsByCourseId[courseId] ?? []
        
        if let type = selectedAssignmentType {
            return assignments.filter { $0.assignmentType == type }
        }
        
        return assignments
    }
} 