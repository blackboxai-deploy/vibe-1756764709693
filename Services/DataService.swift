import Foundation
import Combine
import HealthKit
import UserNotifications
import SwiftData
import SwiftUI

@MainActor
class DataService: ObservableObject {
    static let shared = DataService()
    
    @Published var cycleData = CycleData()
    @Published var isLoading = false
    @Published var error: DataError?
    
    private var modelContext: ModelContext?
    private var currentCycleDataModel: CycleDataModel?
    private var cancellables = Set<AnyCancellable>()
    
    var cycleDataPublisher: Published<CycleData>.Publisher { $cycleData }
    
    private init() {
        setupNotificationObservers()
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        loadCurrentCycleData()
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .sink { [weak self] _ in
                self?.updateDailyData()
            }
            .store(in: &cancellables)
    }
    
    private func updateDailyData() {
        loadCurrentCycleData()
        scheduleNotifications()
    }
    
    // MARK: - Cycle Data Management
    
    func loadCurrentCycleData() {
        guard let context = modelContext else { return }
        
        isLoading = true
        
        let descriptor = FetchDescriptor<CycleDataModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let cycles = try context.fetch(descriptor)
            if let latestCycle = cycles.first {
                currentCycleDataModel = latestCycle
                updateLegacyCycleData(from: latestCycle)
            } else {
                createInitialCycleData()
            }
        } catch {
            self.error = .fetchFailed(error)
            print("Error loading cycle data: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func createInitialCycleData() {
        guard let context = modelContext else { return }
        
        let newCycle = CycleDataModel()
        context.insert(newCycle)
        
        do {
            try context.save()
            currentCycleDataModel = newCycle
            updateLegacyCycleData(from: newCycle)
        } catch {
            self.error = .saveFailed(error)
            print("Error creating initial cycle data: \(error.localizedDescription)")
        }
    }
    
    private func updateLegacyCycleData(from model: CycleDataModel) {
        cycleData.cycleLength = model.cycleLength
        cycleData.periodLength = model.periodLength
        cycleData.cycleDay = model.cycleDay
        cycleData.lastPeriodDate = model.lastPeriodDate
        cycleData.nextPredictedPeriod = model.nextPredictedPeriod
        cycleData.ovulationDate = model.ovulationDate
        cycleData.currentPhase = model.currentPhase
        cycleData.fertilityStatus = model.fertilityStatus
        
        if let nextPeriod = model.nextPredictedPeriod {
            let components = Calendar.current.dateComponents([.day], from: Date(), to: nextPeriod)
            cycleData.daysUntilNextPeriod = max(0, components.day ?? 0)
        }
    }
    
    func updateCycleSettings(lastPeriodDate: Date, cycleLength: Int, periodLength: Int) {
        guard let context = modelContext, let cycleDataModel = currentCycleDataModel else { return }
        
        cycleDataModel.lastPeriodDate = lastPeriodDate
        cycleDataModel.cycleLength = cycleLength
        cycleDataModel.periodLength = periodLength
        cycleDataModel.calculatePredictions()
        
        do {
            try context.save()
            updateLegacyCycleData(from: cycleDataModel)
            scheduleNotifications()
        } catch {
            self.error = .saveFailed(error)
            print("Error saving updated cycle data: \(error.localizedDescription)")
        }
    }
    
    func markPeriodStart(date: Date = Date()) {
        guard let context = modelContext, let cycleDataModel = currentCycleDataModel else { return }
        
        cycleDataModel.lastPeriodDate = date
        cycleDataModel.calculatePredictions()
        
        do {
            try context.save()
            updateLegacyCycleData(from: cycleDataModel)
            scheduleNotifications()
            
            // Save to HealthKit if authorized
            if HealthKitService.shared.isAuthorized {
                HealthKitService.shared.saveFlowEntry(level: .medium, date: date)
            }
        } catch {
            self.error = .saveFailed(error)
            print("Error marking period start: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Symptom Management
    
    func saveSymptom(_ symptom: Symptom) async throws {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let cycleDay = currentCycleDataModel?.cycleDay ?? 1
        let symptomModel = SymptomModel(
            date: symptom.date,
            type: symptom.type,
            name: symptom.name,
            severity: symptom.severity,
            notes: symptom.notes,
            cycleDay: cycleDay
        )
        
        context.insert(symptomModel)
        
        do {
            try context.save()
        } catch {
            throw DataError.saveFailed(error)
        }
    }
    
    func getSymptoms(for date: Date) async throws -> [Symptom] {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = #Predicate<SymptomModel> { symptom in
            symptom.date >= startOfDay && symptom.date < endOfDay
        }
        
        let descriptor = FetchDescriptor<SymptomModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let models = try context.fetch(descriptor)
            return models.map { model in
                Symptom(
                    date: model.date,
                    type: model.type,
                    name: model.name,
                    severity: model.severity,
                    notes: model.notes,
                    cycleDay: model.cycleDay
                )
            }
        } catch {
            throw DataError.fetchFailed(error)
        }
    }
    
    func getRecentSymptoms(days: Int = 30) async throws -> [Symptom] {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<SymptomModel> { symptom in
            symptom.date >= cutoffDate
        }
        
        let descriptor = FetchDescriptor<SymptomModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let models = try context.fetch(descriptor)
            return models.map { model in
                Symptom(
                    date: model.date,
                    type: model.type,
                    name: model.name,
                    severity: model.severity,
                    notes: model.notes,
                    cycleDay: model.cycleDay
                )
            }
        } catch {
            throw DataError.fetchFailed(error)
        }
    }
    
    func getSymptomTrends(days: Int = 90) async throws -> [String: SymptomTrend] {
        let symptoms = try await getRecentSymptoms(days: days)
        var trends: [String: SymptomTrend] = [:]
        
        for symptom in symptoms {
            if var trend = trends[symptom.name] {
                trend.occurrences += 1
                trend.totalSeverity += symptom.severity
                trend.averageSeverity = Double(trend.totalSeverity) / Double(trend.occurrences)
                trend.lastOccurrence = max(trend.lastOccurrence, symptom.date)
                trends[symptom.name] = trend
            } else {
                trends[symptom.name] = SymptomTrend(
                    name: symptom.name,
                    occurrences: 1,
                    totalSeverity: symptom.severity,
                    averageSeverity: Double(symptom.severity),
                    lastOccurrence: symptom.date
                )
            }
        }
        
        return trends
    }
    
    // MARK: - Hormone Management
    
    func saveHormoneReading(_ reading: HormoneReading) async throws {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let cycleDay = currentCycleDataModel?.cycleDay ?? 1
        let readingModel = HormoneReadingModel(
            date: reading.date,
            estrogen: reading.estrogenLevel,
            progesterone: reading.progesteroneLevel,
            lh: reading.lhLevel,
            fsh: reading.fshLevel,
            testosterone: reading.testosteroneLevel,
            cortisol: reading.cortisolLevel,
            cycleDay: cycleDay,
            source: reading.source
        )
        
        context.insert(readingModel)
        
        do {
            try context.save()
        } catch {
            throw DataError.saveFailed(error)
        }
    }
    
    func getRecentHormoneReadings(days: Int = 30) async throws -> [HormoneReading] {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<HormoneReadingModel> { reading in
            reading.date >= cutoffDate
        }
        
        let descriptor = FetchDescriptor<HormoneReadingModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let models = try context.fetch(descriptor)
            return models.map { model in
                HormoneReading(
                    date: model.date,
                    estrogen: model.estrogenLevel,
                    progesterone: model.progesteroneLevel,
                    lh: model.lhLevel,
                    fsh: model.fshLevel,
                    testosterone: model.testosteroneLevel,
                    cortisol: model.cortisolLevel,
                    cycleDay: model.cycleDay,
                    source: model.source
                )
            }
        } catch {
            throw DataError.fetchFailed(error)
        }
    }
    
