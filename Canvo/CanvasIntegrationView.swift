//
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
    University(name: "Custom University", url: "") // Represents the custom option
]

struct CanvasIntegrationView: View {
    // Canvas API state
    @State private var apiKey: String = ""
    // @State private var canvasURL: String = "" // Replaced by selectedUniversity.url or customURL
    @State private var assignments: [CanvasAssignment] = []
    @State private var courses: [CanvasCourse] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // UI state
    @State private var selectedCourseFilter: String = "All Courses"
    @State private var selectedTypeFilter: String = "All Types"
    @State private var isAuthenticated: Bool = false
    @State private var showingApiGuide: Bool = false
    @State private var showingHeaderPicker: Bool = false
    @State private var selectedAssignment: CanvasAssignment? = nil
    @State private var selectedHeaderForAssignment: String = ""
    
    // University Selection State
    @State private var selectedUniversity: University = UNIVERSITIES[0] // Default to the first
    @State private var customUniversityName: String = ""
    @State private var customUniversityURL: String = ""
    @State private var isCustomUniversitySelected: Bool = false
    @State private var showingUniversityPicker: Bool = false // For modal picker
    
    // External state
    @Binding var taskLists: [TaskList]
    var onAddAssignmentToList: ((CanvasAssignment, UUID) -> Void)?
    var availableHeaders: [String] {
        taskLists.map { $0.name }
    }
    
    // Theme properties
    var isDarkMode: Bool = false
    let themeColor = Color.purple

