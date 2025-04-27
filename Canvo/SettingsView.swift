import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Settings will go here.")
                Spacer() // Pushes content to the top
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

#Preview {
    SettingsView()
} 