    func getHormoneChartData(days: Int = 30) async throws -> [HormoneChartData] {
        let readings = try await getRecentHormoneReadings(days: days)
        var chartData: [HormoneChartData] = []
        
        for reading in readings {
            chartData.append(HormoneChartData(day: reading.cycleDay, value: reading.estrogenLevel, type: .estrogen))
            chartData.append(HormoneChartData(day: reading.cycleDay, value: reading.progesteroneLevel, type: .progesterone))
            chartData.append(HormoneChartData(day: reading.cycleDay, value: reading.lhLevel, type: .lh))
            chartData.append(HormoneChartData(day: reading.cycleDay, value: reading.fshLevel, type: .fsh))
            chartData.append(HormoneChartData(day: reading.cycleDay, value: reading.testosteroneLevel, type: .testosterone))
            chartData.append(HormoneChartData(day: reading.cycleDay, value: reading.cortisolLevel, type: .cortisol))
        }
        
        return chartData.sorted { $0.day < $1.day }
    }
    
    // MARK: - Mood Management
    
    func saveMoodEntry(_ entry: MoodEntry) async throws {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let cycleDay = currentCycleDataModel?.cycleDay ?? 1
        let moodModel = MoodEntryModel(
            date: entry.date,
            mood: entry.mood,
            energy: entry.energyLevel,
            stress: entry.stressLevel,
            notes: entry.notes,
            cycleDay: cycleDay
        )
        
        context.insert(moodModel)
        
        do {
            try context.save()
        } catch {
            throw DataError.saveFailed(error)
        }
    }
    
