import Foundation
import SwiftUI
import Combine

// MARK: - UI Models (Classes for Views)

class Symptom: ObservableObject, Identifiable {
    let id = UUID()
    @Published var date: Date
    @Published var type: String
    @Published var name: String
    @Published var severity: Int
    @Published var notes: String?
    @Published var cycleDay: Int

    init(date: Date = Date(), type: String = "", name: String = "", severity: Int = 1, notes: String? = nil, cycleDay: Int = 1) {
        self.date = date
        self.type = type
        self.name = name
        self.severity = severity
        self.notes = notes
        self.cycleDay = cycleDay
    }
}

class CycleData: ObservableObject {
    @Published var currentPhase: CyclePhase = .menstrual
    @Published var daysUntilNextPeriod: Int = 0
    @Published var fertilityStatus: FertilityStatus = .low
    @Published var cycleLength: Int = 28
    @Published var periodLength: Int = 5
    @Published var lastPeriodDate: Date?
    @Published var nextPredictedPeriod: Date?
    @Published var ovulationDate: Date?
    @Published var cycleDay: Int = 1
    @Published var isOnPeriod: Bool = false
    @Published var daysUntilOvulation: Int = 0
    
    init() {
        updateCalculatedFields()
    }
    
    func updateCalculatedFields() {
        guard let lastPeriod = lastPeriodDate else { return }
        
        let calendar = Calendar.current
        let today = Date()
        
        // Calculate cycle day
        let daysSinceLastPeriod = calendar.dateComponents([.day], from: lastPeriod, to: today).day ?? 0
        cycleDay = daysSinceLastPeriod + 1
        
        // Calculate days until next period
        if let nextPeriod = nextPredictedPeriod {
            let daysUntil = calendar.dateComponents([.day], from: today, to: nextPeriod).day ?? 0
            daysUntilNextPeriod = max(0, daysUntil)
        }
        
        // Calculate days until ovulation
        if let ovulation = ovulationDate {
            let daysUntil = calendar.dateComponents([.day], from: today, to: ovulation).day ?? 0
            daysUntilOvulation = max(0, daysUntil)
        }
        
        // Determine if on period
        isOnPeriod = cycleDay <= periodLength
        
        // Update current phase based on cycle day
        currentPhase = calculateCurrentPhase()
        
        // Update fertility status
        fertilityStatus = calculateFertilityStatus()
    }
    
    private func calculateCurrentPhase() -> CyclePhase {
        if cycleDay <= periodLength {
            return .menstrual
        } else if cycleDay <= (cycleLength / 2) - 2 {
            return .follicular
        } else if cycleDay <= (cycleLength / 2) + 2 {
            return .ovulatory
        } else {
            return .luteal
        }
    }
    
    private func calculateFertilityStatus() -> FertilityStatus {
        let ovulationStart = (cycleLength / 2) - 2
        let ovulationEnd = (cycleLength / 2) + 2
        
        if cycleDay >= ovulationStart && cycleDay <= ovulationEnd {
            return cycleDay == (cycleLength / 2) ? .peak : .high
        } else if cycleDay > periodLength && cycleDay < ovulationStart {
            return .medium
        } else {
            return .low
        }
    }
}

class HormoneReading: ObservableObject, Identifiable {
    let id = UUID()
    @Published var date: Date
    @Published var estrogenLevel: Double
    @Published var progesteroneLevel: Double
    @Published var lhLevel: Double
    @Published var fshLevel: Double
    @Published var testosteroneLevel: Double
    @Published var cortisolLevel: Double
    @Published var cycleDay: Int
    @Published var source: String
    @Published var notes: String?

    init(date: Date = Date(), estrogen: Double = 0, progesterone: Double = 0, lh: Double = 0, fsh: Double = 0, testosterone: Double = 0, cortisol: Double = 0, cycleDay: Int = 1, source: String = "manual", notes: String? = nil) {
        self.date = date
        self.estrogenLevel = estrogen
        self.progesteroneLevel = progesterone
        self.lhLevel = lh
        self.fshLevel = fsh
        self.testosteroneLevel = testosterone
        self.cortisolLevel = cortisol
        self.cycleDay = cycleDay
        self.source = source
        self.notes = notes
    }
    
    func getValue(for type: HormoneType) -> Double {
        switch type {
        case .estrogen: return estrogenLevel
        case .progesterone: return progesteroneLevel
        case .lh: return lhLevel
        case .fsh: return fshLevel
        case .testosterone: return testosteroneLevel
        case .cortisol: return cortisolLevel
        }
    }
    
