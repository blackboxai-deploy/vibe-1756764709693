import Foundation
import Combine
import SwiftUI
import Charts

@MainActor
class HormoneTrackingViewModel: ObservableObject {
    @Published var chartData: [HormoneChartData] = []
    @Published var currentReadings: [HormoneReading] = []
    @Published var recentReadings: [HormoneReading] = []
    @Published var selectedHormones: Set<HormoneType> = [.estrogen, .progesterone, .lh]
    @Published var selectedTimeRange: TimeRange = .month
    @Published var isLoading = false
    @Published var error: Error?
    @Published var showingAddReading = false
    @Published var selectedReading: HormoneReading?
    @Published var hormoneStats: [HormoneType: HormoneStats] = [:]
    
    private let dataService = DataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    enum TimeRange: String, CaseIterable {
        case week = "7 days"
        case month = "30 days"
        case threeMonths = "90 days"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
    }
    
    struct HormoneStats {
        let average: Double
        let minimum: Double
        let maximum: Double
        let trend: TrendDirection
        let lastValue: Double
        let changePercentage: Double
    }
    
    enum TrendDirection {
        case increasing, decreasing, stable
        
        var icon: String {
            switch self {
            case .increasing: return "arrow.up.right"
            case .decreasing: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .increasing: return .green
            case .decreasing: return .red
            case .stable: return .blue
            }
        }
    }
    
    init() {
        setupSubscriptions()
        loadData()
    }
    
