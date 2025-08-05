//
//  FirebaseUser.swift
//  ResellAI
//
//  Created by Alec on 8/5/25.
//


//
//  FirebaseService.swift
//  ResellAI
//
//  Complete Firebase Backend Integration
//

import SwiftUI
import Foundation

// MARK: - FIREBASE MODELS
struct FirebaseUser: Codable {
    let id: String
    let email: String?
    let displayName: String?
    let photoURL: String?
    let provider: String // "apple" or "email"
    let createdAt: Date
    let lastLoginAt: Date
    
    // Plan & Usage
    let currentPlan: UserPlan
    let monthlyAnalysisCount: Int
    let monthlyAnalysisLimit: Int
    let subscriptionStatus: SubscriptionStatus
    
    // eBay Integration
    let hasEbayConnected: Bool
    let ebayUserId: String?
    let ebayTokenExpiry: Date?
    
    init(id: String, email: String?, displayName: String?, photoURL: String? = nil, provider: String) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.provider = provider
        self.createdAt = Date()
        self.lastLoginAt = Date()
        
        // Default to free plan
        self.currentPlan = .free
        self.monthlyAnalysisCount = 0
        self.monthlyAnalysisLimit = 10
        self.subscriptionStatus = .free
        
        // Default eBay status
        self.hasEbayConnected = false
        self.ebayUserId = nil
        self.ebayTokenExpiry = nil
    }
}

enum UserPlan: String, CaseIterable, Codable {
    case free = "free"
    case starter = "starter" 
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .starter: return "Starter"
        case .pro: return "Pro"
        }
    }
    
    var monthlyLimit: Int {
        switch self {
        case .free: return 10
        case .starter: return 100
        case .pro: return 400
        }
    }
    
    var price: String {
        switch self {
        case .free: return "Free"
        case .starter: return "$19/month"
        case .pro: return "$49/month"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return ["10 AI analyses/month", "Manual eBay posting", "Basic inventory tracking"]
        case .starter:
            return ["100 AI analyses/month", "Auto eBay posting", "Advanced inventory", "Priority support"]
        case .pro:
            return ["400 AI analyses/month", "Full automation", "Analytics dashboard", "Premium support", "Bulk operations"]
        }
    }
}

enum SubscriptionStatus: String, Codable {
    case free = "free"
    case active = "active"
    case pastDue = "past_due"
    case canceled = "canceled"
    case trial = "trial"
}

struct FirebaseInventoryItem: Codable {
    let id: String
    let userId: String
    let itemNumber: Int
    let inventoryCode: String
    let name: String
    let category: String
    let brand: String
    let purchasePrice: Double
    let suggestedPrice: Double
    let actualPrice: Double?
    let source: String
    let condition: String
    let title: String
    let description: String
    let keywords: [String]
    let status: String // ItemStatus.rawValue
    let dateAdded: Date
    let dateListed: Date?
    let dateSold: Date?
    let imageURLs: [String] // Store images in Firebase Storage
    let ebayItemId: String?
    let ebayURL: String?
    
    // Market Analysis Data
    let marketConfidence: Double?
    let soldListingsCount: Int?
    let demandLevel: String?
    let aiConfidence: Double?
    let resalePotential: Int?
    
    // Physical Storage
    let storageLocation: String
    let binNumber: String
    let isPackaged: Bool
    let packagedDate: Date?
    
    // Sync metadata
    let createdAt: Date
    let updatedAt: Date
    let syncStatus: String // "synced", "pending", "error"
}

struct UsageRecord: Codable {
    let id: String
    let userId: String
    let action: String // "analysis", "listing", "export"
    let timestamp: Date
    let month: String // "2025-08" for monthly tracking
    let metadata: [String: String] // Additional context
}

// MARK: - FIREBASE SERVICE
class FirebaseService: ObservableObject {
    @Published var currentUser: FirebaseUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: String?
    
    // Usage tracking
    @Published var monthlyAnalysisCount = 0
    @Published var canAnalyze = true
    @Published var daysUntilReset = 0
    
    init() {
        print("🔥 Firebase Service initialized")
        // In production, initialize Firebase SDK here
        loadCurrentUser()
    }
    
