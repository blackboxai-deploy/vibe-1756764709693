import Foundation
import Combine
import SwiftUI
import SwiftData

@MainActor
class SymptomLoggingViewModel: ObservableObject {
    @Published var todaySymptoms: [Symptom] = []
    @Published var recentSymptoms: [Symptom] = []
    @Published var symptomTrends: [String: Int] = [:]
    @Published var weeklyTrends: [String: [Int]] = [:]
    @Published var severityTrends: [String: Double] = [:]
    @Published var isLoading = false
    @Published var error: Error?
    @Published var selectedDateSymptoms: [Symptom] = []
    @Published var selectedDate = Date()
    
    private let dataService = DataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSubscriptions()
        loadData()
    }
    
    private func setupSubscriptions() {
        $selectedDate
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] date in
                self?.loadSymptomsForDate(date)
            }
            .store(in: &cancellables)
    }
    
    func loadData() {
        Task {
            isLoading = true
            defer { isLoading = false }
            
            do {
                async let todayTask = dataService.getSymptoms(for: Date())
                async let recentTask = dataService.getRecentSymptoms(days: 30)
                
                todaySymptoms = try await todayTask
                recentSymptoms = try await recentTask
                
                calculateTrends()
                calculateWeeklyTrends()
                calculateSeverityTrends()
            } catch {
                self.error = error
                print("Error loading symptom data: \(error.localizedDescription)")
            }
        }
    }
    
    func loadSymptomsForDate(_ date: Date) {
        Task {
            do {
                selectedDateSymptoms = try await dataService.getSymptoms(for: date)
            } catch {
                self.error = error
                print("Error loading symptoms for date: \(error.localizedDescription)")
            }
        }
    }
    
    private func calculateTrends() {
        var trends: [String: Int] = [:]
        for symptom in recentSymptoms {
            trends[symptom.name, default: 0] += 1
        }
        symptomTrends = trends
    }
    
    private func calculateWeeklyTrends() {
        var weeklyData: [String: [Int]] = [:]
        let calendar = Calendar.current
        
        // Group symptoms by week for the last 4 weeks
        for weekOffset in 0..<4 {
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: Date()) ?? Date()
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? Date()
            
            let weekSymptoms = recentSymptoms.filter { symptom in
                symptom.date >= weekStart && symptom.date < weekEnd
            }
            
            for symptom in weekSymptoms {
                if weeklyData[symptom.name] == nil {
                    weeklyData[symptom.name] = Array(repeating: 0, count: 4)
                }
                weeklyData[symptom.name]?[weekOffset] += 1
            }
        }
        
        weeklyTrends = weeklyData
    }
    
    private func calculateSeverityTrends() {
        var severityData: [String: (total: Double, count: Int)] = [:]
        
        for symptom in recentSymptoms {
            let current = severityData[symptom.name] ?? (total: 0, count: 0)
            severityData[symptom.name] = (
                total: current.total + Double(symptom.severity),
                count: current.count + 1
            )
        }
        
        var averages: [String: Double] = [:]
        for (name, data) in severityData {
            averages[name] = data.total / Double(data.count)
        }
        
        severityTrends = averages
    }
    
    func logSymptom(name: String, type: SymptomType, severity: Int, notes: String? = nil, date: Date = Date()) {
        Task {
            do {
                let symptom = Symptom(
                    date: date,
                    type: type.rawValue,
                    name: name,
                    severity: severity,
                    notes: notes?.isEmpty == true ? nil : notes
                )
                
                try await dataService.saveSymptom(symptom)
                
                // Refresh data after saving
                loadData()
                
                // If logging for today, update today's symptoms immediately
                if Calendar.current.isDate(date, inSameDayAs: Date()) {
                    todaySymptoms.append(symptom)
                }
                
                // If logging for selected date, update selected date symptoms
                if Calendar.current.isDate(date, inSameDayAs: selectedDate) {
                    selectedDateSymptoms.append(symptom)
                }
                
            } catch {
                self.error = error
                print("Error saving symptom: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteSymptom(_ symptom: Symptom) {
        Task {
            do {
                try await dataService.deleteSymptom(symptom)
                
                // Remove from local arrays
                todaySymptoms.removeAll { $0.id == symptom.id }
                recentSymptoms.removeAll { $0.id == symptom.id }
                selectedDateSymptoms.removeAll { $0.id == symptom.id }
                
                // Recalculate trends
                calculateTrends()
                calculateWeeklyTrends()
                calculateSeverityTrends()
                
            } catch {
                self.error = error
                print("Error deleting symptom: \(error.localizedDescription)")
            }
        }
    }
    
    func updateSymptom(_ symptom: Symptom) {
        Task {
            do {
                try await dataService.updateSymptom(symptom)
                loadData()
            } catch {
                self.error = error
                print("Error updating symptom: \(error.localizedDescription)")
            }
        }
    }
    
    func getSymptomsByType() -> [SymptomType: [Symptom]] {
        var groupedSymptoms: [SymptomType: [Symptom]] = [:]
        
        for symptom in todaySymptoms {
            if let type = SymptomType(rawValue: symptom.type) {
                groupedSymptoms[type, default: []].append(symptom)
            }
        }
        
        return groupedSymptoms
    }
    
    func getMostCommonSymptoms(limit: Int = 5) -> [(name: String, count: Int)] {
        return symptomTrends
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { (name: $0.key, count: $0.value) }
    }
    
    func getSymptomFrequency(for symptomName: String) -> Double {
        let occurrences = recentSymptoms.filter { $0.name == symptomName }.count
        let totalDays = 30
        return Double(occurrences) / Double(totalDays) * 100
    }
    
    func getAverageSeverity(for symptomName: String) -> Double {
        let symptoms = recentSymptoms.filter { $0.name == symptomName }
        guard !symptoms.isEmpty else { return 0 }
        
        let totalSeverity = symptoms.reduce(0) { $0 + $1.severity }
        return Double(totalSeverity) / Double(symptoms.count)
    }
    
    func hasSymptomToday(_ symptomName: String) -> Bool {
        return todaySymptoms.contains { $0.name == symptomName }
    }
    
    func getSymptomHistory(for symptomName: String, days: Int = 30) -> [Symptom] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return recentSymptoms
            .filter { $0.name == symptomName && $0.date >= cutoffDate }
            .sorted { $0.date > $1.date }
    }
    
    func refreshData() async {
        await MainActor.run {
            loadData()
        }
    }
    
    func clearError() {
        error = nil
    }
    
    // MARK: - Analytics Methods
    
    func getSymptomCorrelations() -> [(symptom1: String, symptom2: String, correlation: Double)] {
        var correlations: [(String, String, Double)] = []
        let uniqueSymptoms = Array(Set(recentSymptoms.map { $0.name }))
        
        for i in 0..<uniqueSymptoms.count {
            for j in (i+1)..<uniqueSymptoms.count {
                let symptom1 = uniqueSymptoms[i]
                let symptom2 = uniqueSymptoms[j]
                
                let correlation = calculateCorrelation(between: symptom1, and: symptom2)
                if abs(correlation) > 0.3 { // Only include meaningful correlations
                    correlations.append((symptom1, symptom2, correlation))
                }
            }
        }
        
        return correlations.sorted { abs($0.correlation) > abs($1.correlation) }
    }
    
    private func calculateCorrelation(between symptom1: String, and symptom2: String) -> Double {
        let calendar = Calendar.current
        var dayPairs: [(Bool, Bool)] = []
        
        // Check each day in the last 30 days
        for dayOffset in 0..<30 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) ?? Date()
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
            
            let daySymptoms = recentSymptoms.filter { $0.date >= startOfDay && $0.date < endOfDay }
            
            let hasSymptom1 = daySymptoms.contains { $0.name == symptom1 }
            let hasSymptom2 = daySymptoms.contains { $0.name == symptom2 }
            
            dayPairs.append((hasSymptom1, hasSymptom2))
        }
        
        // Calculate Pearson correlation coefficient
        let n = Double(dayPairs.count)
        let sum1 = dayPairs.reduce(0.0) { $0 + ($1.0 ? 1.0 : 0.0) }
        let sum2 = dayPairs.reduce(0.0) { $0 + ($1.1 ? 1.0 : 0.0) }
        let sum1Sq = dayPairs.reduce(0.0) { $0 + ($1.0 ? 1.0 : 0.0) * ($1.0 ? 1.0 : 0.0) }
        let sum2Sq = dayPairs.reduce(0.0) { $0 + ($1.1 ? 1.0 : 0.0) * ($1.1 ? 1.0 : 0.0) }
        let sumProducts = dayPairs.reduce(0.0) { $0 + ($1.0 ? 1.0 : 0.0) * ($1.1 ? 1.0 : 0.0) }
        
        let numerator = n * sumProducts - sum1 * sum2
        let denominator = sqrt((n * sum1Sq - sum1 * sum1) * (n * sum2Sq - sum2 * sum2))
        
        return denominator == 0 ? 0 : numerator / denominator
    }
}