import SwiftUI
import SwiftData

@main
struct CYCLEai_TrackerApp: App {
    // StateObjects to manage global app state and services
    @StateObject private var appState = AppState()
    @StateObject private var healthKitService = HealthKitService.shared
    @StateObject private var dataService = DataService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(healthKitService)
                .environmentObject(dataService)
                .onAppear {
                    // Request necessary permissions on app launch
                    NotificationService.shared.requestPermissions()
                    healthKitService.checkAuthorizationStatus()
                    if !healthKitService.isAuthorized {
                        healthKitService.requestAuthorization()
                    }
                }
        }
        // Defines the SwiftData models the app will use for persistence
        .modelContainer(for: [
            CycleDataModel.self,
            SymptomModel.self,
            HormoneReadingModel.self,
            MoodEntryModel.self,
            NotificationModel.self
        ])
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: "OnboardingComplete")
        }
    }
    
    @Published var selectedTab: Int = 0
    @Published var showingSettings: Bool = false

    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "OnboardingComplete")
    }

    func completeOnboarding() {
        isOnboardingComplete = true
    }
    
    func resetApp() {
        isOnboardingComplete = false
        UserDefaults.standard.removeObject(forKey: "OnboardingComplete")
    }
}