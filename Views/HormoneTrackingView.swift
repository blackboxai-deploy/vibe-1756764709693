import SwiftUI
import Charts

struct HormoneTrackingView: View {
    @StateObject private var viewModel = HormoneTrackingViewModel()
    @State private var showingAddReading = false
    @State private var selectedHormone: HormoneType = .estrogen
    @State private var selectedTimeRange: TimeRange = .week
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Range Selector
                    TimeRangeSelector(selectedRange: $selectedTimeRange)
                        .onChange(of: selectedTimeRange) { _ in
                            viewModel.updateTimeRange(selectedTimeRange)
                        }
                    
                    // Hormone Chart
                    if viewModel.chartData.isEmpty {
                        EmptyChartView()
                    } else {
                        HormoneChartView(
                            data: viewModel.chartData,
                            selectedHormone: $selectedHormone,
                            timeRange: selectedTimeRange
                        )
                    }
                    
                    // Hormone Type Selector
                    HormoneTypeSelector(selectedHormone: $selectedHormone)
                    
                    // Current Levels Card
                    if let currentReading = viewModel.currentReadings.first {
                        CurrentLevelsCard(reading: currentReading)
                    }
                    
                    // Add Reading Button
                    Button("Add Hormone Reading") {
                        showingAddReading = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    // Recent Readings Section
                    RecentReadingsSection(readings: viewModel.recentReadings)
                    
                    // Insights Section
                    if !viewModel.insights.isEmpty {
                        HormoneInsightsSection(insights: viewModel.insights)
                    }
                }
                .padding()
            }
            .navigationTitle("Hormone Tracking")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Export Data") {
                            viewModel.exportData()
                        }
                        Button("Sync with Health") {
                            Task {
                                await viewModel.syncWithHealthKit()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddReading) {
                AddHormoneReadingView { reading in
                    viewModel.addReading(reading)
                }
            }
            .onAppear {
                viewModel.loadData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
}

struct TimeRangeSelector: View {
    @Binding var selectedRange: TimeRange
    
    var body: some View {
        Picker("Time Range", selection: $selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName).tag(range)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

enum TimeRange: String, CaseIterable {
    case week = "7d"
    case month = "30d"
    case threeMonths = "90d"
    
    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .threeMonths: return "3 Months"
        }
    }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }
}

struct HormoneChartView: View {
    let data: [HormoneChartData]
    @Binding var selectedHormone: HormoneType
    let timeRange: TimeRange
    
    private var filteredData: [HormoneChartData] {
        data.filter { $0.type == selectedHormone }
            .sorted { $0.day < $1.day }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Hormone Levels")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(selectedHormone.displayName)
                        .font(.subheadline)
                        .foregroundColor(selectedHormone.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Normal Range")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(selectedHormone.normalRange)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if filteredData.isEmpty {
                Text("No data available for \(selectedHormone.displayName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(filteredData) { dataPoint in
                    LineMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Level", dataPoint.value)
                    )
                    .foregroundStyle(selectedHormone.color)
                    .lineStyle(StrokeStyle(lineWidth: 3))
                    
                    PointMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Level", dataPoint.value)
                    )
                    .foregroundStyle(selectedHormone.color)
                    .symbolSize(50)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .animation(.easeInOut, value: selectedHormone)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
    }
}

struct HormoneTypeSelector: View {
    @Binding var selectedHormone: HormoneType
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(HormoneType.allCases, id: \.self) { hormone in
                    HormoneTypeButton(
                        hormone: hormone,
                        isSelected: selectedHormone == hormone
                    ) {
                        selectedHormone = hormone
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct HormoneTypeButton: View {
    let hormone: HormoneType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(isSelected ? hormone.color : hormone.color.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                Text(hormone.displayName)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? hormone.color : .secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? hormone.color.opacity(0.1) : .clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CurrentLevelsCard: View {
    let reading: HormoneReading
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Current Levels")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(reading.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                HormoneLevelItem(
                    name: "Estrogen",
                    value: reading.estrogenLevel,
                    unit: "pg/mL",
                    color: .blue
                )
                HormoneLevelItem(
                    name: "Progesterone",
                    value: reading.progesteroneLevel,
                    unit: "ng/mL",
                    color: .green
                )
                HormoneLevelItem(
                    name: "LH",
                    value: reading.lhLevel,
                    unit: "mIU/mL",
                    color: .orange
                )
                HormoneLevelItem(
                    name: "FSH",
                    value: reading.fshLevel,
                    unit: "mIU/mL",
                    color: .purple
                )
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
    }
}

struct HormoneLevelItem: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(name)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .bottom, spacing: 2) {
                Text(String(format: "%.1f", value))
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyChartView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Hormone Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first hormone reading to start tracking patterns and trends.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
    }
}

struct RecentReadingsSection: View {
    let readings: [HormoneReading]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Readings")
                .font(.headline)
                .fontWeight(.semibold)
            
