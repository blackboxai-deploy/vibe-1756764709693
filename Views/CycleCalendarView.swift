import SwiftUI
import SwiftData

struct CycleCalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CycleCalendarViewModel()
    @State private var selectedDate = Date()
    @State private var showingDateDetail = false
    @State private var selectedDateData: DateData?
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month Navigation Header
                    MonthNavigationHeader(
                        currentDate: $selectedDate,
                        dateFormatter: dateFormatter
                    )
                    
                    // Calendar Grid
                    CalendarGridView(
                        selectedDate: $selectedDate,
                        cycleData: viewModel.cycleData,
                        dateDataMap: viewModel.dateDataMap,
                        onDateTap: { date in
                            selectedDateData = viewModel.getDateData(for: date)
                            showingDateDetail = true
                        }
                    )
                    
                    // Legend
                    CalendarLegendView()
                    
                    // Current Phase Info
                    if let currentPhase = viewModel.getCurrentPhase() {
                        CurrentPhaseCard(phase: currentPhase, cycleData: viewModel.cycleData)
                    }
                    
                    // Upcoming Events
                    UpcomingEventsSection(events: viewModel.upcomingEvents)
                }
                .padding()
            }
            .navigationTitle("Calendar")
            .background(Color(.systemGroupedBackground))
            .onAppear {
                viewModel.setModelContext(modelContext)
                viewModel.loadData()
            }
            .sheet(isPresented: $showingDateDetail) {
                if let dateData = selectedDateData {
                    DateDetailView(dateData: dateData)
                }
            }
        }
    }
}

struct MonthNavigationHeader: View {
    @Binding var currentDate: Date
    let dateFormatter: DateFormatter
    
    var body: some View {
        HStack {
            Button(action: { changeMonth(-1) }) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(dateFormatter.string(from: currentDate))
                .font(.title2)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button(action: { changeMonth(1) }) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal)
    }
    
    private func changeMonth(_ direction: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = Calendar.current.date(byAdding: .month, value: direction, to: currentDate) ?? currentDate
        }
    }
}

struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let cycleData: CycleData
    let dateDataMap: [Date: DateData]
    let onDateTap: (Date) -> Void
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack(spacing: 0) {
            // Weekday Headers
            HStack {
                ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.bottom, 8)
            
            // Calendar Days
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(getDaysInMonth(), id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        isCurrentMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month),
                        isToday: calendar.isDateInToday(date),
                        dateData: dateDataMap[calendar.startOfDay(for: date)],
                        cyclePhase: getCyclePhase(for: date),
                        onTap: { onDateTap(date) }
                    )
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
    }
    
    private func getDaysInMonth() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.end - 1) else {
            return []
        }
        
        var dates: [Date] = []
        var date = monthFirstWeek.start
        
        while date < monthLastWeek.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        
        return dates
    }
    
    private func getCyclePhase(for date: Date) -> CyclePhase? {
        guard let lastPeriod = cycleData.lastPeriodDate else { return nil }
        
        let daysSinceLastPeriod = calendar.dateComponents([.day], from: lastPeriod, to: date).day ?? 0
        let cycleDay = daysSinceLastPeriod + 1
        
        if cycleDay <= cycleData.periodLength {
            return .menstrual
        } else if cycleDay <= (cycleData.cycleLength / 2) {
            return .follicular
        } else if cycleDay <= (cycleData.cycleLength / 2) + 2 {
            return .ovulatory
        } else if cycleDay <= cycleData.cycleLength {
            return .luteal
        } else {
            return nil
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let dateData: DateData?
    let cyclePhase: CyclePhase?
    let onTap: () -> Void
    
    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(dayFormatter.string(from: date))
                    .font(.system(size: 16, weight: isToday ? .bold : .medium))
                    .foregroundColor(textColor)
                
                // Symptom indicators
                HStack(spacing: 1) {
                    if let symptoms = dateData?.symptoms, !symptoms.isEmpty {
                        Circle()
                            .fill(.orange)
                            .frame(width: 4, height: 4)
                    }
                    
                    if dateData?.hormoneReading != nil {
                        Circle()
                            .fill(.blue)
                            .frame(width: 4, height: 4)
                    }
                    
                    if dateData?.moodEntry != nil {
                        Circle()
                            .fill(.green)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 6)
            }
            .frame(width: 40, height: 40)
            .background(backgroundColor)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isToday ? Color.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return .secondary.opacity(0.5)
        } else if isToday {
            return cyclePhase?.color ?? .primary
        } else {
            return .primary
        }
    }
    
    private var backgroundColor: Color {
        if !isCurrentMonth {
            return .clear
        } else if let phase = cyclePhase {
            return phase.color.opacity(0.2)
        } else {
            return .clear
        }
    }
}

struct CalendarLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legend")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                LegendItem(color: .red, text: "Menstrual")
                LegendItem(color: .blue, text: "Follicular")
                LegendItem(color: .green, text: "Ovulatory")
                LegendItem(color: .orange, text: "Luteal")
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("Symptoms").font(.caption).foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                    Text("Hormones").font(.caption).foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Circle().fill(.green).frame(width: 6, height: 6)
                    Text("Mood").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 12, height: 12)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}

