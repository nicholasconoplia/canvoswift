import SwiftUI
import Foundation

struct AddToTaskView: View {
    let assignment: CanvasKitAssignment
    @Binding var isPresented: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    // State for the new view
    @State private var selectedOption: AddOption = .existingHeader
    @State private var selectedHeaderID: UUID? = nil
    @State private var selectedHeaderName: String = "Select a list"
    @State private var newHeaderName: String = ""
    @State private var showingSuccessMessage = false
    @State private var showDropdown: Bool = false
    
    // Load task lists from DataManager for consistency
    @State private var taskLists: [TaskList] = DataManager.load()
    
    enum AddOption {
        case existingHeader
        case newHeader
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGray6).edgesIgnoringSafeArea(.all)
                
                VStack(alignment: .leading, spacing: 0) {
                    // Title area
                    Text("Add Assignment to Tasks")
                        .font(.headline)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                        .padding(.bottom, 20)
                    
                    // Existing Header Option with dropdown
                    optionExistingHeader
                    
                    // Create New Header Option
                    optionNewHeader
                    
                    Spacer()
                    
                    // Buttons area
                    buttonArea
                }
                .padding()
                
                // Success message overlay
                if showingSuccessMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Label("Task added successfully!", systemImage: "checkmark.circle.fill")
                                .padding()
                                .background(Color.green.opacity(0.9))
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .onTapGesture {
                if showDropdown {
                    showDropdown = false
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var optionExistingHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                selectedOption = .existingHeader
                showDropdown = false
            }) {
                HStack {
                    Image(systemName: selectedOption == .existingHeader ? "circle.fill" : "circle")
                        .foregroundColor(selectedOption == .existingHeader ? themeManager.themeColor : .gray)
                    
                    Text("Select existing list")
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            
            if selectedOption == .existingHeader {
                dropdownButton
                
                if showDropdown {
                    dropdownList
                }
            }
        }
        .padding(.vertical, 8)
        .background(selectedOption == .existingHeader ? Color(UIColor.systemBackground) : Color.clear)
        .cornerRadius(12)
    }
    
