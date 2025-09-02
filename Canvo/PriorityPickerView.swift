import SwiftUI

struct PriorityPickerView: View {
    @Binding var taskPriority: Priority?
    @Binding var showingPriorityPicker: Bool
    @Binding var showingContextMenu: Bool
    var onSave: (() -> Void)? // Callback for saving changes

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Use ForEach over Priority.allCases
            ForEach(Priority.allCases) { priority in
                priorityButton(priority: priority)
                // Add divider unless it's the last item
                if priority != Priority.allCases.last {
                    Divider()
                }
            }
            // Add "Clear Priority" button
            Divider()
            clearPriorityButton()
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 10)
        .frame(maxWidth: 300)
        .padding() // Padding around the VStack
    }

    // Button for a specific priority level
    private func priorityButton(priority: Priority) -> some View {
        Button {
            taskPriority = priority
            // Save changes
            onSave?()
            closePickers()
        } label: {
            HStack {
                Circle()
                    .fill(color(for: priority))
                    .frame(width: 10, height: 10)
                Text(priority.rawValue)
                    .foregroundColor(.primary)
                Spacer()
                // Show checkmark if this priority is selected
                if taskPriority == priority {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Button to clear the priority
    private func clearPriorityButton() -> some View {
        Button {
            taskPriority = nil // Set to nil for no priority
            // Save changes
            onSave?()
            closePickers()
        } label: {
            Text("Clear Priority")
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // Helper to get color for priority
    private func color(for priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    // Helper to close both pickers
    private func closePickers() {
        showingPriorityPicker = false
        showingContextMenu = false
    }
}

// Preview
#Preview {
    struct PreviewWrapper: View {
        @State var priority: Priority? = .medium
        @State var showingPicker = true
        @State var showingContext = true

        var body: some View {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                PriorityPickerView(
                    taskPriority: $priority,
                    showingPriorityPicker: $showingPicker,
                    showingContextMenu: $showingContext,
                    onSave: { print("Save changes") }
                )
            }
        }
    }
    return PreviewWrapper()
} 