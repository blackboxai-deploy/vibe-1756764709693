import SwiftUI

struct QuickActionsGrid: View {
    @EnvironmentObject private var healthKitService: HealthKitService
    @State private var showingPeriodLogger = false
    @State private var showingSymptomLogger = false
    @State private var showingMoodLogger = false
    @State private var showingHormoneScanner = false
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 2)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: columns, spacing: 16) {
                QuickActionCard(
                    title: "Log Period",
                    subtitle: "Track flow & symptoms",
                    icon: "drop.circle.fill",
                    color: .red,
                    gradient: LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                ) {
                    showingPeriodLogger = true
                }
                
                QuickActionCard(
                    title: "Add Symptom",
                    subtitle: "Physical & emotional",
                    icon: "heart.text.square.fill",
                    color: .orange,
                    gradient: LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                ) {
                    showingSymptomLogger = true
                }
                
                QuickActionCard(
                    title: "Track Mood",
                    subtitle: "Energy & stress levels",
                    icon: "face.smiling.inverse",
                    color: .blue,
                    gradient: LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                ) {
                    showingMoodLogger = true
                }
                
                QuickActionCard(
                    title: "Scan Test",
                    subtitle: "Hormone test results",
                    icon: "camera.viewfinder",
                    color: .green,
                    gradient: LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
                ) {
                    showingHormoneScanner = true
                }
            }
        }
        .sheet(isPresented: $showingPeriodLogger) {
            PeriodLoggerView()
        }
        .sheet(isPresented: $showingSymptomLogger) {
            AddSymptomView { name, type, severity, notes in
                // Handle symptom logging
                Task {
                    let symptom = Symptom(type: type.rawValue, name: name, severity: severity, notes: notes)
                    try? await DataService.shared.saveSymptom(symptom)
                }
            }
        }
        .sheet(isPresented: $showingMoodLogger) {
            MoodLoggerView()
        }
        .sheet(isPresented: $showingHormoneScanner) {
            HormoneScannerView()
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let gradient: LinearGradient
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    Spacer()
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: color.opacity(0.3), radius: 2, x: 0, y: 1)
                    Spacer()
                }
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(gradient)
                    .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Supporting Views

struct PeriodLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var healthKitService: HealthKitService
    @State private var selectedFlow: HKCategoryValueMenstrualFlow = .medium
    @State private var selectedDate = Date()
    @State private var notes = ""
    
    let flowOptions: [(HKCategoryValueMenstrualFlow, String, Color)] = [
        (.light, "Light", .blue),
        (.medium, "Medium", .orange),
        (.heavy, "Heavy", .red)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Period Details") {
                    DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Flow Level")
                            .font(.headline)
                        
                        HStack(spacing: 12) {
                            ForEach(flowOptions, id: \.0.rawValue) { flow, name, color in
                                FlowSelectionButton(
                                    name: name,
                                    color: color,
                                    isSelected: selectedFlow == flow,
                                    action: { selectedFlow = flow }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Notes (Optional)") {
                    TextField("How are you feeling?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
                        savePeriodEntry()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func savePeriodEntry() {
        if healthKitService.isAuthorized {
            healthKitService.saveFlowEntry(level: selectedFlow, date: selectedDate)
        }
        
        // Update cycle data
        DataService.shared.updateCycleSettings(
            lastPeriodDate: selectedDate,
            cycleLength: DataService.shared.cycleData.cycleLength,
            periodLength: DataService.shared.cycleData.periodLength
        )
    }
}

struct FlowSelectionButton: View {
    let name: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                    )
                    .shadow(color: color.opacity(0.3), radius: 4, x: 0, y: 2)
                
                Text(name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.1) : Color.clear)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct MoodLoggerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMood = ""
    @State private var energyLevel = 5
    @State private var stressLevel = 5
    @State private var notes = ""
    
    let moods = [
        ("😊", "Happy", Color.green),
        ("😌", "Calm", Color.blue),
        ("😐", "Neutral", Color.gray),
        ("😔", "Sad", Color.blue),
        ("😤", "Irritated", Color.orange),
        ("😰", "Anxious", Color.red)
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("How are you feeling?") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(moods, id: \.0) { emoji, mood, color in
                            MoodSelectionButton(
                                emoji: emoji,
                                mood: mood,
                                color: color,
                                isSelected: selectedMood == mood,
                                action: { selectedMood = mood }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Energy Level") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Low")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(energyLevel)/10")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("High")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(energyLevel) },
                            set: { energyLevel = Int($0) }
                        ), in: 1...10, step: 1)
                        .accentColor(.green)
                    }
                }
                
                Section("Stress Level") {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Low")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(stressLevel)/10")
                                .font(.headline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text("High")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: Binding(
                            get: { Double(stressLevel) },
                            set: { stressLevel = Int($0) }
                        ), in: 1...10, step: 1)
                        .accentColor(.red)
                    }
                }
                
                Section("Notes (Optional)") {
                    TextField("Additional thoughts...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Track Mood")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMoodEntry()
                        dismiss()
                    }
                    .disabled(selectedMood.isEmpty)
                }
            }
        }
    }
    
    private func saveMoodEntry() {
        Task {
            let moodEntry = MoodEntry(
                mood: selectedMood,
                energy: energyLevel,
                stress: stressLevel,
                notes: notes.isEmpty ? nil : notes
            )
            // Save to data service
            print("Saving mood entry: \(selectedMood)")
        }
    }
}

struct MoodSelectionButton: View {
    let emoji: String
    let mood: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji)
                    .font(.system(size: 32))
                
                Text(mood)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.1) : Color.clear)
                    .stroke(isSelected ? color : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HormoneScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var showingManualEntry = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                Spacer()
                
                VStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Scan Hormone Test")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Take a photo of your hormone test results for automatic data extraction")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    Button("Scan with Camera") {
                        showingImagePicker = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("Enter Manually") {
                        showingManualEntry = true
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Hormone Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker { image in
                // Process scanned image
                processScannedImage(image)
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            AddHormoneReadingView { reading in
                Task {
                    try? await DataService.shared.saveHormoneReading(reading)
                }
            }
        }
    }
    
    private func processScannedImage(_ image: UIImage) {
        // In a real app, this would use ML/OCR to extract hormone values
        print("Processing scanned hormone test image")
        dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}