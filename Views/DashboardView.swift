import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @EnvironmentObject private var healthKitService: HealthKitService
    @State private var showingPeriodLogger = false
    @State private var showingSymptomLogger = false
    @State private var showingMoodLogger = false
    @State private var showingHormoneScanner = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 24) {
                    // Cycle Status Card
                    CycleStatusCard(cycleData: viewModel.cycleData)
                        .onTapGesture {
                            showingPeriodLogger = true
                        }
                    
                    // HealthKit Status
                    if healthKitService.isAuthorized {
                        HealthKitStatusCard()
                    }
                    
                    // AI Insights Section
                    AIInsightsSection(insights: viewModel.aiInsights)
                    
                    // Today's Overview
                    TodaysOverviewSection(
                        symptoms: viewModel.recentSymptoms,
                        mood: viewModel.todayMood,
                        hormoneReadings: viewModel.todayHormoneReadings
                    )
                    
                    // Quick Actions Grid
                    QuickActionsGrid(
                        onLogPeriod: { showingPeriodLogger = true },
                        onAddSymptom: { showingSymptomLogger = true },
                        onTrackMood: { showingMoodLogger = true },
                        onScanTest: { showingHormoneScanner = true }
                    )
                    
                    // Cycle Trends Chart
                    CycleTrendsChart(chartData: viewModel.cycleTrendsData)
                    
                    // Recent Activity
                    RecentActivitySection(
                        symptoms: viewModel.recentSymptoms,
                        hormoneReadings: viewModel.recentHormoneReadings
                    )
                }
                .padding()
            }
            .navigationTitle("CYCLEai")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh Data") {
                            Task { await viewModel.refreshData() }
                        }
                        Button("Sync HealthKit") {
                            Task { await healthKitService.syncLatestData() }
                        }
                        Button("Export Data") {
                            // TODO: Implement data export
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .onAppear {
                viewModel.loadData()
            }
            .sheet(isPresented: $showingPeriodLogger) {
                PeriodLoggerView { flow, date in
                    viewModel.logPeriod(flow: flow, date: date)
                }
            }
            .sheet(isPresented: $showingSymptomLogger) {
                QuickSymptomLoggerView { symptom in
                    viewModel.logSymptom(symptom)
                }
            }
            .sheet(isPresented: $showingMoodLogger) {
                QuickMoodLoggerView { mood in
                    viewModel.logMood(mood)
                }
            }
            .sheet(isPresented: $showingHormoneScanner) {
                HormoneScannerView { reading in
                    viewModel.addHormoneReading(reading)
                }
            }
        }
    }
}

struct CycleStatusCard: View {
    @ObservedObject var cycleData: CycleData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Cycle")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(cycleData.currentPhase.description)
                        .font(.subheadline)
                        .foregroundColor(cycleData.currentPhase.color)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Day \(cycleData.cycleDay)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(cycleData.currentPhase.color)
                        .clipShape(Capsule())
                    
