import Foundation
import SwiftUI

struct Constants {
    
    // MARK: - App Configuration
    struct App {
        static let name = "CYCLEai Tracker"
        static let version = "1.0.0"
        static let build = "2025.09.02"
        static let developer = "Manan Rastogi"
        static let bundleIdentifier = "com.mananrastogi.cycleai-tracker"
    }
    
    // MARK: - UserDefaults Keys
    struct UserDefaultsKeys {
        static let onboardingComplete = "OnboardingComplete"
        static let firstLaunch = "FirstLaunch"
        static let lastSyncDate = "LastSyncDate"
        static let notificationsEnabled = "NotificationsEnabled"
        static let healthKitEnabled = "HealthKitEnabled"
        static let darkModePreference = "DarkModePreference"
        static let cycleLength = "CycleLength"
        static let periodLength = "PeriodLength"
        static let lastPeriodDate = "LastPeriodDate"
    }
    
    // MARK: - Cycle Defaults
    struct CycleDefaults {
        static let averageCycleLength = 28
        static let averagePeriodLength = 5
        static let minimumCycleLength = 21
        static let maximumCycleLength = 35
        static let minimumPeriodLength = 3
        static let maximumPeriodLength = 8
        static let ovulationDayOffset = 14
        static let fertilityWindowDays = 6
        static let lutealPhaseLength = 14
    }
    
    // MARK: - UI Constants
    struct UI {
        static let cornerRadius: CGFloat = 12
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 8
        static let animationDuration: Double = 0.3
        static let springAnimation = Animation.spring(response: 0.6, dampingFraction: 0.8)
        
        struct Spacing {
            static let xs: CGFloat = 4
            static let sm: CGFloat = 8
            static let md: CGFloat = 16
            static let lg: CGFloat = 24
            static let xl: CGFloat = 32
        }
        
        struct Padding {
            static let card: CGFloat = 20
            static let screen: CGFloat = 16
            static let button: CGFloat = 16
        }
    }
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.purple
        static let secondary = Color.blue
        static let accent = Color.pink
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
        
        struct Phase {
            static let menstrual = Color.red
            static let follicular = Color.blue
            static let ovulatory = Color.green
            static let luteal = Color.orange
        }
        
        struct Fertility {
            static let low = Color.blue
            static let medium = Color.yellow
            static let high = Color.orange
            static let peak = Color.red
        }
        