struct CurrentPhaseCard: View {
    let phase: CyclePhase
    let cycleData: CycleData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Phase")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("Day \(cycleData.cycleDay)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(phase.color)
                    .clipShape(Capsule())
            }
            
            HStack(spacing: 12) {
                Circle()
                    .fill(phase.color)
                    .frame(width: 16, height: 16)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(getPhaseDescription(phase))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
    }
    
    private func getPhaseDescription(_ phase: CyclePhase) -> String {
        switch phase {
        case .menstrual:
            return "Your period is here. Focus on rest and self-care."
        case .follicular:
            return "Energy levels are rising. Great time for new activities."
        case .ovulatory:
            return "Peak fertility window. You may feel most energetic."
        case .luteal:
            return "Preparing for next cycle. Listen to your body's needs."
        }
    }
}

struct UpcomingEventsSection: View {
    let events: [UpcomingEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Upcoming Events")
                .font(.headline)
                .fontWeight(.semibold)
            
            if events.isEmpty {
                Text("No upcoming events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(events) { event in
                    UpcomingEventRow(event: event)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(.regularMaterial))
    }
}

struct UpcomingEventRow: View {
    let event: UpcomingEvent
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.icon)
                .font(.title3)
                .foregroundColor(event.color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(event.subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("\(event.daysUntil) days")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(event.color)
        }
    }
}