                    Text("of \(cycleData.cycleLength)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 32) {
                // Cycle Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(cycleData.cycleDay) / CGFloat(max(cycleData.cycleLength, 1)))
                        .stroke(
                            AngularGradient(
                                colors: [
                                    cycleData.currentPhase.color,
                                    cycleData.currentPhase.color.opacity(0.6),
                                    cycleData.currentPhase.color
                                ],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.8), value: cycleData.cycleDay)
                    
                    VStack(spacing: 4) {
                        Text("\(max(cycleData.daysUntilNextPeriod, 0))")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(cycleData.currentPhase.color)
                        
                        Text(cycleData.daysUntilNextPeriod <= 0 ? "Period due" : "days left")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                
                // Cycle Information
                VStack(alignment: .leading, spacing: 16) {
                    CycleInfoRow(
                        title: "Fertility",
                        value: cycleData.fertilityStatus.rawValue.capitalized,
                        color: fertilityColor(for: cycleData.fertilityStatus),
                        icon: fertilityIcon(for: cycleData.fertilityStatus)
                    )
                    
                    if let nextPeriod = cycleData.nextPredictedPeriod {
                        CycleInfoRow(
                            title: "Next Period",
                            value: nextPeriod.formatted(.dateTime.month(.abbreviated).day()),
                            color: .red,
                            icon: "drop.circle"
                        )
                    }
                    
                    if let ovulation = cycleData.ovulationDate {
                        CycleInfoRow(
                            title: "Ovulation",
                            value: ovulation.formatted(.dateTime.month(.abbreviated).day()),
                            color: .green,
                            icon: "leaf.circle"
                        )
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
    
    private func fertilityColor(for status: FertilityStatus) -> Color {
        switch status {
        case .low: return .blue
        case .medium: return .yellow
        case .high: return .orange
        case .peak: return .red
        }
    }
    
    private func fertilityIcon(for status: FertilityStatus) -> String {
        switch status {
        case .low: return "circle"
        case .medium: return "circle.lefthalf.filled"
        case .high: return "circle.fill"
        case .peak: return "flame.circle.fill"
        }
    }
}

struct CycleInfoRow: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct HealthKitStatusCard: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .foregroundColor(.red)
                .font(.title2)
                .frame(width: 32, height: 32)
                .background(.red.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text("HealthKit Connected")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("Data synced with Apple Health")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Sync") {
                Task { await healthKitService.syncLatestData() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.green.opacity(0.1))
        )
    }
}

struct AIInsightsSection: View {
    let insights: [AIInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.purple)
                    .font(.title2)
                
                Text("AI Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !insights.isEmpty {
                    Text("\(insights.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.purple)
                        .clipShape(Capsule())
                }
            }
            
            if insights.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("Keep tracking to unlock insights")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Log your symptoms, mood, and cycle data to receive personalized AI-powered insights.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(insights.prefix(3)) { insight in
                        AIInsightCard(insight: insight)
                    }
                    
                    if insights.count > 3 {
                        NavigationLink("View All Insights") {
                            AIInsightsListView(insights: insights)
                        }
                        .font(.caption)
                        .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct AIInsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.type.iconName)
                .font(.title3)
                .foregroundColor(insight.type.color)
                .frame(width: 32, height: 32)
                .background(insight.type.color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(insight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if insight.confidence > 0.8 {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Text(insight.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(insight.type.color.opacity(0.05))
        )
    }
}

struct TodaysOverviewSection: View {
    let symptoms: [Symptom]
    let mood: MoodEntry?
    let hormoneReadings: [HormoneReading]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                OverviewCard(
                    title: "Symptoms",
                    value: "\(symptoms.count)",
                    icon: "heart.text.square",
                    color: .orange
                )
                
                OverviewCard(
                    title: "Mood",
                    value: mood?.mood.isEmpty == false ? mood!.mood : "Not logged",
                    icon: "face.smiling",
                    color: .blue
                )
                
                OverviewCard(
                    title: "Tests",
                    value: "\(hormoneReadings.count)",
                    icon: "testtube.2",
                    color: .green
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct OverviewCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

struct QuickActionsGrid: View {
    let onLogPeriod: () -> Void
    let onAddSymptom: () -> Void
    let onTrackMood: () -> Void
    let onScanTest: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                QuickActionCard(
                    title: "Log Period",
                    icon: "drop.circle",
                    color: .red,
                    action: onLogPeriod
                )
                
                QuickActionCard(
                    title: "Add Symptom",
                    icon: "heart.text.square",
                    color: .orange,
                    action: onAddSymptom
                )
                
                QuickActionCard(
                    title: "Track Mood",
                    icon: "face.smiling",
                    color: .blue,
                    action: onTrackMood
                )
                
                QuickActionCard(
                    title: "Scan Test",
                    icon: "camera.viewfinder",
                    color: .green,
                    action: onScanTest
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CycleTrendsChart: View {
    let chartData: [CycleTrendData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cycle Trends")
                .font(.headline)
                .fontWeight(.semibold)
            
            if chartData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No trend data yet")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Complete a few cycles to see your patterns.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                Chart(chartData) { data in
                    LineMark(
                        x: .value("Cycle", data.cycleNumber),
                        y: .value("Length", data.cycleLength)
                    )
                    .foregroundStyle(.purple)
                    .symbol(Circle())
                }
                .frame(height: 120)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(position: .bottom)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct RecentActivitySection: View {
    let symptoms: [Symptom]
    let hormoneReadings: [HormoneReading]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            if symptoms.isEmpty && hormoneReadings.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(symptoms.prefix(3)) { symptom in
                        ActivityRow(
                            title: symptom.name,
                            subtitle: "Symptom • \(symptom.date.formatted(.dateTime.hour().minute()))",
                            icon: "heart.text.square",
                            color: .orange
                        )
                    }
                    
                    ForEach(hormoneReadings.prefix(2)) { reading in
                        ActivityRow(
                            title: "Hormone Test",
                            subtitle: "Reading • \(reading.date.formatted(.dateTime.hour().minute()))",
                            icon: "testtube.2",
                            color: .green
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
    }
}

struct ActivityRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Supporting Views

struct AIInsightsListView: View {
    let insights: [AIInsight]
    
    var body: some View {
        NavigationView {
            List(insights) { insight in
                AIInsightCard(insight: insight)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("AI Insights")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PeriodLoggerView: View {
    let onSave: (String, Date) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFlow = "Medium"
    @State private var selectedDate = Date()
    
    let flowOptions = ["Light", "Medium", "Heavy"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Period Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("Flow", selection: $selectedFlow) {
                        ForEach(flowOptions, id: \.self) { flow in
                            Text(flow).tag(flow)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Log Period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedFlow, selectedDate)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QuickSymptomLoggerView: View {
    let onSave: (Symptom) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSymptom: SymptomOption?
    @State private var severity = 3
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Quick Symptom Log")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(SymptomOption.allSymptoms.prefix(6)) { symptom in
                        Button {
                            selectedSymptom = symptom
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: symptom.icon)
                                    .font(.title2)
                                    .foregroundColor(selectedSymptom?.id == symptom.id ? .white : symptom.type.color)
                                
                                Text(symptom.name)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedSymptom?.id == symptom.id ? .white : .primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(selectedSymptom?.id == symptom.id ? symptom.type.color : symptom.type.color.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if selectedSymptom != nil {
                    VStack(spacing: 12) {
                        Text("Severity: \(severity)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Slider(value: Binding(get: { Double(severity) }, set: { severity = Int($0) }), in: 1...5, step: 1)
                            .accentColor(selectedSymptom?.type.color)
                    }
                    .padding(.top)
                }
                
                Spacer()
                
                Button("Save Symptom") {
                    if let symptom = selectedSymptom {
                        let newSymptom = Symptom(
                            type: symptom.type.rawValue,
                            name: symptom.name,
                            severity: severity
                        )
                        onSave(newSymptom)
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedSymptom == nil)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct QuickMoodLoggerView: View {
    let onSave: (MoodEntry) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMood = ""
    @State private var energyLevel = 5
    @State private var stressLevel = 5
    
    let moodOptions = ["😊 Happy", "😐 Neutral", "😔 Sad", "😤 Irritated", "😰 Anxious", "😴 Tired"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("How are you feeling?")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(moodOptions, id: \.self) { mood in
                        Button {
                            selectedMood = mood
                        } label: {
                            Text(mood)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(selectedMood == mood ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(selectedMood == mood ? .blue : .blue.opacity(0.1))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Text("Energy Level: \(energyLevel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Slider(value: Binding(get: { Double(energyLevel) }, set: { energyLevel = Int($0) }), in: 1...10, step: 1)
                            .accentColor(.green)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Stress Level: \(stressLevel)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Slider(value: Binding(get: { Double(stressLevel) }, set: { stressLevel = Int($0) }), in: 1...10, step: 1)
                            .accentColor(.red)
                    }
                }
                
                Spacer()
                
                Button("Save Mood") {
                    let mood = MoodEntry(
                        mood: selectedMood,
                        energy: energyLevel,
                        stress: stressLevel
                    )
                    onSave(mood)
                    dismiss()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(selectedMood.isEmpty)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct HormoneScannerView: View {
    let onSave: (HormoneReading) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                
                Text("Hormone Test Scanner")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This feature will use AI to scan and interpret hormone test results from photos.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Take Photo") {
                    // TODO: Implement camera functionality
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Choose from Library") {
                    // TODO: Implement photo library functionality
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Supporting Data Models

struct CycleTrendData: Identifiable {
    let id = UUID()
    let cycleNumber: Int
    let cycleLength: Int
    let date: Date
}

// MARK: - Extensions

private extension SymptomType {
    var color: Color {
        switch self {
        case .physical: return .red
        case .emotional: return .blue
        case .behavioral: return .green
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(HealthKitService.shared)
}