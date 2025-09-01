import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var currentPage = 0
    @State private var showingHealthKitPermission = false
    @State private var showingProfileSetup = false
    @State private var userProfile = UserProfile(name: "", age: 25)
    @State private var lastPeriodDate = Date()
    @State private var cycleLength = 28
    @State private var periodLength = 5
    
    let pages = [
        OnboardingPage(
            title: "Welcome to CYCLEai",
            subtitle: "Your intelligent companion for menstrual health tracking and predictions.",
            image: "🌸",
            backgroundColor: .purple.opacity(0.1),
            systemIcon: "heart.circle.fill"
        ),
        OnboardingPage(
            title: "AI-Powered Predictions",
            subtitle: "Get accurate cycle forecasting with our advanced machine learning algorithms.",
            image: "🧠",
            backgroundColor: .blue.opacity(0.1),
            systemIcon: "brain.head.profile"
        ),
        OnboardingPage(
            title: "Comprehensive Tracking",
            subtitle: "Monitor symptoms, hormones, mood, and more for complete health insights.",
            image: "📊",
            backgroundColor: .green.opacity(0.1),
            systemIcon: "chart.line.uptrend.xyaxis"
        ),
        OnboardingPage(
            title: "Smart Health Integration",
            subtitle: "Seamlessly sync with Apple Health for automatic data collection and backup.",
            image: "❤️",
            backgroundColor: .red.opacity(0.1),
            systemIcon: "heart.text.square.fill"
        ),
        OnboardingPage(
            title: "Personalized Insights",
            subtitle: "Receive tailored recommendations and health insights based on your unique patterns.",
            image: "💡",
            backgroundColor: .orange.opacity(0.1),
            systemIcon: "lightbulb.fill"
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= currentPage ? Color.purple : Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            // Navigation buttons
            VStack(spacing: 16) {
                if currentPage == pages.count - 1 {
                    Button("Get Started") {
                        showingProfileSetup = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
                Button("Skip") {
                    showingProfileSetup = true
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [
                    pages[currentPage].backgroundColor,
                    pages[currentPage].backgroundColor.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .sheet(isPresented: $showingProfileSetup) {
            ProfileSetupView(
                userProfile: $userProfile,
                lastPeriodDate: $lastPeriodDate,
                cycleLength: $cycleLength,
                periodLength: $periodLength,
                onComplete: {
                    showingHealthKitPermission = true
                }
            )
        }
        .sheet(isPresented: $showingHealthKitPermission) {
            HealthKitPermissionView(
                onComplete: {
                    completeOnboarding()
                }
            )
            .environmentObject(healthKitService)
        }
    }
    
    private func completeOnboarding() {
        // Save user profile and cycle data
        saveUserProfile()
        appState.completeOnboarding()
    }
    
    private func saveUserProfile() {
        // Save to UserDefaults for now - in a real app, you'd save to SwiftData
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(userProfile) {
            UserDefaults.standard.set(encoded, forKey: "UserProfile")
        }
        
        UserDefaults.standard.set(lastPeriodDate, forKey: "LastPeriodDate")
        UserDefaults.standard.set(cycleLength, forKey: "CycleLength")
        UserDefaults.standard.set(periodLength, forKey: "PeriodLength")
    }
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon and emoji combination
            ZStack {
                Circle()
                    .fill(page.backgroundColor.opacity(0.3))
                    .frame(width: 140, height: 140)
                
                VStack(spacing: 8) {
                    Text(page.image)
                        .font(.system(size: 50))
                    
                    Image(systemName: page.systemIcon)
                        .font(.title2)
                        .foregroundColor(.primary)
                }
            }
            
            VStack(spacing: 20) {
                Text(page.title)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
            }
            .padding(.horizontal, 32)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProfileSetupView: View {
    @Binding var userProfile: UserProfile
    @Binding var lastPeriodDate: Date
    @Binding var cycleLength: Int
    @Binding var periodLength: Int
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    
    private var isValidInput: Bool {
        !userProfile.name.trimmingCharacters(in: .whitespaces).isEmpty &&
        userProfile.age >= 10 && userProfile.age <= 60 &&
        cycleLength >= 21 && cycleLength <= 35 &&
        periodLength >= 2 && periodLength <= 8
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Progress indicator
                HStack {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index <= currentStep ? Color.purple : Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .animation(.easeInOut(duration: 0.3), value: currentStep)
                    }
                }
                .padding(.horizontal)
                
                ScrollView {
                    VStack(spacing: 30) {
                        if currentStep == 0 {
                            ProfileInfoStep(userProfile: $userProfile)
                        } else if currentStep == 1 {
                            CycleInfoStep(
                                lastPeriodDate: $lastPeriodDate,
                                cycleLength: $cycleLength,
                                periodLength: $periodLength
                            )
                        } else {
                            ReviewStep(
                                userProfile: userProfile,
                                lastPeriodDate: lastPeriodDate,
                                cycleLength: cycleLength,
                                periodLength: periodLength
                            )
                        }
                    }
                    .padding()
                }
                
                // Navigation buttons
                VStack(spacing: 16) {
                    if currentStep == 2 {
                        Button("Complete Setup") {
                            onComplete()
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!isValidInput)
                    } else {
                        Button("Next") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(currentStep == 0 && userProfile.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentStep -= 1
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Profile Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        onComplete()
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ProfileInfoStep: View {
    @Binding var userProfile: UserProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Let's get to know you")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("This helps us provide personalized insights")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    TextField("Enter your name", text: $userProfile.name)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Stepper(value: $userProfile.age, in: 10...60) {
                            Text("\(userProfile.age) years old")
                                .font(.body)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct CycleInfoStep: View {
    @Binding var lastPeriodDate: Date
    @Binding var cycleLength: Int
    @Binding var periodLength: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cycle Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Help us understand your menstrual cycle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Last Period Start Date")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    DatePicker(
                        "Last Period",
                        selection: $lastPeriodDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(CompactDatePickerStyle())
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average Cycle Length")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Stepper(value: $cycleLength, in: 21...35) {
                            Text("\(cycleLength) days")
                                .font(.body)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Average Period Length")
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Stepper(value: $periodLength, in: 2...8) {
                            Text("\(periodLength) days")
                                .font(.body)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
        }
    }
}

struct ReviewStep: View {
    let userProfile: UserProfile
    let lastPeriodDate: Date
    let cycleLength: Int
    let periodLength: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Review Your Information")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Please confirm your details are correct")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 16) {
                ReviewRow(title: "Name", value: userProfile.name)
                ReviewRow(title: "Age", value: "\(userProfile.age) years old")
                ReviewRow(title: "Last Period", value: lastPeriodDate.formatted(date: .abbreviated, time: .omitted))
                ReviewRow(title: "Cycle Length", value: "\(cycleLength) days")
                ReviewRow(title: "Period Length", value: "\(periodLength) days")
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct ReviewRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct HealthKitPermissionView: View {
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var healthKitService: HealthKitService
    @State private var isRequesting = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                }
                
                VStack(spacing: 16) {
                    Text("Health Data Integration")
                        .font(.title)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("Connect with Apple Health to automatically sync your menstrual data and provide more accurate predictions.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
            
            VStack(spacing: 12) {
                HealthKitFeatureRow(
                    icon: "arrow.up.arrow.down.circle.fill",
                    title: "Automatic Sync",
                    description: "Seamlessly sync cycle data across all your devices"
                )
                
                HealthKitFeatureRow(
                    icon: "brain.head.profile",
                    title: "Better Predictions",
                    description: "More accurate forecasting with comprehensive health data"
                )
                
                HealthKitFeatureRow(
                    icon: "lock.shield.fill",
                    title: "Privacy Protected",
                    description: "Your health data stays secure and private on your device"
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(action: {
                    isRequesting = true
                    healthKitService.requestAuthorization()
                    
                    // Give a moment for the authorization to process
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        isRequesting = false
                        onComplete()
                        dismiss()
                    }
                }) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        }
                        Text(isRequesting ? "Requesting Access..." : "Allow Health Access")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isRequesting)
                
                Button("Skip for Now") {
                    onComplete()
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
    }
}

struct HealthKitFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let image: String
    let backgroundColor: Color
    let systemIcon: String
}

#Preview {
    OnboardingView()
        .environmentObject(AppState())
        .environmentObject(HealthKitService.shared)
}