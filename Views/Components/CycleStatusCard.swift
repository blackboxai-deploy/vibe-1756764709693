import SwiftUI

struct CycleStatusCard: View {
    @ObservedObject var cycleData: CycleData
    @State private var animateProgress = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Cycle")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(cycleData.currentPhase.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Cycle Day Badge
                Text("Day \(cycleData.cycleDay)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(cycleData.currentPhase.color)
                    )
            }
            
            // Main Content
            HStack(spacing: 32) {
                // Cycle Progress Ring
                ZStack {
                    // Background Ring
                    Circle()
                        .stroke(
                            cycleData.currentPhase.color.opacity(0.15),
                            lineWidth: 14
                        )
                    
                    // Progress Ring
                    Circle()
                        .trim(from: 0, to: animateProgress ? progressValue : 0)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    cycleData.currentPhase.color,
                                    cycleData.currentPhase.color.opacity(0.7),
                                    cycleData.currentPhase.color
                                ],
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            ),
                            style: StrokeStyle(
                                lineWidth: 14,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animateProgress)
                    
                    // Center Content
                    VStack(spacing: 6) {
                        Text("\(max(0, cycleData.daysUntilNextPeriod))")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(cycleData.currentPhase.color)
                            .contentTransition(.numericText())
                        
                        Text(cycleData.daysUntilNextPeriod <= 1 ? "day left" : "days left")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 140, height: 140)
                
                // Cycle Information
                VStack(alignment: .leading, spacing: 20) {
                    CycleInfoRow(
                        icon: "drop.circle.fill",
                        title: "Next Period",
                        value: nextPeriodText,
                        color: .red
                    )
                    
                    CycleInfoRow(
                        icon: "heart.circle.fill",
                        title: "Fertility",
                        value: cycleData.fertilityStatus.rawValue.capitalized,
                        color: fertilityColor(for: cycleData.fertilityStatus)
                    )
                    
                    if let ovulationDate = cycleData.ovulationDate {
                        CycleInfoRow(
                            icon: "sparkles.circle.fill",
                            title: "Ovulation",
                            value: ovulationText(for: ovulationDate),
                            color: .green
                        )
                    }
                }
                
                Spacer()
            }
            
            // Phase Indicator Bar
            PhaseIndicatorBar(
                currentPhase: cycleData.currentPhase,
                cycleDay: cycleData.cycleDay,
                cycleLength: cycleData.cycleLength
            )
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
        )
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.2)) {
                animateProgress = true
            }
        }
        .onChange(of: cycleData.cycleDay) { _, _ in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                animateProgress = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                    animateProgress = true
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var progressValue: CGFloat {
        guard cycleData.cycleLength > 0 else { return 0 }
        return CGFloat(cycleData.cycleDay) / CGFloat(cycleData.cycleLength)
    }
    
    private var nextPeriodText: String {
        if cycleData.daysUntilNextPeriod <= 0 {
            return "Today"
        } else if cycleData.daysUntilNextPeriod == 1 {
            return "Tomorrow"
        } else {
            return "\(cycleData.daysUntilNextPeriod) days"
        }
    }
    
    private func ovulationText(for date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        
        if days < 0 {
            return "\(-days) days ago"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "In \(days) days"
        }
    }
    
    private func fertilityColor(for status: FertilityStatus) -> Color {
        switch status {
        case .low:
            return .blue
        case .medium:
            return .yellow
        case .high:
            return .orange
        case .peak:
            return .red
        }
    }
}

struct CycleInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct PhaseIndicatorBar: View {
    let currentPhase: CyclePhase
    let cycleDay: Int
    let cycleLength: Int
    
    private let phases: [CyclePhase] = [.menstrual, .follicular, .ovulatory, .luteal]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cycle Phases")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack(spacing: 2) {
                ForEach(phases, id: \.self) { phase in
                    Rectangle()
                        .fill(phase == currentPhase ? phase.color : phase.color.opacity(0.3))
                        .frame(height: 6)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.3), value: currentPhase)
                }
            }
            .clipShape(Capsule())
            
            HStack {
                ForEach(phases, id: \.self) { phase in
                    Text(phaseAbbreviation(for: phase))
                        .font(.caption2)
                        .fontWeight(phase == currentPhase ? .semibold : .regular)
                        .foregroundColor(phase == currentPhase ? phase.color : .secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func phaseAbbreviation(for phase: CyclePhase) -> String {
        switch phase {
        case .menstrual:
            return "M"
        case .follicular:
            return "F"
        case .ovulatory:
            return "O"
        case .luteal:
            return "L"
        }
    }
}

#Preview {
    VStack {
        CycleStatusCard(cycleData: {
            let data = CycleData()
            data.cycleDay = 14
            data.cycleLength = 28
            data.daysUntilNextPeriod = 14
            data.currentPhase = .ovulatory
            data.fertilityStatus = .high
            data.ovulationDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
            return data
        }())
        
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}