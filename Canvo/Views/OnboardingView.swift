import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("useCanvas") private var useCanvas = false
    @State private var showCanvasAPIGuide = false
    @State private var showPreferences = false
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Welcome message
                VStack(spacing: 16) {
                    Image("logooutline")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100)
                    
                    Text("Let's set Canvo up for you")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("We'll help you customize Canvo to fit your workflow")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                // Canvas Integration Question
                VStack(spacing: 20) {
                    Text("Do you use Canvas at your university?")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            useCanvas = true
                            showCanvasAPIGuide = true
                        }) {
                            Text("Yes")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.themeColor)
                                .cornerRadius(12)
                        }
                        
                        Button(action: {
                            useCanvas = false
                            showPreferences = true
                        }) {
                            Text("No")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .sheet(isPresented: $showCanvasAPIGuide) {
                CanvasAPIGuideView(showPreferences: $showPreferences)
            }
            .sheet(isPresented: $showPreferences) {
                NavigationView {
                    UserPreferencesView()
                        .navigationTitle("Preferences")
                        .navigationBarItems(trailing: Button("Done") {
                            hasCompletedOnboarding = true
                            dismiss()
                        })
                }
            }
        }
    }
}

struct CanvasAPIGuideView: View {
    @Binding var showPreferences: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Getting Your Canvas API Token")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        stepView(number: 1, text: "Log in to your Canvas account")
                        stepView(number: 2, text: "Go to Account > Settings")
                        stepView(number: 3, text: "Scroll down to 'Approved Integrations'")
                        stepView(number: 4, text: "Click '+ New Access Token'")
                        stepView(number: 5, text: "Name it 'Canvo' and generate the token")
                        stepView(number: 6, text: "Copy and paste the token in Canvo settings later")
                    }
                    
                    Text("Note: If you can't access tokens, contact your school's IT department for assistance.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    Button(action: {
                        dismiss()
                        showPreferences = true
                    }) {
                        Text("Continue to Preferences")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.themeColor)
                            .cornerRadius(12)
                    }
                    .padding(.top, 32)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Skip") {
                dismiss()
                showPreferences = true
            })
        }
    }
    
    private func stepView(number: Int, text: String) -> some View {
        HStack(spacing: 16) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(themeManager.themeColor)
                .clipShape(Circle())
            
            Text(text)
                .font(.body)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(ThemeManager())
} 