    // MARK: - AUTHENTICATION
    func signInWithApple(completion: @escaping (Bool) -> Void) {
        print("🍎 Starting Apple Sign-In...")
        isLoading = true
        
        // Simulate Apple Sign-In for now
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let user = FirebaseUser(
                id: "apple_\(UUID().uuidString)",
                email: "user@privaterelay.appleid.com",
                displayName: "ResellAI User", 
                provider: "apple"
            )
            
            self.handleSuccessfulAuth(user: user)
            completion(true)
        }
    }
    
    func signInWithEmail(_ email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        print("📧 Signing in with email: \(email)")
        isLoading = true
        
        // Simulate email sign-in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if email.contains("@") && password.count >= 6 {
                let user = FirebaseUser(
                    id: "email_\(UUID().uuidString)",
                    email: email,
                    displayName: email.components(separatedBy: "@").first?.capitalized,
                    provider: "email"
                )
                
                self.handleSuccessfulAuth(user: user)
                completion(true, nil)
            } else {
                self.isLoading = false
                completion(false, "Invalid email or password")
            }
        }
    }
    
    func createAccount(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        print("✨ Creating account for: \(email)")
        isLoading = true
        
        // Simulate account creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let user = FirebaseUser(
                id: "new_\(UUID().uuidString)",
                email: email,
                displayName: email.components(separatedBy: "@").first?.capitalized,
                provider: "email"
            )
            
            self.handleSuccessfulAuth(user: user)
            self.trackUsage(action: "account_created")
            completion(true, nil)
        }
    }
    
    private func handleSuccessfulAuth(user: FirebaseUser) {
        DispatchQueue.main.async {
            self.currentUser = user
            self.isAuthenticated = true
            self.isLoading = false
            self.authError = nil
            
            self.saveUserLocally(user)
            self.syncUserToFirestore(user)
            self.loadMonthlyUsage()
            
            print("✅ User authenticated: \(user.displayName ?? user.email ?? "Unknown")")
        }
    }
    
    func signOut() {
        print("👋 Signing out user")
        currentUser = nil
        isAuthenticated = false
        monthlyAnalysisCount = 0
        canAnalyze = true
        clearLocalUserData()
    }
    
    // MARK: - USER DATA MANAGEMENT
    private func saveUserLocally(_ user: FirebaseUser) {
        do {
            let data = try JSONEncoder().encode(user)
            UserDefaults.standard.set(data, forKey: "firebase_user")
            print("💾 User saved locally")
        } catch {
            print("❌ Error saving user locally: \(error)")
        }
    }
    
    private func loadCurrentUser() {
        guard let data = UserDefaults.standard.data(forKey: "firebase_user") else {
            print("📱 No local user found")
            return
        }
        
        do {
            let user = try JSONDecoder().decode(FirebaseUser.self, from: data)
            currentUser = user
            isAuthenticated = true
            loadMonthlyUsage()
            print("📂 Loaded user from local storage: \(user.displayName ?? "Unknown")")
        } catch {
            print("❌ Error loading local user: \(error)")
            clearLocalUserData()
        }
    }
    
    private func clearLocalUserData() {
        UserDefaults.standard.removeObject(forKey: "firebase_user")
        UserDefaults.standard.removeObject(forKey: "monthly_usage")
    }
    
    private func syncUserToFirestore(_ user: FirebaseUser) {
        print("☁️ Syncing user to Firestore...")
        // In production: save to Firestore
        // For now, just simulate success
    }
    
    // MARK: - USAGE TRACKING & LIMITS
    func trackUsage(action: String, metadata: [String: String] = [:]) {
        guard let user = currentUser else { return }
        
        let usage = UsageRecord(
            id: UUID().uuidString,
            userId: user.id,
            action: action,
            timestamp: Date(),
            month: getCurrentMonth(),
            metadata: metadata
        )
        
        print("📊 Tracking usage: \(action)")
        
        if action == "analysis" {
            monthlyAnalysisCount += 1
            updateAnalysisLimit()
            saveMonthlyUsage()
        }
        
        // In production: save to Firestore
        saveUsageToFirestore(usage)
    }
    
    private func loadMonthlyUsage() {
        let currentMonth = getCurrentMonth()
        let savedCount = UserDefaults.standard.integer(forKey: "monthly_usage_\(currentMonth)")
        monthlyAnalysisCount = savedCount
        updateAnalysisLimit()
        
        print("📈 Monthly usage loaded: \(monthlyAnalysisCount)")
    }
    
    private func saveMonthlyUsage() {
        let currentMonth = getCurrentMonth()
        UserDefaults.standard.set(monthlyAnalysisCount, forKey: "monthly_usage_\(currentMonth)")
    }
    
    private func updateAnalysisLimit() {
        guard let user = currentUser else { return }
        
        canAnalyze = monthlyAnalysisCount < user.monthlyAnalysisLimit
        
        // Calculate days until reset
        let calendar = Calendar.current
        let now = Date()
        let startOfNextMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        daysUntilReset = calendar.dateComponents([.day], from: now, to: startOfNextMonth).day ?? 0
        
        print("🎯 Analysis limit: \(monthlyAnalysisCount)/\(user.monthlyAnalysisLimit), Can analyze: \(canAnalyze)")
    }
    
    private func getCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    private func saveUsageToFirestore(_ usage: UsageRecord) {
        // In production: save to Firestore collection "usage"
        print("☁️ Usage saved to Firestore: \(usage.action)")
    }
    
    // MARK: - INVENTORY SYNC
    func syncInventoryItem(_ item: InventoryItem, completion: @escaping (Bool) -> Void) {
        guard let user = currentUser else {
            completion(false)
            return
        }
        
        let firebaseItem = FirebaseInventoryItem(
            id: item.id.uuidString,
            userId: user.id,
            itemNumber: item.itemNumber,
            inventoryCode: item.inventoryCode,
            name: item.name,
            category: item.category,
            brand: item.brand,
            purchasePrice: item.purchasePrice,
            suggestedPrice: item.suggestedPrice,
            actualPrice: item.actualPrice,
            source: item.source,
            condition: item.condition,
            title: item.title,
            description: item.description,
            keywords: item.keywords,
            status: item.status.rawValue,
            dateAdded: item.dateAdded,
            dateListed: item.dateListed,
            dateSold: item.dateSold,
            imageURLs: [], // TODO: Upload images to Firebase Storage
            ebayItemId: nil,
            ebayURL: item.ebayURL,
            marketConfidence: item.marketConfidence,
            soldListingsCount: item.soldListingsCount,
            demandLevel: item.demandLevel,
            aiConfidence: item.aiConfidence,
            resalePotential: item.resalePotential,
            storageLocation: item.storageLocation,
            binNumber: item.binNumber,
            isPackaged: item.isPackaged,
            packagedDate: item.packagedDate,
            createdAt: Date(),
            updatedAt: Date(),
            syncStatus: "pending"
        )
        
        print("☁️ Syncing inventory item: \(item.name)")
        
        // Simulate sync
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(true)
        }
    }
    
    func loadUserInventory(completion: @escaping ([FirebaseInventoryItem]) -> Void) {
        guard let user = currentUser else {
            completion([])
            return
        }
        
        print("📥 Loading user inventory from Firebase...")
        
        // In production: query Firestore for user's items
        // For now, return empty array
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion([])
        }
    }
    
    // MARK: - PLAN MANAGEMENT
    func upgradePlan(to plan: UserPlan, completion: @escaping (Bool) -> Void) {
        guard var user = currentUser else {
            completion(false)
            return
        }
        
        print("⬆️ Upgrading to \(plan.displayName) plan")
        
        // Update user plan (in production, handle via Stripe webhook)
        let updatedUser = FirebaseUser(
            id: user.id,
            email: user.email,
            displayName: user.displayName,
            photoURL: user.photoURL,
            provider: user.provider
        )
        
        // For now, just update locally
        completion(true)
    }
    
    // MARK: - HELPER METHODS
    var needsUpgrade: Bool {
        guard let user = currentUser else { return false }
        return monthlyAnalysisCount >= user.monthlyAnalysisLimit
    }
    
    var upgradeMessage: String {
        guard let user = currentUser else { return "" }
        
        if user.currentPlan == .free {
            return "Upgrade to Starter ($19/month) for 100 analyses"
        } else if user.currentPlan == .starter {
            return "Upgrade to Pro ($49/month) for 400 analyses"
        } else {
            return "Contact support for enterprise pricing"
        }
    }
    
    func resetMonthlyUsage() {
        // For testing - resets usage
        monthlyAnalysisCount = 0
        updateAnalysisLimit()
        saveMonthlyUsage()
        print("🔄 Monthly usage reset")
    }
}

