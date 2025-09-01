import SwiftUI

struct AIInsightsSection: View {
    let insights: [AIInsight]
    @State private var expandedInsight: UUID?
    
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
                        .background(Color.purple)
                        .clipShape(Capsule())
                }
            }
            
            if insights.isEmpty {
                EmptyInsightsView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(insights) { insight in
                        AIInsightCard(
                            insight: insight,
                            isExpanded: expandedInsight == insight.id,
                            onTap: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    expandedInsight = expandedInsight == insight.id ? nil : insight.id
                                }
                            }
                        )
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

struct AIInsightCard: View {
    let insight: AIInsight
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    InsightIconView(type: insight.type)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(insight.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                            if insight.actionable {
                                ActionableBadge()
                            }
                        }
                        
                        Text(insight.content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(isExpanded ? nil : 2)
                            .multilineTextAlignment(.leading)
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if isExpanded {
                    InsightDetailsView(insight: insight)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(insight.type.color.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(insight.type.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InsightIconView: View {
    let type: AIInsightType
    
    var body: some View {
        Image(systemName: type.iconName)
            .font(.title3)
            .foregroundColor(type.color)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(type.color.opacity(0.15))
            )
    }
}

struct ActionableBadge: View {
    var body: some View {
        Text("Action")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.green)
            )
    }
}

struct InsightDetailsView: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Confidence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        ConfidenceBar(confidence: insight.confidence)
                        Text("\(Int(insight.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Generated")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(insight.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if insight.actionable {
                ActionableButtons(insight: insight)
            }
        }
    }
}

struct ConfidenceBar: View {
    let confidence: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 4)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(confidenceColor)
                    .frame(width: geometry.size.width * confidence, height: 4)
            }
        }
        .frame(width: 60, height: 4)
    }
    
    private var confidenceColor: Color {
        switch confidence {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

struct ActionableButtons: View {
    let insight: AIInsight
    
    var body: some View {
        HStack(spacing: 8) {
            if insight.type == .recommendation {
                Button("Apply") {
                    // Handle recommendation action
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue)
                )
            }
            
            if insight.type == .warning {
                Button("Learn More") {
                    // Handle warning action
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .stroke(Color.orange, lineWidth: 1)
                )
            }
            
            Spacer()
            
            Button("Dismiss") {
                // Handle dismiss action
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
}

struct EmptyInsightsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            
            VStack(spacing: 8) {
                Text("No Insights Yet")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("Keep tracking your cycle to receive personalized AI insights and recommendations.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
            }
            
            Button("Learn About AI Insights") {
                // Handle learn more action
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.purple)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .stroke(Color.purple, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            AIInsightsSection(insights: [
                AIInsight(
                    title: "Ovulation Predicted",
                    content: "You're likely to ovulate in the next 2-3 days based on your cycle patterns and hormone levels.",
                    type: .prediction,
                    confidence: 0.85,
                    actionable: true,
                    createdAt: Date()
                ),
                AIInsight(
                    title: "Unusual Symptom Pattern",
                    content: "Your headache frequency has increased this cycle. Consider tracking sleep and stress levels.",
                    type: .warning,
                    confidence: 0.72,
                    actionable: true,
                    createdAt: Date().addingTimeInterval(-3600)
                ),
                AIInsight(
                    title: "Cycle Length Trend",
                    content: "Your cycles have been consistently 29 days for the past 3 months, showing good regularity.",
                    type: .trend,
                    confidence: 0.95,
                    actionable: false,
                    createdAt: Date().addingTimeInterval(-7200)
                )
            ])
            
            AIInsightsSection(insights: [])
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}