import Foundation
import SwiftUI
import SwiftData
import Combine
import HealthKit

// MARK: - SwiftData Models (Primary Data Store)

@Model
class CycleDataModel {
    @Attribute(.unique) var id: UUID = UUID()
    var cycleLength: Int = 28
    var periodLength: Int = 5
    var lastPeriodDate: Date?
    var nextPredictedPeriod: Date?
    var ovulationDate: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    // Computed properties for real-time calculations
    var cycleDay: Int {
        guard let lastPeriod = lastPeriodDate else { return 1 }
        let components = Calendar.current.dateComponents([.day], from: lastPeriod, to: Date())
        let day = (components.day ?? 0) + 1
        return max(1, min(day, cycleLength))
    }
    
    var daysUntilNextPeriod: Int {
        guard let nextPeriod = nextPredictedPeriod else { return 0 }
        let components = Calendar.current.dateComponents([.day], from: Date(), to: nextPeriod)
        return max(0, components.day ?? 0)
    }
    
    var currentPhase: CyclePhase {
        let day = cycleDay
        if day <= periodLength {
            return .menstrual
        } else if day <= (cycleLength / 2) - 2 {
            return .follicular
        } else if day <= (cycleLength / 2) + 2 {
            return .ovulatory
        } else {
            return .luteal
        }
    }
    
    var fertilityStatus: FertilityStatus {
        let day = cycleDay
        let ovulationStart = (cycleLength / 2) - 2
        let ovulationEnd = (cycleLength / 2) + 2
        
        if day >= ovulationStart - 1 && day <= ovulationEnd {
            if day >= ovulationStart && day <= ovulationStart + 1 {
                return .peak
            }
            return .high
        } else if day > periodLength && day < ovulationStart - 1 {
            return .medium
        } else {
            return .low
        }
    }
    
    init(lastPeriodDate: Date? = nil, cycleLength: Int = 28, periodLength: Int = 5) {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
        self.lastPeriodDate = lastPeriodDate
        self.cycleLength = cycleLength
        self.periodLength = periodLength
        calculatePredictions()
    }
    
    func calculatePredictions() {
        updatedAt = Date()
        if let lastPeriod = lastPeriodDate {
            nextPredictedPeriod = Calendar.current.date(byAdding: .day, value: cycleLength, to: lastPeriod)
            ovulationDate = Calendar.current.date(byAdding: .day, value: cycleLength / 2, to: lastPeriod)
        }
    }
    
    func updateLastPeriod(_ date: Date) {
        lastPeriodDate = date
        calculatePredictions()
    }
}

@Model
class SymptomModel {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var type: String = ""
    var name: String = ""
    var severity: Int = 1
    var notes: String?
    var cycleDay: Int = 1
    var createdAt: Date = Date()
    var tags: [String] = []
    
    init(date: Date = Date(), type: String, name: String, severity: Int, notes: String? = nil, cycleDay: Int, tags: [String] = []) {
        self.id = UUID()
        self.date = date
        self.type = type
        self.name = name
        self.severity = severity
        self.notes = notes
        self.cycleDay = cycleDay
        self.createdAt = Date()
        self.tags = tags
    }
}

@Model
class HormoneReadingModel {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var estrogenLevel: Double = 0
    var progesteroneLevel: Double = 0
    var lhLevel: Double = 0
    var fshLevel: Double = 0
    var testosteroneLevel: Double = 0
    var cortisolLevel: Double = 0
    var cycleDay: Int = 1
    var source: String = "manual"
    var createdAt: Date = Date()
    var notes: String?
    var testType: String = "home"
    
    init(date: Date = Date(), estrogen: Double = 0, progesterone: Double = 0, lh: Double = 0, fsh: Double = 0, testosterone: Double = 0, cortisol: Double = 0, cycleDay: Int = 1, source: String = "manual", notes: String? = nil, testType: String = "home") {
        self.id = UUID()
        self.date = date
        self.estrogenLevel = estrogen
        self.progesteroneLevel = progesterone
        self.lhLevel = lh
        self.fshLevel = fsh
        self.testosteroneLevel = testosterone
        self.cortisolLevel = cortisol
        self.cycleDay = cycleDay
        self.source = source
        self.createdAt = Date()
        self.notes = notes
        self.testType = testType
    }
}

