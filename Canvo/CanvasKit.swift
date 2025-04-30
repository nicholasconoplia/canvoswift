//
//  CanvasKit.swift
//  Canvo
//
//  Created by Nick on 5/19/2024.
//

import Foundation
import Alamofire
import SwiftUI

// MARK: - Models

struct CanvasKitCourse: Codable, Identifiable {
    struct Enrollment: Codable {
        let type: String?
        let enrollment_state: String?
    }
    
    let id: Int
    let name: String?
    let enrollments: [Enrollment]?
    let start_at: String?
    let end_at: String?
    
    // Name accessor with fallback to avoid nil values
    var displayName: String {
        return name ?? "Unnamed Course #\(id)"
    }
    
    var isCurrent: Bool {
        guard let start = start_at, let end = end_at else { 
            // If dates are not available, check for active enrollments
            guard let enrolls = enrollments else { return true }
            return enrolls.contains(where: { $0.enrollment_state == "active" })
        }
        
        // Try multiple date formats since different Canvas instances may use different formats
        
        // First try ISO8601 with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Then try without fractional seconds
        let isoBasicFormatter = ISO8601DateFormatter()
        isoBasicFormatter.formatOptions = [.withInternetDateTime]
        
        // Also try standard RFC3339 date format (common in APIs)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        
        // Try a more lenient format too
        let lenientFormatter = DateFormatter()
        lenientFormatter.dateFormat = "yyyy-MM-dd"
        
        // Get current date for comparison
        let currentDate = Date()
        
        // Try parsing with various formatters
        if let startDate = isoFormatter.date(from: start) ?? 
                          isoBasicFormatter.date(from: start) ?? 
                          dateFormatter.date(from: start) ?? 
                          lenientFormatter.date(from: start),
           let endDate = isoFormatter.date(from: end) ?? 
                        isoBasicFormatter.date(from: end) ?? 
                        dateFormatter.date(from: end) ?? 
                        lenientFormatter.date(from: end) {
            
            // Print debug info about the dates
            print("DEBUG: Successfully parsed dates for course - Start: \(startDate), End: \(endDate), Current: \(currentDate)")
            
            // A course is current if today's date is between start and end dates
            return currentDate >= startDate && currentDate <= endDate
        }
        
        print("DEBUG: Failed to parse dates: \(start) to \(end)")
        
        // If date parsing fails, assume it's current
        return true
    }
}

// Assignment submission model
struct AssignmentSubmission: Decodable {
    let id: Int?
    let workflowState: String?
    let submittedAt: String?
    let attempt: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case workflowState = "workflow_state"
        case submittedAt = "submitted_at"
        case attempt
    }
    
    var isSubmitted: Bool {
        return workflowState == "submitted" || 
               workflowState == "graded"
    }
}

// Quiz submission models
struct QuizSubmissionResponse: Decodable {
    let quizSubmissions: [QuizSubmission]
    
    enum CodingKeys: String, CodingKey {
        case quizSubmissions = "quiz_submissions"
    }
}

struct QuizSubmission: Decodable {
    let id: Int
    let workflowState: String
    let attempt: Int
    let finishedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case workflowState = "workflow_state"
        case attempt
        case finishedAt = "finished_at"
    }
    
    var isSubmitted: Bool {
        return workflowState == "complete"
    }
}

struct CanvasKitAssignment: Codable, Identifiable {
    let id: Int
    let name: String
    let due_at: String?
    let submission_types: [String]?
    let has_submitted_submissions: Bool?
    let html_url: String?
    let quiz_id: Int?
    
    // Coding keys to ensure proper encoding/decoding of all properties
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case due_at
        case submission_types
        case has_submitted_submissions
        case html_url
        case quiz_id
    }
    
    // Computed properties
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
            if types.contains("online_quiz") {
                return "Quiz"
            } else {
                return "Assignment"
            }
        }
        return "Assignment"
    }
    
    var submissionStatus: (String, Color) {
        // Simple approach using only has_submitted_submissions
        if let submitted = has_submitted_submissions {
            return submitted ? ("Submitted", Color.green) : ("NOT SUBMITTED", Color(hex: "b892ff"))
        }
        
        return ("Unknown", Color.gray)
    }
    
    var isQuiz: Bool {
        return assignmentType == "Quiz" || quiz_id != nil
    }
}

// MARK: - CanvasKit Client

