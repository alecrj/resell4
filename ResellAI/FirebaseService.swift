//
//  FirebaseService.swift
//  ResellAI
//
//  Complete Firebase Backend Integration with Real Firebase SDK
//

import SwiftUI
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit

// MARK: - FIREBASE MODELS
struct FirebaseUser: Codable, Identifiable {
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
    
    // Initialize from Firebase Auth User
    init(from authUser: User) {
        self.id = authUser.uid
        self.email = authUser.email
        self.displayName = authUser.displayName
        self.photoURL = authUser.photoURL?.absoluteString
        self.provider = authUser.providerData.first?.providerID == "apple.com" ? "apple" : "email"
        self.createdAt = authUser.metadata.creationDate ?? Date()
        self.lastLoginAt = authUser.metadata.lastSignInDate ?? Date()
        
        // Default values for new users
        self.currentPlan = .free
        self.monthlyAnalysisCount = 0
        self.monthlyAnalysisLimit = 10
        self.subscriptionStatus = .free
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

struct FirebaseInventoryItem: Codable, Identifiable {
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

// MARK: - FIREBASE SERVICE WITH REAL FIREBASE SDK
class FirebaseService: ObservableObject {
    @Published var currentUser: FirebaseUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: String?
    
    // Usage tracking
    @Published var monthlyAnalysisCount = 0
    @Published var canAnalyze = true
    @Published var daysUntilReset = 0
    
    // Firebase instances
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    // Apple Sign In
    private var currentNonce: String?
    
    init() {
        print("🔥 Firebase Service initialized")
        configureFirebase()
        setupAuthStateListener()
    }
    
    private func configureFirebase() {
        // Firebase should be configured in App delegate, but we'll check here
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not configured - run FirebaseApp.configure() in App delegate")
        } else {
            print("✅ Firebase configured successfully")
        }
    }
    
    private func setupAuthStateListener() {
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                if let user = user {
                    print("✅ Firebase Auth state: User signed in - \(user.uid)")
                    self?.handleAuthenticatedUser(user)
                } else {
                    print("📱 Firebase Auth state: No user signed in")
                    self?.handleSignedOutUser()
                }
            }
        }
    }
    
    private func handleAuthenticatedUser(_ user: User) {
        isAuthenticated = true
        isLoading = false
        
        // Load user data from Firestore
        loadUserData(userId: user.uid) { [weak self] firebaseUser in
            DispatchQueue.main.async {
                if let firebaseUser = firebaseUser {
                    self?.currentUser = firebaseUser
                } else {
                    // Create new user record
                    let newUser = FirebaseUser(from: user)
                    self?.currentUser = newUser
                    self?.createUserDocument(newUser)
                }
                
                self?.loadMonthlyUsage()
                print("✅ User loaded: \(self?.currentUser?.displayName ?? "Unknown")")
            }
        }
    }
    
    private func handleSignedOutUser() {
        currentUser = nil
        isAuthenticated = false
        isLoading = false
        monthlyAnalysisCount = 0
        canAnalyze = true
        authError = nil
    }
    
    // MARK: - APPLE SIGN IN WITH FIREBASE
    func signInWithApple() {
        print("🍎 Starting Apple Sign-In with Firebase...")
        isLoading = true
        authError = nil
        
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        
        // Generate nonce for security
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }
    