@Model
class MoodEntryModel {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date = Date()
    var mood: String = ""
    var energyLevel: Int = 5
    var stressLevel: Int = 5
    var sleepQuality: Int = 5
    var notes: String?
    var cycleDay: Int = 1
    var createdAt: Date = Date()
    var activities: [String] = []
    
    init(date: Date = Date(), mood: String, energy: Int = 5, stress: Int = 5, sleep: Int = 5, notes: String? = nil, cycleDay: Int = 1, activities: [String] = []) {
        self.id = UUID()
        self.date = date
        self.mood = mood
        self.energyLevel = energy
        self.stressLevel = stress
        self.sleepQuality = sleep
        self.notes = notes
        self.cycleDay = cycleDay
        self.createdAt = Date()
        self.activities = activities
    }
}

@Model
class PeriodEntryModel {
    @Attribute(.unique) var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date?
    var flow: String = "medium"
    var symptoms: [String] = []
    var notes: String?
    var createdAt: Date = Date()
    
    var duration: Int {
        guard let endDate = endDate else { return 1 }
        let components = Calendar.current.dateComponents([.day], from: startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    init(startDate: Date = Date(), endDate: Date? = nil, flow: String = "medium", symptoms: [String] = [], notes: String? = nil) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.flow = flow
        self.symptoms = symptoms
        self.notes = notes
        self.createdAt = Date()
    }
}

@Model
class MedicationModel {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var type: String = ""
    var dosage: String = ""
    var frequency: String = "daily"
    var startDate: Date = Date()
    var endDate: Date?
    var isActive: Bool = true
    var notes: String?
    var createdAt: Date = Date()
    
