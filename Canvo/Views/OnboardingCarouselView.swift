import SwiftUI

struct CarouselItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
}

struct OnboardingCarouselView: View {
    let useCanvas: Bool
    @Binding var showPreferences: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var carouselItems: [CarouselItem] {
        var items = [
            CarouselItem(
                title: "Tasks",
                description: "Organize your work and stay on top of deadlines with our smart task management system.",
                imageName: "checklist"
            ),
            CarouselItem(
                title: "Spin the Wheel",
                description: "Need help deciding what to work on? Let our wheel of tasks help you choose!",
                imageName: "circle.grid.3x3"
            ),
            CarouselItem(
                title: "Timetable",
                description: "View your schedule at a glance and plan your day effectively.",
                imageName: "calendar"
            ),
            CarouselItem(
                title: "Settings",
                description: "Customize Canvo to match your workflow and preferences.",
                imageName: "gearshape"
            )
        ]
        
        if useCanvas {
            items.insert(
                CarouselItem(
                    title: "Canvas Integration",
                    description: "Sync your assignments and deadlines directly from Canvas.",
                    imageName: "link"
                ),
                at: 1
            )
        }
        
        return items
    }
    
    @State private var currentIndex = 0
    
    var body: some View {
        NavigationView {
            VStack {
                TabView(selection: $currentIndex) {
                    ForEach(Array(carouselItems.enumerated()), id: \.element.id) { index, item in
                        VStack(spacing: 24) {
                            Image(systemName: item.imageName)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .foregroundColor(themeManager.themeColor)
                            
                            Text(item.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(item.description)
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .tag(index)
                        .padding()
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                
                Button(action: {
                    if currentIndex < carouselItems.count - 1 {
                        withAnimation {
                            currentIndex += 1
                        }
                    } else {
                        showPreferences = true
                        dismiss()
                    }
                }) {
                    Text(currentIndex < carouselItems.count - 1 ? "Next" : "Continue to Setup")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeManager.themeColor)
                        .cornerRadius(12)
                }
                .padding()
            }
            .navigationBarItems(trailing: Button("Skip") {
                showPreferences = true
                dismiss()
            })
        }
    }
}

#Preview {
    OnboardingCarouselView(useCanvas: true, showPreferences: .constant(false))
        .environmentObject(ThemeManager())
} 