    func setValue(_ value: Double, for type: HormoneType) {
        switch type {
        case .estrogen: estrogenLevel = value
        case .progesterone: progesteroneLevel = value
        case .lh: lhLevel = value
        case .fsh: fshLevel = value
        case .testosterone: testosteroneLevel = value
        case .cortisol: cortisolLevel = value
        }
    }
}

class MoodEntry: ObservableObject, Identifiable {
    let id = UUID()
    @Published var date: Date
    @Published var mood: String
    @Published var energyLevel: Int
    @Published var stressLevel: Int
    @Published var sleepQuality: Int
    @Published var notes: String?
    @Published var cycleDay: Int
    @Published var tags: [String]

    init(date: Date = Date(), mood: String = "", energy: Int = 5, stress: Int = 5, sleep: Int = 5, notes: String? = nil, cycleDay: Int = 1, tags: [String] = []) {
        self.date = date
        self.mood = mood
        self.energyLevel = energy
        self.stressLevel = stress
        self.sleepQuality = sleep
        self.notes = notes
        self.cycleDay = cycleDay
        self.tags = tags
    }
}

class MedicationEntry: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var dosage: String
    @Published var frequency: String
    @Published var startDate: Date
    @Published var endDate: Date?
    @Published var notes: String?
    @Published var isActive: Bool
    @Published var reminders: [Date]
    
    init(name: String = "", dosage: String = "", frequency: String = "daily", startDate: Date = Date(), endDate: Date? = nil, notes: String? = nil, isActive: Bool = true, reminders: [Date] = []) {
        self.name = name
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.isActive = isActive
        self.reminders = reminders
    }
}

class UserProfile: ObservableObject, Codable {
    let id: UUID
    @Published var name: String
    @Published var age: Int
    @Published var averageCycleLength: Int
    @Published var averagePeriodLength: Int
    @Published var birthControlType: String?
    @Published var healthConditions: [String]
    @Published var notificationPreferences: NotificationPreferences
    @Published var privacySettings: PrivacySettings
    @Published var createdAt: Date
    @Published var lastUpdated: Date

    init(name: String, age: Int) {
        self.id = UUID()
        self.name = name
        self.age = age
        self.averageCycleLength = 28
        self.averagePeriodLength = 5
        self.birthControlType = nil
        self.healthConditions = []
        self.notificationPreferences = NotificationPreferences()
        self.privacySettings = PrivacySettings()
        self.createdAt = Date()
        self.lastUpdated = Date()
    }
    
    enum CodingKeys: CodingKey {
        case id, name, age, averageCycleLength, averagePeriodLength, birthControlType, healthConditions, notificationPreferences, privacySettings, createdAt, lastUpdated
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        age = try container.decode(Int.self, forKey: .age)
        averageCycleLength = try container.decode(Int.self, forKey: .averageCycleLength)
        averagePeriodLength = try container.decode(Int.self, forKey: .averagePeriodLength)
        birthControlType = try container.decodeIfPresent(String.self, forKey: .birthControlType)
        healthConditions = try container.decode([String].self, forKey: .healthConditions)
        notificationPreferences = try container.decode(NotificationPreferences.self, forKey: .notificationPreferences)
        privacySettings = try container.decode(PrivacySettings.self, forKey: .privacySettings)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(age, forKey: .age)
        try container.encode(averageCycleLength, forKey: .averageCycleLength)
        try container.encode(averagePeriodLength, forKey: .averagePeriodLength)
        try container.encode(birthControlType, forKey: .birthControlType)
        try container.encode(healthConditions, forKey: .healthConditions)
        try container.encode(notificationPreferences, forKey: .notificationPreferences)
        try container.encode(privacySettings, forKey: .privacySettings)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
}

struct NotificationPreferences: Codable {
    var periodReminder: Bool = true
    var ovulationReminder: Bool = true
    var symptomReminder: Bool = true
    var medicationReminder: Bool = true
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var advanceDays: Int = 2
}

struct PrivacySettings: Codable {
    var shareWithHealthKit: Bool = false
    var allowAnalytics: Bool = true
    var biometricLock: Bool = false
    var dataRetentionMonths: Int = 24
}

// MARK: - Supporting Enums & Structs

enum SymptomType: String, CaseIterable, Codable {
    case physical = "physical"
    case emotional = "emotional"
    case behavioral = "behavioral"
    case reproductive = "reproductive"

    var displayName: String {
        switch self {
        case .physical: return "Physical"
        case .emotional: return "Emotional"
        case .behavioral: return "Behavioral"
        case .reproductive: return "Reproductive"
        }
    }
    
