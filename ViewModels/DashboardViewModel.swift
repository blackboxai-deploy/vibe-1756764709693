import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
class DashboardViewModel: ObservableObject {
    @Published var cycleData = CycleData()
    @Published var aiInsights: [AIInsight] = []
    @Published var recentSymptoms: [Symptom] = []
    @Published var recentHormoneData: [HormoneReading] = []
    @Published var recentMoodData: [MoodEntry] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingError = false
    @Published var todaySymptomCount = 0
    @Published var weeklyTrends: [String: Double] = [:]
    @Published var nextPeriodCountdown = 0
    @Published var fertilityWindow: (start: Date?, end: Date?) = (nil, nil)
    
    private let dataService = DataService.shared
    private let aiService = AIService.shared
    private let healthKitService = HealthKitService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?

    init() {
        setupSubscriptions()
        loadData()
        startPeriodicRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }

    private func setupSubscriptions() {
        dataService.cycleDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] cycleData in
                self?.cycleData = cycleData
                self?.calculateDerivedData()
                self?.generateInsights()
            }
            .store(in: &cancellables)

        aiService.insightsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] insights in
                self?.aiInsights = insights
            }
            .store(in: &cancellables)
        
        $error
            .map { $0 != nil }
            .assign(to: &$showingError)
    }
    
    private func startPeriodicRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshData()
            }
        }
    }

    func loadData() {
        guard !isLoading else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }

            do {
                async let symptomsTask = dataService.getSymptoms(for: Date())
                async let recentSymptomsTask = dataService.getRecentSymptoms(days: 7)
                async let hormoneDataTask = dataService.getRecentHormoneReadings(days: 7)
                async let moodDataTask = dataService.getRecentMoodEntries(days: 7)
                
                let (todaySymptoms, symptoms, hormones, moods) = try await (
                    symptomsTask,
                    recentSymptomsTask,
                    hormoneDataTask,
                    moodDataTask
                )
                
                self.todaySymptomCount = todaySymptoms.count
                self.recentSymptoms = symptoms
                self.recentHormoneData = hormones
                self.recentMoodData = moods
                
                calculateWeeklyTrends()
                calculateDerivedData()
                
            } catch {
                handleError(error)
            }
        }
    }
    
    private func calculateDerivedData() {
        // Calculate countdown to next period
        if let nextPeriod = cycleData.nextPredictedPeriod {
            let components = Calendar.current.dateComponents([.day], from: Date(), to: nextPeriod)
            nextPeriodCountdown = max(0, components.day ?? 0)
        }
        
        // Calculate fertility window
        if let ovulationDate = cycleData.ovulationDate {
            let calendar = Calendar.current
            fertilityWindow.start = calendar.date(byAdding: .day, value: -5, to: ovulationDate)
            fertilityWindow.end = calendar.date(byAdding: .day, value: 1, to: ovulationDate)
        }
    }
    
    private func calculateWeeklyTrends() {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        
        let weekSymptoms = recentSymptoms.filter { $0.date >= weekAgo }
        let weekMoods = recentMoodData.filter { $0.date >= weekAgo }
        
        // Calculate symptom frequency
        var symptomCounts: [String: Int] = [:]
        for symptom in weekSymptoms {
            symptomCounts[symptom.name, default: 0] += 1
        }
        
        // Calculate average mood metrics
        let avgEnergy = weekMoods.isEmpty ? 0 : Double(weekMoods.map { $0.energyLevel }.reduce(0, +)) / Double(weekMoods.count)
        let avgStress = weekMoods.isEmpty ? 0 : Double(weekMoods.map { $0.stressLevel }.reduce(0, +)) / Double(weekMoods.count)
        
        weeklyTrends = [
            "avgEnergy": avgEnergy,
            "avgStress": avgStress,
            "symptomCount": Double(weekSymptoms.count)
        ]
        
        // Add most common symptoms
        for (symptom, count) in symptomCounts.prefix(3) {
            weeklyTrends[symptom] = Double(count)
        }
    }
    
    private func generateInsights() {
        Task {
            do {
                let insights = try await aiService.generateInsights(for: cycleData)
                self.aiInsights = insights
            } catch {
                handleError(error)
            }
        }
    }

    func refreshData() async {
        await healthKitService.syncLatestData()
        dataService.loadCurrentCycleData()
        loadData()
    }
    
    func quickLogPeriod() {
        Task {
            do {
                dataService.updateCycleSettings(
                    lastPeriodDate: Date(),
                    cycleLength: cycleData.cycleLength,
                    periodLength: cycleData.periodLength
                )
                
                if healthKitService.isAuthorized {
                    healthKitService.saveFlowEntry(level: .medium, date: Date())
                }
                
                await refreshData()
            }
        }
    }
    
    func quickLogSymptom(name: String, type: SymptomType, severity: Int) {
        Task {
            do {
                let symptom = Symptom(
                    type: type.rawValue,
                    name: name,
                    severity: severity
                )
                try await dataService.saveSymptom(symptom)
                loadData()
            } catch {
                handleError(error)
            }
        }
    }
    
    func quickLogMood(mood: String, energy: Int, stress: Int) {
        Task {
            do {
                let moodEntry = MoodEntry(
                    mood: mood,
                    energy: energy,
                    stress: stress
                )
                try await dataService.saveMoodEntry(moodEntry)
                loadData()
            } catch {
                handleError(error)
            }
        }
    }
    
    func getDaysInCurrentPhase() -> Int {
        let cycleDay = cycleData.cycleDay
        
        switch cycleData.currentPhase {
        case .menstrual:
            return cycleDay
        case .follicular:
            return cycleDay - cycleData.periodLength
        case .ovulatory:
            let ovulationStart = (cycleData.cycleLength / 2) - 1
            return cycleDay - ovulationStart
        case .luteal:
            let lutealStart = (cycleData.cycleLength / 2) + 2
            return cycleDay - lutealStart
        }
    }
    
    func getPhaseProgress() -> Double {
        let cycleDay = cycleData.cycleDay
        let cycleLength = cycleData.cycleLength
        
        guard cycleLength > 0 else { return 0 }
        
        return Double(cycleDay) / Double(cycleLength)
    }
    
    func getFertilityStatusColor() -> Color {
        switch cycleData.fertilityStatus {
        case .low:
            return .blue
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .peak:
            return .red
        }
    }
    
    func getInsightsByType(_ type: AIInsightType) -> [AIInsight] {
        return aiInsights.filter { $0.type == type }
    }
    
    func getHighPriorityInsights() -> [AIInsight] {
        return aiInsights.filter { $0.confidence > 0.8 && $0.actionable }
    }
    
    func dismissInsight(_ insight: AIInsight) {
        aiInsights.removeAll { $0.id == insight.id }
    }
    
    private func handleError(_ error: Error) {
        self.error = error
        print("Dashboard Error: \(error.localizedDescription)")
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Computed Properties
    
    var isInFertileWindow: Bool {
        guard let start = fertilityWindow.start,
              let end = fertilityWindow.end else { return false }
        let now = Date()
        return now >= start && now <= end
    }
    
    var cycleProgressPercentage: Int {
        let progress = getPhaseProgress()
        return Int(progress * 100)
    }
    
    var currentPhaseDescription: String {
        let daysInPhase = getDaysInCurrentPhase()
        return "\(cycleData.currentPhase.description) - Day \(daysInPhase)"
    }
    
    var nextMilestone: (title: String, date: Date, daysAway: Int)? {
        let calendar = Calendar.current
        let now = Date()
        
        if let ovulation = cycleData.ovulationDate, ovulation > now {
            let days = calendar.dateComponents([.day], from: now, to: ovulation).day ?? 0
            return ("Ovulation", ovulation, days)
        } else if let nextPeriod = cycleData.nextPredictedPeriod, nextPeriod > now {
            let days = calendar.dateComponents([.day], from: now, to: nextPeriod).day ?? 0
            return ("Next Period", nextPeriod, days)
        }
        
        return nil
    }
    
    var healthScore: Int {
        var score = 70 // Base score
        
        // Adjust based on recent symptoms
        let recentSymptomSeverity = recentSymptoms.prefix(7).map { $0.severity }.reduce(0, +)
        score -= min(recentSymptomSeverity * 2, 30)
        
        // Adjust based on mood data
        if let avgEnergy = weeklyTrends["avgEnergy"], avgEnergy > 0 {
            score += Int((avgEnergy - 5) * 3)
        }
        
        if let avgStress = weeklyTrends["avgStress"], avgStress > 0 {
            score -= Int((avgStress - 5) * 2)
        }
        
        return max(0, min(100, score))
    }
}

