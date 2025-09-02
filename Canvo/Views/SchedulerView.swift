import SwiftUI

struct SchedulerView: View {
    @State private var busyBlocks: [BusyBlock] = []
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            BusyTimeSetupView(busyBlocks: $busyBlocks)
                .navigationTitle("Scheduler Setup")
                .environmentObject(themeManager)
        }
    }
}

#Preview {
    SchedulerView()
        .environmentObject(ThemeManager())
} 