import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = true
    @State private var jsonPreview: String = ""
    @State private var isLoadingJSON = false
    
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
                
                Section(header: Text("Tab Configuration")) {
                    ForEach($themeManager.tabItems) { $item in
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundColor(themeManager.themeColor)
                            
                            Text(item.name)
                            
                            Spacer()
                            
                            Toggle("", isOn: $item.isVisible)
                        }
                    }
                    .onMove { from, to in
                        var updatedItems = themeManager.tabItems
                        updatedItems.move(fromOffsets: from, toOffset: to)
                        
                        // Update order values
                        for (index, var item) in updatedItems.enumerated() {
                            item.order = index
                            updatedItems[index] = item
                        }
                        
                        themeManager.tabItems = updatedItems
                    }
                }
                
                Section(header: Text("Welcome Animation")) {
                    Button(action: {
                        hasSeenWelcome = false
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(themeManager.themeColor)
                            Text("Replay Welcome Animation")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Section(header: Text("JSON File Preview (iCloud/Local)")) {
                    if isLoadingJSON {
                        ProgressView("Loading JSON...")
                    } else {
                        ScrollView(.horizontal) {
                            ScrollView(.vertical) {
                                Text(jsonPreview)
                                    .font(.system(.body, design: .monospaced))
                                    .padding(4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(minHeight: 120, maxHeight: 300)
                        Button("Reload JSON Preview") {
                            loadJSONPreview()
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .preferredColorScheme(themeManager.useSystemAppearance ? nil : (themeManager.isDarkMode ? .dark : .light))
            .environment(\.editMode, .constant(.active))
            .onAppear {
                loadJSONPreview()
            }
        }
    }
    
    private func loadJSONPreview() {
        isLoadingJSON = true
        DispatchQueue.global(qos: .userInitiated).async {
            let fileURL = DataManager.iCloudArchiveURL ?? DataManager.archiveURL
            var preview = ""
            if let data = try? Data(contentsOf: fileURL),
               let jsonString = String(data: data, encoding: .utf8) {
                preview = jsonString
            } else {
                preview = "(No JSON file found at \(fileURL.lastPathComponent))"
            }
            DispatchQueue.main.async {
                self.jsonPreview = preview
                self.isLoadingJSON = false
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
} 