import Foundation
import SwiftUI
import Combine

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var insights: [AIInsight] = []
    @Published var isGeneratingInsights = false
    @Published var lastInsightUpdate: Date?
    
    var insightsPublisher: Published<[AIInsight]>.Publisher { $insights }
    
    private let dataService = DataService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        dataService.cycleDataPublisher
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] cycleData in
                Task {
                    await self?.generateInsights(for: cycleData)
                }
            }
            .store(in: &cancellables)
    }
    
    func generateInsights(for cycleData: CycleData) async throws -> [AIInsight] {
        isGeneratingInsights = true
        defer { isGeneratingInsights = false }
        
        var generatedInsights: [AIInsight] = []
        
        // Cycle Phase Insights
        generatedInsights.append(contentsOf: await generatePhaseInsights(cycleData))
        
        // Fertility Insights
        generatedInsights.append(contentsOf: await generateFertilityInsights(cycleData))
        
        // Symptom Pattern Insights
        generatedInsights.append(contentsOf: await generateSymptomInsights())
        
        // Hormone Level Insights
        generatedInsights.append(contentsOf: await generateHormoneInsights())
        
        // Cycle Irregularity Insights
        generatedInsights.append(contentsOf: await generateIrregularityInsights(cycleData))
        
        // Health Recommendations
        generatedInsights.append(contentsOf: await generateHealthRecommendations(cycleData))
        
        // Sort by confidence and relevance
        generatedInsights.sort { $0.confidence > $1.confidence }
        
        self.insights = Array(generatedInsights.prefix(6))
        self.lastInsightUpdate = Date()
        
        return self.insights
    }
    
    private func generatePhaseInsights(_ cycleData: CycleData) async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        switch cycleData.currentPhase {
        case .menstrual:
            insights.append(AIInsight(
                title: "Menstrual Phase Active",
                content: "You're currently in your menstrual phase. Focus on rest, hydration, and gentle movement. Iron-rich foods can help replenish what's lost.",
                type: .recommendation,
                confidence: 0.95,
                actionable: true,
                createdAt: Date()
            ))
            
            if cycleData.cycleDay > 7 {
                insights.append(AIInsight(
                    title: "Extended Menstrual Phase",
                    content: "Your period has lasted longer than typical. Consider tracking flow intensity and consult your healthcare provider if this continues.",
                    type: .warning,
                    confidence: 0.80,
                    actionable: true,
                    createdAt: Date()
                ))
            }
            
        case .follicular:
            insights.append(AIInsight(
                title: "Follicular Phase Energy",
                content: "You're in your follicular phase when energy typically increases. This is a great time for new projects and challenging workouts.",
                type: .recommendation,
                confidence: 0.90,
                actionable: true,
                createdAt: Date()
            ))
            
        case .ovulatory:
            insights.append(AIInsight(
                title: "Peak Fertility Window",
                content: "You're in your ovulatory phase with peak fertility. Your body temperature may be slightly elevated and cervical mucus changes.",
                type: .prediction,
                confidence: 0.92,
                actionable: true,
                createdAt: Date()
            ))
            
        case .luteal:
            insights.append(AIInsight(
                title: "Luteal Phase Preparation",
                content: "Your body is preparing for your next cycle. You might experience PMS symptoms. Focus on stress management and balanced nutrition.",
                type: .recommendation,
                confidence: 0.88,
                actionable: true,
                createdAt: Date()
            ))
        }
        
        return insights
    }
    
    private func generateFertilityInsights(_ cycleData: CycleData) async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        let daysToOvulation = calculateDaysToOvulation(cycleData)
        
        if daysToOvulation <= 2 && daysToOvulation >= 0 {
            insights.append(AIInsight(
                title: "Ovulation Approaching",
                content: "Ovulation is predicted within the next 2 days. This is your highest fertility window if you're trying to conceive.",
                type: .prediction,
                confidence: 0.87,
                actionable: true,
                createdAt: Date()
            ))
        }
        
        if cycleData.fertilityStatus == .high || cycleData.fertilityStatus == .peak {
            insights.append(AIInsight(
                title: "High Fertility Period",
                content: "You're currently in a high fertility window. Track cervical mucus and basal body temperature for more accurate predictions.",
                type: .recommendation,
                confidence: 0.85,
                actionable: true,
                createdAt: Date()
            ))
        }
        
        return insights
    }
    
    private func generateSymptomInsights() async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        do {
            let recentSymptoms = try await dataService.getRecentSymptoms(days: 30)
            let symptomCounts = Dictionary(grouping: recentSymptoms, by: { $0.name })
                .mapValues { $0.count }
            
            // Find most common symptoms
            if let mostCommon = symptomCounts.max(by: { $0.value < $1.value }) {
                if mostCommon.value >= 5 {
                    insights.append(AIInsight(
                        title: "Recurring Symptom Pattern",
                        content: "You've logged '\(mostCommon.key)' \(mostCommon.value) times this month. Consider tracking triggers and discussing with your healthcare provider.",
                        type: .trend,
                        confidence: 0.82,
                        actionable: true,
                        createdAt: Date()
                    ))
                }
            }
            
            // Check for severe symptoms
            let severeSymptoms = recentSymptoms.filter { $0.severity >= 4 }
            if severeSymptoms.count >= 3 {
                insights.append(AIInsight(
                    title: "High Severity Symptoms",
                    content: "You've reported several high-severity symptoms recently. Consider lifestyle adjustments or consulting your healthcare provider.",
                    type: .warning,
                    confidence: 0.78,
                    actionable: true,
                    createdAt: Date()
                ))
            }
            
        } catch {
            print("Error generating symptom insights: \(error)")
        }
        
        return insights
    }
    
    private func generateHormoneInsights() async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        do {
            let recentReadings = try await dataService.getRecentHormoneReadings(days: 30)
            
            if recentReadings.count >= 3 {
                // Analyze estrogen trends
                let estrogenLevels = recentReadings.map { $0.estrogenLevel }
                if let avgEstrogen = estrogenLevels.average() {
                    if avgEstrogen > 300 {
                        insights.append(AIInsight(
                            title: "Elevated Estrogen Levels",
                            content: "Your recent estrogen readings are above normal range. This could indicate approaching ovulation or other hormonal changes.",
                            type: .trend,
                            confidence: 0.75,
                            actionable: true,
                            createdAt: Date()
                        ))
                    }
                }
                
                // Analyze LH surge
                let lhLevels = recentReadings.map { $0.lhLevel }
                if let maxLH = lhLevels.max(), maxLH > 20 {
                    insights.append(AIInsight(
                        title: "LH Surge Detected",
                        content: "Your LH levels show a surge pattern, indicating ovulation likely occurred within 24-48 hours of the peak reading.",
                        type: .prediction,
                        confidence: 0.88,
                        actionable: true,
                        createdAt: Date()
                    ))
                }
            } else {
                insights.append(AIInsight(
                    title: "More Hormone Data Needed",
                    content: "Track hormone levels more regularly to receive personalized insights about your cycle patterns and predictions.",
                    type: .recommendation,
                    confidence: 0.70,
                    actionable: true,
                    createdAt: Date()
                ))
            }
            
        } catch {
            print("Error generating hormone insights: \(error)")
        }
        
        return insights
    }
    
    private func generateIrregularityInsights(_ cycleData: CycleData) async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Check for cycle length irregularities
        if cycleData.cycleLength < 21 || cycleData.cycleLength > 35 {
            insights.append(AIInsight(
                title: "Irregular Cycle Length",
                content: "Your cycle length of \(cycleData.cycleLength) days is outside the typical range. Consider tracking for a few more cycles and consulting your healthcare provider.",
                type: .warning,
                confidence: 0.85,
                actionable: true,
                createdAt: Date()
            ))
        }
        
        // Check for period length irregularities
        if cycleData.periodLength > 7 {
            insights.append(AIInsight(
                title: "Extended Period Duration",
                content: "Your period duration of \(cycleData.periodLength) days is longer than typical. Monitor flow intensity and consider medical consultation.",
                type: .warning,
                confidence: 0.80,
                actionable: true,
                createdAt: Date()
            ))
        }
        
        return insights
    }
    
    private func generateHealthRecommendations(_ cycleData: CycleData) async -> [AIInsight] {
        var insights: [AIInsight] = []
        
        // Nutrition recommendations based on cycle phase
        switch cycleData.currentPhase {
        case .menstrual:
            insights.append(AIInsight(
                title: "Nutrition Focus: Iron & Magnesium",
                content: "During menstruation, focus on iron-rich foods like spinach and lean meats, plus magnesium for cramp relief from dark chocolate and nuts.",
                type: .recommendation,
                confidence: 0.90,
                actionable: true,
                createdAt: Date()
            ))
            
        case .follicular:
            insights.append(AIInsight(
                title: "Energy Optimization",
                content: "Your energy is naturally increasing. This is an ideal time for high-intensity workouts and tackling challenging projects.",
                type: .recommendation,
                confidence: 0.85,
                actionable: true,
                createdAt: Date()
            ))
            
        case .ovulatory:
            insights.append(AIInsight(
                title: "Peak Performance Window",
                content: "You're at peak physical and mental performance. Great time for important meetings, workouts, and social activities.",
                type: .recommendation,
                confidence: 0.88,
                actionable: true,
                createdAt: Date()
            ))
            
        case .luteal:
            insights.append(AIInsight(
                title: "Self-Care Priority",
                content: "Focus on stress management, gentle exercise, and comfort foods. Your body is working hard preparing for the next cycle.",
                type: .recommendation,
                confidence: 0.87,
                actionable: true,
                createdAt: Date()
            ))
        }
        
        return insights
    }
    
    private func calculateDaysToOvulation(_ cycleData: CycleData) -> Int {
        let ovulationDay = cycleData.cycleLength / 2
        return ovulationDay - cycleData.cycleDay
    }
    
    func refreshInsights() async {
        do {
            _ = try await generateInsights(for: dataService.cycleData)
        } catch {
            print("Error refreshing insights: \(error)")
        }
    }
    
    func clearInsights() {
        insights.removeAll()
        lastInsightUpdate = nil
    }
    
    func getInsightsByType(_ type: AIInsightType) -> [AIInsight] {
        return insights.filter { $0.type == type }
    }
    
    func getActionableInsights() -> [AIInsight] {
        return insights.filter { $0.actionable }
    }
}

// MARK: - Helper Extensions

extension Array where Element == Double {
    func average() -> Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

extension AIInsight {
    var priorityScore: Double {
        var score = confidence
        
        // Boost score based on type importance
        switch type {
        case .warning:
            score += 0.2
        case .prediction:
            score += 0.15
        case .recommendation:
            score += 0.1
        case .trend:
            score += 0.05
        }
        
        // Boost actionable insights
        if actionable {
            score += 0.1
        }
        
        // Reduce score for older insights
        let daysSinceCreated = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        score -= Double(daysSinceCreated) * 0.02
        
        return min(1.0, max(0.0, score))
    }
}