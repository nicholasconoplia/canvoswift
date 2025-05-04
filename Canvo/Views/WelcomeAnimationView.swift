import SwiftUI
import AVFoundation
import CoreText

struct BlobShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        // Create a blob-like shape with bezier curves
        path.move(to: CGPoint(x: width * 0.4, y: height * 0.2))
        path.addCurve(
            to: CGPoint(x: width * 0.8, y: height * 0.3),
            control1: CGPoint(x: width * 0.5, y: height * 0.1),
            control2: CGPoint(x: width * 0.7, y: height * 0.1)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.9, y: height * 0.7),
            control1: CGPoint(x: width * 0.9, y: height * 0.4),
            control2: CGPoint(x: width, y: height * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.6, y: height * 0.9),
            control1: CGPoint(x: width * 0.8, y: height * 0.9),
            control2: CGPoint(x: width * 0.7, y: height)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.2, y: height * 0.7),
            control1: CGPoint(x: width * 0.4, y: height * 0.8),
            control2: CGPoint(x: width * 0.2, y: height * 0.9)
        )
        path.addCurve(
            to: CGPoint(x: width * 0.4, y: height * 0.2),
            control1: CGPoint(x: width * 0.2, y: height * 0.5),
            control2: CGPoint(x: width * 0.3, y: height * 0.3)
        )
        
        return path
    }
}

struct WelcomeAnimationView: View {
    @State private var isActive = false
    @State private var blobScale: CGFloat = 0.1
    @State private var blobOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var buttonOffset: CGFloat = 50
    @State private var buttonOpacity: Double = 0
    @State private var blobRotation: Double = 0
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.8
    @State private var flickerIntensity: Double = 1.0
    @State private var audioPlayer: AVAudioPlayer?
    @State private var characterOffsets: [CGFloat]
    @State private var characterOpacities: [Double]
    @State private var characterBlurs: [CGFloat]
    @Binding var showWelcome: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @State private var logoBlur: CGFloat = 40
    @State private var logoGaussianBlur: CGFloat = 40
    @State private var logoOffset: CGFloat = 1000 // Start well below screen
    @State private var elementsScale: CGFloat = 1
    @State private var elementsOpacity: Double = 1
    
    private let welcomeText = "Welcome to Canvo."
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    init(showWelcome: Binding<Bool>) {
        self._showWelcome = showWelcome
        // Initialize animation states for each character
        let textLength = "Welcome to Canvo.".count
        self._characterOffsets = State(initialValue: Array(repeating: 20, count: textLength))
        self._characterOpacities = State(initialValue: Array(repeating: 0, count: textLength))
        self._characterBlurs = State(initialValue: Array(repeating: 10, count: textLength))
        
        // Register custom font
        if let fontURL = Bundle.main.url(forResource: "MarlinSoftSQ-ExtraBold", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
        }
    }
    
    func flickerAnimation() {
        // First flicker - faster duration (0.08s)
        withAnimation(.easeInOut(duration: 0.08)) {
            logoOpacity = 0.3
            logoGaussianBlur = 5
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation(.easeInOut(duration: 0.08)) {
                logoOpacity = 1
                logoGaussianBlur = 0
            }
            
            // Second flicker - shorter delay (0.15s) and faster duration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeInOut(duration: 0.08)) {
                    logoOpacity = 0.3
                    logoGaussianBlur = 5
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeInOut(duration: 0.08)) {
                        logoOpacity = 1
                        logoGaussianBlur = 0
                    }
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black
                .ignoresSafeArea()
            
            // Theme-colored background that fades in
            themeManager.themeColor.opacity(0.8)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)
            
            // Noise overlay
            Image("noise-light")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blendMode(.overlay)
                .opacity(0.15)
                .ignoresSafeArea()
            
