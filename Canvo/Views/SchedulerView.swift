import SwiftUI

struct SchedulerView: View {
    @State private var busyBlocks: [BusyBlock] = []

    var body: some View {
        NavigationView {
            BusyTimeSetupView(busyBlocks: $busyBlocks)
                .navigationTitle("Scheduler Setup")
        }
    }
}

#Preview {
    SchedulerView()
} 