    init(name: String, type: String, dosage: String, frequency: String = "daily", startDate: Date = Date(), endDate: Date? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.createdAt = Date()
    }
}

@Model
class UserProfileModel {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var age: Int = 25
    var height: Double = 0
    var weight: Double = 0
    var averageCycleLength: Int = 28
    var averagePeriodLength: Int = 5
    var birthControlType: String?
    var healthConditions: [String] = []
    var goals: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    init(name: String = "", age: Int = 25, height: Double = 0, weight: Double = 0) {
        self.id = UUID()
        self.name = name
        self.age = age
        self.height = height
        self.weight = weight
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - UI Models (ObservableObject classes for Views)

class Symptom: ObservableObject, Identifiable {
    let id = UUID()
    @Published var date: Date
    @Published var type: String
    @Published var name: String
    @Published var severity: Int
    @Published var notes: String?
    @Published var cycleDay: Int
    @Published var tags: [String]
    
    init(date: Date = Date(), type: String = "", name: String = "", severity: Int = 1, notes: String? = nil, cycleDay: Int = 1, tags: [String] = []) {
        self.date = date
        self.type = type
        self.name = name
        self.severity = severity
        self.notes = notes
        self.cycleDay = cycleDay
        self.tags = tags
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
    @Published var cycleProgress: Double = 0.0
    
    func updateProgress() {
        if cycleLength > 0 {
            cycleProgress = Double(cycleDay) / Double(cycleLength)
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
    @Published var testType: String
    
    init(date: Date = Date(), estrogen: Double = 0, progesterone: Double = 0, lh: Double = 0, fsh: Double = 0, testosterone: Double = 0, cortisol: Double = 0, cycleDay: Int = 1, source: String = "manual", notes: String? = nil, testType: String = "home") {
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
        self.testType = testType
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
    @Published var activities: [String]
    
    init(date: Date = Date(), mood: String = "", energy: Int = 5, stress: Int = 5, sleep: Int = 5, notes: String? = nil, cycleDay: Int = 1, activities: [String] = []) {
        self.date = date
        self.mood = mood
        self.energyLevel = energy
        self.stressLevel = stress
        self.sleepQuality = sleep
        self.notes = notes
        self.cycleDay = cycleDay
        self.activities = activities
    }
}

class PeriodEntry: ObservableObject, Identifiable {
    let id = UUID()
    @Published var startDate: Date
    @Published var endDate: Date?
    @Published var flow: String
    @Published var symptoms: [String]
    @Published var notes: String?
    
    var duration: Int {
        guard let endDate = endDate else { return 1 }
        let components = Calendar.current.dateComponents([.day], from: startDate, to: endDate)
        return max(1, (components.day ?? 0) + 1)
    }
    
    init(startDate: Date = Date(), endDate: Date? = nil, flow: String = "medium", symptoms: [String] = [], notes: String? = nil) {
        self.startDate = startDate
        self.endDate = endDate
        self.flow = flow
        self.symptoms = symptoms
        self.notes = notes
    }
}

class Medication: ObservableObject, Identifiable {
    let id = UUID()
    @Published var name: String
    @Published var type: String
    @Published var dosage: String
    @Published var frequency: String
    @Published var startDate: Date
    @Published var endDate: Date?
    @Published var isActive: Bool
    @Published var notes: String?
    
    init(name: String = "", type: String = "", dosage: String = "", frequency: String = "daily", startDate: Date = Date(), endDate: Date? = nil, notes: String? = nil) {
        self.name = name
        self.type = type
        self.dosage = dosage
        self.frequency = frequency
        self.startDate = startDate
        self.endDate = endDate
        self.isActive = true
        self.notes = notes
    }
}

// MARK: - Supporting Enums & Structs

enum SymptomType: String, CaseIterable {
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
    
    var color: Color {
        switch self {
        case .physical: return .red
        case .emotional: return .blue
        case .behavioral: return .green
        case .reproductive: return .purple
        }
    }
}

struct SymptomOption: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let type: SymptomType
    let icon: String
    let description: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SymptomOption, rhs: SymptomOption) -> Bool {
        lhs.id == rhs.id
    }
    
    static let allSymptoms: [SymptomOption] = [
        // Physical Symptoms
        SymptomOption(name: "Cramps", type: .physical, icon: "bolt.heart", description: "Menstrual cramps or pelvic pain"),
        SymptomOption(name: "Headache", type: .physical, icon: "brain.head.profile", description: "Head pain or tension"),
        SymptomOption(name: "Bloating", type: .physical, icon: "stomach", description: "Abdominal swelling or fullness"),
        SymptomOption(name: "Breast Tenderness", type: .physical, icon: "heart.circle", description: "Breast pain or sensitivity"),
        SymptomOption(name: "Acne", type: .physical, icon: "face.smiling", description: "Skin breakouts or blemishes"),
        SymptomOption(name: "Back Pain", type: .physical, icon: "figure.walk", description: "Lower back discomfort"),
        SymptomOption(name: "Nausea", type: .physical, icon: "stomach.fill", description: "Feeling sick or queasy"),
        SymptomOption(name: "Hot Flashes", type: .physical, icon: "thermometer.sun", description: "Sudden feeling of heat"),
        
        // Emotional Symptoms
        SymptomOption(name: "Mood Swings", type: .emotional, icon: "face.dashed", description: "Rapid changes in mood"),
        SymptomOption(name: "Irritability", type: .emotional, icon: "exclamationmark.triangle", description: "Feeling easily annoyed"),
        SymptomOption(name: "Anxiety", type: .emotional, icon: "brain", description: "Feelings of worry or nervousness"),
        SymptomOption(name: "Depression", type: .emotional, icon: "cloud.rain", description: "Feelings of sadness or hopelessness"),
        SymptomOption(name: "Emotional Sensitivity", type: .emotional, icon: "heart.fill", description: "Heightened emotional responses"),
        SymptomOption(name: "Crying Spells", type: .emotional, icon: "drop.fill", description: "Episodes of crying"),
        
        // Behavioral Symptoms
        SymptomOption(name: "Food Cravings", type: .behavioral, icon: "fork.knife", description: "Strong desire for specific foods"),
        SymptomOption(name: "Sleep Issues", type: .behavioral, icon: "bed.double", description: "Difficulty sleeping or insomnia"),
        SymptomOption(name: "Low Energy", type: .behavioral, icon: "battery.25", description: "Feeling tired or fatigued"),
        SymptomOption(name: "Concentration Issues", type: .behavioral, icon: "brain.head.profile", description: "Difficulty focusing"),
        SymptomOption(name: "Social Withdrawal", type: .behavioral, icon: "person.slash", description: "Avoiding social interactions"),
        
        // Reproductive Symptoms
        SymptomOption(name: "Spotting", type: .reproductive, icon: "drop.circle", description: "Light bleeding between periods"),
        SymptomOption(name: "Discharge Changes", type: .reproductive, icon: "drop.degreesign", description: "Changes in vaginal discharge"),
        SymptomOption(name: "Ovulation Pain", type: .reproductive, icon: "oval.portrait", description: "Pain during ovulation"),
        SymptomOption(name: "Libido Changes", type: .reproductive, icon: "heart.circle.fill", description: "Changes in sexual desire")
    ]
}

enum CyclePhase: String, CaseIterable {
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
    
    var emoji: String {
        switch self {
        case .menstrual: return "🩸"
        case .follicular: return "🌱"
        case .ovulatory: return "🥚"
        case .luteal: return "🌙"
        }
    }
}

enum FertilityStatus: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case peak = "peak"
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .peak: return .red
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Low Fertility"
        case .medium: return "Medium Fertility"
        case .high: return "High Fertility"
        case .peak: return "Peak Fertility"
        }
    }
    
    var emoji: String {
        switch self {
        case .low: return "🔵"
        case .medium: return "🟡"
        case .high: return "🟠"
        case .peak: return "🔴"
        }
    }
}

struct HormoneChartData: Identifiable {
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

enum HormoneType: String, CaseIterable {
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
        case .lh, .fsh: return "mIU/mL"
        case .testosterone: return "ng/dL"
        case .cortisol: return "μg/dL"
        }
    }
}

struct AIInsight: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let type: AIInsightType
    let confidence: Double
    let actionable: Bool
    let createdAt: Date
    let priority: InsightPriority
    let category: String
    
