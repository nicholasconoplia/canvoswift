import SwiftUI

struct SchedulerView: View {
    var body: some View {
        TimetableView()
    }
}

#Preview {
    SchedulerView()
        .environmentObject(ThemeManager())
} 