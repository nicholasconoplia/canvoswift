import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var systemColorScheme
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = true
    @AppStorage("useCloudKitSync") private var useCloudKitSync = false
    @AppStorage("enableNotifications") private var enableNotifications = true
    @State private var jsonPreview: String = ""
    @State private var isLoadingJSON = false
    @State private var devModeCounter = 0
    @AppStorage("developerMode_enabled") private var developerModeEnabled = false
    @AppStorage("developer_identifier") private var developerIdentifier = ""
    @State private var showingCloudKitAlert = false
    @State private var showingCloudKitBackupAlert = false
    @State private var backupSuccess = false
    @State private var showingBackupResultAlert = false
    
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
                
                // Notifications section
                Section(header: Text("Notifications")) {
                    Toggle("Enable Notifications", isOn: $enableNotifications)
                        .onChange(of: enableNotifications) { newValue in
                            if newValue {
                                // Re-request permissions if notifications are enabled
                                NotificationManager.shared.requestPermission()
                            }
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
                
                // Cloud Sync section (renamed to Cloud Kit with Beta tag)
                Section(header: Text("Cloud Sync")) {
                    Toggle("Cloud Kit (Beta)", isOn: $useCloudKitSync)
                        .help("When off, your data is only stored locally on this device.")
                        .onChange(of: useCloudKitSync) { newValue in
                            if newValue {
                                showingCloudKitAlert = true
                            } else {
                                // When turning off CloudKit, show backup alert
                                showingCloudKitBackupAlert = true
                            }
                        }
                }
                
                // Hidden developer mode section - only appears when activated
                if developerModeEnabled {
                    Section(header: Text("Developer Tools")) {
                        Toggle("Developer Mode", isOn: $developerModeEnabled)
                        
                        if developerModeEnabled {
                            TextField("Developer Identifier", text: $developerIdentifier)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }
                    
                    // JSON preview section - moved inside developer mode
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
                
                // App info section with hidden developer mode trigger
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0") // Update with your app version
                            .foregroundColor(.gray)
                            .onTapGesture(count: 7) {
                                // Secret tap gesture (tap 7 times on version number)
                                activateDeveloperMode()
                            }
                    }
                    
                    // Other about items...
                }
            }
            .navigationTitle("Settings")
            .navigationBarItems(trailing: Button("Done") {
                print("DEBUG: Settings - Done button tapped")
                dismiss()
            })
            .preferredColorScheme(themeManager.useSystemAppearance ? nil : (themeManager.isDarkMode ? .dark : .light))
            .environment(\.editMode, .constant(.active))
            .onAppear {
                print("DEBUG: Settings - View appeared")
                loadJSONPreview()
            }
            .onDisappear {
                print("DEBUG: Settings - View disappeared")
            }
            .alert("Cloud Kit Beta Feature", isPresented: $showingCloudKitAlert) {
                Button("OK", role: .cancel) { }
                Button("Turn Off", role: .destructive) {
                    useCloudKitSync = false
                }
            } message: {
                Text("This feature is still in beta. It may cause crashes or freezing. Use with caution.")
            }
            .alert("Back Up CloudKit Data?", isPresented: $showingCloudKitBackupAlert) {
                Button("Don't Back Up", role: .cancel) {
                    // User chose not to back up, just proceed with turning off CloudKit
                    print("User declined CloudKit backup")
                }
                Button("Back Up to Local", role: .none) {
                    // User wants to back up their CloudKit data to local storage
                    backupSuccess = DataManager.backupCloudKitDataToLocal()
                    showingBackupResultAlert = true
                }
            } message: {
                Text("Would you like to back up your current CloudKit data to local storage? This will replace your previous local data with the current CloudKit data.")
            }
            .alert(backupSuccess ? "Backup Successful" : "Backup Failed", isPresented: $showingBackupResultAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(backupSuccess ? 
                     "Your CloudKit data has been successfully backed up to local storage." : 
                     "Failed to back up CloudKit data. Your local data remains unchanged.")
            }
        }
    }
    
    private func loadJSONPreview() {
        print("DEBUG: Settings - Starting JSON preview load")
        isLoadingJSON = true
        DispatchQueue.global(qos: .userInitiated).async {
            print("DEBUG: Settings - Background thread: Loading JSON file")
            let fileURL = DataManager.iCloudArchiveURL ?? DataManager.archiveURL
            var preview = ""
            do {
                let data = try Data(contentsOf: fileURL)
                if let jsonString = String(data: data, encoding: .utf8) {
                    preview = jsonString
                    print("DEBUG: Settings - JSON file loaded successfully")
                }
            } catch {
                print("DEBUG: Settings - Error loading JSON: \(error)")
                preview = "(Error loading JSON: \(error.localizedDescription))"
            }
            
            DispatchQueue.main.async {
                print("DEBUG: Settings - Updating UI with JSON preview")
                self.jsonPreview = preview
                self.isLoadingJSON = false
            }
        }
    }
    
    // Hidden developer mode activation
    private func activateDeveloperMode() {
        devModeCounter += 1
        
        if devModeCounter >= 5 {
            developerModeEnabled = true
            devModeCounter = 0
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
} 