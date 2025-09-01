import SwiftUI
import SwiftData

@main
struct CYCLEai_TrackerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var healthKitService = HealthKitService.shared
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(healthKitService)
                .environmentObject(notificationService)
                .onAppear {
                    setupApp()
                }
                .preferredColorScheme(appState.preferredColorScheme)
        }
        .modelContainer(for: [
            CycleDataModel.self,
            SymptomModel.self,
            HormoneReadingModel.self,
            MoodEntryModel.self,
            MedicationModel.self,
            NoteModel.self
        ])
    }
    
    private func setupApp() {
        notificationService.requestPermissions()
        
        if !healthKitService.isAuthorized && appState.isOnboardingComplete {
            healthKitService.requestAuthorization()
        }
        
        scheduleBackgroundTasks()
        configureAppearance()
    }
    
    private func scheduleBackgroundTasks() {
        notificationService.schedulePeriodicReminders()
    }
    
    private func configureAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground
        appearance.titleTextAttributes = [.foregroundColor: UIColor.label]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: "OnboardingComplete")
        }
    }
    
    @Published var preferredColorScheme: ColorScheme? {
        didSet {
            if let scheme = preferredColorScheme {
                UserDefaults.standard.set(scheme == .dark ? "dark" : "light", forKey: "PreferredColorScheme")
            } else {
                UserDefaults.standard.removeObject(forKey: "PreferredColorScheme")
            }
        }
    }
    
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "NotificationsEnabled")
        }
    }
    
    @Published var reminderTime: Date {
        didSet {
            UserDefaults.standard.set(reminderTime, forKey: "ReminderTime")
        }
    }
    
    @Published var privacyMode: Bool {
        didSet {
            UserDefaults.standard.set(privacyMode, forKey: "PrivacyMode")
        }
    }
    
    @Published var dataExportEnabled: Bool {
        didSet {
            UserDefaults.standard.set(dataExportEnabled, forKey: "DataExportEnabled")
        }
    }
    
    @Published var selectedLanguage: String {
        didSet {
            UserDefaults.standard.set(selectedLanguage, forKey: "SelectedLanguage")
        }
    }
    
    @Published var temperatureUnit: TemperatureUnit {
        didSet {
            UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "TemperatureUnit")
        }
    }
    
    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "OnboardingComplete")
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "NotificationsEnabled") as? Bool ?? true
        self.privacyMode = UserDefaults.standard.bool(forKey: "PrivacyMode")
        self.dataExportEnabled = UserDefaults.standard.object(forKey: "DataExportEnabled") as? Bool ?? true
        self.selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
        
        if let reminderData = UserDefaults.standard.object(forKey: "ReminderTime") as? Date {
            self.reminderTime = reminderData
        } else {
            let calendar = Calendar.current
            self.reminderTime = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
        }
        
        if let colorSchemeString = UserDefaults.standard.string(forKey: "PreferredColorScheme") {
            self.preferredColorScheme = colorSchemeString == "dark" ? .dark : .light
        } else {
            self.preferredColorScheme = nil
        }
        
        if let tempUnitString = UserDefaults.standard.string(forKey: "TemperatureUnit"),
           let tempUnit = TemperatureUnit(rawValue: tempUnitString) {
            self.temperatureUnit = tempUnit
        } else {
            self.temperatureUnit = .celsius
        }
    }
    
    func completeOnboarding() {
        isOnboardingComplete = true
    }
    
    func resetApp() {
        isOnboardingComplete = false
        preferredColorScheme = nil
        notificationsEnabled = true
        privacyMode = false
        dataExportEnabled = true
        selectedLanguage = "en"
        temperatureUnit = .celsius
        reminderTime = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

enum TemperatureUnit: String, CaseIterable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"
    
    var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    var displayName: String {
        switch self {
        case .celsius: return "Celsius"
        case .fahrenheit: return "Fahrenheit"
        }
    }
    
    func convert(_ value: Double, to unit: TemperatureUnit) -> Double {
        if self == unit { return value }
        
        switch (self, unit) {
        case (.celsius, .fahrenheit):
            return (value * 9/5) + 32
        case (.fahrenheit, .celsius):
            return (value - 32) * 5/9
        default:
            return value
        }
    }
}