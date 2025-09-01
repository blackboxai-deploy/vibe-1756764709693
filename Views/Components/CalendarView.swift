import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showingDayDetail = false
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Month Header
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Text(dateFormatter.string(from: currentMonth))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                            .font(.title2)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Weekday Headers
                HStack(spacing: 0) {
                    ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                        Text(weekday)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                    ForEach(calendarDays, id: \.self) { date in
                        CalendarDayView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            cycleData: viewModel.cycleData,
                            dayData: viewModel.getDayData(for: date)
                        )
                        .onTapGesture {
                            selectedDate = date
                            showingDayDetail = true
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Legend
                CalendarLegendView()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showingDayDetail) {
                DayDetailView(date: selectedDate, dayData: viewModel.getDayData(for: selectedDate))
                    .environmentObject(viewModel)
            }
            .onAppear {
                viewModel.setModelContext(modelContext)
                viewModel.loadData()
            }
            .onChange(of: currentMonth) { _, _ in
                viewModel.loadDataForMonth(currentMonth)
            }
        }
    }
    
    private var calendarDays: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return []
        }
        
        let monthFirstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let daysToSubtract = monthFirstWeekday - calendar.firstWeekday
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: monthInterval.start) else {
            return []
        }
        
        var days: [Date] = []
        var currentDate = startDate
        
        for _ in 0..<42 { // 6 weeks * 7 days
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return days
    }
    
    private func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

struct CalendarDayView: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let cycleData: CycleData
    let dayData: DayData?
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background circle
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 36, height: 36)
                
                // Day number
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(textColor)
            }
            
            // Indicators
            HStack(spacing: 2) {
                if let dayData = dayData {
                    if dayData.hasPeriod {
                        Circle()
                            .fill(.red)
                            .frame(width: 4, height: 4)
                    }
                    
                    if dayData.hasSymptoms {
                        Circle()
                            .fill(.orange)
                            .frame(width: 4, height: 4)
                    }
                    
                    if dayData.hasHormoneReading {
                        Circle()
                            .fill(.blue)
                            .frame(width: 4, height: 4)
                    }
                    
                    if dayData.hasMoodEntry {
                        Circle()
                            .fill(.purple)
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 8)
        }
        .frame(height: 50)
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .accentColor
        }
        
        if calendar.isDateInToday(date) {
            return .accentColor.opacity(0.3)
        }
        
        if let phase = cyclePhaseForDate {
            return phase.color.opacity(0.2)
        }
        
        return .clear
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        }
        
        if calendar.isDateInToday(date) {
            return .accentColor
        }
        
        return .primary
    }
    
    private var cyclePhaseForDate: CyclePhase? {
        guard let lastPeriodDate = cycleData.lastPeriodDate else { return nil }
        
        let daysSinceLastPeriod = calendar.dateComponents([.day], from: lastPeriodDate, to: date).day ?? 0
        let cycleDay = daysSinceLastPeriod + 1
        
        if cycleDay <= cycleData.periodLength {
            return .menstrual
        } else if cycleDay <= (cycleData.cycleLength / 2) {
            return .follicular
        } else if cycleDay <= (cycleData.cycleLength / 2) + 2 {
            return .ovulatory
        } else if cycleDay <= cycleData.cycleLength {
            return .luteal
        }
        
        return nil
    }
}

struct CalendarLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Legend")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 2), spacing: 8) {
                LegendItem(color: .red, text: "Menstrual")
                LegendItem(color: .blue, text: "Follicular")
                LegendItem(color: .green, text: "Ovulatory")
                LegendItem(color: .orange, text: "Luteal")
            }
            
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle().fill(.red).frame(width: 6, height: 6)
                    Text("Period").font(.caption).foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Circle().fill(.orange).frame(width: 6, height: 6)
                    Text("Symptoms").font(.caption).foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Circle().fill(.blue).frame(width: 6, height: 6)
                    Text("Hormones").font(.caption).foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Circle().fill(.purple).frame(width: 6, height: 6)
                    Text("Mood").font(.caption).foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
    }
}

