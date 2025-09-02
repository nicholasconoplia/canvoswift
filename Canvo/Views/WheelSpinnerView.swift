import SwiftUI
import CoreHaptics

struct WheelSpinnerView: View {
    @Binding var taskLists: [TaskList]
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var rotation: Double = 0
    @State private var isSpinning: Bool = false
    @State private var selectedTaskName: String = ""
    @State private var showSelectedTask: Bool = false
    @State private var spinDuration: Double = 5.0
    @State private var rotationTimer: Timer?
    @State private var startRotation: Double = 0
    @State private var targetRotation: Double = 0
    @State private var animationProgress: Double = 0
    @State private var hapticEngine: CHHapticEngine?
    
    // Computed property to get all incomplete tasks
    private var incompleteTasks: [Task] {
        var tasks: [Task] = []
        for list in taskLists {
            tasks.append(contentsOf: list.tasks.filter { !$0.isCompleted })
        }
        return tasks
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if incompleteTasks.isEmpty {
                    emptyStateView
                } else {
                    Spacer(minLength: 20)
                    
                    // Container to hold wheel
                    wheelView(size: min(geometry.size.width * 0.9, geometry.size.height * 0.6))
                        .rotationEffect(.degrees(rotation))
                    
                    Spacer(minLength: 40)
                    
                    spinButton
                    
                    Spacer(minLength: 20)
                    
                    if showSelectedTask {
                        selectedTaskView
                    }
                    
                    Spacer(minLength: 20)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear(perform: prepareHaptics)
        }
        .background(Color(.systemBackground))
    }
    
    // Function to create a darker version of the theme color
    private func darkerThemeColor(percentage: Double = 0.3) -> Color {
        // Extract HSB components
        let uiColor = UIColor(themeManager.themeColor)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        // Create darker color by reducing brightness
        let darkerBrightness = max(0, brightness - CGFloat(percentage))
        return Color(UIColor(hue: hue, saturation: saturation, brightness: darkerBrightness, alpha: alpha))
    }
    
