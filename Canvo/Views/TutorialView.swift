import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    // State to track which tutorial section is expanded
    @State private var expandedSection: TutorialSection? = .tasks
    
    // Tutorial sections
    enum TutorialSection: String, CaseIterable {
        case tasks = "Tasks"
        case canvas = "Canvas Integration"
        case wheelSpinner = "Task Wheel"
        case calendar = "Calendar"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .tasks: return "checklist"
            case .canvas: return "graduationcap"
            case .wheelSpinner: return "circle.circle"
            case .calendar: return "calendar"
            case .settings: return "gear"
            }
        }
        
        var content: String {
            switch self {
            case .tasks:
                return """
                How to manage your tasks:

                1. Creating a Category (Task List):
                   • Look for the "+" button at the bottom
                   • Type a name for your category (like "Shopping" or "Homework")
                   • This creates a new group to organize your tasks
                   • Think of it like a folder or container that you can add tasks under

                2. Adding a new task:
                   • Tap the "+" button in the bottom right
                   • Type what you need to do
                   • Choose which category to put it in
                   • Set a due date if you want (optional)
                   • Pick how important it is (optional)
                   • Add any notes you want (optional)
                   • Tap "ADD TASK"

                3. Managing your tasks:
                   • Tap the circle next to a task to mark it done
                   • Swipe right to left to delete a task
                   • Swipe left to right for quick date and priority options
                   • Tap the three dots (⋯) for more options
                   • Tap the category name to rename it
                   • Tap the arrow to show/hide tasks in a category
                """
            case .canvas:
                return """
                How to connect with Canvas:

                1. First-time setup:
                   • Go to the Canvas tab
                   • Tap "Connect to Canvas"
                   • Choose your school from the list
                   • Follow the steps to get your API key
                   • Paste your API key and tap "Connect"

                2. Using Canvas features:
                   • See all your courses at the top
                   • Assignments are shown below each course
                   • Red means it's due soon
                   • Green means you have time
                   • Tap an assignment to see more details
                   • Use filters at the top to find things easier

                3. Adding Canvas assignments to your tasks:
                   • Find the assignment you want to add
                   • Swipe right to left on the assignment
                   • A green + button will appear
                   • Tap the green + button
                   • Choose to either:
                     - Add to existing category
                     - Create new category
                   • The assignment is now in your Tasks tab
                   • It will appear in Calendar and Task Wheel too!

                4. Tips for Canvas integration:
                   • Added assignments sync with your task list
                   • Use categories like "Math Homework" or "Biology Projects"
                   • All added assignments can be managed in the Tasks tab
                   • Track Canvas deadlines in the Calendar view
                   • Use the Task Wheel to pick which assignment to do first
                """
            case .wheelSpinner:
                return """
                How to use the Task Wheel:

                1. Getting started:
                   • Go to the Task Wheel tab
                   • The wheel shows all your unfinished tasks
                   • Each task gets its own slice of the wheel

                2. Using the wheel:
                   • Tap "Spin the Wheel" to start
                   • Watch the wheel spin
                   • Your phone will vibrate when it stops
                   • The task at the top is your chosen task

                3. Tips:
                   • Use this when you can't decide what to do first
                   • Only unfinished tasks appear on the wheel
                   • Each task has an equal chance of being picked
                   • Tap "Spin Again" if you want to try again
                """
            case .calendar:
                return """
                How to use the Calendar:

                1. Viewing your tasks:
                   • Go to the Calendar tab
                   • Days with tasks have dots under them
                   • Tap any date to see its tasks
                   • Tasks are color-coded by importance

                2. Navigation:
                   • Use arrows to move between months
                   • Tap "View All" to see everything
                   • Tasks are sorted by due date
                   • Today's date is highlighted

                3. Understanding the display:
                   • Red tasks are high priority
                   • Orange tasks are medium priority
                   • Blue tasks are low priority
                   • Each task shows its due date
                """
            case .settings:
                return """
                How to customize your app:

                1. Changing colors:
                   • Tap the gear icon at the top
                   • Move the sliders to pick your favorite color
                   • Watch the preview change
                   • Tap "Reset to Default" to go back

                2. Dark/Light mode:
                   • Turn off "Use System Settings"
                   • Toggle "Dark Mode" on or off
                   • Pick what's easier on your eyes

                3. Organizing tabs:
                   • Scroll down to "Tab Configuration"
                   • Toggle switches to show/hide tabs
                   • Hold and drag ≡ to change order
                   • Tap "Done" when finished
                """
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome section
                    VStack(spacing: 16) {
                        // App icon and title
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.themeColor.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(themeManager.themeColor)
                            }
                            
                            Text("Welcome to Canvo!")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.themeColor)
                        }
                        
                        // App description
                        VStack(spacing: 8) {
                            Text("Your friendly task manager and Canvas helper")
                                .font(.headline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("Tap any section below to learn how to use it")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemBackground))
                            .shadow(color: Color.black.opacity(0.05), radius: 10)
                    )
                    
                    // Tutorial sections
                    ForEach(TutorialSection.allCases, id: \.self) { section in
                        TutorialSectionView(
                            section: section,
                            isExpanded: expandedSection == section,
                            themeColor: themeManager.themeColor
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                expandedSection = expandedSection == section ? nil : section
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("How to Use Canvo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.themeColor)
                }
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

struct TutorialSectionView: View {
    let section: TutorialView.TutorialSection
    let isExpanded: Bool
    let themeColor: Color
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button(action: onTap) {
                HStack {
                    // Icon with background
                    ZStack {
                        Circle()
                            .fill(themeColor.opacity(0.1))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: section.icon)
                            .foregroundColor(themeColor)
                            .font(.system(size: 18))
                    }
                    
                    Text(section.rawValue)
                        .font(.headline)
                        .foregroundColor(themeColor)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(themeColor)
                        .font(.system(size: 20))
                }
                .padding()
                .background(Color(.systemBackground))
            }
            
            // Content
            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(section.content.components(separatedBy: "\n\n"), id: \.self) { section in
                        if section.hasPrefix("How to") {
                            Text(section)
                                .font(.headline)
                                .foregroundColor(themeColor)
                                .padding(.bottom, 4)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                let lines = section.components(separatedBy: "\n")
                                if let title = lines.first {
                                    HStack {
                                        Text(title)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(themeColor)
                                        
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 8)
                                    .background(themeColor.opacity(0.1))
                                    .cornerRadius(6)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(lines.dropFirst(), id: \.self) { line in
                                        HStack(alignment: .top, spacing: 12) {
                                            Text("•")
                                                .foregroundColor(themeColor)
                                            Text(line.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "• ", with: ""))
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                                .padding(.leading, 4)
                            }
                        }
                    }
                }
                .padding()
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5)
    }
}

#Preview {
    TutorialView()
        .environmentObject(ThemeManager())
} 