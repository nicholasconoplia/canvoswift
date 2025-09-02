//
//  CanvasKit.swift
//  Canvo
//
//  Created by Nick on 5/19/2024.
//

import Foundation
import Alamofire
import SwiftUI

// MARK: - Errors
enum CanvasKitError: Error {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case invalidResponse
    case unauthorized
    case notFound
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid Canvas URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Unauthorized. Please check your API key"
        case .notFound:
            return "Resource not found"
        }
    }
}

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

struct CanvasKitAssignment: Codable, Identifiable {
    let id: Int
    let name: String
    let due_at: String?
    let submission_types: [String]?
    let html_url: String?
    let quiz_id: Int?
    let points_possible: Double?
    
    // Submission status information (status, detailed status)
    var submissionStatus: (String, String) = ("Not Submitted", "Not yet submitted")
    
    // Explicit Codable implementation to handle the submissionStatus tuple
    enum CodingKeys: String, CodingKey {
        case id, name, due_at, submission_types, html_url, quiz_id, points_possible
        case submissionStatus // Add key for our tuple
    }
    
    // Custom initializer for decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        due_at = try container.decodeIfPresent(String.self, forKey: .due_at)
        submission_types = try container.decodeIfPresent([String].self, forKey: .submission_types)
        html_url = try container.decodeIfPresent(String.self, forKey: .html_url)
        quiz_id = try container.decodeIfPresent(Int.self, forKey: .quiz_id)
        points_possible = try container.decodeIfPresent(Double.self, forKey: .points_possible)

