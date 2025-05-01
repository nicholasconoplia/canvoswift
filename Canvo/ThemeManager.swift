import SwiftUI
import Combine

class ThemeManager: ObservableObject {
    @Published var themeColor: Color {
        didSet {
            objectWillChange.send()
        }
    }
    
    @Published var hue: Double {
        didSet {
            UserDefaults.standard.set(hue, forKey: "themeHue")
            updateThemeColor()
        }
    }
    
    @Published var saturation: Double {
        didSet {
            UserDefaults.standard.set(saturation, forKey: "themeSaturation")
            updateThemeColor()
        }
    }
    
    @Published var lightness: Double {
        didSet {
            UserDefaults.standard.set(lightness, forKey: "themeLightness")
            updateThemeColor()
        }
    }
    
    @Published var useSystemAppearance: Bool {
        didSet {
            UserDefaults.standard.set(useSystemAppearance, forKey: "useSystemAppearance")
        }
    }
    
    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: "isDarkMode")
        }
    }
    
    init() {
        // First load saved values
        let savedHue = UserDefaults.standard.double(forKey: "themeHue")
        let savedSaturation = UserDefaults.standard.double(forKey: "themeSaturation")
        let savedLightness = UserDefaults.standard.double(forKey: "themeLightness")
        
        // Set initial values
        let initialHue: Double
        let initialSaturation: Double
        let initialLightness: Double
        
        // Use saved values or defaults
        if savedHue == 0 && savedSaturation == 0 && savedLightness == 0 {
            initialHue = 0.75 // Purple hue
            initialSaturation = 0.6
            initialLightness = 0.6
        } else {
            initialHue = savedHue
            initialSaturation = savedSaturation
            initialLightness = savedLightness
        }
        
        // Initialize properties
        self.themeColor = Color(hue: initialHue, 
                              saturation: initialSaturation, 
                              brightness: initialLightness)
        self.hue = initialHue
        self.saturation = initialSaturation
        self.lightness = initialLightness
        
        // Initialize appearance mode properties
        self.useSystemAppearance = UserDefaults.standard.bool(forKey: "useSystemAppearance")
        self.isDarkMode = UserDefaults.standard.bool(forKey: "isDarkMode")
    }
    
    private func updateThemeColor() {
        themeColor = Color(hue: hue, saturation: saturation, brightness: lightness)
    }
    
    func resetToDefault() {
        hue = 0.75 // Purple hue
        saturation = 0.6
        lightness = 0.6
        useSystemAppearance = true
        isDarkMode = false
    }
} 