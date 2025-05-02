import SwiftUI

struct WelcomeOverlayView: View {
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @State private var isAnimating = false
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showTutorial = false
    
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
                                
                                Image(systemName: "star.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(themeManager.themeColor)
                            }
                            
                            Text("Welcome to Canvo!")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(themeManager.themeColor)
                                .multilineTextAlignment(.center)
                        }
                        
                        // Buttons
                        VStack(spacing: 16) {
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
                            
                            Button(action: {
                                withAnimation(.spring()) {
                                    hasSeenTutorial = true
                                    showTutorial = true
                                }
                            }) {
                                Text("Full Guide")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(themeManager.themeColor)
                                    .cornerRadius(12)
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
        .sheet(isPresented: $showTutorial) {
            TutorialView()
        }
    }
}

#Preview {
    WelcomeOverlayView()
        .environmentObject(ThemeManager())
} 