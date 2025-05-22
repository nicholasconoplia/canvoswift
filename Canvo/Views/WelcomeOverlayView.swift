import SwiftUI

struct WelcomeOverlayView: View {
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var isAnimating = false
    @State private var currentTutorialStep = 0
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showTutorial = false
    
    private let tutorialSteps = [
        (title: "Tasks", description: "Organize your assignments, quizzes, and personal tasks in one place", icon: "checklist"),
        (title: "Calendar", description: "View your schedule and upcoming deadlines at a glance", icon: "calendar"),
        (title: "Smart Spinner", description: "Let Canvo intelligently distribute your tasks throughout the week", icon: "arrow.triangle.2.circlepath"),
        (title: "Timetable", description: "See your optimized study schedule with built-in breaks", icon: "clock")
    ]
    
    var body: some View {
        GeometryReader { geometry in
            if !hasSeenTutorial {
                ZStack {
                    // Semi-transparent black overlay
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                    
                    // Welcome popup
                    VStack(spacing: 24) {
                        // App icon and welcome text
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.themeColor.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                
                                Image("logooutline")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60)
                            }
                            
                            Text("🎉 Welcome to Canvo!")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.themeColor)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Tutorial steps
                        if showTutorial {
                            TabView(selection: $currentTutorialStep) {
                                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                                    VStack(spacing: 16) {
                                        Image(systemName: tutorialSteps[index].icon)
                                            .font(.system(size: 40))
                                            .foregroundColor(themeManager.themeColor)
                                        
                                        Text(tutorialSteps[index].title)
                                            .font(.headline)
                                        
                                        Text(tutorialSteps[index].description)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .tag(index)
                                    .padding()
                                }
                            }
                            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                            .frame(height: 200)
                            
                            // Navigation dots
                            HStack(spacing: 8) {
                                ForEach(0..<tutorialSteps.count, id: \.self) { index in
                                    Circle()
                                        .fill(currentTutorialStep == index ? themeManager.themeColor : Color.gray)
                                        .frame(width: 8, height: 8)
                                }
                            }
                            .padding(.top, 8)
                        }
                        
                        // Buttons
                        VStack(spacing: 16) {
                            if !showTutorial {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        showTutorial = true
                                    }
                                }) {
                                    Text("Show me around")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeManager.themeColor)
                                        .cornerRadius(12)
                                }
                                
                                Button(action: {
                                    withAnimation(.spring()) {
                                        hasSeenTutorial = true
                                    }
                                }) {
                                    Text("Skip Tutorial")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                            } else {
                                Button(action: {
                                    withAnimation(.spring()) {
                                        if currentTutorialStep < tutorialSteps.count - 1 {
                                            currentTutorialStep += 1
                                        } else {
                                            hasSeenTutorial = true
                                        }
                                    }
                                }) {
                                    Text(currentTutorialStep < tutorialSteps.count - 1 ? "Next" : "Get Started")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(themeManager.themeColor)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(32)
                    .background(Color(.systemBackground))
                    .cornerRadius(24)
                    .shadow(radius: 20)
                    .padding(.horizontal, 32)
                    .scaleEffect(isAnimating ? 1 : 0.5)
                    .opacity(isAnimating ? 1 : 0)
                }
                .onAppear {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isAnimating = true
                    }
                }
            }
        }
    }
}

#Preview {
    WelcomeOverlayView()
        .environmentObject(ThemeManager())
} 