class CanvasKit {
    private let baseURL: String
    private let apiKey: String
    
    init(baseURL: String, apiKey: String) {
        // Ensure URL doesn't have trailing slash
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
    }
    
    // Common headers for all requests
    private var headers: HTTPHeaders {
        return [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json"
        ]
    }
    
    // MARK: - API Methods
    
    /// Fetch courses from Canvas
    func fetchCourses(completion: @escaping (Result<[CanvasKitCourse], Error>) -> Void) {
        // Try both common endpoints with a fallback mechanism
        fetchFromEndpoint("/api/v1/courses") { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let courses):
                completion(.success(courses))
            case .failure(_):
                // If first endpoint fails, try the alternate endpoint
                self.fetchFromEndpoint("/api/v1/users/self/courses", completion: completion)
            }
        }
    }
    
    /// Helper method to fetch from a specific endpoint
    private func fetchFromEndpoint(_ endpoint: String, completion: @escaping (Result<[CanvasKitCourse], Error>) -> Void) {
        // Make sure the endpoint has the required /api/v1 prefix
        let apiEndpoint = endpoint.hasPrefix("/api/v1") ? endpoint : "/api/v1\(endpoint)"
        let urlString = "\(baseURL)\(apiEndpoint)?per_page=100"
        
        print("DEBUG: Making API request to: \(urlString)")
        print("DEBUG: Using authorization header with token length: \(apiKey.count)")
        
        AF.request(urlString, headers: headers)
            .validate()
            .responseData { [weak self] response in
                print("DEBUG: Response status code: \(response.response?.statusCode ?? 0)")
                
                if let data = response.data, let dataString = String(data: data, encoding: .utf8) {
                    print("DEBUG: Raw response data (\(data.count) bytes): \(dataString.prefix(500))...")
                }
                
                switch response.result {
                case .success(let data):
                    do {
                        // First try to directly decode as an array of courses
                        let courses = try JSONDecoder().decode([CanvasKitCourse].self, from: data)
                        print("DEBUG: Successfully decoded \(courses.count) courses directly")
                        completion(.success(courses))
                    } catch let directError {
                        print("DEBUG: Failed to decode directly: \(directError)")
                        
                        // If that fails, try to parse the JSON manually
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [Any] {
                                print("DEBUG: Successfully parsed as JSON array")
                                
                                // Create a custom decoder that can handle missing fields
                                let decoder = JSONDecoder()
                                var coursesArray: [CanvasKitCourse] = []
                                
                                // Process each item in the array
                                for (index, item) in json.enumerated() {
                                    do {
                                        // Convert item back to data
                                        let itemData = try JSONSerialization.data(withJSONObject: item)
                                        let course = try decoder.decode(CanvasKitCourse.self, from: itemData)
                                        coursesArray.append(course)
                                    } catch let itemError {
                                        print("DEBUG: Skipping item \(index) due to error: \(itemError)")
                                        // Continue processing other items
                                    }
                                }
                                
                                if !coursesArray.isEmpty {
                                    print("DEBUG: Successfully decoded \(coursesArray.count) courses from manual parsing")
                                    completion(.success(coursesArray))
                                    return
                                }
                            } else if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                      let coursesArray = jsonDict["courses"] as? [[String: Any]] {
                                // Try to handle wrapped response
                                print("DEBUG: Found courses array in wrapped response")
                                let coursesData = try JSONSerialization.data(withJSONObject: coursesArray)
                                let courses = try JSONDecoder().decode([CanvasKitCourse].self, from: coursesData)
                                print("DEBUG: Successfully decoded \(courses.count) courses from wrapped response")
                                completion(.success(courses))
                                return
                            }
                        } catch let jsonError {
                            print("DEBUG: JSON parsing error: \(jsonError)")
                        }
                        
                        // If we got here, all decoding attempts failed
                        completion(.failure(directError))
                    }
                case .failure(let error):
                    print("DEBUG: Request failed with error: \(error)")
                    completion(.failure(error))
                }
            }
    }
    
    /// Fetch assignments for a specific course
    func fetchAssignments(forCourseId courseId: Int, completion: @escaping (Result<[CanvasKitAssignment], Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/courses/\(courseId)/assignments?per_page=100"
        
        print("DEBUG: Fetching assignments from: \(urlString)")
        
        AF.request(urlString, headers: headers)
            .validate()
            .responseData { response in
                print("DEBUG: Assignments response status code: \(response.response?.statusCode ?? 0)")
                
                if let data = response.data, let dataString = String(data: data, encoding: .utf8) {
                    print("DEBUG: Raw assignments data (\(data.count) bytes): \(dataString.prefix(200))...")
                }
                
                switch response.result {
                case .success(let data):
                    do {
                        // First try to directly decode as an array of assignments
                        let assignments = try JSONDecoder().decode([CanvasKitAssignment].self, from: data)
                        print("DEBUG: Successfully decoded \(assignments.count) assignments directly")
                        completion(.success(assignments))
                    } catch let directError {
                        print("DEBUG: Failed to decode assignments directly: \(directError)")
                        
                        // If that fails, try to parse the JSON manually
                        do {
                            if let json = try JSONSerialization.jsonObject(with: data) as? [Any] {
                                print("DEBUG: Successfully parsed assignments as JSON array")
                                
                                // Create a custom decoder that can handle missing fields
                                let decoder = JSONDecoder()
                                var assignmentsArray: [CanvasKitAssignment] = []
                                
                                // Process each item in the array
                                for (index, item) in json.enumerated() {
                                    do {
                                        // Convert item back to data
                                        let itemData = try JSONSerialization.data(withJSONObject: item)
                                        let assignment = try decoder.decode(CanvasKitAssignment.self, from: itemData)
                                        assignmentsArray.append(assignment)
                                    } catch let itemError {
                                        print("DEBUG: Skipping assignment \(index) due to error: \(itemError)")
                                        // Continue processing other items
                                    }
                                }
                                
                                if !assignmentsArray.isEmpty {
                                    print("DEBUG: Successfully decoded \(assignmentsArray.count) assignments from manual parsing")
                                    completion(.success(assignmentsArray))
                                    return
                                }
                            } else if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                      let assignmentsArray = jsonDict["assignments"] as? [[String: Any]] {
                                // Try to handle wrapped response
                                print("DEBUG: Found assignments array in wrapped response")
                                let assignmentsData = try JSONSerialization.data(withJSONObject: assignmentsArray)
                                let assignments = try JSONDecoder().decode([CanvasKitAssignment].self, from: assignmentsData)
                                print("DEBUG: Successfully decoded \(assignments.count) assignments from wrapped response")
                                completion(.success(assignments))
                                return
                            }
                        } catch let jsonError {
                            print("DEBUG: JSON parsing error for assignments: \(jsonError)")
                        }
                        
                        // If we got here, all decoding attempts failed
                        completion(.failure(directError))
                    }
                case .failure(let error):
                    print("DEBUG: Assignment request failed with error: \(error)")
                    completion(.failure(error))
                }
            }
    }
    
    /// Verify API connection
    func verifyConnection(completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(baseURL)/api/v1/users/self"
        
        print("DEBUG: Verifying connection to: \(urlString)")
        
        AF.request(urlString, headers: headers)
            .validate()
            .response { [weak self] response in
                print("DEBUG: Verification response status code: \(response.response?.statusCode ?? 0)")
                
                if let data = response.data, let dataString = String(data: data, encoding: .utf8) {
                    print("DEBUG: Verification raw response: \(dataString)")
                }
                
                switch response.result {
                case .success:
                    print("DEBUG: Connection verified successfully")
                    completion(true, nil)
                case .failure(let error):
                    print("DEBUG: Connection verification failed: \(error)")
                    var message = "Failed to connect: \(error.localizedDescription)"
                    
                    // Extract more detailed error message if available
                    if let data = response.data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["message"] as? String {
                        print("DEBUG: Error message from API: \(errorMessage)")
                        message = errorMessage
                    } else if let statusCode = response.response?.statusCode {
                        print("DEBUG: HTTP status code: \(statusCode)")
                        switch statusCode {
                        case 401:
                            message = "Unauthorized. Please check your API key."
                        case 403:
                            message = "Forbidden. Your API key may not have sufficient permissions."
                        case 404:
                            message = "Not found. Check that your university's Canvas URL is correct."
                        default:
                            message = "Error \(statusCode): \(error.localizedDescription)"
                        }
                    }
                    
                    completion(false, message)
                }
            }
    }
    
    /// Fetch assignment submission status
    func fetchAssignmentSubmission(courseId: Int, assignmentId: Int, completion: @escaping (Result<AssignmentSubmission?, Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/courses/\(courseId)/assignments/\(assignmentId)/submissions/self"
        
        print("DEBUG: Fetching assignment submission from: \(urlString)")
        
        AF.request(urlString, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    if data.isEmpty {
                        completion(.success(nil)) // No submission
                        return
                    }
                    
                    do {
                        let submission = try JSONDecoder().decode(AssignmentSubmission.self, from: data)
                        
                        // Check submission status based on workflow_state
                        if submission.workflowState == "submitted" || submission.workflowState == "graded" {
                            print("✅ Assignment has been submitted.")
                        } else {
                            print("❌ Assignment not submitted yet. Status: \(submission.workflowState ?? "unknown")")
                        }
                        
                        completion(.success(submission))
                    } catch {
                        print("DEBUG: Error decoding assignment submission: \(error)")
                        completion(.failure(error))
                    }
                    
                case .failure(let error):
                    // If 404, it means no submission
                    if let statusCode = response.response?.statusCode, statusCode == 404 {
                        print("❌ No submission found for this assignment.")
                        completion(.success(nil))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
    }
    
    /// Fetch quiz submission status
    func fetchQuizSubmission(courseId: Int, quizId: Int, completion: @escaping (Result<QuizSubmissionResponse?, Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/courses/\(courseId)/quizzes/\(quizId)/submission"
        
        print("DEBUG: Fetching quiz submission from: \(urlString)")
        
        AF.request(urlString, headers: headers)
            .responseData { response in
                switch response.result {
                case .success(let data):
                    if data.isEmpty {
                        print("❌ No quiz submission data found.")
                        completion(.success(nil)) // No submission
                        return
                    }
                    
                    do {
                        let quizResponse = try JSONDecoder().decode(QuizSubmissionResponse.self, from: data)
                        
                        // Use the exact check from the user's code
                        if let quiz = quizResponse.quizSubmissions.first {
                            if quiz.workflowState == "complete" {
                                print("✅ Quiz is submitted.")
                            } else {
                                print("❌ Quiz is not submitted yet. Status: \(quiz.workflowState)")
                            }
                        }
                        
                        completion(.success(quizResponse))
                    } catch {
                        print("DEBUG: Error decoding quiz submission: \(error)")
                        completion(.failure(error))
                    }
                    
                case .failure(let error):
                    // If 404, it means no submission
                    if let statusCode = response.response?.statusCode, statusCode == 404 {
                        print("❌ No quiz submission found.")
                        completion(.success(nil))
                    } else {
                        completion(.failure(error))
                    }
                }
            }
    }
    
    /// Checks the submission status for an assignment or quiz
    func checkSubmissionStatus(courseId: Int, assignment: CanvasKitAssignment, completion: @escaping (Bool, String) -> Void) {
        if assignment.isQuiz, let quizId = assignment.quiz_id {
            // Handle quiz submission
            fetchQuizSubmission(courseId: courseId, quizId: quizId) { result in
                switch result {
                case .success(let response):
                    if let quizResponse = response, let quiz = quizResponse.quizSubmissions.first {
                        let isSubmitted = quiz.workflowState == "complete"
                        let statusText = isSubmitted ? "Submitted" : "NOT SUBMITTED (\(quiz.workflowState))"
                        completion(isSubmitted, statusText)
                    } else {
                        // No submission found
                        completion(false, "NOT SUBMITTED")
                    }
                case .failure(let error):
                    print("Error checking quiz submission: \(error)")
                    completion(false, "Error: \(error.localizedDescription)")
                }
            }
        } else {
            // Handle regular assignment submission
            fetchAssignmentSubmission(courseId: courseId, assignmentId: assignment.id) { result in
                switch result {
                case .success(let submission):
                    if let submission = submission {
                        let isSubmitted = submission.workflowState == "submitted" || submission.workflowState == "graded"
                        let statusText = isSubmitted ? "Submitted" : "NOT SUBMITTED (\(submission.workflowState ?? "unknown"))"
                        completion(isSubmitted, statusText)
                    } else {
                        // No submission found
                        completion(false, "NOT SUBMITTED")
                    }
                case .failure(let error):
                    print("Error checking assignment submission: \(error)")
                    completion(false, "Error: \(error.localizedDescription)")
                }
            }
        }
    }
}

// Helper extension for Color from hex
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