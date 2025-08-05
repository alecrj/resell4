//
//  FirebaseService.swift
//  ResellAI
//
//  Complete Firebase Backend Integration with All Auth Methods
//

import SwiftUI
import Foundation
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import AuthenticationServices
import CryptoKit
import LocalAuthentication
import GoogleSignIn

// MARK: - FIREBASE MODELS
struct FirebaseUser: Codable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let photoURL: String?
    let provider: String // "apple", "google", or "email"
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
    
    // Security
    let hasFaceIDEnabled: Bool
    let lastFaceIDCheck: Date?
    
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
        
        // Default Face ID
        self.hasFaceIDEnabled = false
        self.lastFaceIDCheck = nil
    }
    
    // Initialize from Firebase Auth User
    init(from authUser: User) {
        self.id = authUser.uid
        self.email = authUser.email
        self.displayName = authUser.displayName
        self.photoURL = authUser.photoURL?.absoluteString
        
        // Determine provider
        if authUser.providerData.contains(where: { $0.providerID == "apple.com" }) {
            self.provider = "apple"
        } else if authUser.providerData.contains(where: { $0.providerID == "google.com" }) {
            self.provider = "google"
        } else {
            self.provider = "email"
        }
        
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
        self.hasFaceIDEnabled = false
        self.lastFaceIDCheck = nil
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

// MARK: - FIREBASE SERVICE WITH ALL AUTH METHODS
class FirebaseService: NSObject, ObservableObject {
    @Published var currentUser: FirebaseUser?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: String?
    
    // Usage tracking
    @Published var monthlyAnalysisCount = 0
    @Published var canAnalyze = true
    @Published var daysUntilReset = 0
    
    // Face ID
    @Published var isFaceIDEnabled = false
    @Published var isFaceIDAvailable = false
    
    // Firebase instances
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    
    // Apple Sign In
    private var currentNonce: String?
    
    // Face ID Context
    private let biometricContext = LAContext()
    
    override init() {
        super.init()
        print("🔥 Firebase Service initialized")
        configureFirebase()
        checkBiometricAvailability()
        setupAuthStateListener()
    }
    
    private func configureFirebase() {
        // Firebase should be configured in App delegate, but we'll check here
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not configured - run FirebaseApp.configure() in App delegate")
        } else {
            print("✅ Firebase configured successfully")
        }
        
        // Configure Google Sign In
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("⚠️ Could not find Google Service Info")
            return
        }
        
        let config = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = config
        print("✅ Google Sign In configured")
    }
    
    private func checkBiometricAvailability() {
        var error: NSError?
        if biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            DispatchQueue.main.async {
                self.isFaceIDAvailable = true
                print("✅ Face ID/Touch ID available")
            }
        } else {
            print("⚠️ Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
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
                    self?.isFaceIDEnabled = firebaseUser.hasFaceIDEnabled
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
        isFaceIDEnabled = false
    }
    
    // MARK: - APPLE SIGN IN
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
    
    // MARK: - GOOGLE SIGN IN
    func signInWithGoogle() {
        print("🔍 Starting Google Sign-In with Firebase...")
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            print("❌ Could not find root view controller")
            return
        }
        
        isLoading = true
        authError = nil
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.isLoading = false
                    self?.authError = "Google Sign In failed: \(error.localizedDescription)"
                    print("❌ Google Sign In error: \(error)")
                    return
                }
                
                guard let user = result?.user,
                      let idToken = user.idToken?.tokenString else {
                    self?.isLoading = false
                    self?.authError = "Failed to get Google ID token"
                    return
                }
                
                let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                               accessToken: user.accessToken.tokenString)
                
                self?.auth.signIn(with: credential) { authResult, error in
                    DispatchQueue.main.async {
                        self?.isLoading = false
                        
                        if let error = error {
                            self?.authError = self?.parseAuthError(error) ?? "Google Sign In failed"
                            print("❌ Firebase Google Sign In failed: \(error)")
                        } else {
                            print("✅ Google Sign In successful")
                            self?.trackUsage(action: "google_sign_in")
                        }
                    }
                }
            }
        }
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
    
    // MARK: - FACE ID AUTHENTICATION
    func enableFaceID(completion: @escaping (Bool, String?) -> Void) {
        guard isFaceIDAvailable else {
            completion(false, "Face ID not available on this device")
            return
        }
        
        let reason = "Enable Face ID for secure access to ResellAI"
        
        biometricContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.isFaceIDEnabled = true
                    self?.updateUserFaceIDSetting(enabled: true)
                    completion(true, nil)
                    print("✅ Face ID enabled")
                } else {
                    let message = error?.localizedDescription ?? "Face ID setup failed"
                    completion(false, message)
                    print("❌ Face ID setup failed: \(message)")
                }
            }
        }
    }
    
    func authenticateWithFaceID(completion: @escaping (Bool, String?) -> Void) {
        guard isFaceIDEnabled && isFaceIDAvailable else {
            completion(false, "Face ID not enabled or available")
            return
        }
        
        let reason = "Authenticate with Face ID to access ResellAI"
        
        biometricContext.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(true, nil)
                    print("✅ Face ID authentication successful")
                } else {
                    let message = error?.localizedDescription ?? "Face ID authentication failed"
                    completion(false, message)
                    print("❌ Face ID authentication failed: \(message)")
                }
            }
        }
    }
    
    func disableFaceID() {
        isFaceIDEnabled = false
        updateUserFaceIDSetting(enabled: false)
        print("✅ Face ID disabled")
    }
    
    private func updateUserFaceIDSetting(enabled: Bool) {
        guard let user = currentUser else { return }
        
        db.collection("users").document(user.id).updateData([
            "hasFaceIDEnabled": enabled,
            "lastFaceIDCheck": Timestamp()
        ]) { error in
            if let error = error {
                print("❌ Error updating Face ID setting: \(error)")
            } else {
                print("✅ Face ID setting updated in Firestore")
            }
        }
    }
    
    func signOut() {
        print("👋 Signing out user")
        do {
            try auth.signOut()
            GIDSignIn.sharedInstance.signOut()
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
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                let user = try decoder.decode(FirebaseUser.self, from: jsonData)
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
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .secondsSince1970
                        let item = try decoder.decode(FirebaseInventoryItem.self, from: jsonData)
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
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                           rawNonce: nonce,
                                                           fullName: appleIDCredential.fullName)
            
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
