//  CanvasIntegrationView.swift
//  Canvo
//
//  Created by Nick Conoplia on 27/4/2025.
//

import SwiftUI
import Security
import Alamofire
import UIKit
import Foundation

// MARK: - Planner Items Models
struct PlannerItem: Decodable {
    let plannableId: String
    let plannableType: String
    let submissions: PlannerSubmission?
    
    enum CodingKeys: String, CodingKey {
        case plannableId = "plannable_id"
        case plannableType = "plannable_type"
        case submissions
    }
}

struct PlannerSubmission: Decodable {
    let submitted: Bool
}

// MARK: - Submission Models
struct Submission: Decodable {
    let workflowState: String?
    let submittedAt: String?
    let attempt: Int?
    
    enum CodingKeys: String, CodingKey {
        case workflowState = "workflow_state"
        case submittedAt = "submitted_at"
        case attempt
    }
}

// MARK: - Submission Status Logic
class SubmissionStatusService {
    private let apiURL: String
    private let apiKey: String
    
    init(apiURL: String, apiKey: String) {
        self.apiURL = apiURL
        self.apiKey = apiKey
    }
    
    /// Fetches submission data for a specific assignment using the planner items API
    /// - Parameters:
    ///   - courseID: Canvas course ID
    ///   - assignmentID: Canvas assignment ID
    /// - Returns: Optional Submission object with status information
    func fetchSubmissionData(courseID: String, assignmentID: String) async -> Submission? {
        print("[DEBUG SubmissionService] Fetching submission for Course: \(courseID), Assignment: \(assignmentID)")
        
        // Calculate date from a week ago
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let dateFormatter = ISO8601DateFormatter()
        let startDate = dateFormatter.string(from: weekAgo)
        
        // Create URL for planner items API
        guard let url = URL(string: "\(apiURL)/planner/items?start_date=\(startDate)&per_page=75") else {
            print("[DEBUG SubmissionService] Invalid URL generated for Assignment: \(assignmentID)")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let jsonString = String(data: data, encoding: .utf8) {
                print("[DEBUG SubmissionService] Raw JSON response for Assignment \(assignmentID): \(jsonString.prefix(500))...") // Print first 500 chars
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                print("[DEBUG SubmissionService] HTTP Error: \(String(describing: (response as? HTTPURLResponse)?.statusCode)) for Assignment: \(assignmentID)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("[DEBUG SubmissionService] Error Response Body: \(errorData)")
                }
                return nil
            }
            
            // Decode the planner items response
            let plannerItems = try JSONDecoder().decode([PlannerItem].self, from: data)
            
            // Find the matching assignment in planner items
            if let matchingItem = plannerItems.first(where: { $0.plannableId == assignmentID && $0.plannableType == "assignment" }) {
                // Create a Submission object from the planner item data
                return Submission(
                    workflowState: matchingItem.submissions?.submitted == true ? "submitted" : "unsubmitted",
                    submittedAt: nil, // We don't get this from planner items API
                    attempt: matchingItem.submissions?.submitted == true ? 1 : 0 // Use 1 if submitted, 0 if not
                )
            }
            
            print("[DEBUG SubmissionService] No matching planner item found for Assignment: \(assignmentID)")
            return nil
        } catch {
            print("[DEBUG SubmissionService] Error fetching/decoding submission for \(assignmentID): \(error)")
            return nil
        }
    }
    
    /// Determines if an assignment has been submitted based on Canvas API data
    /// - Parameter submission: The Submission object from the Canvas API
    /// - Returns: Boolean indicating if the assignment has been submitted
    func isAssignmentSubmitted(_ submission: Submission?) -> Bool {
        print("[DEBUG SubmissionService] Checking submission status input: \(String(describing: submission))")
        guard let submission = submission else {
            print("[DEBUG SubmissionService] Submission is nil, determined as not submitted.")
            return false
        }
        
        // Simply check if the workflow state indicates submission
        let isSubmitted = submission.workflowState == "submitted"
        print("[DEBUG SubmissionService] Values - workflowState: \(String(describing: submission.workflowState)). Result: \(isSubmitted)")
        return isSubmitted
    }
}

// MARK: - SwiftUI View Extension for Submission Status
extension View {
    /// Adds a submission status badge to a view
    /// - Parameter isSubmitted: Boolean indicating if assignment is submitted
    /// - Returns: A view with the submission status badge
    func submissionStatusBadge(isSubmitted: Bool) -> some View {
        self.overlay(
            VStack {
                HStack {
                    Spacer()
                    
                    // Submission status badge
                    if isSubmitted {
                        Label("Submitted", systemImage: "checkmark")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    } else {
                        Text("Pending")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray5))
                            .foregroundColor(Color(UIColor.systemGray))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color(UIColor.systemGray4), lineWidth: 1)
                            )
                    }
                }
                .padding(8)
            }
        )
    }
}

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