    private func setupSubscriptions() {
        dataService.cycleDataPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadData()
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                let readings = try await dataService.getRecentHormoneReadings(days: selectedTimeRange.days)
                recentReadings = readings
                currentReadings = try await dataService.getCurrentHormoneReadings()
                
                processChartData()
                calculateHormoneStats()
            } catch {
                self.error = error
                print("Error loading hormone data: \(error.localizedDescription)")
            }
        }
    }
    
    private func processChartData() {
        var processedData: [HormoneChartData] = []
        
        for reading in recentReadings {
            for hormoneType in selectedHormones {
                let value = getHormoneValue(from: reading, type: hormoneType)
                let chartPoint = HormoneChartData(
                    day: reading.cycleDay,
                    value: value,
                    type: hormoneType,
                    date: reading.date
                )
                processedData.append(chartPoint)
            }
        }
        
        chartData = processedData.sorted { $0.date < $1.date }
    }
    
    private func getHormoneValue(from reading: HormoneReading, type: HormoneType) -> Double {
        switch type {
        case .estrogen: return reading.estrogenLevel
        case .progesterone: return reading.progesteroneLevel
        case .lh: return reading.lhLevel
        case .fsh: return reading.fshLevel
        case .testosterone: return reading.testosteroneLevel
        case .cortisol: return reading.cortisolLevel
        }
    }
    
    private func calculateHormoneStats() {
        var stats: [HormoneType: HormoneStats] = [:]
        
        for hormoneType in HormoneType.allCases {
            let values = recentReadings.compactMap { reading in
                getHormoneValue(from: reading, type: hormoneType)
            }.filter { $0 > 0 }
            
            guard !values.isEmpty else { continue }
            
            let average = values.reduce(0, +) / Double(values.count)
            let minimum = values.min() ?? 0
            let maximum = values.max() ?? 0
            let lastValue = values.last ?? 0
            
            let trend = calculateTrend(for: values)
            let changePercentage = calculateChangePercentage(for: values)
            
            stats[hormoneType] = HormoneStats(
                average: average,
                minimum: minimum,
                maximum: maximum,
                trend: trend,
                lastValue: lastValue,
                changePercentage: changePercentage
            )
        }
        
        hormoneStats = stats
    }
    
    private func calculateTrend(for values: [Double]) -> TrendDirection {
        guard values.count >= 2 else { return .stable }
        
        let recentValues = Array(values.suffix(3))
        let olderValues = Array(values.prefix(max(1, values.count - 3)))
        
        let recentAverage = recentValues.reduce(0, +) / Double(recentValues.count)
        let olderAverage = olderValues.reduce(0, +) / Double(olderValues.count)
        
        let changeThreshold = olderAverage * 0.1
        
        if recentAverage > olderAverage + changeThreshold {
            return .increasing
        } else if recentAverage < olderAverage - changeThreshold {
            return .decreasing
        } else {
            return .stable
        }
    }
    
    private func calculateChangePercentage(for values: [Double]) -> Double {
        guard values.count >= 2 else { return 0 }
        
        let firstValue = values.first ?? 0
        let lastValue = values.last ?? 0
        
        guard firstValue > 0 else { return 0 }
        
        return ((lastValue - firstValue) / firstValue) * 100
    }
    
    func addReading(_ reading: HormoneReading) {
        Task {
            do {
                try await dataService.saveHormoneReading(reading)
                loadData()
            } catch {
                self.error = error
                print("Error saving hormone reading: \(error.localizedDescription)")
            }
        }
    }
    
    func updateReading(_ reading: HormoneReading) {
        Task {
            do {
                try await dataService.updateHormoneReading(reading)
                loadData()
            } catch {
                self.error = error
                print("Error updating hormone reading: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteReading(_ reading: HormoneReading) {
        Task {
            do {
                try await dataService.deleteHormoneReading(reading)
                loadData()
            } catch {
                self.error = error
                print("Error deleting hormone reading: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleHormone(_ hormone: HormoneType) {
        if selectedHormones.contains(hormone) {
            selectedHormones.remove(hormone)
        } else {
            selectedHormones.insert(hormone)
        }
        processChartData()
    }
    
    func updateTimeRange(_ range: TimeRange) {
        selectedTimeRange = range
        loadData()
    }
    
    func refreshData() async {
        await HealthKitService.shared.syncLatestData()
        loadData()
    }
    
    func exportData() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(recentReadings)
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("Error exporting hormone data: \(error.localizedDescription)")
            return ""
        }
    }
    
    func getReadingsForDate(_ date: Date) -> [HormoneReading] {
        let calendar = Calendar.current
        return recentReadings.filter { reading in
            calendar.isDate(reading.date, inSameDayAs: date)
        }
    }
    
    func getAverageForHormone(_ hormone: HormoneType, in phase: CyclePhase) -> Double {
        let phaseReadings = recentReadings.filter { reading in
            let cycleDay = reading.cycleDay
            switch phase {
            case .menstrual:
                return cycleDay <= 5
            case .follicular:
                return cycleDay > 5 && cycleDay <= 13
            case .ovulatory:
                return cycleDay > 13 && cycleDay <= 15
            case .luteal:
                return cycleDay > 15
            }
        }
        
        let values = phaseReadings.compactMap { reading in
            getHormoneValue(from: reading, type: hormone)
        }.filter { $0 > 0 }
        
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    func predictNextOvulation() -> Date? {
        guard let cycleData = try? await dataService.getCurrentCycleData(),
              let lastPeriod = cycleData.lastPeriodDate else {
            return nil
        }
        
        let avgCycleLength = cycleData.cycleLength
        let ovulationDay = avgCycleLength / 2
        
        return Calendar.current.date(byAdding: .day, value: ovulationDay, to: lastPeriod)
    }
    
    func getHormoneInsights() -> [String] {
        var insights: [String] = []
        
        for (hormone, stats) in hormoneStats {
            switch stats.trend {
            case .increasing:
                if hormone == .lh && stats.lastValue > stats.average * 1.5 {
                    insights.append("LH surge detected - ovulation likely within 24-48 hours")
                } else if hormone == .estrogen && stats.changePercentage > 20 {
                    insights.append("Rising estrogen levels indicate approaching ovulation")
                }
            case .decreasing:
                if hormone == .progesterone && stats.changePercentage < -30 {
                    insights.append("Dropping progesterone may indicate approaching menstruation")
                }
            case .stable:
                if hormone == .cortisol && stats.average > 20 {
                    insights.append("Consistently elevated cortisol - consider stress management")
                }
            }
        }
        
        return insights
    }
    
    func isWithinNormalRange(_ value: Double, for hormone: HormoneType) -> Bool {
        switch hormone {
        case .estrogen:
            return value >= 30 && value <= 400
        case .progesterone:
            return value >= 0.1 && value <= 25
        case .lh:
            return value >= 5 && value <= 25
        case .fsh:
            return value >= 3 && value <= 20
        case .testosterone:
            return value >= 15 && value <= 70
        case .cortisol:
            return value >= 6 && value <= 23
        }
    }
    
    func getRangeStatus(_ value: Double, for hormone: HormoneType) -> RangeStatus {
        let normalRange = getNormalRange(for: hormone)
        
        if value < normalRange.lowerBound {
            return .low
        } else if value > normalRange.upperBound {
            return .high
        } else {
            return .normal
        }
    }
    
    private func getNormalRange(for hormone: HormoneType) -> ClosedRange<Double> {
        switch hormone {
        case .estrogen: return 30...400
        case .progesterone: return 0.1...25
        case .lh: return 5...25
        case .fsh: return 3...20
        case .testosterone: return 15...70
        case .cortisol: return 6...23
        }
    }
    
    enum RangeStatus {
        case low, normal, high
        
        var color: Color {
            switch self {
            case .low: return .blue
            case .normal: return .green
            case .high: return .orange
            }
        }
        
        var description: String {
            switch self {
            case .low: return "Below Normal"
            case .normal: return "Normal"
            case .high: return "Above Normal"
            }
        }
    }
}

extension HormoneChartData {
    var date: Date {
        return Date()
    }
}