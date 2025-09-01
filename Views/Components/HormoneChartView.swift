import SwiftUI
import Charts

struct HormoneChartView: View {
    let readings: [HormoneReading]
    @State private var selectedHormones: Set<HormoneType> = [.estrogen, .progesterone, .lh]
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showingLegend = true
    
    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "90D"
        
        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .threeMonths: return 90
            }
        }
        
        var displayName: String {
            switch self {
            case .week: return "Week"
            case .month: return "Month"
            case .threeMonths: return "3 Months"
            }
        }
    }
    
    private var filteredReadings: [HormoneReading] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeRange.days, to: Date()) ?? Date()
        return readings.filter { $0.date >= cutoffDate }.sorted { $0.date < $1.date }
    }
    
    private var chartData: [HormoneChartDataPoint] {
        var dataPoints: [HormoneChartDataPoint] = []
        
        for reading in filteredReadings {
            if selectedHormones.contains(.estrogen) {
                dataPoints.append(HormoneChartDataPoint(
                    date: reading.date,
                    value: reading.estrogenLevel,
                    type: .estrogen,
                    cycleDay: reading.cycleDay
                ))
            }
            if selectedHormones.contains(.progesterone) {
                dataPoints.append(HormoneChartDataPoint(
                    date: reading.date,
                    value: reading.progesteroneLevel,
                    type: .progesterone,
                    cycleDay: reading.cycleDay
                ))
            }
            if selectedHormones.contains(.lh) {
                dataPoints.append(HormoneChartDataPoint(
                    date: reading.date,
                    value: reading.lhLevel,
                    type: .lh,
                    cycleDay: reading.cycleDay
                ))
            }
            if selectedHormones.contains(.fsh) {
                dataPoints.append(HormoneChartDataPoint(
                    date: reading.date,
                    value: reading.fshLevel,
                    type: .fsh,
                    cycleDay: reading.cycleDay
                ))
            }
            if selectedHormones.contains(.testosterone) {
                dataPoints.append(HormoneChartDataPoint(
                    date: reading.date,
                    value: reading.testosteroneLevel,
                    type: .testosterone,
                    cycleDay: reading.cycleDay
                ))
            }
            if selectedHormones.contains(.cortisol) {
                dataPoints.append(HormoneChartDataPoint(
                    date: reading.date,
                    value: reading.cortisolLevel,
                    type: .cortisol,
                    cycleDay: reading.cycleDay
                ))
            }
        }
        
        return dataPoints
    }
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if chartData.isEmpty {
                emptyStateView
            } else {
                chartSection
                
                if showingLegend {
                    legendSection
                }
            }
            
            hormoneSelectionSection
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20).fill(.regularMaterial))
    }
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hormone Levels")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("\(filteredReadings.count) readings")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { showingLegend.toggle() }) {
                    Image(systemName: showingLegend ? "eye.fill" : "eye.slash.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 120)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Hormone Data")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("Add hormone readings to see your levels over time")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
    }
    
    private var chartSection: some View {
        Chart(chartData) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date),
                y: .value("Level", dataPoint.normalizedValue)
            )
            .foregroundStyle(dataPoint.type.color)
            .lineStyle(StrokeStyle(lineWidth: 2.5))
            .interpolationMethod(.catmullRom)
            
            PointMark(
                x: .value("Date", dataPoint.date),
                y: .value("Level", dataPoint.normalizedValue)
            )
            .foregroundStyle(dataPoint.type.color)
            .symbolSize(30)
        }
        .frame(height: 250)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: selectedTimeRange == .week ? 1 : selectedTimeRange == .month ? 7 : 14)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(position: .bottom, alignment: .center, spacing: 20) {
            if showingLegend {
                HStack(spacing: 16) {
                    ForEach(Array(selectedHormones), id: \.self) { hormone in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(hormone.color)
                                .frame(width: 8, height: 8)
                            Text(hormone.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: selectedHormones)
        .animation(.easeInOut(duration: 0.3), value: selectedTimeRange)
    }
    
    private var legendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Normal Ranges")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(Array(selectedHormones), id: \.self) { hormone in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(hormone.color)
                            .frame(width: 6, height: 6)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hormone.displayName)
                                .font(.caption2)
                                .fontWeight(.medium)
                            Text(hormone.normalRange)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(hormone.color.opacity(0.1)))
                }
            }
        }
    }
    
    private var hormoneSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Hormones")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(HormoneType.allCases, id: \.self) { hormone in
                    HormoneSelectionButton(
                        hormone: hormone,
                        isSelected: selectedHormones.contains(hormone)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedHormones.contains(hormone) {
                                selectedHormones.remove(hormone)
                            } else {
                                selectedHormones.insert(hormone)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct HormoneSelectionButton: View {
    let hormone: HormoneType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Circle()
                    .fill(isSelected ? hormone.color : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                
                Text(hormone.displayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? hormone.color.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? hormone.color : Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HormoneChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let type: HormoneType
    let cycleDay: Int
    
    var normalizedValue: Double {
        switch type {
        case .estrogen:
            return value / 400.0 * 100
        case .progesterone:
            return value / 25.0 * 100
        case .lh:
            return value / 25.0 * 100
        case .fsh:
            return value / 20.0 * 100
        case .testosterone:
            return value / 70.0 * 100
        case .cortisol:
            return value / 23.0 * 100
        }
    }
}

#Preview {
    HormoneChartView(readings: [
        HormoneReading(date: Date().addingTimeInterval(-86400 * 7), estrogen: 150, progesterone: 5, lh: 10, fsh: 8, testosterone: 30, cortisol: 12, cycleDay: 7),
        HormoneReading(date: Date().addingTimeInterval(-86400 * 5), estrogen: 200, progesterone: 8, lh: 15, fsh: 10, testosterone: 35, cortisol: 15, cycleDay: 9),
        HormoneReading(date: Date().addingTimeInterval(-86400 * 3), estrogen: 300, progesterone: 12, lh: 20, fsh: 12, testosterone: 40, cortisol: 18, cycleDay: 11),
        HormoneReading(date: Date().addingTimeInterval(-86400 * 1), estrogen: 250, progesterone: 15, lh: 12, fsh: 9, testosterone: 32, cortisol: 14, cycleDay: 13)
    ])
    .padding()
}