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
        
        // First verify the connection using traditional callbacks
        canvasKit?.verifyConnection { [weak self] success, errorMsg in
            // Jump back to main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if success {
                    // If connection is successful, fetch courses
                    self.fetchCourses()
                } else {
                    self.isLoading = false
                    self.errorMessage = errorMsg ?? "Could not connect to Canvas. Please verify your API key and Canvas URL."
                }
            }
        }
    }
    
    // Fetch courses using CanvasKit
    private func fetchCourses() {
        canvasKit?.fetchCourses { [weak self] result in
            // Jump back to main thread
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let fetchedCourses):
                    // Process fetched courses in a thread-safe manner
                    self.processFetchedCourses(fetchedCourses)
                case .failure(let error):
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
        
        // Filter courses if needed
        let filteredCourses = shouldFilterToCurrent ? 
            fetchedCourses.filter { $0.isCurrent } : 
            fetchedCourses
        
        let sortedCourses = filteredCourses.sorted { $0.name < $1.name }
        
        // Update on main thread (we're already on main thread from fetchCourses)
        self.courses = sortedCourses
        
        // Now fetch assignments for each course
        self.fetchAssignmentsForAllCourses()
    }
    
    // Fetch assignments for all courses
    private func fetchAssignmentsForAllCourses() {
        guard !courses.isEmpty else {
            self.isLoading = false
            self.isApiKeyConnected = true
            self.saveAPIKeyToKeychain()
            self.saveCanvasData()
            return
        }
        
        // Initialize assignments dictionary
        assignmentsByCourseId = [:]
        
        // Create a dispatch group to wait for all fetches
        let dispatchGroup = DispatchGroup()
        
        // Keep track of course IDs to safely access them in the closure
        let courseIds = courses.map { $0.id }
        
        // Fetch assignments for each course
        for courseId in courseIds {
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
                        self.assignmentsByCourseId[courseId] = assignments
                    case .failure:
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