    var icon: String {
        switch self {
        case .physical: return "figure.walk"
        case .emotional: return "brain.head.profile"
        case .behavioral: return "person.fill"
        case .reproductive: return "heart.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .physical: return .red
        case .emotional: return .blue
        case .behavioral: return .green
        case .reproductive: return .pink
        }
    }
}

struct SymptomOption: Identifiable, Hashable, Codable {
    let id = UUID()
    let name: String
    let type: SymptomType
    let icon: String
    let description: String?
    
    init(name: String, type: SymptomType, icon: String, description: String? = nil) {
        self.name = name
        self.type = type
        self.icon = icon
        self.description = description
    }

    static let allSymptoms: [SymptomOption] = [
        // Physical Symptoms
        SymptomOption(name: "Cramps", type: .physical, icon: "bolt.heart", description: "Menstrual or abdominal cramps"),
        SymptomOption(name: "Headache", type: .physical, icon: "brain.head.profile", description: "Head pain or tension"),
        SymptomOption(name: "Bloating", type: .physical, icon: "stomach", description: "Abdominal swelling or fullness"),
        SymptomOption(name: "Breast Tenderness", type: .physical, icon: "heart.circle", description: "Breast pain or sensitivity"),
        SymptomOption(name: "Acne", type: .physical, icon: "face.smiling", description: "Skin breakouts"),
        SymptomOption(name: "Back Pain", type: .physical, icon: "figure.stand", description: "Lower back discomfort"),
        SymptomOption(name: "Joint Pain", type: .physical, icon: "figure.walk", description: "Aches in joints"),
        SymptomOption(name: "Nausea", type: .physical, icon: "stomach.fill", description: "Feeling sick or queasy"),
        
        // Emotional Symptoms
        SymptomOption(name: "Mood Swings", type: .emotional, icon: "face.dashed", description: "Rapid emotional changes"),
        SymptomOption(name: "Irritability", type: .emotional, icon: "exclamationmark.triangle", description: "Feeling easily annoyed"),
        SymptomOption(name: "Anxiety", type: .emotional, icon: "brain", description: "Feelings of worry or nervousness"),
        SymptomOption(name: "Depression", type: .emotional, icon: "cloud.rain", description: "Feelings of sadness"),
        SymptomOption(name: "Emotional Sensitivity", type: .emotional, icon: "heart.fill", description: "Heightened emotional responses"),
        SymptomOption(name: "Crying Spells", type: .emotional, icon: "drop.fill", description: "Episodes of crying"),
        
        // Behavioral Symptoms
        SymptomOption(name: "Food Cravings", type: .behavioral, icon: "fork.knife", description: "Strong desire for specific foods"),
        SymptomOption(name: "Sleep Issues", type: .behavioral, icon: "bed.double", description: "Difficulty sleeping or insomnia"),
        SymptomOption(name: "Low Energy", type: .behavioral, icon: "battery.25", description: "Feeling tired or fatigued"),
        SymptomOption(name: "Concentration Issues", type: .behavioral, icon: "brain.head.profile", description: "Difficulty focusing"),
        SymptomOption(name: "Social Withdrawal", type: .behavioral, icon: "person.slash", description: "Avoiding social interactions"),
        SymptomOption(name: "Increased Appetite", type: .behavioral, icon: "fork.knife.circle", description: "Eating more than usual"),
        
        // Reproductive Symptoms
        SymptomOption(name: "Heavy Flow", type: .reproductive, icon: "drop.circle", description: "Heavy menstrual bleeding"),
        SymptomOption(name: "Light Flow", type: .reproductive, icon: "drop", description: "Light menstrual bleeding"),
        SymptomOption(name: "Spotting", type: .reproductive, icon: "circle.dotted", description: "Light bleeding between periods"),
        SymptomOption(name: "Discharge", type: .reproductive, icon: "drop.triangle", description: "Vaginal discharge"),
        SymptomOption(name: "Ovulation Pain", type: .reproductive, icon: "oval.fill", description: "Pain during ovulation"),
        SymptomOption(name: "Tender Cervix", type: .reproductive, icon: "circle.fill", description: "Cervical tenderness")
    ]
    
    static func symptoms(for type: SymptomType) -> [SymptomOption] {
        return allSymptoms.filter { $0.type == type }
    }
}

enum CyclePhase: String, CaseIterable, Codable {
    case menstrual = "menstrual"
    case follicular = "follicular"
    case ovulatory = "ovulatory"
    case luteal = "luteal"

    var color: Color {
        switch self {
        case .menstrual: return .red
        case .follicular: return .blue
        case .ovulatory: return .green
        case .luteal: return .orange
        }
    }

