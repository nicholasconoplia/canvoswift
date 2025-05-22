import SwiftUI

struct WelcomeOverlayView: View {
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @EnvironmentObject private var themeManager: ThemeManager
    
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
                            
                            Text("Let's get started!")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: {
                            withAnimation {
                                hasSeenTutorial = true
                            }
                        }) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(themeManager.themeColor)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding(24)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(radius: 20)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: min(geometry.size.width - 64, 400))
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

#Preview {
    WelcomeOverlayView()
        .environmentObject(ThemeManager())
} 