    init(title: String, content: String, type: AIInsightType, confidence: Double = 0.8, actionable: Bool = false, priority: InsightPriority = .medium, category: String = "general") {
        self.title = title
        self.content = content
        self.type = type
        self.confidence = confidence
        self.actionable = actionable
        self.createdAt = Date()
        self.priority = priority
        self.category = category
    }
}

enum AIInsightType: String, CaseIterable {
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
}

enum InsightPriority: String, CaseIterable {
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

enum FlowLevel: String, CaseIterable {
    case spotting = "spotting"
    case light = "light"
    case medium = "medium"
    case heavy = "heavy"
    case veryHeavy = "very_heavy"
    
    var displayName: String {
        switch self {
        case .spotting: return "Spotting"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        case .veryHeavy: return "Very Heavy"
        }
    }
    
    var color: Color {
        switch self {
        case .spotting: return .pink
        case .light: return .red.opacity(0.6)
        case .medium: return .red
        case .heavy: return .red.opacity(0.8)
        case .veryHeavy: return .red.opacity(1.0)
        }
    }
    
    var emoji: String {
        switch self {
        case .spotting: return "💧"
        case .light: return "🩸"
        case .medium: return "🔴"
        case .heavy: return "🟥"
        case .veryHeavy: return "⬛"
        }
    }
}

enum MoodType: String, CaseIterable {
    case happy = "happy"
    case sad = "sad"
    case anxious = "anxious"
    case irritable = "irritable"
    case calm = "calm"
    case energetic = "energetic"
    case tired = "tired"
    case neutral = "neutral"
    
    var displayName: String {
        return rawValue.capitalized
    }
    
    var emoji: String {
        switch self {
        case .happy: return "😊"
        case .sad: return "😢"
        case .anxious: return "😰"
        case .irritable: return "😤"
        case .calm: return "😌"
        case .energetic: return "⚡"
        case .tired: return "😴"
        case .neutral: return "😐"
        }
    }
    
    var color: Color {
        switch self {
        case .happy: return .yellow
        case .sad: return .blue
        case .anxious: return .orange
        case .irritable: return .red
        case .calm: return .green
        case .energetic: return .purple
        case .tired: return .gray
        case .neutral: return .secondary
        }
    }
}

struct UserProfile: Codable {
    let id: UUID
    var name: String
    var age: Int
    var height: Double
    var weight: Double
    var averageCycleLength: Int
    var averagePeriodLength: Int
    var birthControlType: String?
    var healthConditions: [String]
    var goals: [String]
    var createdAt: Date
    var updatedAt: Date
    
