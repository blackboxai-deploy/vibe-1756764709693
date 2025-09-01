import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    
    private let center = UNUserNotificationCenter.current()
    
    private init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestPermissions() {
        center.requestAuthorization(options: [.alert, .badge, .sound, .provisional]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if let error = error {
                    print("❌ Notification permission error: \(error.localizedDescription)")
                } else {
                    print("✅ Notification permissions granted: \(granted)")
                }
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    func checkAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.authorizationStatus = settings.authorizationStatus
                self?.isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            }
        }
    }
    
    // MARK: - Cycle Notifications
    
    func schedulePeriodReminder(for date: Date, cycleLength: Int) {
        guard isAuthorized else { return }
        
        let identifier = "period_reminder"
        
        // Cancel existing period reminders
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Period Reminder"
        content.body = "Your period is expected to start today. Don't forget to log it!"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "PERIOD_CATEGORY"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling period reminder: \(error.localizedDescription)")
            } else {
                print("✅ Period reminder scheduled for \(date)")
            }
        }
        
        // Schedule next cycle reminder
        if let nextPeriodDate = calendar.date(byAdding: .day, value: cycleLength, to: date) {
            scheduleNextPeriodReminder(for: nextPeriodDate, cycleLength: cycleLength)
        }
    }
    
    private func scheduleNextPeriodReminder(for date: Date, cycleLength: Int) {
        let identifier = "next_period_reminder"
        
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Next Period Coming"
        content.body = "Your next period is expected in 3 days. Time to prepare!"
        content.sound = .default
        content.categoryIdentifier = "PERIOD_CATEGORY"
        
        let calendar = Calendar.current
        let reminderDate = calendar.date(byAdding: .day, value: -3, to: date) ?? date
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling next period reminder: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleOvulationReminder(for date: Date) {
        guard isAuthorized else { return }
        
        let identifier = "ovulation_reminder"
        
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Ovulation Window"
        content.body = "You're entering your fertile window. Ovulation is expected today!"
        content.sound = .default
        content.categoryIdentifier = "FERTILITY_CATEGORY"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling ovulation reminder: \(error.localizedDescription)")
            } else {
                print("✅ Ovulation reminder scheduled for \(date)")
            }
        }
    }
    
    func scheduleFertilityWindowReminder(startDate: Date) {
        guard isAuthorized else { return }
        
        let identifier = "fertility_window_start"
        
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Fertile Window Starting"
        content.body = "Your fertile window begins today. Track your symptoms for better predictions!"
        content.sound = .default
        content.categoryIdentifier = "FERTILITY_CATEGORY"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: startDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling fertility window reminder: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Daily Reminders
    
    func scheduleDailySymptomReminder(at time: DateComponents) {
        guard isAuthorized else { return }
        
        let identifier = "daily_symptom_reminder"
        
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Daily Check-in"
        content.body = "How are you feeling today? Log your symptoms and mood."
        content.sound = .default
        content.categoryIdentifier = "DAILY_REMINDER_CATEGORY"
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling daily symptom reminder: \(error.localizedDescription)")
            } else {
                print("✅ Daily symptom reminder scheduled")
            }
        }
    }
    
    func scheduleWeeklyDataReview() {
        guard isAuthorized else { return }
        
        let identifier = "weekly_data_review"
        
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        
        let content = UNMutableNotificationContent()
        content.title = "Weekly Cycle Review"
        content.body = "Check out your cycle insights and patterns from this week!"
        content.sound = .default
        content.categoryIdentifier = "INSIGHTS_CATEGORY"
        
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 10
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling weekly review reminder: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Medication Reminders
    
    func scheduleMedicationReminder(name: String, times: [DateComponents]) {
        guard isAuthorized else { return }
        
        for (index, time) in times.enumerated() {
            let identifier = "medication_\(name.lowercased())_\(index)"
            
            let content = UNMutableNotificationContent()
            content.title = "Medication Reminder"
            content.body = "Time to take your \(name)"
            content.sound = .default
            content.categoryIdentifier = "MEDICATION_CATEGORY"
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            center.add(request) { error in
                if let error = error {
                    print("❌ Error scheduling medication reminder: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Smart Notifications
    
    func scheduleSmartInsightNotification(title: String, body: String, delay: TimeInterval = 0) {
        guard isAuthorized else { return }
        
        let identifier = "smart_insight_\(UUID().uuidString)"
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "AI_INSIGHTS_CATEGORY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delay, 1), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling smart insight notification: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleAnomalyAlert(message: String) {
        guard isAuthorized else { return }
        
        let identifier = "anomaly_alert_\(UUID().uuidString)"
        
        let content = UNMutableNotificationContent()
        content.title = "Cycle Alert"
        content.body = message
        content.sound = .critical
        content.categoryIdentifier = "HEALTH_ALERT_CATEGORY"
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("❌ Error scheduling anomaly alert: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Notification Management
    
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        print("✅ All notifications cancelled")
    }
    
    func cancelNotifications(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }
    
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
    
    func getDeliveredNotifications() async -> [UNNotification] {
        return await center.deliveredNotifications()
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let periodCategory = UNNotificationCategory(
            identifier: "PERIOD_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "LOG_PERIOD", title: "Log Period", options: .foreground),
                UNNotificationAction(identifier: "SNOOZE", title: "Remind Later", options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let fertilityCategory = UNNotificationCategory(
            identifier: "FERTILITY_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "LOG_SYMPTOMS", title: "Log Symptoms", options: .foreground),
                UNNotificationAction(identifier: "VIEW_INSIGHTS", title: "View Insights", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let dailyReminderCategory = UNNotificationCategory(
            identifier: "DAILY_REMINDER_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "QUICK_LOG", title: "Quick Log", options: .foreground),
                UNNotificationAction(identifier: "SKIP_TODAY", title: "Skip Today", options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let medicationCategory = UNNotificationCategory(
            identifier: "MEDICATION_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "TAKEN", title: "Taken", options: []),
                UNNotificationAction(identifier: "SNOOZE_MED", title: "Snooze", options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let insightsCategory = UNNotificationCategory(
            identifier: "INSIGHTS_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "VIEW_INSIGHTS", title: "View Insights", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let aiInsightsCategory = UNNotificationCategory(
            identifier: "AI_INSIGHTS_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "VIEW_AI_INSIGHTS", title: "View Details", options: .foreground)
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let healthAlertCategory = UNNotificationCategory(
            identifier: "HEALTH_ALERT_CATEGORY",
            actions: [
                UNNotificationAction(identifier: "VIEW_ALERT", title: "View Details", options: .foreground),
                UNNotificationAction(identifier: "DISMISS_ALERT", title: "Dismiss", options: [])
            ],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([
            periodCategory,
            fertilityCategory,
            dailyReminderCategory,
            medicationCategory,
            insightsCategory,
            aiInsightsCategory,
            healthAlertCategory
        ])
    }
    
    // MARK: - Notification Settings
    
    func updateNotificationPreferences(
        periodReminders: Bool,
        ovulationReminders: Bool,
        dailyReminders: Bool,
        weeklyReviews: Bool,
        smartInsights: Bool
    ) {
        UserDefaults.standard.set(periodReminders, forKey: "notification_period_reminders")
        UserDefaults.standard.set(ovulationReminders, forKey: "notification_ovulation_reminders")
        UserDefaults.standard.set(dailyReminders, forKey: "notification_daily_reminders")
        UserDefaults.standard.set(weeklyReviews, forKey: "notification_weekly_reviews")
        UserDefaults.standard.set(smartInsights, forKey: "notification_smart_insights")
        
        // Cancel and reschedule notifications based on new preferences
        if !dailyReminders {
            cancelNotifications(withIdentifiers: ["daily_symptom_reminder"])
        }
        
        if !weeklyReviews {
            cancelNotifications(withIdentifiers: ["weekly_data_review"])
        }
    }
    
    func getNotificationPreferences() -> (periodReminders: Bool, ovulationReminders: Bool, dailyReminders: Bool, weeklyReviews: Bool, smartInsights: Bool) {
        return (
            periodReminders: UserDefaults.standard.bool(forKey: "notification_period_reminders"),
            ovulationReminders: UserDefaults.standard.bool(forKey: "notification_ovulation_reminders"),
            dailyReminders: UserDefaults.standard.bool(forKey: "notification_daily_reminders"),
            weeklyReviews: UserDefaults.standard.bool(forKey: "notification_weekly_reviews"),
            smartInsights: UserDefaults.standard.bool(forKey: "notification_smart_insights")
        )
    }
}

// MARK: - Notification Delegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let actionIdentifier = response.actionIdentifier
        let notification = response.notification
        
        switch actionIdentifier {
        case "LOG_PERIOD":
            // Handle period logging action
            NotificationCenter.default.post(name: .logPeriodFromNotification, object: nil)
        case "LOG_SYMPTOMS":
            // Handle symptom logging action
            NotificationCenter.default.post(name: .logSymptomsFromNotification, object: nil)
        case "QUICK_LOG":
            // Handle quick logging action
            NotificationCenter.default.post(name: .quickLogFromNotification, object: nil)
        case "TAKEN":
            // Handle medication taken action
            NotificationCenter.default.post(name: .medicationTakenFromNotification, object: notification.request.content.body)
        case "VIEW_INSIGHTS":
            // Handle view insights action
            NotificationCenter.default.post(name: .viewInsightsFromNotification, object: nil)
        case "SNOOZE":
            // Handle snooze action - reschedule for 1 hour later
            scheduleSmartInsightNotification(
                title: notification.request.content.title,
                body: notification.request.content.body,
                delay: 3600 // 1 hour
            )
        default:
            break
        }
        
        completionHandler()
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let logPeriodFromNotification = Notification.Name("logPeriodFromNotification")
    static let logSymptomsFromNotification = Notification.Name("logSymptomsFromNotification")
    static let quickLogFromNotification = Notification.Name("quickLogFromNotification")
    static let medicationTakenFromNotification = Notification.Name("medicationTakenFromNotification")
    static let viewInsightsFromNotification = Notification.Name("viewInsightsFromNotification")
}