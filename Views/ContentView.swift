import SwiftUI
import SwiftData

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitService: HealthKitService
    @Environment(\.modelContext) private var modelContext
    @State private var isInitialized = false
    
    var body: some View {
        Group {
            if !isInitialized {
                SplashScreenView()
            } else if appState.isOnboardingComplete {
                DashboardTabView()
                    .environmentObject(healthKitService)
            } else {
                OnboardingView()
                    .environmentObject(healthKitService)
            }
        }
        .onAppear {
            setupApp()
        }
        .animation(.easeInOut(duration: 0.5), value: isInitialized)
        .animation(.easeInOut(duration: 0.3), value: appState.isOnboardingComplete)
    }
    
    private func setupApp() {
        // Initialize DataService with SwiftData context
        DataService.shared.setModelContext(modelContext)
        
        // Check HealthKit authorization status
        healthKitService.checkAuthorizationStatus()
        
        // Simulate app initialization delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isInitialized = true
            }
        }
    }
}

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.purple.opacity(0.8), .blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .pink.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
                
                VStack(spacing: 8) {
                    Text("CYCLEai Tracker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .opacity(opacity)
                    
                    Text("Your Intelligent Health Companion")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(opacity)
                }
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environmentObject(HealthKitService.shared)
        .modelContainer(for: [
            CycleDataModel.self,
            SymptomModel.self,
            HormoneReadingModel.self,
            MoodEntryModel.self
        ])
}