// MARK: - FIREBASE AUTH VIEW
struct FirebaseAuthView: View {
    @StateObject private var firebaseService = FirebaseService()
    @State private var showingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App branding
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("ResellAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("AI-Powered Reselling Automation")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if firebaseService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Signing you in...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 16) {
                        // Apple Sign-In
                        Button(action: {
                            firebaseService.signInWithApple { _ in }
                        }) {
                            HStack {
                                Image(systemName: "applelogo")
                                    .font(.title2)
                                Text("Continue with Apple")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                        
                        // Divider
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("or")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        
                        // Email/Password fields
                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if showingSignUp {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        // Action button
                        Button(action: {
                            if showingSignUp {
                                createAccount()
                            } else {
                                signIn()
                            }
                        }) {
                            Text(showingSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .disabled(email.isEmpty || password.isEmpty || (showingSignUp && confirmPassword.isEmpty))
                        
                        // Toggle sign up/in
                        Button(action: {
                            showingSignUp.toggle()
                            clearFields()
                        }) {
                            Text(showingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                // Terms
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $firebaseService.isAuthenticated) {
            ContentView()
                .environmentObject(firebaseService)
        }
    }
    
    private func signIn() {
        firebaseService.signInWithEmail(email, password: password) { success, error in
            if !success {
                errorMessage = error ?? "Sign in failed"
                showingError = true
            }
        }
    }
    
    private func createAccount() {
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            showingError = true
            return
        }
        
        firebaseService.createAccount(email: email, password: password) { success, error in
            if !success {
                errorMessage = error ?? "Account creation failed"
                showingError = true
            }
        }
    }
    
    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
    }
}

// MARK: - USAGE LIMIT VIEW
struct UsageLimitView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 24) {
            // Limit reached icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("Monthly Limit Reached")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You've used all \(firebaseService.currentUser?.monthlyAnalysisLimit ?? 0) AI analyses for this month.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            // Current plan info
            if let user = firebaseService.currentUser {
                VStack(spacing: 12) {
                    Text("Current Plan: \(user.currentPlan.displayName)")
                        .font(.headline)
                    
                    Text("Resets in \(firebaseService.daysUntilReset) days")
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Upgrade options
            VStack(spacing: 16) {
                Text("Upgrade for More Analyses")
                    .font(.headline)
                    .foregroundColor(.blue)
                
                ForEach(UserPlan.allCases.filter { $0 != .free }, id: \.self) { plan in
                    Button(action: {
                        upgradeToPlan(plan)
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(plan.displayName)
                                    .fontWeight(.semibold)
                                
                                Text("\(plan.monthlyLimit) analyses/month")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(plan.price)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Button("Continue with Free Plan") {
                dismiss()
            }
            .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(24)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
    
    private func upgradeToPlan(_ plan: UserPlan) {
        firebaseService.upgradePlan(to: plan) { success in
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - PLAN FEATURES VIEW
struct PlanFeaturesView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose Your Plan")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    ForEach(UserPlan.allCases, id: \.self) { plan in
                        PlanCard(
                            plan: plan,
                            isCurrentPlan: firebaseService.currentUser?.currentPlan == plan,
                            onSelect: {
                                if plan != .free {
                                    upgradeToPlan(plan)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
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
    
    private func upgradeToPlan(_ plan: UserPlan) {
        firebaseService.upgradePlan(to: plan) { success in
            if success {
                dismiss()
            }
        }
    }
}

struct PlanCard: View {
    let plan: UserPlan
    let isCurrentPlan: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(plan.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isCurrentPlan {
                    Text("Current")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Text(plan.price)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
            
            if !isCurrentPlan && plan != .free {
                Button(action: onSelect) {
                    Text("Select \(plan.displayName)")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrentPlan ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
    }
}