            // Blob and logo
            ZStack {
                // Blob animation
                BlobShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.themeColor.opacity(0.95),
                                themeManager.themeColor.opacity(0.8),
                                themeManager.themeColor.opacity(0.7)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(blobScale)
                    .opacity(blobOpacity)
                    .blur(radius: 30)
                    .rotationEffect(.degrees(blobRotation))
                    .overlay(
                        BlobShape()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.4),
                                        Color.clear
                                    ]),
                                    center: .topLeading,
                                    startRadius: 0,
                                    endRadius: 300
                                )
                            )
                            .frame(width: 300, height: 300)
                            .scaleEffect(blobScale)
                            .opacity(blobOpacity * 0.8)
                            .blur(radius: 20)
                            .rotationEffect(.degrees(blobRotation))
                            .blendMode(.plusLighter)
                    )
                
                // Noise overlay for blob
                BlobShape()
                    .fill(
                        ImagePaint(image: Image("noise-light"))
                    )
                    .frame(width: 300, height: 300)
                    .scaleEffect(blobScale)
                    .opacity(blobOpacity * 0.15)
                    .blur(radius: 30)
                    .rotationEffect(.degrees(blobRotation))
                    .blendMode(.overlay)
                
                // Logo
                Image("logooutline")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200)
                    .opacity(logoOpacity * flickerIntensity)
                    .scaleEffect(logoScale)
                    .blur(radius: logoBlur)
                    .blur(radius: logoGaussianBlur)
                    .offset(y: logoOffset)
            }
            
            // Welcome text and button
            VStack(spacing: 20) {
                // Animated welcome text
                HStack(spacing: 0) {
                    ForEach(Array(welcomeText.enumerated()), id: \.offset) { index, character in
                        Text(String(character))
                            .font(.custom("MarlinSoftSQ-ExtraBold", size: 34))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .offset(y: characterOffsets[index])
                            .blur(radius: characterBlurs[index])
                            .opacity(characterOpacities[index])
                    }
                }
                
                // Enter button
                Button(action: {
                    // Start fading out the music
                    if let player = audioPlayer {
                        // Start from current volume
                        let startVolume = player.volume
                        let steps = 20
                        let fadeOutDuration = 0.6 // Match animation duration
                        let stepDuration = fadeOutDuration / Double(steps)
                        
                        for i in 0..<steps {
                            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepDuration) {
                                player.volume = startVolume * Float(steps - i - 1) / Float(steps)
                            }
                        }
                        
                        // Stop the player after fade out
                        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
                            player.stop()
                        }
                    }
                    
                    // Animate all elements collapsing and fading out
                    withAnimation(.easeInOut(duration: 0.6)) {
                        elementsScale = 0.7
                        elementsOpacity = 0
                        blobScale = 0.3
                        blobOpacity = 0
                        backgroundOpacity = 0
                    }
                    
                    // After animation completes, dismiss the view
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            hasSeenWelcome = true
                            showWelcome = false
                        }
                    }
                }) {
                    ZStack {
                        // White rectangle background
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 56, height: 36)
                        
                        // Arrow
                        Image(systemName: "arrow.right")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(themeManager.themeColor)
                    }
                }
                .offset(y: buttonOffset)
                .opacity(buttonOpacity)
            }
            .scaleEffect(elementsScale)
            .opacity(elementsOpacity)
        }
        .onReceive(timer) { _ in
            // Create random flicker effect during fade out
            if logoOpacity > 0 && logoOpacity < 0.3 {
                flickerIntensity = Double.random(in: 0.3...1.0)
            }
        }
        .onAppear {
            // Play sound if available
            if let soundURL = Bundle.main.url(forResource: "welcome", withExtension: "mp3") {
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                    audioPlayer?.prepareToPlay()
                    audioPlayer?.play()
                } catch {
                    print("Failed to play welcome sound: \(error.localizedDescription)")
                }
            }
            
            // Initial blob appearance
            withAnimation(.easeInOut(duration: 0.8)) {
                blobOpacity = 1
                blobScale = 0.8 // Set initial size
            }
            
            // Start rotation animation
            withAnimation(
                .linear(duration: 4.0)
                .repeatCount(1, autoreverses: false)
            ) {
                blobRotation = 360
            }
            
            // Expand blob after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation(.easeInOut(duration: 2.0)) {
                    blobScale = 10
                    backgroundOpacity = 1
                }
                
                // Initialize logo at bottom
                logoOpacity = 0
                logoScale = 1
                logoBlur = 40
                logoGaussianBlur = 40
                logoOffset = 1000 // Start well below screen
                
                // Animate from bottom to middle with ease-in-out
                withAnimation(
                    .timingCurve(0.6, 0.0, 0.2, 1.0, duration: 1.2) // Custom ease-in-out curve
                ) {
                    logoOpacity = 1
                    logoBlur = 0
                    logoGaussianBlur = 0
                    logoOffset = 0 // Stop in the middle
                }
                
                // After reaching center, perform double flicker
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    flickerAnimation()
                    
                    // After flicker and pause, animate to top
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        withAnimation(
                            .timingCurve(0.4, 0.0, 0.2, 1.0, duration: 1.2) // Custom ease-in curve for exit
                        ) {
                            logoOpacity = 0
                            logoBlur = 40
                            logoGaussianBlur = 40
                            logoOffset = -1000 // Move well above screen
                        }
                        
                        // Start text animation after logo exits
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            // Animate text characters
                            let characterDelay = 0.1
                            
                            for (index, _) in welcomeText.enumerated() {
                                let delay = Double(index) * characterDelay
                                
                                // Set initial state
                                characterBlurs[index] = 20
                                characterOpacities[index] = 0
                                
                                // Animate in with blur reveal
                                withAnimation(
                                    .easeOut(duration: 0.8)
                                    .delay(delay)
                                ) {
                                    characterBlurs[index] = 0
                                    characterOpacities[index] = 1
                                    characterOffsets[index] = 0
                                }
                            }
                            
                            // Animate button after text
                            let textAnimationDuration = Double(welcomeText.count) * characterDelay
                            let buttonDelay = textAnimationDuration + 0.3
                            
                            DispatchQueue.main.asyncAfter(deadline: .now() + buttonDelay) {
                                withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                                    buttonOffset = 0
                                }
                                withAnimation(.easeOut(duration: 0.8)) {
                                    buttonOpacity = 1
                                }
                            }
                        }
                    }
                }
            }
        }
    }
} 