    func getRecentMoodEntries(days: Int = 30) async throws -> [MoodEntry] {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let predicate = #Predicate<MoodEntryModel> { mood in
            mood.date >= cutoffDate
        }
        
        let descriptor = FetchDescriptor<MoodEntryModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        
        do {
            let models = try context.fetch(descriptor)
            return models.map { model in
                MoodEntry(
                    date: model.date,
                    mood: model.mood,
                    energy: model.energyLevel,
                    stress: model.stressLevel,
                    notes: model.notes,
                    cycleDay: model.cycleDay
                )
            }
        } catch {
            throw DataError.fetchFailed(error)
        }
    }
    
    func getTodayMood() async throws -> MoodEntry? {
        let moods = try await getRecentMoodEntries(days: 1)
        return moods.first
    }
    
    // MARK: - Data Export/Import
    
    func exportData() async throws -> Data {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let symptoms = try await getRecentSymptoms(days: 365)
        let hormones = try await getRecentHormoneReadings(days: 365)
        let moods = try await getRecentMoodEntries(days: 365)
        
        let exportData = ExportData(
            cycleData: cycleData,
            symptoms: symptoms,
            hormoneReadings: hormones,
            moodEntries: moods,
            exportDate: Date()
        )
        
        return try JSONEncoder().encode(exportData)
    }
    
    func importData(_ data: Data) async throws {
        let importData = try JSONDecoder().decode(ExportData.self, from: data)
        
        for symptom in importData.symptoms {
            try await saveSymptom(symptom)
        }
        
        for hormone in importData.hormoneReadings {
            try await saveHormoneReading(hormone)
        }
        
        for mood in importData.moodEntries {
            try await saveMoodEntry(mood)
        }
        
        loadCurrentCycleData()
    }
    
    // MARK: - Notifications
    
    private func scheduleNotifications() {
        guard let nextPeriod = cycleData.nextPredictedPeriod,
              let ovulation = cycleData.ovulationDate else { return }
        
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        // Period reminder
        let periodContent = UNMutableNotificationContent()
        periodContent.title = "Period Reminder"
        periodContent.body = "Your period is expected to start tomorrow. Don't forget to track it!"
        periodContent.sound = .default
        
        let periodDate = Calendar.current.date(byAdding: .day, value: -1, to: nextPeriod)!
        let periodTrigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: periodDate),
            repeats: false
        )
        
        let periodRequest = UNNotificationRequest(
            identifier: "period-reminder",
            content: periodContent,
            trigger: periodTrigger
        )
        
        // Ovulation reminder
        let ovulationContent = UNMutableNotificationContent()
        ovulationContent.title = "Fertility Window"
        ovulationContent.body = "You're entering your fertile window. Consider tracking symptoms!"
        ovulationContent.sound = .default
        
        let ovulationTrigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour], from: ovulation),
            repeats: false
        )
        
        let ovulationRequest = UNNotificationRequest(
            identifier: "ovulation-reminder",
            content: ovulationContent,
            trigger: ovulationTrigger
        )
        
        UNUserNotificationCenter.current().add(periodRequest)
        UNUserNotificationCenter.current().add(ovulationRequest)
    }
    
    // MARK: - HealthKit Sync
    
    func syncWithHealthKit() async {
        await HealthKitService.shared.syncLatestData()
        loadCurrentCycleData()
    }
    
    // MARK: - Data Validation
    
    func validateCycleData(cycleLength: Int, periodLength: Int) -> ValidationResult {
        var errors: [String] = []
        
        if cycleLength < 21 || cycleLength > 35 {
            errors.append("Cycle length should be between 21-35 days")
        }
        
        if periodLength < 2 || periodLength > 8 {
            errors.append("Period length should be between 2-8 days")
        }
        
        if periodLength >= cycleLength {
            errors.append("Period length cannot be longer than cycle length")
        }
        
        return ValidationResult(isValid: errors.isEmpty, errors: errors)
    }
    
    // MARK: - Analytics
    
    func getCycleAnalytics(months: Int = 6) async throws -> CycleAnalytics {
        guard let context = modelContext else { throw DataError.contextUnavailable }
        
        let cutoffDate = Calendar.current.date(byAdding: .month, value: -months, to: Date())!
        let descriptor = FetchDescriptor<CycleDataModel>(
            predicate: #Predicate { $0.createdAt >= cutoffDate },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let cycles = try context.fetch(descriptor)
            let cycleLengths = cycles.map { $0.cycleLength }
            let periodLengths = cycles.map { $0.periodLength }
            
            return CycleAnalytics(
                averageCycleLength: cycleLengths.isEmpty ? 28 : cycleLengths.reduce(0, +) / cycleLengths.count,
                averagePeriodLength: periodLengths.isEmpty ? 5 : periodLengths.reduce(0, +) / periodLengths.count,
                cycleVariability: calculateVariability(cycleLengths),
                totalCycles: cycles.count,
                predictedAccuracy: calculatePredictionAccuracy(cycles)
            )
        } catch {
            throw DataError.fetchFailed(error)
        }
    }
    
    private func calculateVariability(_ values: [Int]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = Double(values.reduce(0, +)) / Double(values.count)
        let variance = values.map { pow(Double($0) - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
    
    private func calculatePredictionAccuracy(_ cycles: [CycleDataModel]) -> Double {
        // Simplified accuracy calculation
        return 0.85
    }
}

// MARK: - Supporting Types

struct SymptomTrend {
    let name: String
    var occurrences: Int
    var totalSeverity: Int
    var averageSeverity: Double
    var lastOccurrence: Date
}

struct ExportData: Codable {
    let cycleData: CycleData
    let symptoms: [Symptom]
    let hormoneReadings: [HormoneReading]
    let moodEntries: [MoodEntry]
    let exportDate: Date
}

struct ValidationResult {
    let isValid: Bool
    let errors: [String]
}

struct CycleAnalytics {
    let averageCycleLength: Int
    let averagePeriodLength: Int
    let cycleVariability: Double
    let totalCycles: Int
    let predictedAccuracy: Double
}

enum DataError: Error, LocalizedError {
    case contextUnavailable
    case fetchFailed(Error)
    case saveFailed(Error)
    case validationFailed(String)
    case exportFailed(Error)
    case importFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return "Database context is not available"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .exportFailed(let error):
            return "Failed to export data: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Failed to import data: \(error.localizedDescription)"
        }
    }
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
    
    convenience init(from decoder: Decoder) throws {
        self.init()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if let phaseString = try? container.decode(String.self, forKey: .currentPhase),
           let phase = CyclePhase(rawValue: phaseString) {
            self.currentPhase = phase
        }
        
        if let fertilityString = try? container.decode(String.self, forKey: .fertilityStatus),
           let fertility = FertilityStatus(rawValue: fertilityString) {
            self.fertilityStatus = fertility
        }
        
        self.daysUntilNextPeriod = try container.decodeIfPresent(Int.self, forKey: .daysUntilNextPeriod) ?? 0
        self.cycleLength = try container.decodeIfPresent(Int.self, forKey: .cycleLength) ?? 28
        self.periodLength = try container.decodeIfPresent(Int.self, forKey: .periodLength) ?? 5
        self.lastPeriodDate = try container.decodeIfPresent(Date.self, forKey: .lastPeriodDate)
        self.nextPredictedPeriod = try container.decodeIfPresent(Date.self, forKey: .nextPredictedPeriod)
        self.ovulationDate = try container.decodeIfPresent(Date.self, forKey: .ovulationDate)
        self.cycleDay = try container.decodeIfPresent(Int.self, forKey: .cycleDay) ?? 1
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
        case date, estrogenLevel, progesteroneLevel, lhLevel, fshLevel
        case testosteroneLevel, cortisolLevel, cycleDay, source
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