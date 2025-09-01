import Foundation
import SwiftUI
import HealthKit

// MARK: - Date Extensions
extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? self
    }
    
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    func daysBetween(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: self, to: date).day ?? 0
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isSameMonth(as date: Date) -> Bool {
        Calendar.current.isDate(self, equalTo: date, toGranularity: .month)
    }
    
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }
    
    var day: Int {
        Calendar.current.component(.day, from: self)
    }
    
    var month: Int {
        Calendar.current.component(.month, from: self)
    }
    
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    func formatted(style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        return formatter.string(from: self)
    }
    
    func cycleDay(from startDate: Date) -> Int {
        max(1, daysBetween(startDate) + 1)
    }
}

// MARK: - Color Extensions
extension Color {
    static let cycleRed = Color(red: 0.9, green: 0.2, blue: 0.3)
    static let cycleBlue = Color(red: 0.2, green: 0.6, blue: 0.9)
    static let cycleGreen = Color(red: 0.3, green: 0.8, blue: 0.4)
    static let cycleOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let cyclePurple = Color(red: 0.6, green: 0.3, blue: 0.9)
    
    static let primaryBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func lighter(by percentage: CGFloat = 30.0) -> Color {
        return self.adjustBrightness(by: abs(percentage))
    }
    
    func darker(by percentage: CGFloat = 30.0) -> Color {
        return self.adjustBrightness(by: -1 * abs(percentage))
    }
    
    func adjustBrightness(by percentage: CGFloat) -> Color {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return Color(
            red: min(max(red + percentage/100, 0.0), 1.0),
            green: min(max(green + percentage/100, 0.0), 1.0),
            blue: min(max(blue + percentage/100, 0.0), 1.0),
            opacity: alpha
        )
    }
}

// MARK: - View Extensions
extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(Color.secondaryBackground)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    func primaryCardStyle() -> some View {
        self
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(.regularMaterial)
            )
    }
    
    func glassEffect() -> some View {
        self
            .background(.ultraThinMaterial)
            .cornerRadius(16)
    }
    
    func shimmer(active: Bool = true) -> some View {
        self.modifier(ShimmerModifier(active: active))
    }
    
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
}

// MARK: - String Extensions
extension String {
    var isValidEmail: Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: self)
    }
    
    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isNotEmpty: Bool {
        !self.trimmed.isEmpty
    }
    
    func capitalizingFirstLetter() -> String {
        return prefix(1).capitalized + dropFirst()
    }
    
    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}

// MARK: - Array Extensions
extension Array where Element: Identifiable {
    func removeDuplicates() -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
}

extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
    
    var standardDeviation: Double {
        guard count > 1 else { return 0 }
        let avg = average
        let variance = map { pow($0 - avg, 2) }.reduce(0, +) / Double(count - 1)
        return sqrt(variance)
    }
}

// MARK: - HealthKit Extensions
extension HKCategoryValueMenstrualFlow {
    var description: String {
        switch self {
        case .unspecified: return "Unspecified"
        case .none: return "None"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        @unknown default: return "Unknown"
        }
    }
    
    var color: Color {
        switch self {
        case .light: return .pink
        case .medium: return .red
        case .heavy: return .cycleRed
        default: return .gray
        }
    }
    
    var severity: Int {
        switch self {
        case .none: return 0
        case .light: return 1
        case .medium: return 2
        case .heavy: return 3
        default: return 0
        }
    }
}

extension HKCategoryValueCervicalMucusQuality {
    var description: String {
        switch self {
        case .dry: return "Dry"
        case .sticky: return "Sticky"
        case .creamy: return "Creamy"
        case .watery: return "Watery"
        case .eggWhite: return "Egg White"
        @unknown default: return "Unknown"
        }
    }
    
    var fertilityIndicator: FertilityStatus {
        switch self {
        case .dry, .sticky: return .low
        case .creamy: return .medium
        case .watery: return .high
        case .eggWhite: return .peak
        @unknown default: return .low
        }
    }
}

