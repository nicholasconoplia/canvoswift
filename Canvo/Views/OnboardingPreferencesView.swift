import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case workingHours
    case workingDays
    case workTimePreferences
    case sessionPreferences
    case breakPreferences
    case complete
    
    var title: String {
        switch self {
        case .workingHours: return "Working Hours"
        case .workingDays: return "Working Days"
        case .workTimePreferences: return "Work Time Preferences"
        case .sessionPreferences: return "Session Length"
        case .breakPreferences: return "Break Preferences"
        case .complete: return "All Set!"
        }
    }
    
    var description: String {
        switch self {
        case .workingHours: return "When do you usually work best during the day?"
        case .workingDays: return "Which days would you like to work?"
        case .workTimePreferences: return "What times of day do you feel most productive?"
        case .sessionPreferences: return "How long do you like to focus in one go?"
        case .breakPreferences: return "Let's set up your break schedule"
        case .complete: return "Your preferences are all set! You can always change these later in Settings."
        }
    }
}

struct OnboardingPreferencesView: View {
    @State private var preferences = UserPreferences.load()
    @State private var currentStep: OnboardingStep = .workingHours
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var themeManager: ThemeManager
    
    private let weekdays = [
        (1, "Sunday"),
        (2, "Monday"),
        (3, "Tuesday"),
        (4, "Wednesday"),
        (5, "Thursday"),
        (6, "Friday"),
        (7, "Saturday")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Progress indicator
                ProgressView(value: Double(currentStep.rawValue), total: Double(OnboardingStep.allCases.count - 1))
                    .tint(themeManager.themeColor)
                    .padding(.horizontal)
                
                // Title and description
                VStack(spacing: 8) {
                    Text(currentStep.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(currentStep.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Step content
                ScrollView {
                    VStack(spacing: 24) {
                        switch currentStep {
                        case .workingHours:
                            workingHoursView
                        case .workingDays:
                            workingDaysView
                        case .workTimePreferences:
                            workTimePreferencesView
                        case .sessionPreferences:
                            sessionPreferencesView
                        case .breakPreferences:
                            breakPreferencesView
                        case .complete:
                            completeView
                        }
                    }
                    .padding()
                }
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentStep != .workingHours {
                        Button(action: previousStep) {
                            Text("Back")
                                .font(.headline)
                                .foregroundColor(themeManager.themeColor)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                    
                    Button(action: nextStep) {
                        Text(currentStep == .complete ? "Get Started" : "Continue")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.themeColor)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            .navigationBarHidden(true)
        }
    }
    
    private var workingHoursView: some View {
        VStack(spacing: 24) {
            HStack {
                Image(systemName: "sunrise")
                    .font(.title)
                    .foregroundColor(themeManager.themeColor)
                
                DatePicker(
                    "Start Time",
                    selection: Binding(
                        get: { preferences.workingHours.startTime },
                        set: { preferences.workingHours.startTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
            
            HStack {
                Image(systemName: "sunset")
                    .font(.title)
                    .foregroundColor(themeManager.themeColor)
                
                DatePicker(
                    "End Time",
                    selection: Binding(
                        get: { preferences.workingHours.endTime },
                        set: { preferences.workingHours.endTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }
    
    private var workingDaysView: some View {
        VStack(spacing: 16) {
            ForEach(weekdays, id: \.0) { weekday in
                Toggle(weekday.1, isOn: Binding(
                    get: { preferences.workingDays.contains(weekday.0) },
                    set: { isOn in
                        if isOn {
                            preferences.workingDays.insert(weekday.0)
                        } else {
                            preferences.workingDays.remove(weekday.0)
                        }
                    }
                ))
                .tint(themeManager.themeColor)
            }
        }
    }
    
    private var workTimePreferencesView: some View {
        VStack(spacing: 16) {
            ForEach(UserPreferences.WorkTimePreference.allCases, id: \.rawValue) { preference in
                Button(action: {
                    if preferences.workTimePreferences.contains(preference) {
                        preferences.workTimePreferences.remove(preference)
                    } else {
                        preferences.workTimePreferences.insert(preference)
                    }
                }) {
                    HStack {
                        Image(systemName: preferences.workTimePreferences.contains(preference) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(themeManager.themeColor)
                        
                        VStack(alignment: .leading) {
                            Text(preference.displayText.title)
                                .font(.headline)
                            Text(preference.displayText.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private var sessionPreferencesView: some View {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Session Duration")
                    .font(.headline)
                Text("How long would you like each focus session to be?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Stepper(
                    "\(Int(preferences.preferredSessionDuration)) minutes",
                    value: Binding(
                        get: { preferences.preferredSessionDuration },
                        set: { preferences.preferredSessionDuration = $0 }
                    ),
                    in: 15...120,
                    step: 15
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Sessions")
                    .font(.headline)
                Text("What's your target number of sessions per day?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Stepper(
                    "\(preferences.maximumSessionsPerDay) sessions",
                    value: Binding(
                        get: { preferences.maximumSessionsPerDay },
                        set: { preferences.maximumSessionsPerDay = $0 }
                    ),
                    in: 1...12
                )
            }
        }
    }
    
    private var breakPreferencesView: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Break Duration")
                    .font(.headline)
                Text("How long would you like your breaks to be?")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Stepper(
                    "\(Int(preferences.minimumBreakBetweenSessions)) minutes",
                    value: Binding(
                        get: { preferences.minimumBreakBetweenSessions },
                        set: { preferences.minimumBreakBetweenSessions = $0 }
                    ),
                    in: 0...60,
                    step: 5
                )
            }
        }
    }
    
    private var completeView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(themeManager.themeColor)
            
            Text("You're all set!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your preferences have been saved. You can always adjust them later in Settings.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private func nextStep() {
        if currentStep == .complete {
            preferences.save()
            hasCompletedOnboarding = true
            dismiss()
        } else {
            withAnimation {
                currentStep = OnboardingStep(rawValue: currentStep.rawValue + 1) ?? .complete
            }
        }
    }
    
    private func previousStep() {
        withAnimation {
            currentStep = OnboardingStep(rawValue: currentStep.rawValue - 1) ?? .workingHours
        }
    }
}

#Preview {
    OnboardingPreferencesView()
        .environmentObject(ThemeManager())
} 