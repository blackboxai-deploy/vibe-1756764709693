import SwiftUI

struct SymptomCard: View {
    let symptom: Symptom
    @State private var showingDetails = false
    
    var body: some View {
        Button(action: { showingDetails = true }) {
            HStack(spacing: 16) {
                // Symptom Icon
                ZStack {
                    Circle()
                        .fill(symptomTypeColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: symptomIcon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(symptomTypeColor)
                }
                
                // Symptom Details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(symptom.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(symptom.date, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 8) {
                        // Severity Indicator
                        SeverityIndicator(severity: symptom.severity)
                        
                        Spacer()
                        
                        // Cycle Day Badge
                        Text("Day \(symptom.cycleDay)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.7))
                            )
                    }
                    
                    // Notes Preview
                    if let notes = symptom.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetails) {
            SymptomDetailView(symptom: symptom)
        }
    }
    
    private var symptomTypeColor: Color {
        guard let type = SymptomType(rawValue: symptom.type) else { return .gray }
        switch type {
        case .physical:
            return .red
        case .emotional:
            return .blue
        case .behavioral:
            return .green
        }
    }
    
    private var symptomIcon: String {
        if let option = SymptomOption.allSymptoms.first(where: { $0.name == symptom.name }) {
            return option.icon
        }
        
        guard let type = SymptomType(rawValue: symptom.type) else { return "circle" }
        switch type {
        case .physical:
            return "bolt.heart"
        case .emotional:
            return "brain"
        case .behavioral:
            return "figure.walk"
        }
    }
}

struct SeverityIndicator: View {
    let severity: Int
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { level in
                Circle()
                    .fill(level <= severity ? severityColor : Color.gray.opacity(0.2))
                    .frame(width: 6, height: 6)
            }
        }
    }
    
    private var severityColor: Color {
        switch severity {
        case 1:
            return .green
        case 2:
            return .yellow
        case 3:
            return .orange
        case 4:
            return .red
        case 5:
            return .purple
        default:
            return .gray
        }
    }
}

struct SymptomDetailView: View {
    let symptom: Symptom
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(symptomTypeColor.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: symptomIcon)
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(symptomTypeColor)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(symptom.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text(symptom.type.capitalized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        // Details Grid
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                            DetailItem(title: "Date", value: symptom.date.formatted(date: .abbreviated, time: .shortened))
                            DetailItem(title: "Cycle Day", value: "Day \(symptom.cycleDay)")
                            DetailItem(title: "Severity", value: severityText)
                            DetailItem(title: "Type", value: symptom.type.capitalized)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                    
                    // Severity Visualization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Severity Level")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        HStack {
                            ForEach(1...5, id: \.self) { level in
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(level <= symptom.severity ? severityColor(for: level) : Color.gray.opacity(0.2))
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Text("\(level)")
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .foregroundColor(level <= symptom.severity ? .white : .secondary)
                                        )
                                    
                                    Text(severityLabel(for: level))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                if level < 5 {
                                    Spacer()
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.regularMaterial)
                    )
                    
                    // Notes Section
                    if let notes = symptom.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(notes)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Symptom Details")
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
    
    private var symptomTypeColor: Color {
        guard let type = SymptomType(rawValue: symptom.type) else { return .gray }
        switch type {
        case .physical: return .red
        case .emotional: return .blue
        case .behavioral: return .green
        }
    }
    
    private var symptomIcon: String {
        if let option = SymptomOption.allSymptoms.first(where: { $0.name == symptom.name }) {
            return option.icon
        }
        
        guard let type = SymptomType(rawValue: symptom.type) else { return "circle" }
        switch type {
        case .physical: return "bolt.heart"
        case .emotional: return "brain"
        case .behavioral: return "figure.walk"
        }
    }
    
    private var severityText: String {
        switch symptom.severity {
        case 1: return "Very Mild"
        case 2: return "Mild"
        case 3: return "Moderate"
        case 4: return "Severe"
        case 5: return "Very Severe"
        default: return "Unknown"
        }
    }
    
    private func severityColor(for level: Int) -> Color {
        switch level {
        case 1: return .green
        case 2: return .yellow
        case 3: return .orange
        case 4: return .red
        case 5: return .purple
        default: return .gray
        }
    }
    
    private func severityLabel(for level: Int) -> String {
        switch level {
        case 1: return "Very Mild"
        case 2: return "Mild"
        case 3: return "Moderate"
        case 4: return "Severe"
        case 5: return "Very Severe"
        default: return ""
        }
    }
}

struct DetailItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    SymptomCard(symptom: Symptom(
        date: Date(),
        type: "physical",
        name: "Cramps",
        severity: 3,
        notes: "Mild cramping in the morning",
        cycleDay: 2
    ))
    .padding()
}