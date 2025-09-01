import Foundation
import HealthKit
import SwiftUI
import Combine

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    
    @Published var isAuthorized = false
    @Published var authorizationStatus: String = "Not Requested"
    @Published var isLoading = false
    @Published var lastSyncDate: Date?
    
    private let healthStore = HKHealthStore()
    private var cancellables = Set<AnyCancellable>()
    
    // Define what data types we want to read and write
    private let typesToShare: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
        HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!,
        HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!,
        HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
        HKObjectType.categoryType(forIdentifier: .sexualActivity)!
    ]
    
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.categoryType(forIdentifier: .menstrualFlow)!,
        HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!,
        HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!,
        HKObjectType.quantityType(forIdentifier: .basalBodyTemperature)!,
        HKObjectType.categoryType(forIdentifier: .sexualActivity)!,
        HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .bodyTemperature)!
    ]
    
    private init() {
        checkInitialAuthorizationStatus()
        setupObservers()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("❌ HealthKit not available on this device")
            authorizationStatus = "Not Available"
            return
        }
        
        authorizationStatus = "Requesting..."
        isLoading = true
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if success {
                    self?.isAuthorized = true
                    self?.authorizationStatus = "Authorized"
                    print("✅ HealthKit authorized successfully")
                    self?.performInitialSync()
                } else {
                    self?.isAuthorized = false
                    self?.authorizationStatus = "Denied"
                    print("❌ HealthKit authorization denied")
                }
                
                if let error = error {
                    print("HealthKit authorization error: \(error.localizedDescription)")
                    self?.authorizationStatus = "Error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func checkInitialAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else {
            authorizationStatus = "Not Available"
            return
        }
        
        let menstrualFlowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let status = healthStore.authorizationStatus(for: menstrualFlowType)
        
        switch status {
        case .notDetermined:
            authorizationStatus = "Not Requested"
            isAuthorized = false
        case .sharingDenied:
            authorizationStatus = "Denied"
            isAuthorized = false
        case .sharingAuthorized:
            authorizationStatus = "Authorized"
            isAuthorized = true
            performInitialSync()
        @unknown default:
            authorizationStatus = "Unknown"
            isAuthorized = false
        }
    }
    
    func checkAuthorizationStatus() -> String {
        guard HKHealthStore.isHealthDataAvailable() else {
            return "HealthKit not available"
        }
        
        let menstrualFlowType = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let status = healthStore.authorizationStatus(for: menstrualFlowType)
        
        switch status {
        case .notDetermined:
            return "Not Determined"
        case .sharingDenied:
            return "Sharing Denied"
        case .sharingAuthorized:
            return "Sharing Authorized"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Data Writing
    
    func saveMenstrualFlow(flow: HKCategoryValueMenstrualFlow, date: Date = Date()) {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot save menstrual flow")
            return
        }
        
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let sample = HKCategorySample(
            type: type,
            value: flow.rawValue,
            start: date,
            end: date
        )
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Menstrual flow (\(flow.description)) saved to HealthKit")
                } else if let error = error {
                    print("❌ Error saving menstrual flow: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func saveBasalBodyTemperature(temperature: Double, date: Date = Date()) {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot save temperature")
            return
        }
        
        let type = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!
        let quantity = HKQuantity(unit: HKUnit.degreeCelsius(), doubleValue: temperature)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Temperature (\(temperature)°C) saved to HealthKit")
                } else if let error = error {
                    print("❌ Error saving temperature: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func saveCervicalMucusQuality(quality: HKCategoryValueCervicalMucusQuality, date: Date = Date()) {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot save cervical mucus")
            return
        }
        
        let type = HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!
        let sample = HKCategorySample(
            type: type,
            value: quality.rawValue,
            start: date,
            end: date
        )
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Cervical mucus quality saved to HealthKit")
                } else if let error = error {
                    print("❌ Error saving cervical mucus: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func saveOvulationTestResult(result: HKCategoryValueOvulationTestResult, date: Date = Date()) {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot save ovulation test")
            return
        }
        
        let type = HKObjectType.categoryType(forIdentifier: .ovulationTestResult)!
        let sample = HKCategorySample(
            type: type,
            value: result.rawValue,
            start: date,
            end: date
        )
        
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("✅ Ovulation test result saved to HealthKit")
                } else if let error = error {
                    print("❌ Error saving ovulation test: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Data Reading
    
    func fetchRecentMenstrualData(lastDays: Int = 90, completion: @escaping ([HKCategorySample]) -> Void) {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot fetch menstrual data")
            completion([])
            return
        }
        
        let type = HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
        let startDate = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("❌ Error fetching menstrual data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            let results = samples as? [HKCategorySample] ?? []
            print("✅ Fetched \(results.count) menstrual flow entries from HealthKit")
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchBasalBodyTemperature(lastDays: Int = 90, completion: @escaping ([HKQuantitySample]) -> Void) {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot fetch temperature data")
            completion([])
            return
        }
        
        let type = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature)!
        let startDate = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("❌ Error fetching temperature data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            let results = samples as? [HKQuantitySample] ?? []
            print("✅ Fetched \(results.count) temperature readings from HealthKit")
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchCervicalMucusData(lastDays: Int = 90, completion: @escaping ([HKCategorySample]) -> Void) {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot fetch cervical mucus data")
            completion([])
            return
        }
        
        let type = HKObjectType.categoryType(forIdentifier: .cervicalMucusQuality)!
        let startDate = Calendar.current.date(byAdding: .day, value: -lastDays, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: type,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            if let error = error {
                print("❌ Error fetching cervical mucus data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            let results = samples as? [HKCategorySample] ?? []
            print("✅ Fetched \(results.count) cervical mucus entries from HealthKit")
            
            DispatchQueue.main.async {
                completion(results)
            }
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Sync Operations
    
    func syncLatestData() async {
        guard isAuthorized else {
            print("❌ HealthKit not authorized - cannot sync data")
            return
        }
        
        isLoading = true
        
        await withCheckedContinuation { continuation in
            let group = DispatchGroup()
            
            // Fetch menstrual data
            group.enter()
            fetchRecentMenstrualData(lastDays: 30) { samples in
                // Process menstrual flow data
                self.processMenstrualFlowData(samples)
                group.leave()
            }
            
            // Fetch temperature data
            group.enter()
            fetchBasalBodyTemperature(lastDays: 30) { samples in
                // Process temperature data
                self.processTemperatureData(samples)
                group.leave()
            }
            
            // Fetch cervical mucus data
            group.enter()
            fetchCervicalMucusData(lastDays: 30) { samples in
                // Process cervical mucus data
                self.processCervicalMucusData(samples)
                group.leave()
            }
            
            group.notify(queue: .main) {
                self.isLoading = false
                self.lastSyncDate = Date()
                print("🔄 HealthKit sync completed")
                continuation.resume()
            }
        }
    }
    
    private func performInitialSync() {
        Task {
            await syncLatestData()
        }
    }
    
    // MARK: - Data Processing
    
    private func processMenstrualFlowData(_ samples: [HKCategorySample]) {
        // Process and update local data store
        for sample in samples {
            let flowValue = HKCategoryValueMenstrualFlow(rawValue: sample.value)
            print("Processing menstrual flow: \(flowValue?.description ?? "Unknown") on \(sample.startDate)")
            
            // Here you would update your SwiftData models
            // This is where you'd integrate with DataService to update cycle data
        }
    }
    
    private func processTemperatureData(_ samples: [HKQuantitySample]) {
        // Process temperature readings
        for sample in samples {
            let temperature = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
            print("Processing temperature: \(temperature)°C on \(sample.startDate)")
            
            // Update local data store with temperature readings
        }
    }
    
    private func processCervicalMucusData(_ samples: [HKCategorySample]) {
        // Process cervical mucus quality data
        for sample in samples {
            let quality = HKCategoryValueCervicalMucusQuality(rawValue: sample.value)
            print("Processing cervical mucus: \(quality?.description ?? "Unknown") on \(sample.startDate)")
            
            // Update local data store
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Set up background delivery for real-time updates
        guard isAuthorized else { return }
        
        for type in typesToRead {
            if let sampleType = type as? HKSampleType {
                let query = HKObserverQuery(sampleType: sampleType, predicate: nil) { [weak self] _, _, error in
                    if let error = error {
                        print("❌ Observer query error: \(error.localizedDescription)")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        print("🔄 HealthKit data updated, triggering sync")
                        Task {
                            await self?.syncLatestData()
                        }
                    }
                }
                
                healthStore.execute(query)
                healthStore.enableBackgroundDelivery(for: sampleType, frequency: .immediate) { success, error in
                    if let error = error {
                        print("❌ Background delivery setup error: \(error.localizedDescription)")
                    } else if success {
                        print("✅ Background delivery enabled for \(sampleType.identifier)")
                    }
                }
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    func saveFlowEntry(level: String, date: Date = Date()) {
        let flow: HKCategoryValueMenstrualFlow
        
        switch level.lowercased() {
        case "light":
            flow = .light
        case "medium":
            flow = .medium
        case "heavy":
            flow = .heavy
        default:
            flow = .unspecified
        }
        
        saveMenstrualFlow(flow: flow, date: date)
    }
    
    func getHealthKitStatus() -> (isAvailable: Bool, isAuthorized: Bool, statusMessage: String) {
        let isAvailable = HKHealthStore.isHealthDataAvailable()
        return (isAvailable, isAuthorized, authorizationStatus)
    }
}

// MARK: - Extensions for Better Descriptions

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
}

extension HKCategoryValueOvulationTestResult {
    var description: String {
        switch self {
        case .negative: return "Negative"
        case .luteinizingHormoneSurge: return "LH Surge"
        case .indeterminate: return "Indeterminate"
        case .estrogenSurge: return "Estrogen Surge"
        @unknown default: return "Unknown"
        }
    }
}