    private var dropdownButton: some View {
        Button(action: {
            withAnimation {
                showDropdown.toggle()
            }
        }) {
            HStack {
                Text(selectedHeaderName)
                    .foregroundColor(selectedHeaderID == nil ? .gray : .primary)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .foregroundColor(.gray)
                    .rotationEffect(.degrees(showDropdown ? 180 : 0))
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal)
    }
    
    private var dropdownList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if taskLists.isEmpty {
                Text("No task lists available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(taskLists) { list in
                    Button(action: {
                        selectedHeaderID = list.id
                        selectedHeaderName = list.name
                        showDropdown = false
                    }) {
                        HStack {
                            Text(list.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedHeaderID == list.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.themeColor)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(
                            selectedHeaderID == list.id ? 
                                Color(UIColor.systemGray6) : Color.clear
                        )
                    }
                    
                    if list.id != taskLists.last?.id {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal)
    }
    
    private var optionNewHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                selectedOption = .newHeader
                showDropdown = false
            }) {
                HStack {
                    Image(systemName: selectedOption == .newHeader ? "circle.fill" : "circle")
                        .foregroundColor(selectedOption == .newHeader ? themeManager.themeColor : .gray)
                    
                    Text("Create new list")
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                }
            }
            .padding(.horizontal)
            
            if selectedOption == .newHeader {
                TextField("Custom List Name", text: $newHeaderName)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(selectedOption == .newHeader ? Color(UIColor.systemBackground) : Color.clear)
        .cornerRadius(12)
    }
    
    private var buttonArea: some View {
        HStack(spacing: 20) {
            Button("Cancel") {
                isPresented = false
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(UIColor.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(12)
            
            Button("Add Assignment") {
                addTask()
                showingSuccessMessage = true
                
                // Dismiss after a short delay to show success message
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isPresented = false
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canAddTask ? themeManager.themeColor : Color(UIColor.systemGray3))
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(!canAddTask)
        }
    }
    
    private var canAddTask: Bool {
        (selectedOption == .existingHeader && selectedHeaderID != nil) ||
        (selectedOption == .newHeader && !newHeaderName.isEmpty)
    }
    
    // MARK: - Helper Methods
    
    private func parseDueDate(dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        // Try with ISO8601 with fractional seconds
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        let basicFormatter = ISO8601DateFormatter()
        basicFormatter.formatOptions = [.withInternetDateTime]
        
        if let date = basicFormatter.date(from: dateString) {
            return date
        }
        
        // Try standard RFC3339 format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        return dateFormatter.date(from: dateString)
    }
    
    private func addTask() {
        // Create new task from assignment
        let newTask = Task(
            name: assignment.name,
            notes: nil,
            isCompleted: false,
            dueDate: parseDueDate(dateString: assignment.due_at),
            priority: .medium,
            isEditing: false
        )
        
        print("DEBUG: Created new task with name: \(newTask.name) and ID: \(newTask.id)")
        
        // Force refresh taskLists from storage to ensure we have the latest data
        taskLists = DataManager.load()
        print("DEBUG: Loaded \(taskLists.count) lists from storage")
        
        var updatedLists = taskLists
        
        // Add to existing or new task list based on selection
        if selectedOption == .existingHeader {
            guard let headerID = selectedHeaderID,
                  let index = updatedLists.firstIndex(where: { $0.id == headerID }) else {
                print("ERROR: Could not find selected list with ID \(String(describing: selectedHeaderID))")
                return
            }
            
            let listName = updatedLists[index].name
            let taskCount = updatedLists[index].tasks.count
            
            print("DEBUG: Adding task '\(newTask.name)' to list '\(listName)' (current tasks: \(taskCount))")
            
            // Create a new copy of the tasks array with the new task
            var updatedTasks = updatedLists[index].tasks
            updatedTasks.append(newTask)
            
            print("DEBUG: Updated tasks array now has \(updatedTasks.count) tasks")
            
            // Create a new TaskList with the updated tasks and replace the old one
            // This ensures SwiftUI recognizes the change
            let updatedList = TaskList(
                id: updatedLists[index].id,
                name: updatedLists[index].name,
                tasks: updatedTasks
            )
            
            // Replace the list at the index
            updatedLists[index] = updatedList
            
            print("DEBUG: Replaced list at index \(index). New task count: \(updatedLists[index].tasks.count)")
        } else {
            // Create new task list
            let newList = TaskList(name: newHeaderName, tasks: [newTask])
            updatedLists.append(newList)
            print("DEBUG: Created new list '\(newHeaderName)' with task '\(newTask.name)'")
        }
        
        // Save using DataManager
        DataManager.save(lists: updatedLists)
        print("DEBUG: Saved updated lists to DataManager")
        
        // Also update the local state to ensure UI updates
        taskLists = updatedLists
        
        // Post notification to ensure the UI updates
        NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
        print("DEBUG: Posted first TaskListsUpdated notification")
        
        // Use multiple delayed notifications to ensure all views refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Second notification with delay
            NotificationCenter.default.post(name: Notification.Name("TaskListsUpdated"), object: nil)
            print("DEBUG: Posted second TaskListsUpdated notification")
            
            // Verify if our changes were persisted
            let verifyLists = DataManager.load()
            print("DEBUG: Verification - Loaded \(verifyLists.count) lists from storage")
            
            if let headerID = self.selectedHeaderID,
               let verifyList = verifyLists.first(where: { $0.id == headerID }) {
                print("DEBUG: Verification - List '\(verifyList.name)' has \(verifyList.tasks.count) tasks")
                
                // Check if our task is actually in the list
                let foundTask = verifyList.tasks.contains { $0.name == newTask.name }
                print("DEBUG: Verification - Task '\(newTask.name)' found in list: \(foundTask)")
            }
        }
    }
}

struct AddToTaskView_Previews: PreviewProvider {
    static var previews: some View {
        AddToTaskView(
            assignment: CanvasKitAssignment(
                id: 1,
                name: "Sample Assignment",
                due_at: "2024-05-20T23:59:59Z",
                submission_types: ["online_text_entry"],
                points_possible: 100
            ),
            isPresented: .constant(true)
        )
        .environmentObject(ThemeManager())
    }
} 