// MARK: - Extensions

extension DashboardViewModel {
    func exportCycleData() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let exportData = CycleExportData(
            cycleData: cycleData,
            symptoms: recentSymptoms,
            hormoneReadings: recentHormoneData,
            moodEntries: recentMoodData,
            exportDate: Date()
        )
        
        do {
            let data = try encoder.encode(exportData)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }
}

// MARK: - Supporting Types

struct CycleExportData: Codable {
    let cycleData: CycleData
    let symptoms: [Symptom]
    let hormoneReadings: [HormoneReading]
    let moodEntries: [MoodEntry]
    let exportDate: Date
}

extension CycleData: Codable {
    enum CodingKeys: String, CodingKey {
        case currentPhase, daysUntilNextPeriod, fertilityStatus
        case cycleLength, periodLength, lastPeriodDate
        case nextPredictedPeriod, ovulationDate, cycleDay
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentPhase.rawValue, forKey: .currentPhase)
        try container.encode(daysUntilNextPeriod, forKey: .daysUntilNextPeriod)
        try container.encode(fertilityStatus.rawValue, forKey: .fertilityStatus)
        try container.encode(cycleLength, forKey: .cycleLength)
        try container.encode(periodLength, forKey: .periodLength)
        try container.encode(lastPeriodDate, forKey: .lastPeriodDate)
        try container.encode(nextPredictedPeriod, forKey: .nextPredictedPeriod)
        try container.encode(ovulationDate, forKey: .ovulationDate)
        try container.encode(cycleDay, forKey: .cycleDay)
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let phaseString = try container.decode(String.self, forKey: .currentPhase)
        currentPhase = CyclePhase(rawValue: phaseString) ?? .menstrual
        daysUntilNextPeriod = try container.decode(Int.self, forKey: .daysUntilNextPeriod)
        let fertilityString = try container.decode(String.self, forKey: .fertilityStatus)
        fertilityStatus = FertilityStatus(rawValue: fertilityString) ?? .low
        cycleLength = try container.decode(Int.self, forKey: .cycleLength)
        periodLength = try container.decode(Int.self, forKey: .periodLength)
        lastPeriodDate = try container.decodeIfPresent(Date.self, forKey: .lastPeriodDate)
        nextPredictedPeriod = try container.decodeIfPresent(Date.self, forKey: .nextPredictedPeriod)
        ovulationDate = try container.decodeIfPresent(Date.self, forKey: .ovulationDate)
        cycleDay = try container.decode(Int.self, forKey: .cycleDay)
    }
}

