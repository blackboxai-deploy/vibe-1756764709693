import SwiftUI
import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    @Published var isOnboardingComplete: Bool {
        didSet {
            UserDefaults.standard.set(isOnboardingComplete, forKey: "OnboardingComplete")
        }
    }
    
    @Published var currentUser: UserProfile? {
        didSet {
            if let user = currentUser {
                saveUserProfile(user)
            }
        }
    }
    
    @Published var appTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(appTheme.rawValue, forKey: "AppTheme")
        }
    }
    
    @Published var notificationsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "NotificationsEnabled")
        }
    }
    
    @Published var healthKitSyncEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(healthKitSyncEnabled, forKey: "HealthKitSyncEnabled")
        }
    }
    
    @Published var dataExportEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(dataExportEnabled, forKey: "DataExportEnabled")
        }
    }
    
    @Published var reminderSettings: ReminderSettings {
        didSet {
            saveReminderSettings(reminderSettings)
        }
    }
    
    @Published var privacySettings: PrivacySettings {
        didSet {
            savePrivacySettings(privacySettings)
        }
    }
    
    @Published var isFirstLaunch: Bool = true
    @Published var lastSyncDate: Date?
    @Published var appVersion: String = "1.0.0"
    @Published var buildNumber: String = "2025.01.01"
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        self.isOnboardingComplete = UserDefaults.standard.bool(forKey: "OnboardingComplete")
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "NotificationsEnabled") as? Bool ?? true
        self.healthKitSyncEnabled = UserDefaults.standard.bool(forKey: "HealthKitSyncEnabled")
        self.dataExportEnabled = UserDefaults.standard.object(forKey: "DataExportEnabled") as? Bool ?? true
        self.lastSyncDate = UserDefaults.standard.object(forKey: "LastSyncDate") as? Date
        
        // Load theme
        if let themeRawValue = UserDefaults.standard.object(forKey: "AppTheme") as? String,
           let theme = AppTheme(rawValue: themeRawValue) {
            self.appTheme = theme
        } else {
            self.appTheme = .system
        }
        
        // Load user profile
        self.currentUser = loadUserProfile()
        
        // Load reminder settings
        self.reminderSettings = loadReminderSettings()
        
        // Load privacy settings
        self.privacySettings = loadPrivacySettings()
        
        // Check if first launch
        self.isFirstLaunch = !UserDefaults.standard.bool(forKey: "HasLaunchedBefore")
        if isFirstLaunch {
            UserDefaults.standard.set(true, forKey: "HasLaunchedBefore")
        }
        
        // Load app version info
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            self.appVersion = version
        }
        if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            self.buildNumber = build
        }
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    func completeOnboarding() {
        isOnboardingComplete = true
    }
    
    func resetOnboarding() {
        isOnboardingComplete = false
    }
    
    func updateLastSyncDate() {
        lastSyncDate = Date()
        UserDefaults.standard.set(lastSyncDate, forKey: "LastSyncDate")
    }
    
    func resetAppState() {
        // Reset all user defaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "OnboardingComplete")
        defaults.removeObject(forKey: "UserProfile")
        defaults.removeObject(forKey: "ReminderSettings")
        defaults.removeObject(forKey: "PrivacySettings")
        defaults.removeObject(forKey: "AppTheme")
        defaults.removeObject(forKey: "NotificationsEnabled")
        defaults.removeObject(forKey: "HealthKitSyncEnabled")
        defaults.removeObject(forKey: "DataExportEnabled")
        defaults.removeObject(forKey: "LastSyncDate")
        
        // Reset published properties
        isOnboardingComplete = false
        currentUser = nil
        appTheme = .system
        notificationsEnabled = true
        healthKitSyncEnabled = false
        dataExportEnabled = true
        reminderSettings = ReminderSettings()
        privacySettings = PrivacySettings()
        lastSyncDate = nil
    }
    
    func createUserProfile(name: String, age: Int, cycleLength: Int = 28, periodLength: Int = 5) {
        let profile = UserProfile(name: name, age: age)
        var updatedProfile = profile
        updatedProfile.averageCycleLength = cycleLength
        updatedProfile.averagePeriodLength = periodLength
        currentUser = updatedProfile
    }
    
    func updateUserProfile(_ updates: (inout UserProfile) -> Void) {
        guard var profile = currentUser else { return }
        updates(&profile)
        currentUser = profile
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Observe app lifecycle events
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.saveAppState()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.saveAppState()
            }
            .store(in: &cancellables)
    }
    
    private func saveAppState() {
        // Save any pending state changes
        UserDefaults.standard.synchronize()
    }
    
    private func saveUserProfile(_ profile: UserProfile) {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "UserProfile")
        }
    }
    
    private func loadUserProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "UserProfile"),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return nil
        }
        return profile
    }
    
    private func saveReminderSettings(_ settings: ReminderSettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "ReminderSettings")
        }
    }
    
    private func loadReminderSettings() -> ReminderSettings {
        guard let data = UserDefaults.standard.data(forKey: "ReminderSettings"),
              let settings = try? JSONDecoder().decode(ReminderSettings.self, from: data) else {
            return ReminderSettings()
        }
        return settings
    }
    
    private func savePrivacySettings(_ settings: PrivacySettings) {
        if let encoded = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encoded, forKey: "PrivacySettings")
        }
    }
    
    private func loadPrivacySettings() -> PrivacySettings {
        guard let data = UserDefaults.standard.data(forKey: "PrivacySettings"),
              let settings = try? JSONDecoder().decode(PrivacySettings.self, from: data) else {
            return PrivacySettings()
        }
        return settings
    }
}

// MARK: - Supporting Types
enum AppTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

struct ReminderSettings: Codable {
    var periodReminder: Bool = true
    var ovulationReminder: Bool = true
    var symptomReminder: Bool = true
    var medicationReminder: Bool = false
    
    var periodReminderDays: Int = 1
    var ovulationReminderDays: Int = 2
    var symptomReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date()
    var medicationReminderTimes: [Date] = []
    
    var reminderSound: String = "default"
    var vibrationEnabled: Bool = true
}

struct PrivacySettings: Codable {
    var dataEncryption: Bool = true
    var biometricLock: Bool = false
    var autoLockTimeout: Int = 300 // 5 minutes in seconds
    var shareDataWithHealthKit: Bool = false
    var shareDataWithPartner: Bool = false
    var anonymousAnalytics: Bool = true
    var crashReporting: Bool = true
}

// MARK: - Extensions
extension AppState {
    var isHealthKitAvailable: Bool {
        return healthKitSyncEnabled && currentUser != nil
    }
    
    var shouldShowOnboarding: Bool {
        return !isOnboardingComplete || currentUser == nil
    }
    
    var daysSinceLastSync: Int? {
        guard let lastSync = lastSyncDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastSync, to: Date()).day
    }
    
    func formattedLastSyncDate() -> String {
        guard let lastSync = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
}