// MARK: - UserDefaults Extensions
extension UserDefaults {
    enum Keys {
        static let onboardingComplete = "OnboardingComplete"
        static let lastPeriodDate = "LastPeriodDate"
        static let cycleLength = "CycleLength"
        static let periodLength = "PeriodLength"
        static let notificationsEnabled = "NotificationsEnabled"
        static let healthKitEnabled = "HealthKitEnabled"
        static let darkModePreference = "DarkModePreference"
        static let temperatureUnit = "TemperatureUnit"
    }
    
    func setDate(_ date: Date?, forKey key: String) {
        set(date, forKey: key)
    }
    
    func date(forKey key: String) -> Date? {
        object(forKey: key) as? Date
    }
}

// MARK: - Notification Extensions
extension UNUserNotificationCenter {
    func schedulePeriodicReminder(title: String, body: String, identifier: String, hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleCycleReminder(for date: Date, title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "CYCLE_REMINDER"
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        add(request) { error in
            if let error = error {
                print("Error scheduling cycle reminder: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Custom Modifiers
struct ShimmerModifier: ViewModifier {
    let active: Bool
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase)
                    .animation(
                        active ? Animation.linear(duration: 1.5).repeatForever(autoreverses: false) : .default,
                        value: phase
                    )
                    .onAppear {
                        if active {
                            phase = 300
                        }
                    }
                    .mask(content)
            )
    }
}

struct CardModifier: ViewModifier {
    let backgroundColor: Color
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    
    init(backgroundColor: Color = Color(.systemBackground), cornerRadius: CGFloat = 12, shadowRadius: CGFloat = 2) {
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: 0, y: 1)
    }
}

// MARK: - Cycle Phase Extensions
extension CyclePhase {
    var emoji: String {
        switch self {
        case .menstrual: return "🩸"
        case .follicular: return "🌱"
        case .ovulatory: return "🥚"
        case .luteal: return "🌙"
        }
    }
    
    var detailedDescription: String {
        switch self {
        case .menstrual:
            return "Your period has started. Focus on rest and self-care."
        case .follicular:
            return "Your body is preparing for ovulation. Energy levels may be increasing."
        case .ovulatory:
            return "You're in your fertile window. This is the best time for conception."
        case .luteal:
            return "Post-ovulation phase. You may experience PMS symptoms."
        }
    }
    
    var recommendations: [String] {
        switch self {
        case .menstrual:
            return ["Stay hydrated", "Use heat therapy for cramps", "Get adequate rest", "Eat iron-rich foods"]
        case .follicular:
            return ["Increase physical activity", "Try new challenges", "Focus on protein intake", "Plan important tasks"]
        case .ovulatory:
            return ["Track cervical mucus", "Consider fertility awareness", "Stay active", "Maintain healthy diet"]
        case .luteal:
            return ["Practice stress management", "Limit caffeine", "Get enough sleep", "Consider magnesium supplements"]
        }
    }
}

// MARK: - Fertility Status Extensions
extension FertilityStatus {
    var emoji: String {
        switch self {
        case .low: return "🔵"
        case .medium: return "🟡"
        case .high: return "🟠"
        case .peak: return "🔴"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Low fertility - unlikely to conceive"
        case .medium: return "Medium fertility - possible to conceive"
        case .high: return "High fertility - good chance of conception"
        case .peak: return "Peak fertility - highest chance of conception"
        }
    }
}

// MARK: - Hormone Type Extensions
extension HormoneType {
    var unit: String {
        switch self {
        case .estrogen: return "pg/mL"
        case .progesterone: return "ng/mL"
        case .lh, .fsh: return "mIU/mL"
        case .testosterone: return "ng/dL"
        case .cortisol: return "μg/dL"
        }
    }
    
    var normalRangeValues: ClosedRange<Double> {
        switch self {
        case .estrogen: return 30...400
        case .progesterone: return 0.1...25
        case .lh: return 5...25
        case .fsh: return 3...20
        case .testosterone: return 15...70
        case .cortisol: return 6...23
        }
    }
    
    var description: String {
        switch self {
        case .estrogen: return "Primary female sex hormone"
        case .progesterone: return "Hormone that prepares the uterus for pregnancy"
        case .lh: return "Luteinizing hormone triggers ovulation"
        case .fsh: return "Follicle-stimulating hormone promotes egg development"
        case .testosterone: return "Androgen hormone present in small amounts"
        case .cortisol: return "Stress hormone that affects many body functions"
        }
    }
}