struct DateDetailView: View {
    let dateData: DateData
    @Environment(\.dismiss) private var dismiss
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Date Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dateFormatter.string(from: dateData.date))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let cycleDay = dateData.cycleDay {
                            Text("Cycle Day \(cycleDay)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Symptoms
                    if !dateData.symptoms.isEmpty {
                        DateDetailSection(title: "Symptoms", icon: "heart.text.square") {
                            ForEach(dateData.symptoms, id: \.id) { symptom in
                                HStack {
                                    Text(symptom.name)
                                    Spacer()
                                    SeverityIndicator(severity: symptom.severity)
                                }
                            }
                        }
                    }
                    
                    // Hormone Reading
                    if let hormone = dateData.hormoneReading {
                        DateDetailSection(title: "Hormone Reading", icon: "chart.line.uptrend.xyaxis") {
                            VStack(alignment: .leading, spacing: 8) {
                                if hormone.estrogenLevel > 0 {
                                    HormoneRow(name: "Estrogen", value: hormone.estrogenLevel, unit: "pg/mL")
                                }
                                if hormone.progesteroneLevel > 0 {
                                    HormoneRow(name: "Progesterone", value: hormone.progesteroneLevel, unit: "ng/mL")
                                }
                                if hormone.lhLevel > 0 {
                                    HormoneRow(name: "LH", value: hormone.lhLevel, unit: "mIU/mL")
                                }
                            }
                        }
                    }
                    
                    // Mood Entry
                    if let mood = dateData.moodEntry {
                        DateDetailSection(title: "Mood", icon: "face.smiling") {
                            VStack(alignment: .leading, spacing: 8) {
                                if !mood.mood.isEmpty {
                                    Text("Mood: \(mood.mood)")
                                }
                                Text("Energy: \(mood.energyLevel)/10")
                                Text("Stress: \(mood.stressLevel)/10")
                                if let notes = mood.notes, !notes.isEmpty {
                                    Text("Notes: \(notes)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DateDetailSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }
}

struct HormoneRow: View {
    let name: String
    let value: Double
    let unit: String
    
    var body: some View {
        HStack {
            Text(name)
            Spacer()
            Text("\(value, specifier: "%.1f") \(unit)")
                .foregroundColor(.secondary)
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

@MainActor
class CycleCalendarViewModel: ObservableObject {
    @Published var cycleData = CycleData()
    @Published var dateDataMap: [Date: DateData] = [:]
    @Published var upcomingEvents: [UpcomingEvent] = []
    
    private var modelContext: ModelContext?
    private let calendar = Calendar.current
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadData() {
        loadCycleData()
        loadDateData()
        generateUpcomingEvents()
    }
    
    private func loadCycleData() {
        guard let context = modelContext else { return }
        
        let descriptor = FetchDescriptor<CycleDataModel>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let cycles = try context.fetch(descriptor)
            if let latestCycle = cycles.first {
                updateCycleData(from: latestCycle)
            }
        } catch {
            print("Error loading cycle data: \(error)")
        }
    }
    
    private func updateCycleData(from model: CycleDataModel) {
        cycleData.cycleLength = model.cycleLength
        cycleData.periodLength = model.periodLength
        cycleData.cycleDay = model.cycleDay
        cycleData.lastPeriodDate = model.lastPeriodDate
        cycleData.nextPredictedPeriod = model.nextPredictedPeriod
        cycleData.ovulationDate = model.ovulationDate
        cycleData.currentPhase = model.currentPhase
        cycleData.fertilityStatus = model.fertilityStatus
        
        if let nextPeriod = model.nextPredictedPeriod {
            let components = calendar.dateComponents([.day], from: Date(), to: nextPeriod)
            cycleData.daysUntilNextPeriod = max(0, components.day ?? 0)
        }
    }
    
    private func loadDateData() {
        guard let context = modelContext else { return }
        
        let startDate = calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .month, value: 2, to: Date()) ?? Date()
        
        // Load symptoms
        let symptomPredicate = #Predicate<SymptomModel> { $0.date >= startDate && $0.date <= endDate }
        let symptomDescriptor = FetchDescriptor<SymptomModel>(predicate: symptomPredicate)
        
        // Load hormone readings
        let hormonePredicate = #Predicate<HormoneReadingModel> { $0.date >= startDate && $0.date <= endDate }
        let hormoneDescriptor = FetchDescriptor<HormoneReadingModel>(predicate: hormonePredicate)
        
        // Load mood entries
        let moodPredicate = #Predicate<MoodEntryModel> { $0.date >= startDate && $0.date <= endDate }
        let moodDescriptor = FetchDescriptor<MoodEntryModel>(predicate: moodPredicate)
        
        do {
            let symptoms = try context.fetch(symptomDescriptor)
            let hormones = try context.fetch(hormoneDescriptor)
            let moods = try context.fetch(moodDescriptor)
            
            var tempDateDataMap: [Date: DateData] = [:]
            
            // Group symptoms by date
            for symptom in symptoms {
                let dayStart = calendar.startOfDay(for: symptom.date)
                if tempDateDataMap[dayStart] == nil {
                    tempDateDataMap[dayStart] = DateData(date: dayStart)
                }
                let uiSymptom = Symptom(
                    date: symptom.date,
                    type: symptom.type,
                    name: symptom.name,
                    severity: symptom.severity,
                    notes: symptom.notes,
                    cycleDay: symptom.cycleDay
                )
                tempDateDataMap[dayStart]?.symptoms.append(uiSymptom)
                tempDateDataMap[dayStart]?.cycleDay = symptom.cycleDay
            }
            
            // Add hormone readings
            for hormone in hormones {
                let dayStart = calendar.startOfDay(for: hormone.date)
                if tempDateDataMap[dayStart] == nil {
                    tempDateDataMap[dayStart] = DateData(date: dayStart)
                }
                let uiHormone = HormoneReading(
                    date: hormone.date,
                    estrogen: hormone.estrogenLevel,
                    progesterone: hormone.progesteroneLevel,
                    lh: hormone.lhLevel,
                    fsh: hormone.fshLevel,
                    testosterone: hormone.testosteroneLevel,
                    cortisol: hormone.cortisolLevel,
                    cycleDay: hormone.cycleDay,
                    source: hormone.source
                )
                tempDateDataMap[dayStart]?.hormoneReading = uiHormone
                tempDateDataMap[dayStart]?.cycleDay = hormone.cycleDay
            }
            
            // Add mood entries
            for mood in moods {
                let dayStart = calendar.startOfDay(for: mood.date)
                if tempDateDataMap[dayStart] == nil {
                    tempDateDataMap[dayStart] = DateData(date: dayStart)
                }
                let uiMood = MoodEntry(
                    date: mood.date,
                    mood: mood.mood,
                    energy: mood.energyLevel,
                    stress: mood.stressLevel,
                    notes: mood.notes,
                    cycleDay: mood.cycleDay
                )
                tempDateDataMap[dayStart]?.moodEntry = uiMood
                tempDateDataMap[dayStart]?.cycleDay = mood.cycleDay
            }
            
            dateDataMap = tempDateDataMap
            
        } catch {
            print("Error loading date data: \(error)")
        }
    }
    
    private func generateUpcomingEvents() {
        var events: [UpcomingEvent] = []
        
        if let nextPeriod = cycleData.nextPredictedPeriod {
            let daysUntil = calendar.dateComponents([.day], from: Date(), to: nextPeriod).day ?? 0
            if daysUntil > 0 {
                events.append(UpcomingEvent(
                    title: "Next Period",
                    subtitle: "Predicted start date",
                    daysUntil: daysUntil,
                    icon: "drop.circle",
                    color: .red
                ))
            }
        }
        
        if let ovulation = cycleData.ovulationDate {
            let daysUntil = calendar.dateComponents([.day], from: Date(), to: ovulation).day ?? 0
            if daysUntil > 0 && daysUntil <= 7 {
                events.append(UpcomingEvent(
                    title: "Ovulation",
                    subtitle: "Fertile window",
                    daysUntil: daysUntil,
                    icon: "heart.circle",
                    color: .green
                ))
            }
        }
        
        upcomingEvents = events.sorted { $0.daysUntil < $1.daysUntil }
    }
    
    func getCurrentPhase() -> CyclePhase? {
        return cycleData.currentPhase
    }
    
    func getDateData(for date: Date) -> DateData? {
        let dayStart = calendar.startOfDay(for: date)
        return dateDataMap[dayStart] ?? DateData(date: dayStart)
    }
}

struct DateData {
    let date: Date
    var symptoms: [Symptom] = []
    var hormoneReading: HormoneReading?
    var moodEntry: MoodEntry?
    var cycleDay: Int?
}

struct UpcomingEvent: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let daysUntil: Int
    let icon: String
    let color: Color
}