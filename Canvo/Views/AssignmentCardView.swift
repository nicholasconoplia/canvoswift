import SwiftUI

// MARK: - Assignment Card View
struct AssignmentCardView: View {
    let assignment: CanvasKitAssignment
    @ObservedObject var viewModel: CanvasIntegrationViewModel
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var submissionStatus: SubmissionStatus {
        viewModel.submissionStatus(for: assignment)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Assignment Title and Type
            HStack {
                Text(assignment.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Submission Status Badge
                SubmissionStatusBadgeView(status: submissionStatus)
            }
            
            // Due Date if available
            if let dueDate = assignment.due_at {
                Text("Due: \(formatDueDate(dueDate))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Points if available
            if let points = assignment.points_possible {
                Text("Points: \(Int(points))")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Submission details if available
            if let detail = submissionStatus.detail {
                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func formatDueDate(_ dateString: String) -> String {
        guard let date = DateFormatter.iso8601Full.date(from: dateString) else {
            return "No due date"
        }
        return DateFormatter.submissionDateFormatter.string(from: date)
    }
}

// MARK: - Submission Status Badge View
struct SubmissionStatusBadgeView: View {
    let status: SubmissionStatus
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var backgroundColor: Color {
        switch status.state {
        case .graded:
            return .green
        case .submitted:
            return themeManager.themeColor
        case .late:
            return .orange
        case .missing:
            return .red
        case .notSubmitted:
            return .gray
        }
    }
    
    var body: some View {
        Text(status.displayText)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(8)
    }
}

// MARK: - Preview
struct AssignmentCardView_Previews: PreviewProvider {
    static var previews: some View {
        AssignmentCardView(
            assignment: CanvasKitAssignment(
                id: 1,
                name: "Sample Assignment",
                due_at: "2024-05-20T23:59:59Z",
                submission_types: ["online_text_entry"],
                points_possible: 100
            ),
            viewModel: CanvasIntegrationViewModel()
        )
        .environmentObject(ThemeManager())
    }
} 