            if readings.isEmpty {
                Text("No readings yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(readings.prefix(5)) { reading in
                    HormoneReadingRow(reading: reading)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
    }
}

struct HormoneReadingRow: View {
    let reading: HormoneReading
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(reading.date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Cycle Day \(reading.cycleDay)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("Source: \(reading.source.capitalized)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(reading.estrogenLevel > 0 ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(reading.progesteroneLevel > 0 ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(reading.lhLevel > 0 ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                    Circle()
                        .fill(reading.fshLevel > 0 ? .green : .gray.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct HormoneInsightsSection: View {
    let insights: [HormoneInsight]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
                
                Text("Hormone Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ForEach(insights) { insight in
                HormoneInsightCard(insight: insight)
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
    }
}

struct HormoneInsightCard: View {
    let insight: HormoneInsight
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: insight.iconName)
                .font(.title3)
                .foregroundColor(insight.color)
                .frame(width: 32, height: 32)
                .background(insight.color.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct HormoneInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let color: Color
}

struct AddHormoneReadingView: View {
    let onSave: (HormoneReading) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var reading = HormoneReading()
    @State private var selectedDate = Date()
    @State private var estrogenText = ""
    @State private var progesteroneText = ""
    @State private var lhText = ""
    @State private var fshText = ""
    @State private var testosteroneText = ""
    @State private var cortisolText = ""
    @State private var source = "manual"
    
    private var isValidInput: Bool {
        !estrogenText.isEmpty || !progesteroneText.isEmpty || 
        !lhText.isEmpty || !fshText.isEmpty ||
        !testosteroneText.isEmpty || !cortisolText.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reading Details")) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    Picker("Source", selection: $source) {
                        Text("Manual Entry").tag("manual")
                        Text("Lab Test").tag("lab")
                        Text("Home Test").tag("home")
                        Text("Doctor Visit").tag("doctor")
                    }
                }
                
                Section(header: Text("Hormone Levels")) {
                    HormoneInputRow(
                        name: "Estrogen",
                        unit: "pg/mL",
                        text: $estrogenText,
                        color: .blue
                    )
                    
                    HormoneInputRow(
                        name: "Progesterone",
                        unit: "ng/mL",
                        text: $progesteroneText,
                        color: .green
                    )
                    
                    HormoneInputRow(
                        name: "LH",
                        unit: "mIU/mL",
                        text: $lhText,
                        color: .orange
                    )
                    
                    HormoneInputRow(
                        name: "FSH",
                        unit: "mIU/mL",
                        text: $fshText,
                        color: .purple
                    )
                    
                    HormoneInputRow(
                        name: "Testosterone",
                        unit: "ng/dL",
                        text: $testosteroneText,
                        color: .red
                    )
                    
                    HormoneInputRow(
                        name: "Cortisol",
                        unit: "μg/dL",
                        text: $cortisolText,
                        color: .yellow
                    )
                }
                
                Section(footer: Text("Enter values for the hormones you want to track. Leave others blank if not measured.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Add Reading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReading()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
    }
    
    private func saveReading() {
        reading.date = selectedDate
        reading.source = source
        reading.estrogenLevel = Double(estrogenText) ?? 0
        reading.progesteroneLevel = Double(progesteroneText) ?? 0
        reading.lhLevel = Double(lhText) ?? 0
        reading.fshLevel = Double(fshText) ?? 0
        reading.testosteroneLevel = Double(testosteroneText) ?? 0
        reading.cortisolLevel = Double(cortisolText) ?? 0
        
        onSave(reading)
        dismiss()
    }
}

struct HormoneInputRow: View {
    let name: String
    let unit: String
    @Binding var text: String
    let color: Color
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(name)
                    .fontWeight(.medium)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                TextField("0.0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 40, alignment: .leading)
            }
        }
    }
}

#Preview {
    HormoneTrackingView()
}