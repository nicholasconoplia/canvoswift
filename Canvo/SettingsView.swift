import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Appearance")) {
                    Toggle("Use System Settings", isOn: $themeManager.useSystemAppearance)
                    
                    if !themeManager.useSystemAppearance {
                        Toggle("Dark Mode", isOn: $themeManager.isDarkMode)
                    }
                }
                
                Section(header: Text("App Theme Color")) {
                    VStack(alignment: .leading) {
                        Text("Preview")
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(themeManager.themeColor)
                            .cornerRadius(10)
                        
                        VStack(spacing: 20) {
                            HStack {
                                Text("Hue")
                                Slider(value: $themeManager.hue, in: 0...1)
                                    .tint(Color(hue: themeManager.hue, saturation: 1, brightness: 1))
                            }
                            
                            HStack {
                                Text("Saturation")
                                Slider(value: $themeManager.saturation, in: 0...1)
                                    .tint(themeManager.themeColor)
                            }
                            
                            HStack {
                                Text("Lightness")
                                Slider(value: $themeManager.lightness, in: 0...1)
                                    .tint(themeManager.themeColor)
                            }
                        }
                        
                        Button("Reset to Default") {
                            themeManager.resetToDefault()
                        }
                        .padding(.top)
                    }
                }
                
                // Add other settings sections here
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .preferredColorScheme(themeManager.useSystemAppearance ? nil : (themeManager.isDarkMode ? .dark : .light))
        }
    }
}

#Preview {
    SettingsView()
} 