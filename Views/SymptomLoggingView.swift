import SwiftUI

struct SymptomLoggingView: View {
    @StateObject private var viewModel = SymptomLoggingViewModel()
    @State private var showingAddSymptom = false
    @State private var selectedSymptomFilter: SymptomType? = nil
    @State private var showingSymptomTrends = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Today's Summary Card
                    TodaysSummaryCard(
                        todaySymptoms: viewModel.todaySymptoms,
                        cycleDay: viewModel.currentCycleDay
                    )
                    
                    // Quick Add Symptoms
                    QuickAddSymptomsSection(onSymptomTap: { symptom in
                        viewModel.logQuickSymptom(symptom)
                    })
                    
                    // Filter Controls
                    SymptomFilterControls(
                        selectedFilter: $selectedSymptomFilter,
                        onClearFilter: { selectedSymptomFilter = nil }
                    )
                    
                    // Today's Symptoms
                    TodaySymptomsSection(
                        symptoms: filteredTodaySymptoms,
                        onDeleteSymptom: { symptom in
                            viewModel.deleteSymptom(symptom)
                        }
                    )
                    
                    // Recent Symptoms History
                    RecentSymptomsSection(
                        symptoms: filteredRecentSymptoms,
                        onSymptomTap: { symptom in
                            // Handle symptom detail view
                        }
                    )
                    