    init(name: String = "", age: Int = 25, height: Double = 0, weight: Double = 0) {
        self.id = UUID()
        self.name = name
        self.age = age
        self.height = height
        self.weight = weight
        self.averageCycleLength = 28
        self.averagePeriodLength = 5
        self.healthConditions = []
        self.goals = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Chart Data Structures

struct CycleChartData: Identifiable {
    let id = UUID()
    let day: Int
    let phase: CyclePhase
    let fertility: FertilityStatus
    let date: Date
    let hasSymptoms: Bool
    let symptomCount: Int
    
    init(day: Int, phase: CyclePhase, fertility: FertilityStatus, date: Date, hasSymptoms: Bool = false, symptomCount: Int = 0) {
        self.day = day
        self.phase = phase
        self.fertility = fertility
        self.date = date
        self.hasSymptoms = hasSymptoms
        self.symptomCount = symptomCount
    }
}

struct SymptomTrendData: Identifiable {
    let id = UUID()
    let symptomName: String
    let frequency: Int
    let averageSeverity: Double
    let lastOccurrence: Date
    let trend: TrendDirection
    
    enum TrendDirection {
        case increasing, decreasing, stable
        
        var color: Color {
            switch self {
            case .increasing: return .red
            case .decreasing: return .green
            case .stable: return .blue
            }
        }
        
        var icon: String {
            switch self {
            case .increasing: return "arrow.up"
            case .decreasing: return "arrow.down"
            case .stable: return "minus"
            }
        }
    }
}

// MARK: - Notification Models

struct CycleNotification: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let type: NotificationType
    let scheduledDate: Date
    let isEnabled: Bool
    
    enum NotificationType: String, CaseIterable {
        case periodReminder = "period_reminder"
        case ovulationReminder = "ovulation_reminder"
        case symptomReminder = "symptom_reminder"
        case medicationReminder = "medication_reminder"
        case appointmentReminder = "appointment_reminder"
        
        var displayName: String {
            switch self {
            case .periodReminder: return "Period Reminder"
            case .ovulationReminder: return "Ovulation Reminder"
            case .symptomReminder: return "Symptom Logging"
            case .medicationReminder: return "Medication"
            case .appointmentReminder: return "Appointment"
            }
        }
        
        var icon: String {
            switch self {
            case .periodReminder: return "drop.circle"
            case .ovulationReminder: return "oval.portrait"
            case .symptomReminder: return "heart.text.square"
            case .medicationReminder: return "pills"
            case .appointmentReminder: return "calendar.badge.clock"
            }
        }
    }
}

// MARK: - Export/Import Models

struct CycleDataExport: Codable {
    let exportDate: Date
    let version: String
    let userProfile: UserProfile?
    let cycleData: [CycleDataExportItem]
    let symptoms: [SymptomExportItem]
    let hormoneReadings: [HormoneReadingExportItem]
    let moodEntries: [MoodEntryExportItem]
    let periodEntries: [PeriodEntryExportItem]
    let medications: [MedicationExportItem]
}

struct CycleDataExportItem: Codable {
    let id: UUID
    let cycleLength: Int
    let periodLength: Int
    let lastPeriodDate: Date?
    let createdAt: Date
}

struct SymptomExportItem: Codable {
    let id: UUID
    let date: Date
    let type: String
    let name: String
    let severity: Int
    let notes: String?
    let cycleDay: Int
}

struct HormoneReadingExportItem: Codable {
    let id: UUID
    let date: Date
    let estrogenLevel: Double
    let progesteroneLevel: Double
    let lhLevel: Double
    let fshLevel: Double
    let testosteroneLevel: Double
    let cortisolLevel: Double
    let cycleDay: Int
    let source: String
}

struct MoodEntryExportItem: Codable {
    let id: UUID
    let date: Date
    let mood: String
    let energyLevel: Int
    let stressLevel: Int
    let sleepQuality: Int
    let notes: String?
    let cycleDay: Int
}

struct PeriodEntryExportItem: Codable {
    let id: UUID
    let startDate: Date
    let endDate: Date?
    let flow: String
    let symptoms: [String]
    let notes: String?
}

struct MedicationExportItem: Codable {
    let id: UUID
    let name: String
    let type: String
    let dosage: String
    let frequency: String
    let startDate: Date
    let endDate: Date?
    let isActive: Bool
    let notes: String?
}