// MARK: - Canvas Integration View
struct CanvasIntegrationView: View {
    // Use StateObject for the ViewModel to persist between view lifecycles
    @StateObject private var viewModel = CanvasIntegrationViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    
    // UI state
    @State private var showingApiGuide: Bool = false
    @State private var showingUniversityPicker: Bool = false // For modal picker
    @State private var showingCourseFilterMenu: Bool = false // For courses filter
    @State private var showingTypeFilterMenu: Bool = false
    
    // Theme properties
    var isDarkMode: Bool = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Canvas tab shell: just university picker, API key, and placeholder
                apiSetupView
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        // API Key Guide Modal
        .sheet(isPresented: $showingApiGuide) {
            apiGuideModal
        }
        // University picker sheet
        .sheet(isPresented: $showingUniversityPicker) {
            universityPickerSheet
        }
        // Course selection modal
        .sheet(isPresented: $viewModel.showingCourseSelectionModal) {
            CourseSelectionModalView(viewModel: viewModel)
        }
        // Course filter confirmation dialog
        .confirmationDialog("Filter by Course", isPresented: $showingCourseFilterMenu, titleVisibility: .visible) {
            Button("All Courses") { viewModel.selectCourse(nil) }
            ForEach(viewModel.filteredCourses) { course in
                Button(course.displayName) { viewModel.selectCourse(course.id) }
            }
            Button("Cancel", role: .cancel) {}
        }
        // Assignment type filter confirmation dialog
        .confirmationDialog("Filter by Assignment Type", isPresented: $showingTypeFilterMenu, titleVisibility: .visible) {
            Button("All Types") { viewModel.selectedAssignmentType = nil }
            ForEach(viewModel.assignmentTypes, id: \.self) { type in
                Button(type) { viewModel.selectedAssignmentType = type }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    // MARK: - Subviews
    
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
                    .foregroundColor(themeManager.themeColor)
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
                    .background(themeManager.themeColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(viewModel.apiKey.isEmpty || viewModel.effectiveCanvasURL.isEmpty || viewModel.isLoading)
                }
            } else {
                // Canvas Integration Bar when connected
                VStack(spacing: 16) {
                    HStack {
                        Text("Canvas Integration Connected")
                            .font(.subheadline)
                            .foregroundColor(themeManager.themeColor)
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
                    
                    // Course selection and refresh buttons in one row
                    HStack(spacing: 12) {
                        Button(action: {
                            viewModel.resetCourseVisibilityConfiguration()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("Customize Visible Courses")
                            }
                            .font(.subheadline)
                            .foregroundColor(themeManager.themeColor)
                        }
                        
                        Spacer()
                        
                        // Refresh button
                        Button(action: {
                            viewModel.fetchCanvasData()
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .foregroundColor(themeManager.themeColor)
                            .font(.subheadline)
                        }
                    }
                    
                    // Add filter for showing only future assignments
                    Toggle("Show only future assignments", isOn: $viewModel.showOnlyFutureAssignments)
                        .font(.subheadline)
                        .padding(.horizontal)
                        .onChange(of: viewModel.showOnlyFutureAssignments) { _ in
                            viewModel.objectWillChange.send()
                        }
                    
                    // Top filter pills
                    HStack(spacing: 16) {
                        // Course filter
                        FilterPillButton(
                            title: viewModel.selectedCourseId == nil ? "All Courses" : viewModel.courses.first(where: { $0.id == viewModel.selectedCourseId })?.displayName ?? "Course",
                            isActive: true
                        ) {
                            showingCourseFilterMenu = true
                        }
                        
                        // Assignment type filter
                        FilterPillButton(
                            title: viewModel.selectedAssignmentType == nil ? "All Types" : viewModel.selectedAssignmentType!,
                            isActive: true
                        ) {
                            showingTypeFilterMenu = true
                        }
                    }
                    .padding(.horizontal)
                    
                    // Course list
                    if viewModel.isLoading {
                        ProgressView("Loading your Canvas data...")
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.themeColor))
                            .padding()
                    } else if viewModel.filteredCourses.isEmpty {
                        Text(viewModel.hasConfiguredVisibleCourses ? 
                             "No visible courses selected. Tap 'Customize Visible Courses' to select courses." : 
                             "No courses found")
                            .foregroundColor(.secondary)
                            .padding()
                            .multilineTextAlignment(.center)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(viewModel.filteredCourses) { course in
                                CourseCardView(
                                    course: course, 
                                    assignments: viewModel.assignmentsByCourseId[course.id] ?? [], 
                                    isLoading: viewModel.fetchingAssignments.contains(course.id),
                                    viewModel: viewModel
                                )
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
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
                                .foregroundColor(themeManager.themeColor)
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
                                    .background(themeManager.themeColor)
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
                .fill(themeManager.themeColor)
                .frame(width: 32, height: 32)
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding(.top, 2)
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
                                    .foregroundColor(themeManager.themeColor)
                            } else if university.url.isEmpty && viewModel.isCustomUniversitySelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.themeColor)
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

// MARK: - Course Selection Modal View
struct CourseSelectionModalView: View {
    @ObservedObject var viewModel: CanvasIntegrationViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var searchText: String = ""
    
    private var filteredCourses: [CanvasKitCourse] {
        if searchText.isEmpty {
            return viewModel.courses
        } else {
            return viewModel.courses.filter { course in
                course.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header explanation
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select Courses to Display")
                        .font(.headline)
                    
                    Text("Choose which courses you want to see in your Canvas integration. This helps you focus on your current semester's courses.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search courses...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Course list with checkboxes
                List {
                    ForEach(filteredCourses) { course in
                        HStack {
                            // Course name
                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.displayName)
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            // Checkbox
                            Image(systemName: viewModel.temporaryVisibleCourseIds.contains(course.id) ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(viewModel.temporaryVisibleCourseIds.contains(course.id) ? themeManager.themeColor : .gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.toggleCourseVisibility(courseId: course.id)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Footer with buttons
                VStack(spacing: 16) {
                    // Select/deselect buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            // Select all current courses
                            viewModel.temporaryVisibleCourseIds = viewModel.courses.filter { $0.isCurrent }.map { $0.id }
                        }) {
                            Text("Select Current")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        
                        Button(action: {
                            // Select all courses
                            viewModel.temporaryVisibleCourseIds = viewModel.courses.map { $0.id }
                        }) {
                            Text("Select All")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Deselect all courses
                        viewModel.temporaryVisibleCourseIds = []
                    }) {
                        Text("Deselect All")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(8)
                    
                    // Save/cancel buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            viewModel.cancelCourseSelection()
                        }) {
                            Text("Cancel")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        
                        Button(action: {
                            viewModel.saveCourseSelectionPreferences()
                        }) {
                            Text("Save")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 14)
                        .background(themeManager.themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.05), radius: 5, y: -5)
            }
            .navigationBarTitle("Customize Courses", displayMode: .inline)
            .navigationBarItems(trailing: Button(action: {
                viewModel.cancelCourseSelection()
            }) {
                Image(systemName: "xmark")
                    .font(.headline)
            })
        }
    }
}

// MARK: - Course Card View
struct CourseCardView: View {
    let course: CanvasKitCourse
    let assignments: [CanvasKitAssignment]
    let isLoading: Bool
    @ObservedObject var viewModel: CanvasIntegrationViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Course Header
            Text(course.displayName)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.themeColor)
                .cornerRadius(16)
            
            // Assignments
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.themeColor))
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
                    AssignmentCardView(assignment: assignment, viewModel: viewModel)
                        .padding(.bottom, 8)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

// Helper extension for UserDefaults with Codable objects
extension UserDefaults {
    func setCodableObject<T: Codable>(_ object: T, forKey key: String) {
        if let encoded = try? JSONEncoder().encode(object) {
            UserDefaults.standard.set(encoded, forKey: key)
            
            // If we're saving task lists, also save them with DataManager
            if key == "taskLists", let taskLists = object as? [TaskList] {
                DataManager.save(lists: taskLists)
            }
            
            // Post notification that data has changed so other views can update
            NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
        }
    }
    
    func codableObject<T: Codable>(forKey key: String, castTo type: T.Type) -> T? {
        // If requesting task lists, try to load from DataManager first
        if key == "taskLists" && type == [TaskList].self {
            return DataManager.load() as? T
        }
        
        // Otherwise fall back to regular UserDefaults
        if let data = UserDefaults.standard.data(forKey: key) {
            return try? JSONDecoder().decode(type, from: data)
        }
        return nil
    }
}

// Note: The Color extension with init(hex:) has been removed as it already exists in CanvasKit.swift