struct LegendItem: View {
    let color: Color
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.3))
                .frame(width: 16, height: 16)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct DayDetailView: View {
    let date: Date
    let dayData: DayData?
    @EnvironmentObject var viewModel: CalendarViewModel
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
                        Text(dateFormatter.string(from: date))
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let cycleDay = viewModel.getCycleDay(for: date) {
                            Text("Cycle Day \(cycleDay)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let dayData = dayData {
                        // Period Status
                        if dayData.hasPeriod {
                            DetailSection(title: "Period", icon: "drop.circle.fill", color: .red) {
                                Text("Period day")
                                    .font(.subheadline)
                            }
                        }
                        
                        // Symptoms
                        if !dayData.symptoms.isEmpty {
                            DetailSection(title: "Symptoms", icon: "heart.text.square.fill", color: .orange) {
                                ForEach(dayData.symptoms, id: \.id) { symptom in
                                    HStack {
                                        Text(symptom.name)
                                        Spacer()
                                        SeverityIndicator(severity: symptom.severity)
                                    }
                                }
                            }
                        }
                        
                        // Hormone Readings
                        if !dayData.hormoneReadings.isEmpty {
                            DetailSection(title: "Hormone Readings", icon: "chart.line.uptrend.xyaxis", color: .blue) {
                                ForEach(dayData.hormoneReadings, id: \.id) { reading in
                                    VStack(alignment: .leading, spacing: 4) {
                                        if reading.estrogenLevel > 0 {
                                            HStack {
                                                Text("Estrogen")
                                                Spacer()
                                                Text("\(reading.estrogenLevel, specifier: "%.1f") pg/mL")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        if reading.progesteroneLevel > 0 {
                                            HStack {
                                                Text("Progesterone")
                                                Spacer()
                                                Text("\(reading.progesteroneLevel, specifier: "%.1f") ng/mL")
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Mood Entries
                        if !dayData.moodEntries.isEmpty {
                            DetailSection(title: "Mood", icon: "face.smiling.fill", color: .purple) {
                                ForEach(dayData.moodEntries, id: \.id) { mood in
                                    VStack(alignment: .leading, spacing: 4) {
                                        if !mood.mood.isEmpty {
                                            Text("Mood: \(mood.mood)")
                                        }
                                        HStack {
                                            Text("Energy: \(mood.energyLevel)/10")
                                            Spacer()
                                            Text("Stress: \(mood.stressLevel)/10")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    } else {
                        // No data for this day
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.gray.opacity(0.5))
                            
                            Text("No data for this day")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("Start tracking to see your cycle patterns")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Day Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            content
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        .padding(.horizontal)
    }
}

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var cycleData = CycleData()
    @Published var monthlyData: [Date: DayData] = [:]
    
    private var modelContext: ModelContext?
    private let calendar = Calendar.current
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadData() {
        loadCycleData()
        loadDataForMonth(Date())
    }
    
    func loadDataForMonth(_ month: Date) {
        guard let context = modelContext else { return }
        
        // Get month range
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return }
        
        // Load symptoms for the month
        let symptomDescriptor = FetchDescriptor<SymptomModel>(
            predicate: #Predicate { $0.date >= monthInterval.start && $0.date < monthInterval.end },
            sortBy: [SortDescriptor(\.date)]
        )
        
        // Load hormone readings for the month
        let hormoneDescriptor = FetchDescriptor<HormoneReadingModel>(
            predicate: #Predicate { $0.date >= monthInterval.start && $0.date < monthInterval.end },
            sortBy: [SortDescriptor(\.date)]
        )
        
        // Load mood entries for the month
        let moodDescriptor = FetchDescriptor<MoodEntryModel>(
            predicate: #Predicate { $0.date >= monthInterval.start && $0.date < monthInterval.end },
            sortBy: [SortDescriptor(\.date)]
        )
        
        do {
            let symptoms = try context.fetch(symptomDescriptor)
            let hormoneReadings = try context.fetch(hormoneDescriptor)
            let moodEntries = try context.fetch(moodDescriptor)
            
            // Group data by date
            var newMonthlyData: [Date: DayData] = [:]
            
            // Process each day in the month
            var currentDate = monthInterval.start
            while currentDate < monthInterval.end {
                let dayStart = calendar.startOfDay(for: currentDate)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                
                let daySymptoms = symptoms.filter { $0.date >= dayStart && $0.date < dayEnd }
                let dayHormones = hormoneReadings.filter { $0.date >= dayStart && $0.date < dayEnd }
                let dayMoods = moodEntries.filter { $0.date >= dayStart && $0.date < dayEnd }
                
                let hasPeriod = isPeriodDay(currentDate)
                
                if !daySymptoms.isEmpty || !dayHormones.isEmpty || !dayMoods.isEmpty || hasPeriod {
                    newMonthlyData[dayStart] = DayData(
                        date: dayStart,
                        symptoms: daySymptoms.map { convertToSymptom($0) },
                        hormoneReadings: dayHormones.map { convertToHormoneReading($0) },
                        moodEntries: dayMoods.map { convertToMoodEntry($0) },
                        hasPeriod: hasPeriod
                    )
                }
                
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
            
            monthlyData = newMonthlyData
        } catch {
            print("Error loading monthly data: \(error)")
        }
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
        cycleData.lastPeriodDate = model.lastPeriodDate
        cycleData.nextPredictedPeriod = model.nextPredictedPeriod
        cycleData.ovulationDate = model.ovulationDate
        cycleData.currentPhase = model.currentPhase
        cycleData.fertilityStatus = model.fertilityStatus
        cycleData.cycleDay = model.cycleDay
        
        if let nextPeriod = model.nextPredictedPeriod {
            let components = calendar.dateComponents([.day], from: Date(), to: nextPeriod)
            cycleData.daysUntilNextPeriod = max(0, components.day ?? 0)
        }
    }
    
    func getDayData(for date: Date) -> DayData? {
        let dayStart = calendar.startOfDay(for: date)
        return monthlyData[dayStart]
    }
    
    func getCycleDay(for date: Date) -> Int? {
        guard let lastPeriodDate = cycleData.lastPeriodDate else { return nil }
        let components = calendar.dateComponents([.day], from: lastPeriodDate, to: date)
        return (components.day ?? 0) + 1
    }
    
    private func isPeriodDay(_ date: Date) -> Bool {
        guard let lastPeriodDate = cycleData.lastPeriodDate else { return false }
        let components = calendar.dateComponents([.day], from: lastPeriodDate, to: date)
        let daysSince = components.day ?? 0
        return daysSince >= 0 && daysSince < cycleData.periodLength
    }
    
    private func convertToSymptom(_ model: SymptomModel) -> Symptom {
        let symptom = Symptom()
        symptom.date = model.date
        symptom.type = model.type
        symptom.name = model.name
        symptom.severity = model.severity
        symptom.notes = model.notes
        symptom.cycleDay = model.cycleDay
        return symptom
    }
    
    private func convertToHormoneReading(_ model: HormoneReadingModel) -> HormoneReading {
        let reading = HormoneReading()
        reading.date = model.date
        reading.estrogenLevel = model.estrogenLevel
        reading.progesteroneLevel = model.progesteroneLevel
        reading.lhLevel = model.lhLevel
        reading.fshLevel = model.fshLevel
        reading.testosteroneLevel = model.testosteroneLevel
        reading.cortisolLevel = model.cortisolLevel
        reading.cycleDay = model.cycleDay
        reading.source = model.source
        return reading
    }
    
    private func convertToMoodEntry(_ model: MoodEntryModel) -> MoodEntry {
        let mood = MoodEntry()
        mood.date = model.date
        mood.mood = model.mood
        mood.energyLevel = model.energyLevel
        mood.stressLevel = model.stressLevel
        mood.notes = model.notes
        mood.cycleDay = model.cycleDay
        return mood
    }
}

struct DayData {
    let date: Date
    let symptoms: [Symptom]
    let hormoneReadings: [HormoneReading]
    let moodEntries: [MoodEntry]
    let hasPeriod: Bool
    
    var hasSymptoms: Bool { !symptoms.isEmpty }
    var hasHormoneReading: Bool { !hormoneReadings.isEmpty }
    var hasMoodEntry: Bool { !moodEntries.isEmpty }
}

#Preview {
    CalendarView()
        .modelContainer(for: [CycleDataModel.self, SymptomModel.self, HormoneReadingModel.self, MoodEntryModel.self])
}