import SwiftUI

struct WorkTimePreferenceView: View {
    @State private var preferences = UserPreferences.load()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("When do you prefer to work?")) {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(UserPreferences.WorkTimePreference.allCases, id: \.self) { preference in
                            let displayText = preference.displayText
                            PreferenceOption(
                                title: displayText.title,
                                subtitle: displayText.subtitle,
                                systemImage: displayText.icon,
                                isSelected: preferences.workTimePreferences.contains(preference),
                                themeColor: themeManager.themeColor
                            ) {
                                if preferences.workTimePreferences.contains(preference) {
                                    preferences.workTimePreferences.remove(preference)
                                } else {
                                    preferences.workTimePreferences.insert(preference)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section(footer: Text("Select one or more time periods when you're most productive. You can change this later in settings.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Work Time Preference")
            .navigationBarItems(
                trailing: Button("Done") {
                    // Ensure at least one preference is selected
                    if preferences.workTimePreferences.isEmpty {
                        preferences.workTimePreferences.insert(.morning)
                    }
                    preferences.save()
                    dismiss()
                }
            )
        }
    }
}

struct PreferenceOption: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool
    let themeColor: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundColor(isSelected ? themeColor : .gray)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(themeColor)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    WorkTimePreferenceView()
        .environmentObject(ThemeManager())
} 