extension Symptom: Codable {
    enum CodingKeys: String, CodingKey {
        case date, type, name, severity, notes, cycleDay
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(type, forKey: .type)
        try container.encode(name, forKey: .name)
        try container.encode(severity, forKey: .severity)
        try container.encode(notes, forKey: .notes)
        try container.encode(cycleDay, forKey: .cycleDay)
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)
        let type = try container.decode(String.self, forKey: .type)
        let name = try container.decode(String.self, forKey: .name)
        let severity = try container.decode(Int.self, forKey: .severity)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let cycleDay = try container.decode(Int.self, forKey: .cycleDay)
        
        self.init(date: date, type: type, name: name, severity: severity, notes: notes, cycleDay: cycleDay)
    }
}

extension HormoneReading: Codable {
    enum CodingKeys: String, CodingKey {
        case date, estrogenLevel, progesteroneLevel, lhLevel
        case fshLevel, testosteroneLevel, cortisolLevel
        case cycleDay, source
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(estrogenLevel, forKey: .estrogenLevel)
        try container.encode(progesteroneLevel, forKey: .progesteroneLevel)
        try container.encode(lhLevel, forKey: .lhLevel)
        try container.encode(fshLevel, forKey: .fshLevel)
        try container.encode(testosteroneLevel, forKey: .testosteroneLevel)
        try container.encode(cortisolLevel, forKey: .cortisolLevel)
        try container.encode(cycleDay, forKey: .cycleDay)
        try container.encode(source, forKey: .source)
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)
        let estrogen = try container.decode(Double.self, forKey: .estrogenLevel)
        let progesterone = try container.decode(Double.self, forKey: .progesteroneLevel)
        let lh = try container.decode(Double.self, forKey: .lhLevel)
        let fsh = try container.decode(Double.self, forKey: .fshLevel)
        let testosterone = try container.decode(Double.self, forKey: .testosteroneLevel)
        let cortisol = try container.decode(Double.self, forKey: .cortisolLevel)
        let cycleDay = try container.decode(Int.self, forKey: .cycleDay)
        let source = try container.decode(String.self, forKey: .source)
        
        self.init(date: date, estrogen: estrogen, progesterone: progesterone, lh: lh, fsh: fsh, testosterone: testosterone, cortisol: cortisol, cycleDay: cycleDay, source: source)
    }
}

extension MoodEntry: Codable {
    enum CodingKeys: String, CodingKey {
        case date, mood, energyLevel, stressLevel, notes, cycleDay
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(mood, forKey: .mood)
        try container.encode(energyLevel, forKey: .energyLevel)
        try container.encode(stressLevel, forKey: .stressLevel)
        try container.encode(notes, forKey: .notes)
        try container.encode(cycleDay, forKey: .cycleDay)
    }
    
    convenience init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let date = try container.decode(Date.self, forKey: .date)
        let mood = try container.decode(String.self, forKey: .mood)
        let energy = try container.decode(Int.self, forKey: .energyLevel)
        let stress = try container.decode(Int.self, forKey: .stressLevel)
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)
        let cycleDay = try container.decode(Int.self, forKey: .cycleDay)
        
        self.init(date: date, mood: mood, energy: energy, stress: stress, notes: notes, cycleDay: cycleDay)
    }
}