        // Decode submissionStatus from an array, provide default if missing or invalid
        if let statusArray = try container.decodeIfPresent([String].self, forKey: .submissionStatus), statusArray.count == 2 {
            submissionStatus = (statusArray[0], statusArray[1])
        } else {
            // If key is missing or array is malformed, use default
            submissionStatus = ("Not Submitted", "Not yet submitted")
        }
    }

    // Custom encoder
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(due_at, forKey: .due_at)
        try container.encodeIfPresent(submission_types, forKey: .submission_types)
        try container.encodeIfPresent(html_url, forKey: .html_url)
        try container.encodeIfPresent(quiz_id, forKey: .quiz_id)
        try container.encodeIfPresent(points_possible, forKey: .points_possible)
        
        // Encode submissionStatus as an array of two strings
        try container.encode([submissionStatus.0, submissionStatus.1], forKey: .submissionStatus)
    }
    
    // Add a custom initializer for previews
    init(id: Int, name: String, due_at: String? = nil, submission_types: [String]? = nil, 
         html_url: String? = nil, quiz_id: Int? = nil, points_possible: Double? = nil) {
        self.id = id
        self.name = name
        self.due_at = due_at
        self.submission_types = submission_types
        self.html_url = html_url
        self.quiz_id = quiz_id
        self.points_possible = points_possible
        self.submissionStatus = ("Not Submitted", "Not yet submitted")
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
    
    var isQuiz: Bool {
        return assignmentType == "Quiz" || quiz_id != nil
    }
    
    // Days from now (negative for past dates, positive for future dates)
    var daysFromNow: Int? {
        guard let dueAtString = due_at else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let dueDate = formatter.date(from: dueAtString) {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let dueDateDay = calendar.startOfDay(for: dueDate)
            let components = calendar.dateComponents([.day], from: today, to: dueDateDay)
            return components.day
        } else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let dueDate = formatter.date(from: dueAtString) {
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let dueDateDay = calendar.startOfDay(for: dueDate)
                let components = calendar.dateComponents([.day], from: today, to: dueDateDay)
                return components.day
            }
        }
        
        return nil
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
                        var assignments = try JSONDecoder().decode([CanvasKitAssignment].self, from: data)
                        print("DEBUG: Successfully decoded \(assignments.count) assignments directly")
                        
                        // Fetch submission status for each assignment
                        let dispatchGroup = DispatchGroup()
                        
                        for i in 0..<assignments.count {
                            dispatchGroup.enter()
                            self.fetchSubmissionStatus(forCourseId: courseId, assignmentId: assignments[i].id) { result in
                                switch result {
                                case .success(let status):
                                    assignments[i].submissionStatus = status
                                case .failure(let error):
                                    print("DEBUG: Failed to fetch submission status: \(error.localizedDescription)")
                                }
                                dispatchGroup.leave()
                            }
                        }
                        
                        dispatchGroup.notify(queue: .main) { [weak self, completion] in
                            completion(.success(assignments))
                        }
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
                                        var assignment = try decoder.decode(CanvasKitAssignment.self, from: itemData)
                                        assignmentsArray.append(assignment)
                                    } catch let itemError {
                                        print("DEBUG: Skipping assignment \(index) due to error: \(itemError)")
                                        // Continue processing other items
                                    }
                                }
                                
                                if !assignmentsArray.isEmpty {
                                    print("DEBUG: Successfully decoded \(assignmentsArray.count) assignments from manual parsing")
                                    
                                    // Fetch submission status for each assignment
                                    let dispatchGroup = DispatchGroup()
                                    
                                    for i in 0..<assignmentsArray.count {
                                        dispatchGroup.enter()
                                        self.fetchSubmissionStatus(forCourseId: courseId, assignmentId: assignmentsArray[i].id) { result in
                                            switch result {
                                            case .success(let status):
                                                assignmentsArray[i].submissionStatus = status
                                            case .failure(let error):
                                                print("DEBUG: Failed to fetch submission status: \(error.localizedDescription)")
                                            }
                                            dispatchGroup.leave()
                                        }
                                    }
                                    
                                    dispatchGroup.notify(queue: .main) { [weak self, completion] in
                                        completion(.success(assignmentsArray))
                                    }
                                    return
                                }
                            } else if let jsonDict = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                                      let assignmentsArray = jsonDict["assignments"] as? [[String: Any]] {
                                // Try to handle wrapped response
                                print("DEBUG: Found assignments array in wrapped response")
                                let assignmentsData = try JSONSerialization.data(withJSONObject: assignmentsArray)
                                var assignments = try JSONDecoder().decode([CanvasKitAssignment].self, from: assignmentsData)
                                print("DEBUG: Successfully decoded \(assignments.count) assignments from wrapped response")
                                
                                // Fetch submission status for each assignment
                                let dispatchGroup = DispatchGroup()
                                
                                for i in 0..<assignments.count {
                                    dispatchGroup.enter()
                                    self.fetchSubmissionStatus(forCourseId: courseId, assignmentId: assignments[i].id) { result in
                                        switch result {
                                        case .success(let status):
                                            assignments[i].submissionStatus = status
                                        case .failure(let error):
                                            print("DEBUG: Failed to fetch submission status: \(error.localizedDescription)")
                                        }
                                        dispatchGroup.leave()
                                    }
                                }
                                
                                dispatchGroup.notify(queue: .main) { [weak self, completion] in
                                    completion(.success(assignments))
                                }
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
    
    /// Fetch submission status for a specific assignment
    func fetchSubmissionStatus(forCourseId courseId: Int, assignmentId: Int, completion: @escaping (Result<(String, String), Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/courses/\(courseId)/assignments/\(assignmentId)/submissions/self"
        
        print("DEBUG: Fetching submission status from: \(urlString)")
        
        AF.request(urlString, headers: headers)
            .validate()
            .responseData { response in
                print("DEBUG: Submission status response code: \(response.response?.statusCode ?? 0)")
                
                switch response.result {
                case .success(let data):
                    do {
                        // Define a local Submission struct for decoding
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
                        
                        // Try to decode as Submission model
                        let decoder = JSONDecoder()
                        
                        let submission = try decoder.decode(Submission.self, from: data)
                        
                        // Determine submission status
                        let isSubmitted = submission.workflowState == "submitted" || 
                                         submission.workflowState == "graded" || 
                                         (submission.submittedAt != nil && (submission.attempt ?? 0) > 0)
                        
                        if isSubmitted {
                            completion(.success(("Submitted", "Assignment has been submitted")))
                        } else {
                            completion(.success(("Not Submitted", "Assignment has not been submitted yet")))
                        }
                    } catch {
                        print("DEBUG: Error decoding submission: \(error)")
                        completion(.success(("Not Submitted", "Status information unavailable")))
                    }
                case .failure(let error):
                    print("DEBUG: Submission status request failed: \(error)")
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

// MARK: - Submission Fetching
extension CanvasKit {
    /// Fetches submissions for multiple assignments in a course in a single API call
    /// - Parameters:
    ///   - courseId: The ID of the course
    ///   - assignmentIds: Array of assignment IDs to fetch submissions for
    ///   - completion: Completion handler with Result containing dictionary mapping assignment IDs to their submissions
    func fetchSubmissionsForAssignments(courseId: Int, assignmentIds: [Int], completion: @escaping (Result<[Int: CanvasSubmission], Error>) -> Void) {
        // Construct the URL with query parameters
        var components = URLComponents(string: "\(baseURL)/api/v1/courses/\(courseId)/students/submissions")
        
        // Add query parameters
        components?.queryItems = [
            URLQueryItem(name: "student_ids[]", value: "self"),
            URLQueryItem(name: "include[]", value: "submission_history"),
            URLQueryItem(name: "include[]", value: "assignment"),
            URLQueryItem(name: "per_page", value: "100")
        ]
        
        // Add assignment IDs
        assignmentIds.forEach { id in
            components?.queryItems?.append(URLQueryItem(name: "assignment_ids[]", value: String(id)))
        }
        
        guard let url = components?.url else {
            print("DEBUG: Invalid URL constructed for submissions fetch")
            completion(.failure(CanvasKitError.invalidURL))
            return
        }
        
        print("DEBUG: Fetching submissions from URL: \(url.absoluteString)")
        print("DEBUG: Fetching submissions for assignments: \(assignmentIds)")
        
        // Create request with authorization header
        var request = URLRequest(url: url)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Make the request using Alamofire
        AF.request(request)
            .validate()
            .responseData { response in
                print("DEBUG: Submission response status: \(response.response?.statusCode ?? 0)")
                
                if let data = response.data, let str = String(data: data, encoding: .utf8) {
                    print("DEBUG: Raw submission response: \(str.prefix(500))...")
                }
                
                switch response.result {
                case .success(let data):
                    do {
                        // Decode the array of submissions
                        let submissions = try JSONDecoder().decode([CanvasSubmission].self, from: data)
                        print("DEBUG: Successfully decoded \(submissions.count) submissions")
                        
                        // Create a dictionary mapping assignment IDs to their submissions
                        let submissionsByAssignmentId = Dictionary(uniqueKeysWithValues:
                            submissions.map { ($0.assignmentId, $0) }
                        )
                        
                        // Log which assignments have submissions
                        let submittedAssignments = submissionsByAssignmentId.keys.sorted()
                        print("DEBUG: Found submissions for assignments: \(submittedAssignments)")
                        
                        // Log assignments that are missing submissions
                        let missingSubmissions = Set(assignmentIds).subtracting(Set(submittedAssignments))
                        if !missingSubmissions.isEmpty {
                            print("DEBUG: Missing submissions for assignments: \(missingSubmissions)")
                        }
                        
                        completion(.success(submissionsByAssignmentId))
                    } catch {
                        print("DEBUG: Failed to decode submissions: \(error)")
                        if let data = response.data, let str = String(data: data, encoding: .utf8) {
                            print("DEBUG: Failed to decode JSON: \(str)")
                        }
                        completion(.failure(error))
                    }
                case .failure(let error):
                    print("DEBUG: Failed to fetch submissions: \(error)")
                    completion(.failure(error))
                }
            }
    }
} 