    var description: String {
        switch self {
        case .menstrual: return "Menstrual Phase"
        case .follicular: return "Follicular Phase"
        case .ovulatory: return "Ovulatory Phase"
        case .luteal: return "Luteal Phase"
        }
    }
    
    var shortDescription: String {
        switch self {
        case .menstrual: return "Period"
        case .follicular: return "Pre-Ovulation"
        case .ovulatory: return "Ovulation"
        case .luteal: return "Post-Ovulation"
        }
    }
    
    var icon: String {
        switch self {
        case .menstrual: return "drop.circle.fill"
        case .follicular: return "leaf.circle.fill"
        case .ovulatory: return "sun.max.circle.fill"
        case .luteal: return "moon.circle.fill"
        }
    }
    
    var typicalLength: Int {
        switch self {
        case .menstrual: return 5
        case .follicular: return 9
        case .ovulatory: return 3
        case .luteal: return 11
        }
    }
}

enum FertilityStatus: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case peak = "peak"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .peak: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "circle"
        case .medium: return "circle.lefthalf.filled"
        case .high: return "circle.fill"
        case .peak: return "flame.fill"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Low chance of pregnancy"
        case .medium: return "Moderate chance of pregnancy"
        case .high: return "High chance of pregnancy"
        case .peak: return "Peak fertility - highest chance of pregnancy"
        }
    }
}

struct HormoneChartData: Identifiable, Codable {
    let id = UUID()
    let day: Int
    let value: Double
    let type: HormoneType
    let date: Date
    
    init(day: Int, value: Double, type: HormoneType, date: Date = Date()) {
        self.day = day
        self.value = value
        self.type = type
        self.date = date
    }
}

enum HormoneType: String, CaseIterable, Codable {
    case estrogen = "estrogen"
    case progesterone = "progesterone"
    case lh = "lh"
    case fsh = "fsh"
    case testosterone = "testosterone"
    case cortisol = "cortisol"

    var displayName: String {
        switch self {
        case .estrogen: return "Estrogen"
        case .progesterone: return "Progesterone"
        case .lh: return "LH"
        case .fsh: return "FSH"
        case .testosterone: return "Testosterone"
        case .cortisol: return "Cortisol"
        }
    }

    var color: Color {
        switch self {
        case .estrogen: return .blue
        case .progesterone: return .green
        case .lh: return .orange
        case .fsh: return .purple
        case .testosterone: return .red
        case .cortisol: return .yellow
        }
    }
    
    var normalRange: String {
        switch self {
        case .estrogen: return "30-400 pg/mL"
        case .progesterone: return "0.1-25 ng/mL"
        case .lh: return "5-25 mIU/mL"
        case .fsh: return "3-20 mIU/mL"
        case .testosterone: return "15-70 ng/dL"
        case .cortisol: return "6-23 μg/dL"
        }
    }
    
    var unit: String {
        switch self {
        case .estrogen: return "pg/mL"
        case .progesterone: return "ng/mL"
        case .lh: return "mIU/mL"
        case .fsh: return "mIU/mL"
        case .testosterone: return "ng/dL"
        case .cortisol: return "μg/dL"
        }
    }
    
    var icon: String {
        switch self {
        case .estrogen: return "e.circle.fill"
        case .progesterone: return "p.circle.fill"
        case .lh: return "l.circle.fill"
        case .fsh: return "f.circle.fill"
        case .testosterone: return "t.circle.fill"
        case .cortisol: return "c.circle.fill"
        }
    }
}

struct AIInsight: Identifiable, Codable {
    let id = UUID()
    let title: String
    let content: String
    let type: AIInsightType
    let confidence: Double
    let actionable: Bool
    let createdAt: Date
    let priority: InsightPriority
    let category: InsightCategory
    let relatedData: [String: String]?
    
    init(title: String, content: String, type: AIInsightType, confidence: Double = 0.8, actionable: Bool = false, priority: InsightPriority = .medium, category: InsightCategory = .general, relatedData: [String: String]? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.type = type
        self.confidence = confidence
        self.actionable = actionable
        self.createdAt = Date()
        self.priority = priority
        self.category = category
        self.relatedData = relatedData
    }
}

enum AIInsightType: String, CaseIterable, Codable {
    case prediction = "prediction"
    case trend = "trend"
    case warning = "warning"
    case recommendation = "recommendation"
    case achievement = "achievement"

    var iconName: String {
        switch self {
        case .prediction: return "brain.head.profile"
        case .trend: return "chart.line.uptrend.xyaxis"
        case .warning: return "exclamationmark.triangle"
        case .recommendation: return "lightbulb"
        case .achievement: return "star.fill"
        }
    }