    // View when there are no incomplete tasks
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80))
                .foregroundColor(themeManager.themeColor)
            
            Text("All tasks completed!")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(themeManager.themeColor)
            
            Text("Add new tasks from the Tasks tab")
                .foregroundColor(.gray)
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity)
    }
    
    // The wheel view with all incomplete tasks
    private func wheelView(size: CGFloat) -> some View {
        ZStack {
            // Outer wheel circle
            Circle()
                .fill(themeManager.themeColor.opacity(0.2))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
            
            // Combined wheel sections and text
            ForEach(0..<incompleteTasks.count, id: \.self) { index in
                let angle = Double(index) * (360.0 / Double(incompleteTasks.count))
                let sectionAngle = 360.0 / Double(incompleteTasks.count)
                let midAngle = angle + (sectionAngle / 2)
                
                // Create section
                WheelSectionWithText(
                    task: incompleteTasks[index],
                    startAngle: angle,
                    endAngle: angle + sectionAngle,
                    color: index % 2 == 0 ? 
                        themeManager.themeColor.opacity(0.7) : 
                        darkerThemeColor().opacity(0.85),
                    size: size
                )
            }
            
            // Center circle
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [themeManager.themeColor.opacity(0.8), themeManager.themeColor]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.25, height: size * 0.25)
                .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                .overlay(
                    Text("SPIN")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
        }
    }
    
    // Spin button
    private var spinButton: some View {
        Button(action: spinWheel) {
            Text("Spin the Wheel")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 30)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [themeManager.themeColor.opacity(0.8), themeManager.themeColor]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
        .disabled(isSpinning)
        .opacity(isSpinning ? 0.6 : 1)
        .scaleEffect(isSpinning ? 0.95 : 1)
        .animation(.easeInOut(duration: 0.2), value: isSpinning)
    }
    
    // Selected task view that appears after spinning
    private var selectedTaskView: some View {
        VStack(spacing: 20) {
            Text("Your task is:")
                .font(.title3)
                .foregroundColor(.gray)
            
            Text(selectedTaskName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(themeManager.themeColor)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(themeManager.themeColor.opacity(0.1))
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 1)
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
        )
        .transition(.scale.combined(with: .opacity))
    }
    
    // Function to spin the wheel
    private func spinWheel() {
        guard !incompleteTasks.isEmpty else { return }
        
        isSpinning = true
        showSelectedTask = false
        
        // Save start position
        startRotation = rotation
        
        // Generate a random number of rotations (between 2 and 5 full rotations)
        let rotations = Double.random(in: 720...1800)
        
        // Calculate target position
        targetRotation = startRotation + rotations
        
        // Set up animation duration
        spinDuration = Double.random(in: 4.0...6.0)
        animationProgress = 0
        
        // Invalidate any existing timer
        rotationTimer?.invalidate()
        
        // Use standard SwiftUI animation with our completion handler
        withAnimation(.easeInOut(duration: spinDuration)) {
            rotation = targetRotation
        }
        
        // Use a delayed action for completion
        DispatchQueue.main.asyncAfter(deadline: .now() + spinDuration) {
            selectFinalTask()
        }
    }
    
    // Easing function for smooth acceleration and deceleration
    private func easeInOutQuart(_ x: Double) -> Double {
        // x < 0.5 ? 8 * x * x * x * x : 1 - pow(-2 * x + 2, 4) / 2
        if x < 0.5 {
            return 8 * x * x * x * x
        } else {
            let t = -2 * x + 2
            return 1 - t * t * t * t / 2
        }
    }
    
    // Determine which task is selected after spinning
    private func selectFinalTask() {
        // Calculate which segment is at the top after spinning
        let segmentAngle = 360.0 / Double(incompleteTasks.count)
        let normalizedRotation = rotation.truncatingRemainder(dividingBy: 360)
        let selectedIndex = Int(floor(normalizedRotation / segmentAngle))
        let adjustedIndex = (incompleteTasks.count - selectedIndex - 1) % incompleteTasks.count
        
        if incompleteTasks.indices.contains(adjustedIndex) {
            selectedTaskName = incompleteTasks[adjustedIndex].name
            
            // Play haptic feedback when the task is selected
            playSelectionHaptic()
            
            withAnimation {
                showSelectedTask = true
            }
        }
        
        isSpinning = false
    }
    
    // MARK: - Haptic Feedback
    
    // Prepare the haptic engine
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            hapticEngine = try CHHapticEngine()
            try hapticEngine?.start()
        } catch {
            print("Error creating haptic engine: \(error.localizedDescription)")
        }
    }
    
    // Play a selection haptic pattern
    private func playSelectionHaptic() {
        // Fall back to basic haptic if advanced haptics aren't available
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics,
              let engine = hapticEngine else {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
            return
        }
        
        // Create an advanced haptic pattern
        var events = [CHHapticEvent]()
        
        // Create a sharp tap
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        events.append(event)
        
        // Add a continuous haptic that fades out
        let continuous = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0.1,
            duration: 0.3
        )
        events.append(continuous)
        
        // Create and start the pattern
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            print("Failed to play haptic pattern: \(error.localizedDescription)")
        }
    }
}

// Combined view for wheel section and text
struct WheelSectionWithText: View {
    let task: Task
    let startAngle: Double
    let endAngle: Double
    let color: Color
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Section background
            Sector(
                startAngle: .degrees(startAngle),
                endAngle: .degrees(endAngle)
            )
            .fill(color)
            
            // Text label
            let midAngle = startAngle + ((endAngle - startAngle) / 2)
            let midRadians = midAngle * .pi / 180
            let radius = size * 0.35
            let xPosition = radius * cos(midRadians - .pi/2)
            let yPosition = radius * sin(midRadians - .pi/2)
            let textRotation = midAngle > 90 && midAngle < 270 ? midAngle + 180 : midAngle
            
            Text(task.name)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: size * 0.3, height: size * 0.15)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)
                .rotationEffect(.degrees(textRotation))
                .position(
                    x: size / 2 + xPosition,
                    y: size / 2 + yPosition
                )
        }
        .frame(width: size, height: size)
    }
}

// Sector shape for wheel sections
struct Sector: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        path.closeSubpath()
        
        return path
    }
}

// Preview provider for WheelSpinnerView
struct WheelSpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        WheelSpinnerView(taskLists: .constant([
            TaskList(name: "Test List", tasks: [
                Task(name: "Task 1", isCompleted: false),
                Task(name: "Task 2", isCompleted: false),
                Task(name: "Task 3", isCompleted: true),
                Task(name: "Task 4", isCompleted: false)
            ])
        ]))
        .environmentObject(ThemeManager())
    }
} 