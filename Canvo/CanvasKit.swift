//
//  CanvasKit.swift
//  Canvo
//
//  Created by Nick on 5/19/2024.
//

import Foundation
import Alamofire

// MARK: - Models

struct CanvasKitCourse: Codable, Identifiable {
    struct Enrollment: Codable {
        let type: String?
        let enrollment_state: String?
    }
    
    let id: Int
    let name: String
    let enrollments: [Enrollment]?
    let start_at: String?
    let end_at: String?
    
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

struct CanvasKitAssignment: Codable, Identifiable {
    let id: Int
    let name: String
    let due_at: String?
    let submission_types: [String]?
    let has_submitted_submissions: Bool?
    let html_url: String?
    
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
        fetchFromEndpoint("/api/v1/courses") { result in
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
        let urlString = "\(baseURL)\(endpoint)?per_page=100"
        
        AF.request(urlString, headers: headers)
            .validate()
            .responseDecodable(of: [CanvasKitCourse].self) { response in
                switch response.result {
                case .success(let courses):
                    completion(.success(courses))
                case .failure(let error):
                    // If decoding fails, try to handle wrapped response format
                    if let data = response.data {
                        do {
                            // Try to decode as a wrapped response
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let coursesArray = json["courses"] as? [[String: Any]] {
                                let coursesData = try JSONSerialization.data(withJSONObject: coursesArray)
                                let courses = try JSONDecoder().decode([CanvasKitCourse].self, from: coursesData)
                                completion(.success(courses))
                                return
                            }
                        } catch {
                            print("Error parsing wrapped courses: \(error)")
                        }
                    }
                    completion(.failure(error))
                }
            }
    }
    
    /// Fetch assignments for a specific course
    func fetchAssignments(forCourseId courseId: Int, completion: @escaping (Result<[CanvasKitAssignment], Error>) -> Void) {
        let urlString = "\(baseURL)/api/v1/courses/\(courseId)/assignments?per_page=100"
        
        AF.request(urlString, headers: headers)
            .validate()
            .responseDecodable(of: [CanvasKitAssignment].self) { response in
                switch response.result {
                case .success(let assignments):
                    completion(.success(assignments))
                case .failure(let error):
                    // If decoding fails, try to handle wrapped response format
                    if let data = response.data {
                        do {
                            // Try to decode as a wrapped response
                            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                               let assignmentsArray = json["assignments"] as? [[String: Any]] {
                                let assignmentsData = try JSONSerialization.data(withJSONObject: assignmentsArray)
                                let assignments = try JSONDecoder().decode([CanvasKitAssignment].self, from: assignmentsData)
                                completion(.success(assignments))
                                return
                            }
                        } catch {
                            print("Error parsing wrapped assignments: \(error)")
                        }
                    }
                    completion(.failure(error))
                }
            }
    }
    
    /// Verify API connection
    func verifyConnection(completion: @escaping (Bool, String?) -> Void) {
        let urlString = "\(baseURL)/api/v1/users/self"
        
        AF.request(urlString, headers: headers)
            .validate()
            .response { response in
                switch response.result {
                case .success:
                    completion(true, nil)
                case .failure(let error):
                    var message = "Failed to connect: \(error.localizedDescription)"
                    
                    // Extract more detailed error message if available
                    if let data = response.data, let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let errorMessage = errorJson["message"] as? String {
                        message = errorMessage
                    } else if let statusCode = response.response?.statusCode {
                        switch statusCode {
                        case 401:
                            message = "Unauthorized. Please check your API key."
                        case 403:
                            message = "Forbidden. Your API key may not have sufficient permissions."
                        case 404:
                            message = "API endpoint not found. Please check your Canvas URL."
                        default:
                            message = "API Error (HTTP \(statusCode))"
                        }
                    }
                    
                    completion(false, message)
                }
            }
    }
} 