        struct Severity {
            static let minimal = Color.green
            static let mild = Color.yellow
            static let moderate = Color.orange
            static let severe = Color.red
            static let extreme = Color.purple
        }
    }
    
    // MARK: - Fonts
    struct Fonts {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.semibold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.medium)
        static let headline = Font.headline.weight(.semibold)
        static let subheadline = Font.subheadline.weight(.medium)
        static let body = Font.body
        static let callout = Font.callout
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Icons
    struct Icons {
        static let dashboard = "house.fill"
        static let symptoms = "heart.text.square.fill"
        static let hormones = "chart.line.uptrend.xyaxis"
        static let calendar = "calendar"
        static let settings = "gearshape.fill"
        static let healthKit = "heart.fill"
        static let ai = "brain.head.profile"
        static let notification = "bell.fill"
        static let sync = "arrow.clockwise"
        static let export = "square.and.arrow.up"
        static let import = "square.and.arrow.down"
        static let profile = "person.circle.fill"
        static let privacy = "lock.shield.fill"
        static let help = "questionmark.circle.fill"
        static let about = "info.circle.fill"
    }
    
    // MARK: - Notification Identifiers
    struct NotificationIdentifiers {
        static let periodReminder = "period_reminder"
        static let ovulationReminder = "ovulation_reminder"
        static let symptomReminder = "symptom_reminder"
        static let medicationReminder = "medication_reminder"
        static let cycleInsight = "cycle_insight"
    }
    
    // MARK: - HealthKit Identifiers
    struct HealthKit {
        static let menstrualFlow = "HKCategoryTypeIdentifierMenstrualFlow"
        static let cervicalMucus = "HKCategoryTypeIdentifierCervicalMucusQuality"
        static let basalBodyTemperature = "HKQuantityTypeIdentifierBasalBodyTemperature"
        static let heartRate = "HKQuantityTypeIdentifierHeartRate"
        static let sleepAnalysis = "HKCategoryTypeIdentifierSleepAnalysis"
        static let steps = "HKQuantityTypeIdentifierStepCount"
        static let weight = "HKQuantityTypeIdentifierBodyMass"
    }
    
    // MARK: - Data Limits
    struct DataLimits {
        static let maxSymptomsPerDay = 20
        static let maxNotesLength = 500
        static let maxHormoneReadingsPerDay = 10
        static let maxMoodEntriesPerDay = 5
        static let dataRetentionDays = 1095 // 3 years
        static let syncBatchSize = 100
    }
    
    // MARK: - API Configuration
    struct API {
        static let baseURL = "https://api.cycleai.com/v1"
        static let timeout: TimeInterval = 30
        static let maxRetries = 3
        static let rateLimitDelay: TimeInterval = 1
    }
    
    // MARK: - Feature Flags
    struct FeatureFlags {
        static let aiInsightsEnabled = true
        static let healthKitSyncEnabled = true
        static let cloudSyncEnabled = true
        static let advancedChartsEnabled = true
        static let partnerSharingEnabled = false
        static let medicationTrackingEnabled = true
        static let exportDataEnabled = true
        static let biometricAuthEnabled = true
    }
    
    // MARK: - Validation Rules
    struct Validation {
        static let minAge = 13
        static let maxAge = 65
        static let minCycleLength = 21
        static let maxCycleLength = 45
        static let minPeriodLength = 1
        static let maxPeriodLength = 10
        static let maxFutureDateDays = 365
        static let maxPastDateDays = 1095
    }
    
    // MARK: - Chart Configuration
    struct Charts {
        static let maxDataPoints = 90
        static let animationDuration: Double = 1.0
        static let lineWidth: CGFloat = 3
        static let pointRadius: CGFloat = 4
        static let gridLineWidth: CGFloat = 1
        static let chartHeight: CGFloat = 200
    }
    
    // MARK: - Accessibility
    struct Accessibility {
        static let minimumTapTarget: CGFloat = 44
        static let preferredContentSizeCategory = ContentSizeCategory.large
        static let reduceMotionEnabled = false
        static let voiceOverEnabled = false
    }
    
    // MARK: - Error Messages
    struct ErrorMessages {
        static let genericError = "Something went wrong. Please try again."
        static let networkError = "Network connection error. Please check your internet connection."
        static let dataError = "Unable to save data. Please try again."
        static let healthKitError = "HealthKit access denied. Please enable in Settings."
        static let validationError = "Please check your input and try again."
        static let syncError = "Unable to sync data. Please try again later."
        static let exportError = "Unable to export data. Please try again."
        static let importError = "Unable to import data. Please check the file format."
    }
    
    // MARK: - Success Messages
    struct SuccessMessages {
        static let dataSaved = "Data saved successfully"
        static let dataExported = "Data exported successfully"
        static let dataImported = "Data imported successfully"
        static let syncCompleted = "Sync completed successfully"
        static let settingsUpdated = "Settings updated successfully"
        static let notificationScheduled = "Reminder set successfully"
    }
    
    // MARK: - URLs
    struct URLs {
        static let privacyPolicy = "https://cycleai.com/privacy"
        static let termsOfService = "https://cycleai.com/terms"
        static let support = "https://cycleai.com/support"
        static let feedback = "mailto:feedback@cycleai.com"
        static let appStore = "https://apps.apple.com/app/cycleai-tracker"
        static let website = "https://cycleai.com"
    }
    
    // MARK: - File Paths
    struct FilePaths {
        static let documentsDirectory = "Documents"
        static let backupDirectory = "Backups"
        static let exportDirectory = "Exports"
        static let cacheDirectory = "Cache"
        static let tempDirectory = "Temp"
    }
    
    // MARK: - Date Formats
    struct DateFormats {
        static let display = "MMM d, yyyy"
        static let short = "MM/dd/yy"
        static let long = "EEEE, MMMM d, yyyy"
        static let time = "h:mm a"
        static let dateTime = "MMM d, yyyy 'at' h:mm a"
        static let iso8601 = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        static let api = "yyyy-MM-dd"
    }
}