    // MARK: - EMAIL AUTHENTICATION
    func signInWithEmail(_ email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        print("📧 Signing in with email: \(email)")
        isLoading = true
        authError = nil
        
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let errorMessage = self?.parseAuthError(error) ?? "Sign in failed"
                    self?.authError = errorMessage
                    completion(false, errorMessage)
                    print("❌ Email sign in failed: \(errorMessage)")
                } else {
                    print("✅ Email sign in successful")
                    self?.trackUsage(action: "email_sign_in")
                    completion(true, nil)
                }
            }
        }
    }
    
    func createAccount(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        print("✨ Creating account for: \(email)")
        isLoading = true
        authError = nil
        
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    let errorMessage = self?.parseAuthError(error) ?? "Account creation failed"
                    self?.authError = errorMessage
                    completion(false, errorMessage)
                    print("❌ Account creation failed: \(errorMessage)")
                } else {
                    print("✅ Account created successfully")
                    self?.trackUsage(action: "account_created")
                    completion(true, nil)
                }
            }
        }
    }
    
    func signOut() {
        print("👋 Signing out user")
        do {
            try auth.signOut()
            // handleSignedOutUser() will be called by auth state listener
        } catch {
            print("❌ Sign out error: \(error)")
        }
    }
    
    // MARK: - FIRESTORE USER MANAGEMENT
    private func loadUserData(userId: String, completion: @escaping (FirebaseUser?) -> Void) {
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ Error loading user data: \(error)")
                completion(nil)
                return
            }
            
            guard let data = snapshot?.data() else {
                print("📱 No user document found")
                completion(nil)
                return
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data)
                let user = try JSONDecoder().decode(FirebaseUser.self, from: jsonData)
                print("✅ User data loaded from Firestore")
                completion(user)
            } catch {
                print("❌ Error decoding user data: \(error)")
                completion(nil)
            }
        }
    }
    
    private func createUserDocument(_ user: FirebaseUser) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        
        do {
            let data = try encoder.encode(user)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            db.collection("users").document(user.id).setData(dict) { error in
                if let error = error {
                    print("❌ Error creating user document: \(error)")
                } else {
                    print("✅ User document created in Firestore")
                }
            }
        } catch {
            print("❌ Error encoding user data: \(error)")
        }
    }
    
    private func updateUserDocument(_ user: FirebaseUser) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        
        do {
            let data = try encoder.encode(user)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            db.collection("users").document(user.id).updateData(dict) { error in
                if let error = error {
                    print("❌ Error updating user document: \(error)")
                } else {
                    print("✅ User document updated in Firestore")
                }
            }
        } catch {
            print("❌ Error encoding user data for update: \(error)")
        }
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
        
        // Update local count
        if action == "analysis" {
            monthlyAnalysisCount += 1
            updateAnalysisLimit()
            
            // Update user document with new count
            var updatedUser = user
            // Note: We need to create a mutable copy properly
            // For now, we'll update the document directly
            updateUserUsageCount()
        }
        
        // Save usage record to Firestore
        saveUsageToFirestore(usage)
    }
    
    private func updateUserUsageCount() {
        guard let user = currentUser else { return }
        
        db.collection("users").document(user.id).updateData([
            "monthlyAnalysisCount": monthlyAnalysisCount,
            "lastLoginAt": Timestamp()
        ]) { error in
            if let error = error {
                print("❌ Error updating usage count: \(error)")
            } else {
                print("✅ Usage count updated in Firestore")
            }
        }
    }
    
    private func loadMonthlyUsage() {
        guard let user = currentUser else { return }
        
        let currentMonth = getCurrentMonth()
        
        // Load from Firestore
        db.collection("usage")
            .whereField("userId", isEqualTo: user.id)
            .whereField("month", isEqualTo: currentMonth)
            .whereField("action", isEqualTo: "analysis")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading monthly usage: \(error)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                
                DispatchQueue.main.async {
                    self?.monthlyAnalysisCount = count
                    self?.updateAnalysisLimit()
                    print("📈 Monthly usage loaded: \(count)")
                }
            }
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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        
        do {
            let data = try encoder.encode(usage)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            db.collection("usage").document(usage.id).setData(dict) { error in
                if let error = error {
                    print("❌ Error saving usage to Firestore: \(error)")
                } else {
                    print("✅ Usage saved to Firestore: \(usage.action)")
                }
            }
        } catch {
            print("❌ Error encoding usage data: \(error)")
        }
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
            syncStatus: "synced"
        )
        
        print("☁️ Syncing inventory item: \(item.name)")
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        
        do {
            let data = try encoder.encode(firebaseItem)
            let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
            
            db.collection("inventory").document(firebaseItem.id).setData(dict) { error in
                if let error = error {
                    print("❌ Error syncing inventory item: \(error)")
                    completion(false)
                } else {
                    print("✅ Inventory item synced to Firestore")
                    completion(true)
                }
            }
        } catch {
            print("❌ Error encoding inventory item: \(error)")
            completion(false)
        }
    }
    
    func loadUserInventory(completion: @escaping ([FirebaseInventoryItem]) -> Void) {
        guard let user = currentUser else {
            completion([])
            return
        }
        
        print("📥 Loading user inventory from Firestore...")
        
        db.collection("inventory")
            .whereField("userId", isEqualTo: user.id)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ Error loading inventory: \(error)")
                    completion([])
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }
                
                var items: [FirebaseInventoryItem] = []
                
                for doc in documents {
                    do {
                        let data = doc.data()
                        let jsonData = try JSONSerialization.data(withJSONObject: data)
                        let item = try JSONDecoder().decode(FirebaseInventoryItem.self, from: jsonData)
                        items.append(item)
                    } catch {
                        print("❌ Error decoding inventory item: \(error)")
                    }
                }
                
                print("✅ Loaded \(items.count) inventory items from Firestore")
                completion(items)
            }
    }
    
    // MARK: - PLAN MANAGEMENT
    func upgradePlan(to plan: UserPlan, completion: @escaping (Bool) -> Void) {
        guard let user = currentUser else {
            completion(false)
            return
        }
        
        print("⬆️ Upgrading to \(plan.displayName) plan")
        
        // Update user document with new plan
        db.collection("users").document(user.id).updateData([
            "currentPlan": plan.rawValue,
            "monthlyAnalysisLimit": plan.monthlyLimit,
            "subscriptionStatus": "active",
            "lastLoginAt": Timestamp()
        ]) { [weak self] error in
            if let error = error {
                print("❌ Error upgrading plan: \(error)")
                completion(false)
            } else {
                print("✅ Plan upgraded successfully")
                
                // Update local user
                if var updatedUser = self?.currentUser {
                    // Create updated user with new plan
                    let newUser = FirebaseUser(
                        id: updatedUser.id,
                        email: updatedUser.email,
                        displayName: updatedUser.displayName,
                        photoURL: updatedUser.photoURL,
                        provider: updatedUser.provider
                    )
                    
                    DispatchQueue.main.async {
                        self?.currentUser = newUser
                        self?.updateAnalysisLimit()
                    }
                }
                
                completion(true)
            }
        }
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
        print("🔄 Monthly usage reset")
    }
    
    // MARK: - ERROR HANDLING
    private func parseAuthError(_ error: Error) -> String {
        if let authError = error as NSError? {
            switch authError.code {
            case AuthErrorCode.emailAlreadyInUse.rawValue:
                return "Email already in use"
            case AuthErrorCode.invalidEmail.rawValue:
                return "Invalid email address"
            case AuthErrorCode.weakPassword.rawValue:
                return "Password is too weak"
            case AuthErrorCode.userNotFound.rawValue:
                return "Account not found"
            case AuthErrorCode.wrongPassword.rawValue:
                return "Incorrect password"
            case AuthErrorCode.networkError.rawValue:
                return "Network error - check connection"
            default:
                return authError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}

// MARK: - APPLE SIGN IN DELEGATE
extension FirebaseService: ASAuthorizationControllerDelegate {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            
            guard let nonce = currentNonce else {
                print("❌ Invalid state: A login callback was received, but no login request was sent.")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.authError = "Authentication failed"
                }
                return
            }
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("❌ Unable to fetch identity token")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.authError = "Unable to get identity token"
                }
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("❌ Unable to serialize token string from data")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.authError = "Unable to serialize token"
                }
                return
            }
            
            // Initialize a Firebase credential
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                      idToken: idTokenString,
                                                      rawNonce: nonce)
            
            // Sign in with Firebase
            auth.signIn(with: credential) { [weak self] result, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        let errorMessage = self?.parseAuthError(error) ?? "Apple Sign In failed"
                        self?.authError = errorMessage
                        print("❌ Apple Sign In failed: \(errorMessage)")
                    } else {
                        print("✅ Apple Sign In successful")
                        self?.trackUsage(action: "apple_sign_in")
                    }
                }
            }
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple Sign In error: \(error)")
        DispatchQueue.main.async {
            self.isLoading = false
            if let authError = error as? ASAuthorizationError {
                switch authError.code {
                case .canceled:
                    self.authError = "Sign in was canceled"
                case .failed:
                    self.authError = "Apple Sign In failed"
                case .invalidResponse:
                    self.authError = "Invalid response from Apple"
                case .notHandled:
                    self.authError = "Sign in not handled"
                case .unknown:
                    self.authError = "Unknown Apple Sign In error"
                @unknown default:
                    self.authError = "Unknown Apple Sign In error"
                }
            } else {
                self.authError = "Apple Sign In failed"
            }
        }
    }
}

// MARK: - APPLE SIGN IN PRESENTATION CONTEXT
extension FirebaseService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - APPLE SIGN IN CRYPTO HELPERS
extension FirebaseService {
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

// MARK: - FIREBASE AUTH VIEW
struct FirebaseAuthView: View {
    @EnvironmentObject var firebaseService: FirebaseService
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
                            firebaseService.signInWithApple()
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
        .onChange(of: firebaseService.authError) { error in
            if let error = error {
                errorMessage = error
                showingError = true
            }
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
        NavigationView {
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
