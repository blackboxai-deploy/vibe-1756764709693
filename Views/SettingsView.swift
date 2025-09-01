import SwiftUI
import HealthKit

struct SettingsView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @State private var showingHealthTest = false
    @State private var showingCycleSettings = false
    @State private var showingDataExport = false
    @State private var showingAbout = false
    @State private var testTemperature: Double = 36.5
    @State private var selectedFlow: HKCategoryValueVaginalBleeding = .medium
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false
    
    let flowOptions: [HKCategoryValueVaginalBleeding] = [.light, .medium, .heavy]

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section(header: Text("Profile")) {
                    HStack {
                        Circle()
                            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text("CY")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CycleTracker User")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Text("Tracking since January 2024")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Edit") {
                            // TODO: Implement profile editing
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Button {
                        showingCycleSettings = true
                    } label: {
                        Label("Cycle Settings", systemImage: "calendar.circle")
                    }
                    .foregroundColor(.primary)
                }

                // HealthKit Integration Section
                Section(header: Text("Health Integration")) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .frame(width: 30)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("HealthKit Status")
                                .font(.subheadline)
                            Text(healthKitService.authorizationStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if healthKitService.isAuthorized {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title2)
                        } else {
                            Button("Enable") {
                                healthKitService.requestAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)
                            .controlSize(.small)
                        }
                    }
                    
                    if healthKitService.isAuthorized {
                        Button {
                            Task { await healthKitService.syncLatestData() }
                        } label: {
                            Label("Sync with Health App", systemImage: "arrow.clockwise")
                        }
                        .foregroundColor(.primary)

                        Button {
                            showingHealthTest = true
                        } label: {
                            Label("Test HealthKit Features", systemImage: "testtube.2")
                        }
                        .foregroundColor(.blue)
                    }
                    
                    NavigationLink("HealthKit Details", destination: HealthKitDetailView())
                }

                // App Settings Section
                Section(header: Text("App Settings")) {
                    HStack {
                        Label("Notifications", systemImage: "bell")
                        Spacer()
                        Toggle("", isOn: $notificationsEnabled)
                            .onChange(of: notificationsEnabled) { _, newValue in
                                if newValue {
                                    NotificationService.shared.requestPermissions()
                                }
                            }
                    }
                    
                    HStack {
                        Label("Dark Mode", systemImage: "moon")
                        Spacer()
                        Toggle("", isOn: $darkModeEnabled)
                    }
                    
                    Button {
                        showingDataExport = true
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.primary)
                }

                // Support Section
                Section(header: Text("Support")) {
                    Button {
                        // TODO: Implement help/FAQ
                    } label: {
                        Label("Help & FAQ", systemImage: "questionmark.circle")
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        // TODO: Implement feedback
                    } label: {
                        Label("Send Feedback", systemImage: "envelope")
                    }
                    .foregroundColor(.primary)
                    
                    Button {
                        showingAbout = true
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingHealthTest) {
                HealthKitTestView(
                    selectedFlow: $selectedFlow,
                    testTemperature: $testTemperature,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage
                )
                .environmentObject(healthKitService)
            }
            .sheet(isPresented: $showingCycleSettings) {
                CycleSettingsView()
            }
            .sheet(isPresented: $showingDataExport) {
                DataExportView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .alert("HealthKit", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }
}

// MARK: - Supporting Views

struct HealthKitDetailView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @State private var recentData: [HKCategorySample] = []
    @State private var isLoading = false

    var body: some View {
        List {
            Section(header: Text("Authorization Status")) {
                HStack {
                    Text("Current Status")
                    Spacer()
                    Text(healthKitService.authorizationStatus)
                        .fontWeight(.semibold)
                        .foregroundColor(healthKitService.isAuthorized ? .green : .orange)
                }
                
                HStack {
                    Text("System Check")
                    Spacer()
                    Text(healthKitService.checkAuthorizationStatus())
                        .foregroundColor(.secondary)
                }
                
                if !healthKitService.isAuthorized {
                    Button("Request Authorization") {
                        healthKitService.requestAuthorization()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            
            if healthKitService.isAuthorized {
                Section(header: Text("Recent Data")) {
                    if isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading...")
                                .foregroundColor(.secondary)
                        }
                    } else if recentData.isEmpty {
                        Text("No recent data")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(recentData.prefix(10), id: \.uuid) { sample in
                            VStack(alignment: .leading) {
                                Text(flowDescription(sample))
                                    .font(.headline)
                                Text(sample.startDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                    
                    Button("Refresh") {
                        loadData()
                    }
                }
            }
        }
        .navigationTitle("HealthKit Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
    }

    func loadData() {
        guard healthKitService.isAuthorized else { return }
        isLoading = true
        healthKitService.fetchRecentMenstrualData { samples in
            recentData = samples
            isLoading = false
        }
    }

    func flowDescription(_ sample: HKCategorySample) -> String {
        return HKCategoryValueVaginalBleeding(rawValue: sample.value)?.description ?? "Unknown"
    }
}

struct HealthKitTestView: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @Binding var selectedFlow: HKCategoryValueVaginalBleeding
    @Binding var testTemperature: Double
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @Environment(\.dismiss) private var dismiss

    let flowOptions: [HKCategoryValueVaginalBleeding] = [.light, .medium, .heavy]

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Test Menstrual Flow")) {
                    Picker("Flow Level", selection: $selectedFlow) {
                        ForEach(flowOptions, id: \.self) { flow in
                            Text(flow.description).tag(flow)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button("Save Flow") {
                        healthKitService.saveMenstrualFlow(flow: selectedFlow, date: Date())
                        showAlertMessage("✅ \(selectedFlow.description) flow saved!")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Section(header: Text("Test Temperature")) {
                    VStack(alignment: .leading) {
                        Text("Temperature: \(testTemperature, specifier: "%.1f") °C")
                            .foregroundColor(.secondary)
                        Slider(value: $testTemperature, in: 35...40, step: 0.1)
                        Button("Save Temperature") {
                            healthKitService.saveBasalBodyTemperature(temperature: testTemperature, date: Date())
                            showAlertMessage("🌡️ Temperature \(String(format: "%.1f", testTemperature)) °C saved!")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Section(header: Text("Actions")) {
                    Button("Sync Data") {
                        Task {
                            await healthKitService.syncLatestData()
                            showAlertMessage("🔄 Data synced")
                        }
                    }
                    Button("Check Authorization") {
                        let status = healthKitService.checkAuthorizationStatus()
                        showAlertMessage("🔍 Authorization status: \(status)")
                    }
                }
            }
            .navigationTitle("HealthKit Test")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("HealthKit", isPresented: $showAlert) {
                Button("OK") {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func showAlertMessage(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

struct CycleSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cycleLength: Double = 28
    @State private var periodLength: Double = 5
    @State private var lastPeriodDate = Date()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Cycle Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Average Cycle Length: \(Int(cycleLength)) days")
                        Slider(value: $cycleLength, in: 21...35, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Period Length: \(Int(periodLength)) days")
                        Slider(value: $periodLength, in: 3...10, step: 1)
                    }
                    
                    DatePicker("Last Period Start", selection: $lastPeriodDate, displayedComponents: .date)
                }
                
                Section(header: Text("Predictions")) {
                    HStack {
                        Text("Next Period")
                        Spacer()
                        Text(nextPeriodDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Estimated Ovulation")
                        Spacer()
                        Text(ovulationDate.formatted(date: .abbreviated, time: .omitted))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Cycle Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // TODO: Save settings to DataService
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var nextPeriodDate: Date {
        Calendar.current.date(byAdding: .day, value: Int(cycleLength), to: lastPeriodDate) ?? Date()
    }
    
    private var ovulationDate: Date {
        Calendar.current.date(byAdding: .day, value: Int(cycleLength / 2), to: lastPeriodDate) ?? Date()
    }
}

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var exportFormat = "JSON"
    @State private var includeSymptoms = true
    @State private var includeHormones = true
    @State private var includeMoods = true
    @State private var showingShareSheet = false
    
    let formats = ["JSON", "CSV", "PDF"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(formats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Data to Include")) {
                    Toggle("Symptoms", isOn: $includeSymptoms)
                    Toggle("Hormone Readings", isOn: $includeHormones)
                    Toggle("Mood Entries", isOn: $includeMoods)
                }
                
                Section {
                    Button("Export Data") {
                        showingShareSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                // TODO: Implement actual data export and sharing
                Text("Export functionality will be implemented here")
                    .presentationDetents([.medium])
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text("🌸")
                                .font(.system(size: 50))
                        )
                    
                    VStack(spacing: 8) {
                        Text("CycleTracker")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your intelligent companion for menstrual health")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        InfoRow(title: "Version", value: "1.0.0")
                        InfoRow(title: "Build", value: "2025.01.20")
                        InfoRow(title: "Developer", value: "Enhanced by AI")
                        InfoRow(title: "Platform", value: "iOS 17.0+")
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        FeatureRow(icon: "brain.head.profile", text: "AI-powered cycle predictions")
                        FeatureRow(icon: "heart.text.square", text: "Comprehensive symptom tracking")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Hormone level monitoring")
                        FeatureRow(icon: "calendar", text: "Interactive cycle calendar")
                        FeatureRow(icon: "heart.fill", text: "HealthKit integration")
                    }
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
                    
                    Text("© 2025 CycleTracker. All rights reserved.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// Extension for readable descriptions
extension HKCategoryValueVaginalBleeding {
    var description: String {
        switch self {
        case .unspecified: return "Unspecified"
        case .light: return "Light"
        case .medium: return "Medium"
        case .heavy: return "Heavy"
        @unknown default: return "Unknown"
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(HealthKitService.shared)
}