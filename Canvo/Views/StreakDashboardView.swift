import SwiftUI

struct StreakDashboardView: View {
    @EnvironmentObject private var streakService: StreakService
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showingConfetti = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("🔥 Streaks Dashboard")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Daily Streak Card
            StreakCard(
                title: "Consistency Streak",
                emoji: "🔥",
                level: streakService.streakModel.dailyStreakLevel,
                progress: streakService.streakModel.dailyStreakProgress,
                streakCount: streakService.streakModel.dailyStreak,
                totalCount: streakService.streakModel.totalDailyStreakDays,
                description: "You've opened Canvo \(streakService.streakModel.dailyStreak) days in a row!"
            )
            
            // Weekly Study Streak Card
            StreakCard(
                title: "Study Rhythm",
                emoji: "📚",
                level: streakService.streakModel.weeklyStudyStreakLevel,
                progress: streakService.streakModel.weeklyStudyStreakProgress,
                streakCount: streakService.streakModel.weeklyStudyStreak,
                totalCount: streakService.streakModel.totalWeeklyStudyWeeks,
                description: "You've studied for \(streakService.streakModel.weeklyStudyStreak) weeks in a row!"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .onReceive(NotificationCenter.default.publisher(for: .showConfetti)) { _ in
            showingConfetti = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                showingConfetti = false
            }
        }
        .overlay {
            if showingConfetti {
                ConfettiView()
            }
        }
    }
}

struct StreakCard: View {
    let title: String
    let emoji: String
    let level: Int
    let progress: Double
    let streakCount: Int
    let totalCount: Int
    let description: String
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("\(emoji) \(title)")
                    .font(.headline)
                Spacer()
                Text("Level \(level)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    // Progress
                    RoundedRectangle(cornerRadius: 5)
                        .fill(themeManager.themeColor)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
            
            // Description
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Total Stats
            Text("Total: \(totalCount) \(title == "Consistency Streak" ? "days" : "weeks")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct ConfettiView: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(0..<50) { index in
                ConfettiPiece(
                    position: CGPoint(
                        x: CGFloat.random(in: 0...geometry.size.width),
                        y: -20
                    ),
                    color: [Color.red, Color.blue, Color.green, Color.yellow, Color.purple].randomElement()!
                )
                .offset(y: isAnimating ? geometry.size.height + 100 : 0)
                .animation(
                    Animation.linear(duration: Double.random(in: 2...3))
                        .delay(Double.random(in: 0...0.5))
                        .repeatCount(1),
                    value: isAnimating
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

struct ConfettiPiece: View {
    let position: CGPoint
    let color: Color
    @State private var rotation = Double.random(in: 0...360)
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .position(position)
            .rotationEffect(.degrees(rotation))
            .animation(
                Animation.linear(duration: 2)
                    .repeatForever(autoreverses: false),
                value: rotation
            )
            .onAppear {
                rotation += 360
            }
    }
} 