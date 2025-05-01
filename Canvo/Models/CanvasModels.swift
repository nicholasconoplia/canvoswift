import Foundation

// MARK: - Submission Models
struct CanvasSubmission: Codable {
    let id: Int
    let assignmentId: Int
    let workflowState: String
    let submittedAt: String?
    let gradedAt: String?
    let score: Double?
    let grade: String?
    let attempt: Int?
    let late: Bool
    let missing: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case assignmentId = "assignment_id"
        case workflowState = "workflow_state"
        case submittedAt = "submitted_at"
        case gradedAt = "graded_at"
        case score
        case grade
        case attempt
        case late
        case missing
    }
}

// MARK: - Submission Status View Model
struct SubmissionStatus {
    let state: State
    let displayText: String
    let detail: String?
    let isLate: Bool
    let isMissing: Bool
    
    enum State {
        case notSubmitted
        case submitted
        case graded
        case late
        case missing
    }
    
    init(from submission: CanvasSubmission?) {
        if let submission = submission {
            self.isLate = submission.late
            self.isMissing = submission.missing
            
            // First check for graded state
            if submission.workflowState == "graded" {
                self.state = .graded
                if let grade = submission.grade {
                    self.displayText = "Graded: \(grade)"
                    self.detail = submission.gradedAt.map { "Graded on: \(DateFormatter.submissionDateFormatter.string(from: DateFormatter.iso8601Full.date(from: $0) ?? Date()))" }
                } else if let score = submission.score {
                    self.displayText = "Graded: \(score)"
                    self.detail = submission.gradedAt.map { "Graded on: \(DateFormatter.submissionDateFormatter.string(from: DateFormatter.iso8601Full.date(from: $0) ?? Date()))" }
                } else {
                    self.displayText = "Graded"
                    self.detail = nil
                }
            }
            // Then check for missing assignments
            else if submission.missing {
                self.state = .missing
                self.displayText = "Missing"
                self.detail = "Past due"
            }
            // Then check for normal submissions
            else if submission.workflowState == "submitted" || submission.workflowState == "pending_review" || (submission.submittedAt != nil && (submission.attempt ?? 0) > 0) {
                self.state = .submitted
                self.displayText = "Submitted"
                self.detail = submission.submittedAt.map { "Submitted on: \(DateFormatter.submissionDateFormatter.string(from: DateFormatter.iso8601Full.date(from: $0) ?? Date()))" }
            }
            // Default to not submitted
            else {
                self.state = .notSubmitted
                self.displayText = "Not Submitted"
                self.detail = "Not yet submitted"
            }
        } else {
            self.state = .notSubmitted
            self.displayText = "Not Submitted"
            self.detail = "Not yet submitted"
            self.isLate = false
            self.isMissing = false
        }
    }
}

// MARK: - Date Formatter Extensions
extension DateFormatter {
    static let iso8601Full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static let submissionDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
} 