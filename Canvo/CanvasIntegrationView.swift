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
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var courses: [CanvasCourse] = []
    @State private var assignments: [CanvasAssignment] = []
    // UI state
    @State private var showingApiGuide: Bool = false
    // University Selection State
    @State private var selectedUniversity: University = UNIVERSITIES[0] // Default to the first
    @State private var customUniversityName: String = ""
    @State private var customUniversityURL: String = ""
    @State private var isCustomUniversitySelected: Bool = false
    @State private var showingUniversityPicker: Bool = false // For modal picker
    @State private var isApiKeyConnected: Bool = false
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

    // MARK: - Canvas API Models
    struct CanvasCourse: Codable, Identifiable {
        struct Enrollment: Codable {
            let type: String?
            let enrollment_state: String?
        }
        let id: Int
        let name: String
        let enrollments: [Enrollment]?
    }
    struct CanvasAssignment: Codable, Identifiable {
        let id: Int
        let name: String
    }

    // MARK: - Fetch Logic
    private func fetchCanvasData() {
        guard !apiKey.isEmpty, !effectiveCanvasURL.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        courses = []
        assignments = []
        // Build courses URL
        let coursesURL = "\(effectiveCanvasURL)/api/v1/users/self/courses"
        guard let url = URL(string: coursesURL) else {
            self.errorMessage = "Invalid Canvas URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.errorMessage = "Invalid response"
                    self.isLoading = false
                    return
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    self.errorMessage = "HTTP \(httpResponse.statusCode): \(body)"
                    self.isLoading = false
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data returned"
                    self.isLoading = false
                    return
                }
                do {
                    let fetchedCourses = try JSONDecoder().decode([CanvasCourse].self, from: data)
                    // Only show courses where any enrollment is active and type is student
                    let activeCourses = fetchedCourses.filter { course in
                        guard let enrollments = course.enrollments else { return false }
                        return enrollments.contains(where: { $0.type == "student" && $0.enrollment_state == "active" })
                    }
                    self.courses = activeCourses
                    if !activeCourses.isEmpty {
                        self.isApiKeyConnected = true
                    }
                    if let firstCourse = activeCourses.first {
                        self.fetchAssignments(for: firstCourse.id)
                    } else {
                        self.isLoading = false
                    }
                } catch {
                    let raw = String(data: data, encoding: .utf8) ?? "<invalid>"
                    print("[Canvas API] Raw courses JSON: \(raw)")
                    self.errorMessage = "Failed to decode courses: \(error.localizedDescription)\nResponse: \(raw)"
                    self.isLoading = false
                }
            }
        }.resume()
    }

    private func fetchAssignments(for courseID: Int) {
        let urlString = "\(effectiveCanvasURL)/api/v1/courses/\(courseID)/assignments"
        guard let url = URL(string: urlString) else {
            self.errorMessage = "Invalid assignments URL"
            self.isLoading = false
            return
        }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                guard let data = data else {
                    self.errorMessage = "No data returned for assignments"
                    return
                }
                do {
                    let fetchedAssignments = try JSONDecoder().decode([CanvasAssignment].self, from: data)
                    self.assignments = fetchedAssignments
                } catch {
                    let raw = String(data: data, encoding: .utf8) ?? "<invalid>"
                    print("[Canvas API] Raw assignments JSON: \(raw)")
                    self.errorMessage = "Failed to decode assignments: \(error.localizedDescription)\nResponse: \(raw)"
                }
            }
        }.resume()
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
            // Canvas tab shell: just university picker, API key, and placeholder
            apiSetupView
            Spacer()
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
                                let urlString = isCustomUniversitySelected ? customUniversityURL : selectedUniversity.url
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
            if !isApiKeyConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("University")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Picker("University", selection: $selectedUniversity) {
                        ForEach(UNIVERSITIES) { university in
                            Text(university.name).tag(university)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedUniversity) {
                        isCustomUniversitySelected = (selectedUniversity.name == "Custom University")
                        if !isCustomUniversitySelected {
                            customUniversityName = ""
                            customUniversityURL = ""
                        }
                    }
                }
            }

            // Custom University Fields (Conditional, only if not connected)
            if isCustomUniversitySelected && !isApiKeyConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Custom University Name")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Enter University Name", text: $customUniversityName)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.words)
                    Text("Custom University URL")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    TextField("Enter Canvas URL", text: $customUniversityURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
            }
            
            // API Key Input (only if not connected)
            if !isApiKeyConnected {
                VStack(alignment: .leading, spacing: 6) {
                    Text("API Key")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    SecureField("Your Canvas API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                    Button("Where do I find this?") {
                        showingApiGuide = true
                    }
                    .font(.footnote)
                    .foregroundColor(themeColor)
                    .padding(.top, 2)
                    
                    Button(action: {
                        fetchCanvasData()
                    }) {
                        if isLoading {
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
                    .disabled(apiKey.isEmpty || effectiveCanvasURL.isEmpty || isLoading)
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
                        isApiKeyConnected = false
                        apiKey = ""
                        courses = []
                        assignments = []
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
                // Fetch Assignments button
                Button(action: {
                    fetchCanvasData()
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Fetch Assignments")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(themeColor)
                .foregroundColor(.white)
                .cornerRadius(8)
                .disabled(isLoading)
            }

            // Display error message
            if let error = errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }

            // Modern Card-based UI for Courses and Assignments
            if !courses.isEmpty {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(courses, id: \.id) { course in
                            VStack(alignment: .leading, spacing: 12) {
                                // Course Title and Term (if available)
                                Text(course.name)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .padding(.bottom, 2)
                                // Placeholder: In real data, parse term from course name or add a term property
                                if let term = course.name.components(separatedBy: "-").last?.trimmingCharacters(in: .whitespaces) {
                                    Text(term)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Divider()
                                // Assignments for this course (if loaded)
                                if course.id == (assignments.first?.id ?? -1) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Assignments")
                                            .font(.subheadline)
                                            .foregroundColor(.purple)
                                        ForEach(assignments, id: \.id) { assignment in
                                            HStack {
                                                Text(assignment.name)
                                                    .font(.body)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .background(Color.purple.opacity(0.1))
                                                    .cornerRadius(8)
                                                // Example status badge
                                                Text("Assignment")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.purple)
                                                    .cornerRadius(6)
                                                // Placeholder: Add more status badges as needed
                                            }
                                            // Example action buttons
                                            HStack(spacing: 8) {
                                                Button(action: {/* open in Canvas */}) {
                                                    Text("VIEW IN CANVAS")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.purple)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 4)
                                                        .background(Color.purple.opacity(0.12))
                                                        .cornerRadius(6)
                                                }
                                                Button(action: {/* add to list */}) {
                                                    Text("ADD TO LIST")
                                                        .font(.caption)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 10)
                                                        .padding(.vertical, 4)
                                                        .background(Color.purple)
                                                        .cornerRadius(6)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.vertical, 12)
                }
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
}