    // Computed property for the effective Canvas URL
    private var effectiveCanvasURL: String {
        if isCustomUniversitySelected {
            return customUniversityURL.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            return selectedUniversity.url
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title section
            Text("Canvas Integration")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(themeColor)
                .foregroundColor(.white)
                
            if !isAuthenticated {
                // API key setup
                apiSetupView
            } else {
                // Main content when authenticated
                authenticatedView
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 3)
        .sheet(isPresented: $showingApiGuide) {
            apiGuideView
        }
        .sheet(isPresented: $showingHeaderPicker) {
            headerPickerSheet
        }
        // Use a sheet for the university picker for better UI on smaller screens
        .sheet(isPresented: $showingUniversityPicker) {
            universityPickerSheet
        }
        .onAppear {
            loadStoredCredentials()
        }
    }
    
    // MARK: - Subviews
    
    private var apiSetupView: some View {
        VStack(spacing: 20) {
            // University Selection Dropdown
            VStack(alignment: .leading, spacing: 6) {
                Text("University")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Use a button to trigger the modal picker
                Button(action: { showingUniversityPicker = true }) {
                    HStack {
                        Text(isCustomUniversitySelected ? customUniversityName : selectedUniversity.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }

            // Custom University Fields (Conditional)
            if isCustomUniversitySelected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom University Name")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextField("Your University Name", text: $customUniversityName)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom Canvas URL")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    TextField("https://canvas.yourschool.edu", text: $customUniversityURL)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            
            // API Key Input
            VStack(alignment: .leading, spacing: 6) {
                Text("API Key")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                SecureField("Your Canvas API Key", text: $apiKey)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            
            HStack {
                Button(action: {
                    showingApiGuide = true
                }) {
                    Text("How to get API Key?")
                        .font(.subheadline)
                        .foregroundColor(themeColor)
                }
                
                Spacer()
                
                Button(action: connectToCanvas) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("Connect")
                            .fontWeight(.semibold)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(themeColor)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(apiKey.isEmpty || effectiveCanvasURL.isEmpty || (isCustomUniversitySelected && customUniversityName.isEmpty) || isLoading)
            }
            
            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .padding()
    }

    // University Picker Sheet
    private var universityPickerSheet: some View {
        NavigationView {
            List {
                ForEach(UNIVERSITIES) { university in
                    Button(action: {
                        selectedUniversity = university
                        if university.url.isEmpty { // Custom University selected
                            isCustomUniversitySelected = true
                        } else {
                            isCustomUniversitySelected = false
                            // Reset custom fields if a predefined uni is chosen
                            customUniversityName = ""
                            customUniversityURL = ""
                        }
                        showingUniversityPicker = false
                    }) {
                        HStack {
                            Text(university.name)
                            Spacer()
                            if university.id == selectedUniversity.id && !isCustomUniversitySelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeColor)
                            } else if university.url.isEmpty && isCustomUniversitySelected {
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
    
    private var authenticatedView: some View {
        VStack(spacing: 12) {
            // Controls
            HStack {
                Button(action: fetchAssignments) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("FETCH ASSIGNMENTS")
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(themeColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
                
                Spacer()
                
                Button(action: disconnectFromCanvas) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("DISCONNECT")
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray5))
                    .foregroundColor(.red)
                    .cornerRadius(8)
                }
                .disabled(isLoading)
            }
            .padding(.horizontal)
            
            // Filters
            filtersView
                .padding(.horizontal)
            
            if isLoading {
                Spacer()
                ProgressView("Loading assignments...")
                    .padding()
                Spacer()
            } else if assignments.isEmpty {
                Spacer()
                Text("No assignments to display")
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            } else {
                // Assignment list
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(filteredAssignmentsByCourse.keys.sorted(), id: \.self) { courseId in
                            if let course = filteredAssignmentsByCourse[courseId] {
                                Section(header: courseHeaderView(courseName: course.courseName)) {
                                    ForEach(course.assignments) { assignment in
                                        assignmentRow(assignment: assignment)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
        .padding(.top)
    }
    
    private var filtersView: some View {
        HStack {
            // Course filter
            Menu {
                Button("All Courses", action: { selectedCourseFilter = "All Courses" })
                Divider()
                ForEach(courses, id: \.id) { course in
                    Button(course.courseCode ?? course.name, action: {
                        selectedCourseFilter = course.id
                    })
                }
            } label: {
                HStack {
                    Text(selectedCourseFilter == "All Courses" ? "All Courses" : (courses.first(where: { $0.id == selectedCourseFilter })?.courseCode ?? "All Courses"))
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
            
            // Type filter
            Menu {
                Button("All Types", action: { selectedTypeFilter = "All Types" })
                Divider()
                let types = Set(assignments.compactMap { $0.type }).sorted()
                ForEach(types, id: \.self) { type in
                    Button(type, action: {
                        selectedTypeFilter = type
                    })
                }
            } label: {
                HStack {
                    Text(selectedTypeFilter)
                        .foregroundColor(.primary)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    private func courseHeaderView(courseName: String) -> some View {
        Text(courseName)
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.vertical, 10)
            .padding(.horizontal)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isDarkMode ? Color(.systemGray6) : Color(.systemGray5))
    }
    
    private func assignmentRow(assignment: CanvasAssignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(assignment.name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                // Type badge
                Text(assignment.type ?? "Assignment")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(themeColor.opacity(0.2))
                    .foregroundColor(themeColor)
                    .cornerRadius(12)
                
                // Submission status
                if assignment.isSubmitted ?? false {
                    Text("Submitted")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                } else {
                    Text("NOT SUBMITTED")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(12)
                }
            }
            
            // Due date information
            if let dueDate = assignment.dueDate {
                HStack {
                    Text("Due: \(dueDate)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    if let relativeDue = assignment.relativeDue {
                        Text(relativeDue)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isDueToday(relativeDue) ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                            .foregroundColor(isDueToday(relativeDue) ? .red : .gray)
                            .cornerRadius(4)
                    }
                }
            }
            
            // Action buttons
            HStack {
                Button(action: {
                    if let url = URL(string: assignment.html_url ?? "") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.forward.app")
                        Text("VIEW IN CANVAS")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(themeColor.opacity(0.2))
                    .foregroundColor(themeColor)
                    .cornerRadius(8)
                }
                
                Spacer()
                
                Button(action: {
                    selectedAssignment = assignment
                    if !availableHeaders.isEmpty {
                        selectedHeaderForAssignment = availableHeaders[0]
                    }
                    showingHeaderPicker = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("ADD TO LIST")
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(themeColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(isDarkMode ? Color(.systemGray6) : Color.white)
        .cornerRadius(8)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        .padding(.vertical, 4)
    }
    
    private var apiGuideView: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How to Get Your Canvas API Key")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("1. Log in to your Canvas account")
                            .font(.headline)
                        Text("Go to your Canvas LMS website (e.g., \(selectedUniversity.url)) and sign in.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("2. Go to Account Settings")
                            .font(.headline)
                        Text("Click on your profile picture or name, then select 'Settings'.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("3. Find Approved Integrations")
                            .font(.headline)
                        Text("Scroll down to the 'Approved Integrations' section.")
                         // Optionally add a button to open the settings page directly
                         Button("Open Canvas Settings") {
                             if let url = URL(string: "\(effectiveCanvasURL)/profile/settings") {
                                 UIApplication.shared.open(url)
                             }
                         }
                         .buttonStyle(.bordered)
                         .tint(themeColor)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("4. Generate New Token")
                            .font(.headline)
                        Text("Click on '+ New Access Token'.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("5. Create Access Token")
                            .font(.headline)
                        Text("Enter 'Canvo App' as the purpose, and set an expiration date (optional, leaving blank means no expiry). Then click 'Generate Token'.")
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("6. Copy Your API Key")
                            .font(.headline)
                        Text("Your API access token will be displayed. Copy this token *immediately* (you won't see it again!) and paste it into the API Key field in the Canvo app.")
                    }
                }
                .padding()
            }
            .navigationBarTitle("API Key Guide", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                showingApiGuide = false
            })
        }
    }
    
    private var headerPickerSheet: some View {
        NavigationView {
            VStack {
                Text("Add assignment to list:")
                    .font(.headline)
                    .padding()
                
                if let assignment = selectedAssignment {
                    Text(assignment.name)
                        .fontWeight(.semibold)
                        .padding()
                        .multilineTextAlignment(.center)
                }
                
                List {
                    ForEach(availableHeaders, id: \.self) { header in
                        Button(action: {
                            selectedHeaderForAssignment = header
                        }) {
                            HStack {
                                Text(header)
                                Spacer()
                                if selectedHeaderForAssignment == header {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(themeColor)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Button(action: addAssignmentToList) {
                    Text("Add to List")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
                .disabled(selectedHeaderForAssignment.isEmpty || selectedAssignment == nil)
            }
            .navigationBarTitle("Choose List", displayMode: .inline)
            .navigationBarItems(trailing: Button("Cancel") {
                showingHeaderPicker = false
            })
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredAssignments: [CanvasAssignment] {
        var filtered = assignments
        
        // Apply course filter using idString
        if selectedCourseFilter != "All Courses" {
            filtered = filtered.filter { $0.course_idString == selectedCourseFilter }
        }
        
        // Apply type filter
        if selectedTypeFilter != "All Types" {
            // Basic type filtering (can be improved)
            if selectedTypeFilter == "Quiz" {
                 filtered = filtered.filter { $0.type?.lowercased().contains("quiz") ?? false }
            } else {
                 // Assume anything not a quiz is an assignment for simplicity
                 filtered = filtered.filter { !($0.type?.lowercased().contains("quiz") ?? false) }
            }
        }
        
        return filtered
    }
    
    private var filteredAssignmentsByCourse: [String: (courseName: String, courseCode: String, assignments: [CanvasAssignment])] {
        var result: [String: (courseName: String, courseCode: String, assignments: [CanvasAssignment])] = [:]
        
        for assignment in filteredAssignments {
            let courseIdStr = assignment.course_idString // Use String ID from assignment
            
            if result[courseIdStr] == nil {
                // Find course by comparing its String id with the assignment's course_idString
                let course = courses.first { $0.id == courseIdStr }
                result[courseIdStr] = (
                    courseName: course?.name ?? "Unknown Course",
                    courseCode: course?.courseCode ?? "Unknown",
                    assignments: []
                )
            }
            
            // Sort assignments within the course by due date before adding
            result[courseIdStr]?.assignments.append(assignment)
            result[courseIdStr]?.assignments.sort { assign1, assign2 in
                 guard let date1Str = assign1.due_at, let date2Str = assign2.due_at else { 
                     // Handle nil dates - maybe put them at the end?
                     return assign1.due_at != nil // true if assign1 has date, assign2 doesn't
                 }
                 // Use ISO8601DateFormatter for parsing Canvas dates
                 let dateFormatter = ISO8601DateFormatter()
                 dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds] // Try with fractional first
                 guard let date1 = dateFormatter.date(from: date1Str) ?? ISO8601DateFormatter.withInternetDateTime.date(from: date1Str) else { return false } // Fallback
                 guard let date2 = dateFormatter.date(from: date2Str) ?? ISO8601DateFormatter.withInternetDateTime.date(from: date2Str) else { return false } // Fallback
                 return date1 < date2
             }
        }
        
        return result
    }
    
    // MARK: - Helper Methods
    
    private func isDueToday(_ relativeDue: String?) -> Bool {
        return relativeDue?.lowercased().contains("due today") ?? false
    }
    
    private func loadStoredCredentials() {
        let defaults = UserDefaults.standard
        let storedURL = defaults.string(forKey: "canvasURL") ?? ""
        let storedName = defaults.string(forKey: "selectedUniversityName") ?? ""
        let storedCustomName = defaults.string(forKey: "customUniversityName") ?? ""
        let storedCustomURL = defaults.string(forKey: "customUniversityURL") ?? ""
        
        if let apiKeyData = KeychainManager.load(key: "canvasApiKey") {
            apiKey = String(decoding: apiKeyData, as: UTF8.self)
            if !apiKey.isEmpty {
                // Restore selected university or custom info
                if !storedCustomName.isEmpty && !storedCustomURL.isEmpty {
                    selectedUniversity = UNIVERSITIES.first { $0.name == "Custom University" }!
                    customUniversityName = storedCustomName
                    customUniversityURL = storedCustomURL
                    isCustomUniversitySelected = true
                } else if let foundUniversity = UNIVERSITIES.first(where: { $0.url == storedURL }) {
                    selectedUniversity = foundUniversity
                    isCustomUniversitySelected = false
                } else if !storedURL.isEmpty {
                     // If URL exists but doesn't match predefined, assume custom (legacy or manual entry)
                     selectedUniversity = UNIVERSITIES.first { $0.name == "Custom University" }!
                     customUniversityName = storedName.isEmpty ? "Custom" : storedName
                     customUniversityURL = storedURL
                     isCustomUniversitySelected = true
                } else {
                    // Default if nothing stored
                    selectedUniversity = UNIVERSITIES[0]
                    isCustomUniversitySelected = false
                }
                
                if !effectiveCanvasURL.isEmpty {
                    isAuthenticated = true
                    // Fetch assignments if we're authenticated
                    fetchAssignments()
                }
            } else {
                 isAuthenticated = false
                 // Reset university selection if no API key
                 selectedUniversity = UNIVERSITIES[0]
                 isCustomUniversitySelected = false
                 customUniversityName = ""
                 customUniversityURL = ""
            }
        } else {
            isAuthenticated = false
            // Reset university selection if no API key
            selectedUniversity = UNIVERSITIES[0]
            isCustomUniversitySelected = false
            customUniversityName = ""
            customUniversityURL = ""
        }
    }
    
    private func saveCredentials() {
        let apiKeyData = apiKey.data(using: .utf8) ?? Data()
        let saveSuccessful = KeychainManager.save(key: "canvasApiKey", data: apiKeyData)
        if !saveSuccessful {
            print("Error: Failed to save API key to Keychain.")
            // Optionally, you could show an error message to the user here
        }
        
        let defaults = UserDefaults.standard
        defaults.set(effectiveCanvasURL, forKey: "canvasURL")
        defaults.set(selectedUniversity.name, forKey: "selectedUniversityName") // Save name for display
        
        if isCustomUniversitySelected {
            defaults.set(customUniversityName, forKey: "customUniversityName")
            defaults.set(customUniversityURL, forKey: "customUniversityURL")
        } else {
            // Remove custom keys if a predefined university is selected
            defaults.removeObject(forKey: "customUniversityName")
            defaults.removeObject(forKey: "customUniversityURL")
        }
    }
    
    private func connectToCanvas() {
        isLoading = true
        errorMessage = nil
        
        let urlToValidate = effectiveCanvasURL
        
        // Validate URL format
        guard !urlToValidate.isEmpty, let url = URL(string: urlToValidate), UIApplication.shared.canOpenURL(url) else {
            errorMessage = "Invalid Canvas URL format"
            isLoading = false
            return
        }
        
        // Validate API key
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "API key cannot be empty"
            isLoading = false
            return
        }
        
        // Validate Custom Name if needed
        if isCustomUniversitySelected && customUniversityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
             errorMessage = "Custom University Name cannot be empty"
             isLoading = false
             return
        }
        
        // Save credentials *before* attempting connection
        saveCredentials()
        
        // Initialize API service with the correct URL
        CanvasAPIService.shared.initialize(baseURL: urlToValidate, apiKey: apiKey)
        
        // Fetch initial data to validate connection
        CanvasAPIService.shared.fetchCourses { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let fetchedCourses):
                    courses = fetchedCourses
                    isAuthenticated = true
                    errorMessage = nil // Clear error on success
                    // Fetch assignments after successful course fetch
                    fetchAssignments()
                case .failure(let error):
                    errorMessage = "Connection error: \(error.localizedDescription)"
                    isAuthenticated = false
                    // Optionally clear credentials on auth failure?
                    // disconnectFromCanvas() 
                }
            }
        }
    }
    
    private func disconnectFromCanvas() {
        KeychainManager.delete(key: "canvasApiKey")
        
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "canvasURL")
        defaults.removeObject(forKey: "selectedUniversityName")
        defaults.removeObject(forKey: "customUniversityName")
        defaults.removeObject(forKey: "customUniversityURL")
        
        // Reset state
        apiKey = ""
        selectedUniversity = UNIVERSITIES[0] // Reset to default
        isCustomUniversitySelected = false
        customUniversityName = ""
        customUniversityURL = ""
        isAuthenticated = false
        assignments = []
        courses = []
        errorMessage = nil
    }
    
    private func fetchAssignments() {
        guard isAuthenticated else { return }
        isLoading = true
        errorMessage = nil // Clear previous errors
        
        CanvasAPIService.shared.initialize(baseURL: effectiveCanvasURL, apiKey: apiKey) // Ensure service is initialized
        CanvasAPIService.shared.fetchAssignments { result in
            DispatchQueue.main.async {
                isLoading = false
                
                switch result {
                case .success(let fetchedAssignments):
                    assignments = fetchedAssignments
                case .failure(let error):
                    errorMessage = "Failed to fetch assignments: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func addAssignmentToList() {
        guard let assignment = selectedAssignment else { return }
        
        if let listId = taskLists.first(where: { $0.name == selectedHeaderForAssignment })?.id {
            if let onAdd = onAddAssignmentToList {
                onAdd(assignment, listId)
            } else {
                addAssignmentDirectly(assignment: assignment, toListWithID: listId)
            }
        }
        
        showingHeaderPicker = false
        selectedAssignment = nil
        selectedHeaderForAssignment = "" // Reset selection
    }
    
    private func addAssignmentDirectly(assignment: CanvasAssignment, toListWithID listId: UUID) {
        if let listIndex = taskLists.firstIndex(where: { $0.id == listId }) {
            let newTask = Task(
                name: assignment.name,
                notes: "From Canvas: \(assignment.course_name)\n\(assignment.html_url ?? "")",
                dueDate: parseDueDate(assignment.due_at)
            )
            taskLists[listIndex].tasks.append(newTask)
        }
    }
    
    private func parseDueDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = .withInternetDateTime
        return formatter.date(from: dateString)
    }

    private func getRelativeDueDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDate)
        guard let days = components.day else { return "" }
        
        if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days > 1 {
            return "Due in \(days) days"
        } else { // days < 0
            return "\(abs(days)) days ago"
        }
    }
}

// MARK: - Canvas Models

struct CanvasAssignment: Identifiable, Decodable, Hashable {
    // Make properties optional where necessary and provide defaults
    let idString: String // Store original ID as string
    var id: Int { Int(idString) ?? 0 } // Use Int for Identifiable if possible, handle potential errors
    var name: String
    var due_at: String?
    var lock_at: String? // Add lock_at field for assignments with no due_at
    var course_idString: String // Store original ID as string
    var course_id: Int { Int(course_idString) ?? 0 } // Use Int for comparison if needed
    var course_name: String
    var points_possible: Double?
    var html_url: String?
    var type: String?
    var published: Bool?
    var isSubmitted: Bool?
    var dueDate: String?
    var relativeDue: String?
    var submission_types: [String]?

    // Conform to Decodable
    enum CodingKeys: String, CodingKey {
        case idString = "id"
        case name
        case due_at
        case lock_at
        case course_idString = "course_id"
        case course_name
        case points_possible
        case html_url
        case published
        case submission_types
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Decode id as Int first, then convert to String
        let idInt = try container.decode(Int.self, forKey: .idString)
        self.idString = String(idInt)
        self.name = try container.decode(String.self, forKey: .name)
        self.due_at = try container.decodeIfPresent(String.self, forKey: .due_at)
        self.lock_at = try container.decodeIfPresent(String.self, forKey: .lock_at)
        // Decode course_id as Int first, then convert to String
        let courseIdInt = try container.decode(Int.self, forKey: .course_idString)
        self.course_idString = String(courseIdInt)
        // Course name might not be directly in assignment, handle if needed
        self.course_name = try container.decodeIfPresent(String.self, forKey: .course_name) ?? "Unknown Course" 
        self.points_possible = try container.decodeIfPresent(Double.self, forKey: .points_possible)
        self.html_url = try container.decodeIfPresent(String.self, forKey: .html_url)
        self.published = try container.decodeIfPresent(Bool.self, forKey: .published) ?? true
        // Handle potential array for submission_types
        self.submission_types = try container.decodeIfPresent([String].self, forKey: .submission_types)
        if self.submission_types == nil, let typeString = try? container.decodeIfPresent(String.self, forKey: .submission_types) {
            self.submission_types = [typeString]
        }
        self.type = self.submission_types?.first
        
        // isSubmitted, dueDate, relativeDue are populated later
        self.isSubmitted = nil 
        self.dueDate = nil
        self.relativeDue = nil
    }
     
    // Manual init for testing or direct creation
    init(id: String, name: String, due_at: String? = nil, course_id: String, course_name: String, points_possible: Double? = nil, html_url: String? = nil, type: String? = nil, isSubmitted: Bool? = nil, dueDate: String? = nil, relativeDue: String? = nil) {
        self.idString = id
        self.name = name
        self.due_at = due_at
        self.lock_at = nil
        self.course_idString = course_id
        self.course_name = course_name
        self.points_possible = points_possible
        self.html_url = html_url
        self.type = type
        self.published = true
        self.submission_types = type != nil ? [type!] : nil
        self.isSubmitted = isSubmitted
        self.dueDate = dueDate
        self.relativeDue = relativeDue
    }
}

struct CanvasCourse: Identifiable, Decodable, Hashable {
    // Ensure id is decoded correctly (might be Int from API)
    let idInt: Int
    var id: String { String(idInt) }
    var name: String
    var course_code: String?
    var courseCode: String? { course_code }
    var end_at: String? // Course end date
    var start_at: String? // Course start date
    var workflow_state: String?
    var access_restricted_by_date: Bool?
    var enrollments: [CanvasEnrollment]?
    
    // Computed property to check if course is current based on JS implementation
    var isCurrent: Bool {
        // Skip non-academic courses
        if name.contains("Consent Matters") || name == "FEIT OPELA" {
            return false
        }
        
        // Check workflow state and enrollments
        let isAvailable = workflow_state == "available"
        let hasActiveEnrollment = enrollments?.contains(where: { $0.enrollment_state == "active" }) ?? false
        
        // Match the filtering logic from JS implementation
        return isAvailable && hasActiveEnrollment
    }

    enum CodingKeys: String, CodingKey {
        case idInt = "id"
        case name
        case course_code
        case end_at
        case start_at
        case workflow_state
        case access_restricted_by_date
        case enrollments
    }
    
    // Custom decoding implementation to handle potential duplicates in the JSON
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode ID, handling potential type mismatches
        if let intId = try? container.decode(Int.self, forKey: .idInt) {
            self.idInt = intId
        } else if let stringId = try? container.decode(String.self, forKey: .idInt),
                  let intValue = Int(stringId) {
            self.idInt = intValue
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .idInt,
                in: container, 
                debugDescription: "Expected Int or String convertible to Int for id")
        }
        
        // Decode name with fallback
        if let nameValue = try? container.decode(String.self, forKey: .name) {
            self.name = nameValue
        } else {
            self.name = "Unknown Course"
        }
        
        // Optional fields
        self.course_code = try container.decodeIfPresent(String.self, forKey: .course_code)
        self.end_at = try container.decodeIfPresent(String.self, forKey: .end_at)
        self.start_at = try container.decodeIfPresent(String.self, forKey: .start_at)
        self.workflow_state = try container.decodeIfPresent(String.self, forKey: .workflow_state)
        self.access_restricted_by_date = try container.decodeIfPresent(Bool.self, forKey: .access_restricted_by_date)
        self.enrollments = try container.decodeIfPresent([CanvasEnrollment].self, forKey: .enrollments)
    }
}

// Add enrollment structure
struct CanvasEnrollment: Codable, Hashable {
    let id: Int?
    let user_id: Int?
    let enrollment_state: String?
    let type: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case enrollment_state
        case type
    }
}

// MARK: - Canvas API Service

class CanvasAPIService {
    static let shared = CanvasAPIService()
    
    private var baseURL: String = ""
    private var apiKey: String = ""
    private var session: URLSession { // Configure session for better caching/timeout
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30 // 30 seconds timeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData // Force reload
        return URLSession(configuration: configuration)
    }
    
    // Keep track of active courses for filtering
    private var activeCourses: [String] = []
    
    func initialize(baseURL: String, apiKey: String) {
        // Normalize base URL: remove trailing slash, ensure https
        var normalizedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedURL.hasSuffix("/") {
            normalizedURL = String(normalizedURL.dropLast())
        }
        if !normalizedURL.hasPrefix("http://") && !normalizedURL.hasPrefix("https://") {
             normalizedURL = "https://" + normalizedURL
        }
        self.baseURL = normalizedURL
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        print("CanvasAPIService Initialized with Base URL: \(self.baseURL)")
    }
    
    // Helper to create authorized requests
    private func createRequest(endpoint: String, params: [String: String]? = nil) -> URLRequest? {
         guard !baseURL.isEmpty, !apiKey.isEmpty else { return nil }
         
         var urlString = "\(baseURL)/api/v1\(endpoint)"
         if let params = params, !params.isEmpty {
             var components = URLComponents(string: urlString)
             
             // Create query items, handling possible comma-separated values
             var queryItems: [URLQueryItem] = []
             for (key, value) in params {
                 if key.hasSuffix("[]") && value.contains(",") {
                     // Split comma-separated values into multiple query items with the same key
                     let values = value.components(separatedBy: ",")
                     for individualValue in values {
                         queryItems.append(URLQueryItem(name: key, value: individualValue.trimmingCharacters(in: .whitespacesAndNewlines)))
                     }
                 } else {
                     queryItems.append(URLQueryItem(name: key, value: value))
                 }
             }
             
             components?.queryItems = queryItems
             
             if let urlWithParams = components?.url?.absoluteString {
                 urlString = urlWithParams
             }
         }

         guard let url = URL(string: urlString) else { return nil }
         
         var request = URLRequest(url: url)
         request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
         request.addValue("application/json", forHTTPHeaderField: "Accept")
         request.cachePolicy = .reloadIgnoringLocalCacheData // Ensure fresh data
         print("Creating request for: \(urlString)")
         return request
     }

    // Helper to handle API responses
     private func handleResponse<T: Decodable>(data: Data?, response: URLResponse?, error: Error?, completion: @escaping (Result<T, Error>) -> Void) {
         if let error = error {
             // print("API Request Error: \(error.localizedDescription)") // Commented out for preview
             completion(.failure(error))
             return
         }
         
         guard let httpResponse = response as? HTTPURLResponse else {
              completion(.failure(NSError(domain: "CanvasAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response type"])))
              return
         }

         // print("API Response Status Code: \(httpResponse.statusCode)") // Commented out for preview

         guard (200...299).contains(httpResponse.statusCode) else {
             let statusCodeError = NSError(domain: "CanvasAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: Status Code \(httpResponse.statusCode)"])
             // print("API Status Code Error: \(httpResponse.statusCode)") // Commented out for preview
             completion(.failure(statusCodeError))
             return
         }
         
         guard let data = data else {
             completion(.failure(NSError(domain: "CanvasAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
             return
         }
         
         // Print raw response for debugging - Commented out for preview
         /*
         if let jsonString = String(data: data, encoding: .utf8) {
             print("Raw API Data (preview): \(String(jsonString.prefix(200)))...")
             // Check for potential duplicate keys in the JSON
             if jsonString.contains("\"id\":") && (
                jsonString.contains("\"course_id\":") || 
                jsonString.contains("\"course_code\":") ||
                jsonString.contains("\"end_at\":")) {
                print("Potential key that might be duplicated in JSON: searching for duplicate entries...")
                
                let keyPatterns = ["\"id\":", "\"course_id\":", "\"course_code\":", "\"end_at\":", "\"start_at\":"]
                for pattern in keyPatterns {
                    let components = jsonString.components(separatedBy: pattern)
                    print("Found \(components.count-1) occurrences of \(pattern)")
                }
            }
         }
         */
         
         do {
             let decoder = JSONDecoder()
             // Handle date decoding if necessary (Canvas dates are ISO8601)
             decoder.dateDecodingStrategy = .iso8601
             // Make the decoder more lenient for key conversion - will convert camelCase to snake_case if needed
             decoder.keyDecodingStrategy = .convertFromSnakeCase
             
             // Try to decode using print statements to catch any errors - Commented out for preview
             // print("About to decode JSON data to \(T.self)")
             let decodedObject = try decoder.decode(T.self, from: data)
             // print("Successfully decoded object of type \(T.self)")
             completion(.success(decodedObject))
         } catch let decodingError {
              // print("API Decoding Error: \(decodingError)") // Commented out for preview
             // Provide more context on decoding errors
             /*
             if let jsonString = String(data: data, encoding: .utf8) {
                 print("Failed to decode JSON snippet: \(String(jsonString.prefix(500)))...")
             }
             
             // Try to determine if this is an array or object
             if let firstChar = data.first, let lastChar = data.last {
                 let isArray = firstChar == UInt8(ascii: "[") && lastChar == UInt8(ascii: "]")
                 let isObject = firstChar == UInt8(ascii: "{") && lastChar == UInt8(ascii: "}")
                 print("JSON structure appears to be: \(isArray ? "array" : isObject ? "object" : "unknown")")
             }
             */
             completion(.failure(decodingError))
         }
     }
    
    func fetchCourses(completion: @escaping (Result<[CanvasCourse], Error>) -> Void) {
        // Fix duplicate "include[]" keys by using an array for includes
        let params: [String: String] = [
            "per_page": "100", 
            "enrollment_state": "active",
            "include[]": "term,course_progress,enrollments" // Include enrollments for filtering
        ]
        guard let request = createRequest(endpoint: "/courses", params: params) else {
            completion(.failure(NSError(domain: "CanvasAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create request"])))
            return
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            self.handleResponse(data: data, response: response, error: error) { (result: Result<[CanvasCourse], Error>) in
                switch result {
                case .success(let courses):
                    // Filter to keep only current courses using our enhanced criteria
                    let currentCourses = courses.filter { $0.isCurrent }
                    
                    if currentCourses.isEmpty {
                        completion(.failure(NSError(domain: "CanvasAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "No current courses found. Please check if you have any active course enrollments."])))
                        return
                    }
                    
                    // Store active course IDs for later filtering
                    self.activeCourses = currentCourses.map { $0.id }
                    
                    print("Filtered \(courses.count) courses down to \(currentCourses.count) current courses")
                    completion(.success(currentCourses))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    private func fetchAssignmentsForCourse(courseId: String, courseName: String, completion: @escaping (Result<[CanvasAssignment], Error>) -> Void) {
        // Match the parameters from JS implementation
        let params: [String: String] = [
            "per_page": "100",
            "bucket": "future", // Only future assignments
            "order_by": "due_at",
            "include[]": "submission,due_dates,all_dates,overrides,observed_users" // Match JS params
        ]
        
        guard let request = createRequest(endpoint: "/courses/\(courseId)/assignments", params: params) else {
            completion(.failure(NSError(domain: "CanvasAPI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to create request for course \(courseId)"])))
            return
        }
        
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { 
                completion(.failure(NSError(domain: "CanvasAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "API Service deallocated"])))
                return 
            }
            
            self.handleResponse(data: data, response: response, error: error) { (result: Result<[CanvasAssignment], Error>) in
                switch result {
                case .success(var assignments):
                    // Filter assignments to match JS implementation
                    assignments = assignments.filter { assignment in
                        // Only include published assignments with due dates (or lock dates)
                        return (assignment.published == true) && (assignment.due_at != nil || assignment.lock_at != nil)
                    }
                    
                    // Safely post-process assignments
                    assignments = assignments.map { assignment in
                        var updatedAssignment = assignment
                        
                        // Set course name if missing
                        if updatedAssignment.course_name.isEmpty || updatedAssignment.course_name == "Unknown Course" {
                            updatedAssignment.course_name = courseName
                        }
                        
                        // Set submission status
                        updatedAssignment.isSubmitted = false // Default - can be updated with actual status
                        
                        // Set date formatting
                        if let date = self.parseDueDate(updatedAssignment.due_at) {
                            updatedAssignment.dueDate = self.formatDate(date)
                            updatedAssignment.relativeDue = self.getRelativeDueDate(date)
                        } else if let lockDate = self.parseDueDate(updatedAssignment.lock_at) {
                            // Use lock_at as fallback date if due_at is not available
                            updatedAssignment.dueDate = self.formatDate(lockDate)
                            updatedAssignment.relativeDue = self.getRelativeDueDate(lockDate)
                        } else {
                            updatedAssignment.dueDate = "No Due Date"
                            updatedAssignment.relativeDue = nil
                        }
                        
                        return updatedAssignment
                    }
                    
                    completion(.success(assignments))
                    
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    func fetchAssignments(completion: @escaping (Result<[CanvasAssignment], Error>) -> Void) {
        fetchCourses { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let courses):
                let group = DispatchGroup()
                // Use dispatch queue for thread-safe operations
                let queue = DispatchQueue(label: "com.canvo.assignmentQueue", attributes: .concurrent)
                // Container for thread-safe collection of assignments
                var allAssignmentsPerCourse: [Int: [CanvasAssignment]] = [:]
                var fetchErrors: [Error] = [] // Collect errors from individual course fetches
                let syncQueue = DispatchQueue(label: "com.canvo.syncQueue")
                
                print("Fetched \(courses.count) courses. Fetching assignments for each...")
                for course in courses {
                    // Make a local copy of the course to avoid capture issues
                    let localCourse = course
                    group.enter()
                    queue.async {
                        self.fetchAssignmentsForCourse(courseId: localCourse.id, courseName: localCourse.name) { result in
                            switch result {
                            case .success(let assignments):
                                // Ensure course_name is set here if not present in assignment data
                                let assignmentsWithCourseName = assignments.map { assign -> CanvasAssignment in
                                    var updatedAssign = assign
                                    if updatedAssign.course_name.isEmpty || updatedAssign.course_name == "Unknown Course" {
                                        updatedAssign.course_name = localCourse.name
                                    }
                                    return updatedAssign
                                }
                                // Safely update shared collections
                                syncQueue.sync {
                                    allAssignmentsPerCourse[localCourse.idInt] = assignmentsWithCourseName
                                }
                            case .failure(let error):
                                print("Error fetching assignments for course \(localCourse.id): \(error.localizedDescription)")
                                syncQueue.sync {
                                    fetchErrors.append(error) // Collect error
                                }
                            }
                            group.leave()
                        }
                    }
                }
                
                group.notify(queue: .main) {
                    // Merge all assignments
                    let allAssignments = syncQueue.sync {
                        Array(allAssignmentsPerCourse.values.flatMap { $0 })
                    }
                    
                    if allAssignments.isEmpty {
                        // If we got no errors but no assignments, return a specific message
                        if fetchErrors.isEmpty {
                            completion(.failure(NSError(domain: "CanvasAPI", code: 404, userInfo: [NSLocalizedDescriptionKey: "No assignments found. Make sure you have active courses with assignments."])))
                            return
                        }
                        
                        // If we have errors and no assignments, return the first error
                        completion(.failure(fetchErrors.first!))
                        return
                    }
                    
                    // Sort assignments first by course name, then by due date
                    let sortedAssignments = allAssignments.sorted { a, b in
                        // First sort by course name
                        let courseCompare = a.course_name.compare(b.course_name)
                        if courseCompare != .orderedSame {
                            return courseCompare == .orderedAscending
                        }
                        
                        // Then sort by due date
                        if let dateA = a.due_at.flatMap({ self.parseDueDate($0) }),
                           let dateB = b.due_at.flatMap({ self.parseDueDate($0) }) {
                            return dateA < dateB
                        }
                        
                        // Handle cases where one or both assignments don't have dates
                        if a.due_at == nil { return false }
                        if b.due_at == nil { return true }
                        
                        return false
                    }
                    
                    print("Successfully fetched and sorted \(sortedAssignments.count) assignments total.")
                    completion(.success(sortedAssignments))
                }
                
            case .failure(let error):
                 print("Failed to fetch courses: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    // Date parsing helper
    func parseDueDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = .withInternetDateTime
        return formatter.date(from: dateString)
    }
    
    // Date formatting helper
    func formatDate(_ date: Date) -> String {
        // Format similar to JS implementation: "5 Jun at 23:59"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMM"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        
        let day = dayFormatter.string(from: date)
        let month = monthFormatter.string(from: date)
        let time = timeFormatter.string(from: date)
        
        return "\(day) \(month) at \(time)"
    }
    
    // Relative date formatting helper
    func getRelativeDueDate(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDate = calendar.startOfDay(for: date)
        
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfDate)
        guard let days = components.day else { return "" }
        
        if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "Due tomorrow"
        } else if days > 1 {
            return "Due in \(days) days"
        } else { // days < 0
            return "\(abs(days)) days ago"
        }
    }
}

// MARK: - Keychain Helper

struct KeychainManager {
    static func save(key: String, data: Data) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly // Accessibility
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary) // Delete existing item first
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Keychain save error: \(status)")
        }
        return status == errSecSuccess
    }
    
    static func load(key: String) -> Data? {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status != errSecSuccess && status != errSecItemNotFound {
             print("Keychain load error: \(status)")
        }
        return status == errSecSuccess ? result as? Data : nil
    }
    
    static func delete(key: String) -> Bool {
        let query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ] as [String: Any]
        
        let status = SecItemDelete(query as CFDictionary)
         if status != errSecSuccess && status != errSecItemNotFound {
             print("Keychain delete error: \(status)")
        }
        return status == errSecSuccess || status == errSecItemNotFound // Consider not found as success
    }
}

// MARK: - Preview
#Preview {
    CanvasIntegrationView(taskLists: .constant([
        TaskList(name: "Homework"),
        TaskList(name: "Projects"),
        TaskList(name: "Exams")
    ]))
}

// Add an extension for the date formatter fallback
extension ISO8601DateFormatter {
    static let withInternetDateTime: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = .withInternetDateTime
        return formatter
    }()
} 