    var color: Color {
        switch self {
        case .prediction: return .purple
        case .trend: return .blue
        case .warning: return .orange
        case .recommendation: return .green
        case .achievement: return .yellow
        }
    }
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum InsightPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case urgent = "urgent"
    
    var color: Color {
        switch self {
        case .low: return .gray
        case .medium: return .blue
        case .high: return .orange
        case .urgent: return .red
        }
    }
}

enum InsightCategory: String, CaseIterable, Codable {
    case general = "general"
    case cycle = "cycle"
    case symptoms = "symptoms"
    case hormones = "hormones"
    case mood = "mood"
    case health = "health"
    
    var displayName: String {
        return rawValue.capitalized
    }
}

enum MoodType: String, CaseIterable, Codable {
    case happy = "happy"
    case sad = "sad"
    case anxious = "anxious"
    case irritable = "irritable"
    case calm = "calm"
    case energetic = "energetic"
    case tired = "tired"
    case stressed = "stressed"
    case content = "content"
    case overwhelmed = "overwhelmed"
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .anxious: return "😰"
        case .irritable: return "😤"
        case .calm: return "😌"
        case .energetic: return "⚡"
        case .tired: return "😴"
        case .stressed: return "😫"
        case .content: return "😊"
        case .overwhelmed: return "🤯"
        }
    }
    
    var color: Color {
        switch self {
        case .happy, .content: return .green
        case .sad, .tired: return .blue
        case .anxious, .stressed, .overwhelmed: return .orange
        case .irritable: return .red
        case .calm: return .mint
        case .energetic: return .yellow
        }
    }
}

struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let cycleDay: Int?
    let phase: CyclePhase?
    let isPeriod: Bool
    let isOvulation: Bool
    let isFertile: Bool
    let hasSymptoms: Bool
    let hasHormoneData: Bool
    let hasMoodData: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    
    init(date: Date, cycleDay: Int? = nil, phase: CyclePhase? = nil, isPeriod: Bool = false, isOvulation: Bool = false, isFertile: Bool = false, hasSymptoms: Bool = false, hasHormoneData: Bool = false, hasMoodData: Bool = false) {
        self.date = date
        self.cycleDay = cycleDay
        self.phase = phase
        self.isPeriod = isPeriod
        self.isOvulation = isOvulation
        self.isFertile = isFertile
        self.hasSymptoms = hasSymptoms
        self.hasHormoneData = hasHormoneData
        self.hasMoodData = hasMoodData
        
        let calendar = Calendar.current
        self.isToday = calendar.isDateInToday(date)
        self.isCurrentMonth = calendar.isDate(date, equalTo: Date(), toGranularity: .month)
    }
}

struct ExportData: Codable {
    let exportDate: Date
    let userProfile: UserProfile
    let cycleData: [CycleDataExport]
    let symptoms: [SymptomExport]
    let hormoneReadings: [HormoneReadingExport]
    let moodEntries: [MoodEntryExport]
    let medications: [MedicationExport]
    let version: String
    
    init(userProfile: UserProfile, cycleData: [CycleDataExport] = [], symptoms: [SymptomExport] = [], hormoneReadings: [HormoneReadingExport] = [], moodEntries: [MoodEntryExport] = [], medications: [MedicationExport] = []) {
        self.exportDate = Date()
        self.userProfile = userProfile
        self.cycleData = cycleData
        self.symptoms = symptoms
        self.hormoneReadings = hormoneReadings
        self.moodEntries = moodEntries
        self.medications = medications
        self.version = "1.0.0"
    }
}

struct CycleDataExport: Codable {
    let cycleLength: Int
    let periodLength: Int
    let lastPeriodDate: Date?
    let nextPredictedPeriod: Date?
    let ovulationDate: Date?
    let createdAt: Date
}

struct SymptomExport: Codable {
    let date: Date
    let type: String
    let name: String
    let severity: Int
    let notes: String?
    let cycleDay: Int
}

struct HormoneReadingExport: Codable {
    let date: Date
    let estrogenLevel: Double
    let progesteroneLevel: Double
    let lhLevel: Double
    let fshLevel: Double
    let testosteroneLevel: Double
    let cortisolLevel: Double
    let cycleDay: Int
    let source: String
    let notes: String?
}

struct MoodEntryExport: Codable {
    let date: Date
    let mood: String
    let energyLevel: Int
    let stressLevel: Int
    let sleepQuality: Int
    let notes: String?
    let cycleDay: Int
    let tags: [String]
}

struct MedicationExport: Codable {
    let name: String
    let dosage: String
    let frequency: String
    let startDate: Date
    let endDate: Date?
    let notes: String?
    let isActive: Bool
}