                    // Symptom Trends
                    SymptomTrendsCard(
                        trends: viewModel.symptomTrends,
                        onViewAllTrends: { showingSymptomTrends = true }
                    )
                }
                .padding()
            }
            .navigationTitle("Symptoms")
            .background(Color(.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSymptom = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
            }
            .sheet(isPresented: $showingAddSymptom) {
                AddSymptomView { name, type, severity, notes in
                    viewModel.logSymptom(name: name, type: type, severity: severity, notes: notes)
                }
            }
            .sheet(isPresented: $showingSymptomTrends) {
                SymptomTrendsDetailView(trends: viewModel.symptomTrends)
            }
            .onAppear {
                viewModel.loadData()
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") { viewModel.clearError() }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }
    
    private var filteredTodaySymptoms: [Symptom] {
        guard let filter = selectedSymptomFilter else { return viewModel.todaySymptoms }
        return viewModel.todaySymptoms.filter { SymptomType(rawValue: $0.type) == filter }
    }
    
    private var filteredRecentSymptoms: [Symptom] {
        guard let filter = selectedSymptomFilter else { return viewModel.recentSymptoms }
        return viewModel.recentSymptoms.filter { SymptomType(rawValue: $0.type) == filter }
    }
}

struct TodaysSummaryCard: View {
    let todaySymptoms: [Symptom]
    let cycleDay: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Overview")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Cycle Day \(cycleDay)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(Date(), style: .date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 24) {
                SummaryMetric(
                    title: "Symptoms",
                    value: "\(todaySymptoms.count)",
                    icon: "heart.text.square",
                    color: .red
                )
                
                SummaryMetric(
                    title: "Avg Severity",
                    value: averageSeverity,
                    icon: "chart.bar",
                    color: .orange
                )
                
                SummaryMetric(
                    title: "Most Common",
                    value: mostCommonSymptom,
                    icon: "star.fill",
                    color: .blue
                )
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    private var averageSeverity: String {
        guard !todaySymptoms.isEmpty else { return "0" }
        let avg = Double(todaySymptoms.reduce(0) { $0 + $1.severity }) / Double(todaySymptoms.count)
        return String(format: "%.1f", avg)
    }
    
    private var mostCommonSymptom: String {
        guard !todaySymptoms.isEmpty else { return "None" }
        let counts = Dictionary(grouping: todaySymptoms, by: { $0.name })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key ?? "None"
    }
}

struct SummaryMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(Circle())
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickAddSymptomsSection: View {
    let onSymptomTap: (SymptomOption) -> Void
    
    private let quickSymptoms = Array(SymptomOption.allSymptoms.prefix(6))
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Add")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(quickSymptoms) { symptom in
                    QuickSymptomButton(symptom: symptom) {
                        onSymptomTap(symptom)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
}

struct QuickSymptomButton: View {
    let symptom: SymptomOption
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: symptom.icon)
                    .font(.title3)
                    .foregroundColor(symptom.type.color)
                
                Text(symptom.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(symptom.type.color.opacity(0.1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SymptomFilterControls: View {
    @Binding var selectedFilter: SymptomType?
    let onClearFilter: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Filter by Type")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if selectedFilter != nil {
                    Button("Clear", action: onClearFilter)
                        .font(.caption)
                        .foregroundColor(.purple)
                }
            }
            
            HStack(spacing: 12) {
                ForEach(SymptomType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        isSelected: selectedFilter == type,
                        color: type.color
                    ) {
                        selectedFilter = selectedFilter == type ? nil : type
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.1))
                )
                .foregroundColor(isSelected ? .white : color)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TodaySymptomsSection: View {
    let symptoms: [Symptom]
    let onDeleteSymptom: (Symptom) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Today's Symptoms")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(symptoms.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.purple))
            }
            
            if symptoms.isEmpty {
                EmptyStateView(
                    icon: "heart.text.square",
                    title: "No symptoms today",
                    subtitle: "Tap the + button to log your first symptom"
                )
            } else {
                ForEach(symptoms) { symptom in
                    SymptomCard(symptom: symptom) {
                        onDeleteSymptom(symptom)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
}

struct SymptomCard: View {
    let symptom: Symptom
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Symptom Icon
            if let symptomOption = SymptomOption.allSymptoms.first(where: { $0.name == symptom.name }) {
                Image(systemName: symptomOption.icon)
                    .font(.title3)
                    .foregroundColor(symptomOption.type.color)
                    .frame(width: 32, height: 32)
                    .background(symptomOption.type.color.opacity(0.1))
                    .clipShape(Circle())
            } else {
                Image(systemName: "circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
            }
            
            // Symptom Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(symptom.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(symptom.date, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    SeverityIndicator(severity: symptom.severity)
                    
                    if let notes = symptom.notes, !notes.isEmpty {
                        Text("• \(notes)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct SeverityIndicator: View {
    let severity: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= severity ? severityColor : Color.gray.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var severityColor: Color {
        switch severity {
        case 1...2: return .green
        case 3: return .yellow
        case 4: return .orange
        case 5: return .red
        default: return .gray
        }
    }
}

struct RecentSymptomsSection: View {
    let symptoms: [Symptom]
    let onSymptomTap: (Symptom) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent History")
                .font(.headline)
                .fontWeight(.semibold)
            
            if symptoms.isEmpty {
                Text("No recent symptoms")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(groupedSymptoms.keys.sorted(by: >), id: \.self) { date in
                    SymptomDayGroup(
                        date: date,
                        symptoms: groupedSymptoms[date] ?? [],
                        onSymptomTap: onSymptomTap
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
    
    private var groupedSymptoms: [Date: [Symptom]] {
        Dictionary(grouping: symptoms) { symptom in
            Calendar.current.startOfDay(for: symptom.date)
        }
    }
}

struct SymptomDayGroup: View {
    let date: Date
    let symptoms: [Symptom]
    let onSymptomTap: (Symptom) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(date, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(symptoms.count) symptoms")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ForEach(symptoms.prefix(4)) { symptom in
                    Button {
                        onSymptomTap(symptom)
                    } label: {
                        HStack(spacing: 6) {
                            if let symptomOption = SymptomOption.allSymptoms.first(where: { $0.name == symptom.name }) {
                                Image(systemName: symptomOption.icon)
                                    .font(.caption)
                                    .foregroundColor(symptomOption.type.color)
                            }
                            
                            Text(symptom.name)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            SeverityIndicator(severity: symptom.severity)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.bottom, 8)
    }
}

struct SymptomTrendsCard: View {
    let trends: [String: Int]
    let onViewAllTrends: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Symptom Trends")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("View All", action: onViewAllTrends)
                    .font(.caption)
                    .foregroundColor(.purple)
            }
            
            if trends.isEmpty {
                Text("Track symptoms for a few days to see your patterns")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                let sortedTrends = trends.sorted { $0.value > $1.value }.prefix(3)
                ForEach(Array(sortedTrends), id: \.key) { trend in
                    TrendRow(name: trend.key, count: trend.value, maxCount: trends.values.max() ?? 1)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
        )
    }
}

struct TrendRow: View {
    let name: String
    let count: Int
    let maxCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(count) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.quaternary)
                        .frame(height: 6)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.purple)
                        .frame(width: geometry.size.width * (Double(count) / Double(maxCount)), height: 6)
                        .animation(.easeInOut(duration: 0.5), value: count)
                }
            }
            .frame(height: 6)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            Text(title)
                .font(.headline)
                .fontWeight(.medium)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct AddSymptomView: View {
    let onSave: (String, SymptomType, Int, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedSymptom: SymptomOption?
    @State private var customSymptomName: String = ""
    @State private var selectedType: SymptomType = .physical
    @State private var severity: Int = 3
    @State private var notes: String = ""
    @State private var selectedDate = Date()
    
    private var isValidInput: Bool {
        selectedSymptom != nil || !customSymptomName.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Symptom Details")) {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    
                    Picker("Choose Symptom", selection: $selectedSymptom) {
                        Text("Custom Symptom").tag(nil as SymptomOption?)
                        ForEach(SymptomOption.allSymptoms) { option in
                            HStack {
                                Image(systemName: option.icon)
                                    .foregroundColor(option.type.color)
                                Text(option.name)
                            }
                            .tag(option as SymptomOption?)
                        }
                    }
                    
                    if selectedSymptom == nil {
                        TextField("Enter symptom name", text: $customSymptomName)
                        
                        Picker("Type", selection: $selectedType) {
                            ForEach(SymptomType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section(header: Text("Severity")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Severity: \(severity)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            SeverityIndicator(severity: severity)
                        }
                        
                        Slider(
                            value: Binding(
                                get: { Double(severity) },
                                set: { severity = Int($0) }
                            ),
                            in: 1...5,
                            step: 1
                        )
                        
                        HStack {
                            Text("Mild")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Severe")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Notes (Optional)")) {
                    TextField("Additional details...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Log Symptom")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = selectedSymptom?.name ?? customSymptomName
                        let type = selectedSymptom?.type ?? selectedType
                        onSave(name, type, severity, notes.isEmpty ? nil : notes)
                        dismiss()
                    }
                    .disabled(!isValidInput)
                }
            }
        }
    }
}

struct SymptomTrendsDetailView: View {
    let trends: [String: Int]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("All Symptom Trends")) {
                    if trends.isEmpty {
                        Text("No trends available yet")
                            .foregroundColor(.secondary)
                    } else {
                        let sortedTrends = trends.sorted { $0.value > $1.value }
                        ForEach(Array(sortedTrends), id: \.key) { trend in
                            HStack {
                                if let symptomOption = SymptomOption.allSymptoms.first(where: { $0.name == trend.key }) {
                                    Image(systemName: symptomOption.icon)
                                        .foregroundColor(symptomOption.type.color)
                                        .frame(width: 24)
                                }
                                
                                Text(trend.key)
                                    .font(.subheadline)
                                
                                Spacer()
                                
                                Text("\(trend.value) days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Symptom Trends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

extension SymptomType {
    var color: Color {
        switch self {
        case .physical: return .red
        case .emotional: return .blue
        case .behavioral: return .green
        }
    }
}

#Preview {
    SymptomLoggingView()
}