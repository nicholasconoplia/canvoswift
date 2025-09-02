import SwiftUI

struct WorkTimePreferenceView: View {
    @Binding var preferences: UserPreferences
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section(header: Text("When do you prefer to work?")) {
                ForEach(UserPreferences.WorkTimePreference.allCases, id: \.self) { preference in
                    let isSelected = preferences.workTimePreferences.contains(preference)
                    let displayText = preference.displayText
                    
                    Button(action: {
                        if isSelected {
                            preferences.workTimePreferences.remove(preference)
                        } else {
                            preferences.workTimePreferences.insert(preference)
                        }
                    }) {
                        HStack {
                            Image(systemName: displayText.icon)
                                .foregroundColor(isSelected ? .accentColor : .secondary)
                            
                            VStack(alignment: .leading) {
                                Text(displayText.title)
                                    .foregroundColor(isSelected ? .primary : .secondary)
                                Text(displayText.subtitle)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("Work Time Preferences")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    preferences.save()
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    WorkTimePreferenceView(preferences: .constant(UserPreferences.load()))
} 