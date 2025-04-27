import SwiftUI

struct NotesEditorView: View {
    // Use a local state variable initialized from the binding
    // to avoid direct modification issues with TextEditor
    @State private var notesText: String
    // The original binding to update the task
    private var taskNotesBinding: Binding<String?>

    @Binding var showingNotesEditor: Bool
    @Binding var showingContextMenu: Bool

    // Custom initializer
    init(taskNotes: Binding<String?>, showingNotesEditor: Binding<Bool>, showingContextMenu: Binding<Bool>) {
        self.taskNotesBinding = taskNotes
        self._showingNotesEditor = showingNotesEditor
        self._showingContextMenu = showingContextMenu
        // Initialize local state with current notes or empty string
        _notesText = State(initialValue: taskNotes.wrappedValue ?? "")
    }

    var body: some View {
        VStack(spacing: 15) {
            // Header with Title and Close Button
            HStack {
                Text("Notes")
                    .font(.title2).bold()
                Spacer()
                Button {
                    closeEditor()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }

            // Notes Text Editor
            TextEditor(text: $notesText)
                .frame(height: 200) // Adjust height as needed
                .border(Color.gray.opacity(0.3))
                .cornerRadius(8)

            // Save Button
            Button("Save Notes") {
                saveAndClose()
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.purple)
            .foregroundColor(.white)
            .cornerRadius(10)
            .font(.headline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(maxWidth: 350) // Adjust width
        .padding(30) // Padding from screen edges
    }

    private func saveAndClose() {
        // Update the original binding
        taskNotesBinding.wrappedValue = notesText.isEmpty ? nil : notesText
        closeEditor()
    }

    private func closeEditor() {
        showingNotesEditor = false
        showingContextMenu = false // Also close the context menu
    }
}

// Preview Provider
#Preview {
    struct PreviewWrapper: View {
        @State var notes: String? = "Existing note text here."
        @State var showingNotes = true
        @State var showingContext = true

        var body: some View {
            ZStack {
                Color.black.opacity(0.4).ignoresSafeArea()
                NotesEditorView(
                    taskNotes: $notes,
                    showingNotesEditor: $showingNotes,
                    showingContextMenu: $showingContext
                )
            }
        }
    }
    return PreviewWrapper()
} 