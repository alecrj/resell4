//
//  AuthService.swift
//  ResellAI
//
//  Authentication Feature - Service with Fixed State Updates
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

// MARK: - AUTHENTICATION SERVICE (FIXED)
class AuthService: NSObject, ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var authError: String?
    
    // Usage tracking
    @Published var monthlyAnalysisCount = 0
    @Published var monthlyListingCount = 0
    @Published var canAnalyze = true
    @Published var canCreateListing = true
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
        print("🔐 AuthService initialized")
        checkBiometricAvailability()
        setupAuthStateListener()
    }
    
    // MARK: - INITIALIZATION
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
                    print("✅ Auth state: User signed in - \(user.uid)")
                    self?.handleAuthenticatedUser(user)
                } else {
                    print("📱 Auth state: No user signed in")
                    self?.handleSignedOutUser()
                }
            }
        }
    }
    
    private func handleAuthenticatedUser(_ user: FirebaseAuth.User) {
        print("🔄 Handling authenticated user: \(user.uid)")
        
        // Set authentication state immediately
        isAuthenticated = true
        isLoading = false
        authError = nil
        
        print("✅ Authentication state updated - isAuthenticated: \(isAuthenticated)")
        
        // Load user data from Firestore (this can fail without affecting auth state)
        loadUserData(userId: user.uid) { [weak self] userData in
            DispatchQueue.main.async {
                if let userData = userData {
                    self?.currentUser = userData
                    self?.isFaceIDEnabled = userData.hasFaceIDEnabled
                    self?.monthlyAnalysisCount = userData.monthlyAnalysisCount
                    self?.monthlyListingCount = userData.monthlyListingCount
                    print("✅ User data loaded from Firestore: \(userData.displayName ?? "Unknown")")
                } else {
                    // Create new user record
                    let newUser = User(from: user)
                    self?.currentUser = newUser
                    self?.createUserDocument(newUser)
                    print("✅ New user created: \(newUser.displayName ?? "Unknown")")
                }
                
                self?.loadMonthlyUsage()
            }
        }
    }
    
    private func handleSignedOutUser() {
        print("🔄 Handling signed out user")
        currentUser = nil
        isAuthenticated = false
        isLoading = false
        monthlyAnalysisCount = 0
        monthlyListingCount = 0
        canAnalyze = true
        canCreateListing = true
        authError = nil
        isFaceIDEnabled = false
        print("✅ Sign out state updated - isAuthenticated: \(isAuthenticated)")
    }
    
    // MARK: - APPLE SIGN IN
    func signInWithApple() {
        print("🍎 Starting Apple Sign-In...")
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
        print("🔍 Starting Google Sign-In...")
        
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
                            // Track usage but don't let it fail the auth flow
                            self?.trackUsageQuietly(action: "google_sign_in")
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
                    self?.trackUsageQuietly(action: "email_sign_in")
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
                    self?.trackUsageQuietly(action: "account_created")
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
    
    // MARK: - SIGN OUT
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
    
    // MARK: - USER DATA MANAGEMENT
    private func loadUserData(userId: String, completion: @escaping (User?) -> Void) {
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
            
            // Convert Firestore data to User manually
            if let user = self.parseUser(from: data) {
                print("✅ User data loaded from Firestore")
                completion(user)
            } else {
                completion(nil)
            }
        }
    }
    
    private func parseUser(from data: [String: Any]) -> User? {
        guard let id = data["id"] as? String else { return nil }
        
        let email = data["email"] as? String
        let displayName = data["displayName"] as? String
        let photoURL = data["photoURL"] as? String
        let provider = data["provider"] as? String ?? "email"
        
        // Convert Timestamps to Dates
        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let lastLoginAt = (data["lastLoginAt"] as? Timestamp)?.dateValue() ?? Date()
        
        let currentPlan = UserPlan(rawValue: data["currentPlan"] as? String ?? "free") ?? .free
        let monthlyAnalysisCount = data["monthlyAnalysisCount"] as? Int ?? 0
        let monthlyAnalysisLimit = data["monthlyAnalysisLimit"] as? Int ?? currentPlan.monthlyLimit
        let monthlyListingCount = data["monthlyListingCount"] as? Int ?? 0
        let monthlyListingLimit = data["monthlyListingLimit"] as? Int ?? currentPlan.monthlyListingLimit
        let subscriptionStatus = SubscriptionStatus(rawValue: data["subscriptionStatus"] as? String ?? "free") ?? .free
        
        let hasEbayConnected = data["hasEbayConnected"] as? Bool ?? false
        let ebayUserId = data["ebayUserId"] as? String
        let ebayTokenExpiry = (data["ebayTokenExpiry"] as? Timestamp)?.dateValue()
        
        let hasFaceIDEnabled = data["hasFaceIDEnabled"] as? Bool ?? false
        let lastFaceIDCheck = (data["lastFaceIDCheck"] as? Timestamp)?.dateValue()
        
        return User(
            id: id,
            email: email,
            displayName: displayName,
            photoURL: photoURL,
            provider: provider,
            createdAt: createdAt,
            lastLoginAt: lastLoginAt,
            currentPlan: currentPlan,
            monthlyAnalysisCount: monthlyAnalysisCount,
            monthlyAnalysisLimit: monthlyAnalysisLimit,
            monthlyListingCount: monthlyListingCount,
            monthlyListingLimit: monthlyListingLimit,
            subscriptionStatus: subscriptionStatus,
            hasEbayConnected: hasEbayConnected,
            ebayUserId: ebayUserId,
            ebayTokenExpiry: ebayTokenExpiry,
            hasFaceIDEnabled: hasFaceIDEnabled,
            lastFaceIDCheck: lastFaceIDCheck
        )
    }
    
    private func createUserDocument(_ user: User) {
        // Convert User to Firestore-compatible dictionary manually
        let userData: [String: Any] = [
            "id": user.id,
            "email": user.email ?? NSNull(),
            "displayName": user.displayName ?? NSNull(),
            "photoURL": user.photoURL ?? NSNull(),
            "provider": user.provider,
            "createdAt": Timestamp(date: user.createdAt),
            "lastLoginAt": Timestamp(date: user.lastLoginAt),
            "currentPlan": user.currentPlan.rawValue,
            "monthlyAnalysisCount": user.monthlyAnalysisCount,
            "monthlyAnalysisLimit": user.monthlyAnalysisLimit,
            "monthlyListingCount": user.monthlyListingCount,
            "monthlyListingLimit": user.monthlyListingLimit,
            "subscriptionStatus": user.subscriptionStatus.rawValue,
            "hasEbayConnected": user.hasEbayConnected,
            "ebayUserId": user.ebayUserId ?? NSNull(),
            "ebayTokenExpiry": user.ebayTokenExpiry != nil ? Timestamp(date: user.ebayTokenExpiry!) : NSNull(),
            "hasFaceIDEnabled": user.hasFaceIDEnabled,
            "lastFaceIDCheck": user.lastFaceIDCheck != nil ? Timestamp(date: user.lastFaceIDCheck!) : NSNull()
        ]
        
        db.collection("users").document(user.id).setData(userData) { error in
            if let error = error {
                print("❌ Error creating user document: \(error)")
            } else {
                print("✅ User document created in Firestore")
            }
        }
    }
    
    // MARK: - USAGE TRACKING & LIMITS (FIXED TO NOT BLOCK AUTH)
    
    // Public method that handles errors gracefully
    func trackUsage(action: String, metadata: [String: String] = [:]) {
        guard let user = currentUser else { return }
        
        print("📊 Tracking usage: \(action)")
        
        // Update local counts first (immediate)
        updateLocalUsage(action: action)
        
        // Save to Firestore (can fail without blocking)
        saveUsageToFirestore(action: action, metadata: metadata, userId: user.id)
    }
    
    // Quiet version that doesn't log errors (for auth flows)
    private func trackUsageQuietly(action: String, metadata: [String: String] = [:]) {
        guard let user = currentUser else { return }
        
        // Update local counts
        updateLocalUsage(action: action)
        
        // Try to save to Firestore silently
        let usageData: [String: Any] = [
            "id": UUID().uuidString,
            "userId": user.id,
            "action": action,
            "timestamp": Timestamp(date: Date()),
            "month": getCurrentMonth(),
            "metadata": metadata
        ]
        
        db.collection("usage").document(UUID().uuidString).setData(usageData) { _ in
            // Silently ignore errors during auth flows
        }
    }
    
    private func updateLocalUsage(action: String) {
        DispatchQueue.main.async {
            if action == "analysis" {
                self.monthlyAnalysisCount += 1
                self.updateAnalysisLimit()
            } else if action == "listing_created" {
                self.monthlyListingCount += 1
                self.updateListingLimit()
            }
        }
        
        // Update Firestore user document
        updateUserUsageCount()
    }
    
    private func saveUsageToFirestore(action: String, metadata: [String: String], userId: String) {
        let usageData: [String: Any] = [
            "id": UUID().uuidString,
            "userId": userId,
            "action": action,
            "timestamp": Timestamp(date: Date()),
            "month": getCurrentMonth(),
            "metadata": metadata
        ]
        
        db.collection("usage").document(UUID().uuidString).setData(usageData) { error in
            if let error = error {
                print("❌ Error saving usage to Firestore: \(error)")
                print("⚠️ This may be due to Firestore security rules. Usage tracking will continue locally.")
            } else {
                print("✅ Usage saved to Firestore: \(action)")
            }
        }
    }
    
    private func updateUserUsageCount() {
        guard let user = currentUser else { return }
        
        db.collection("users").document(user.id).updateData([
            "monthlyAnalysisCount": monthlyAnalysisCount,
            "monthlyListingCount": monthlyListingCount,
            "lastLoginAt": Timestamp()
        ]) { error in
            if let error = error {
                print("❌ Error updating usage count: \(error)")
                print("⚠️ This may be due to Firestore security rules.")
            } else {
                print("✅ Usage count updated in Firestore")
            }
        }
    }
    
    private func loadMonthlyUsage() {
        guard let user = currentUser else { return }
        
        let currentMonth = getCurrentMonth()
        
        // Load analysis usage
        db.collection("usage")
            .whereField("userId", isEqualTo: user.id)
            .whereField("month", isEqualTo: currentMonth)
            .whereField("action", isEqualTo: "analysis")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading monthly analysis usage: \(error)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                
                DispatchQueue.main.async {
                    self?.monthlyAnalysisCount = count
                    self?.updateAnalysisLimit()
                    print("📈 Monthly analysis usage loaded: \(count)")
                }
            }
        
        // Load listing usage
        db.collection("usage")
            .whereField("userId", isEqualTo: user.id)
            .whereField("month", isEqualTo: currentMonth)
            .whereField("action", isEqualTo: "listing_created")
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error loading monthly listing usage: \(error)")
                    return
                }
                
                let count = snapshot?.documents.count ?? 0
                
                DispatchQueue.main.async {
                    self?.monthlyListingCount = count
                    self?.updateListingLimit()
                    print("📈 Monthly listing usage loaded: \(count)")
                }
            }
    }
    
    private func updateAnalysisLimit() {
        guard let user = currentUser else { return }
        
        canAnalyze = monthlyAnalysisCount < user.monthlyAnalysisLimit
        updateDaysUntilReset()
        
        print("🎯 Analysis limit: \(monthlyAnalysisCount)/\(user.monthlyAnalysisLimit), Can analyze: \(canAnalyze)")
    }
    
    private func updateListingLimit() {
        guard let user = currentUser else { return }
        
        canCreateListing = monthlyListingCount < user.monthlyListingLimit
        updateDaysUntilReset()
        
        print("📤 Listing limit: \(monthlyListingCount)/\(user.monthlyListingLimit), Can create listing: \(canCreateListing)")
    }
    
    private func updateDaysUntilReset() {
        let calendar = Calendar.current
        let now = Date()
        let startOfNextMonth = calendar.dateInterval(of: .month, for: now)?.end ?? now
        daysUntilReset = calendar.dateComponents([.day], from: now, to: startOfNextMonth).day ?? 0
    }
    
    private func getCurrentMonth() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
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
            "monthlyListingLimit": plan.monthlyListingLimit,
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
                    let newUser = User(
                        id: updatedUser.id,
                        email: updatedUser.email,
                        displayName: updatedUser.displayName,
                        photoURL: updatedUser.photoURL,
                        provider: updatedUser.provider,
                        createdAt: updatedUser.createdAt,
                        lastLoginAt: Date(),
                        currentPlan: plan,
                        monthlyAnalysisCount: updatedUser.monthlyAnalysisCount,
                        monthlyAnalysisLimit: plan.monthlyLimit,
                        monthlyListingCount: updatedUser.monthlyListingCount,
                        monthlyListingLimit: plan.monthlyListingLimit,
                        subscriptionStatus: .active,
                        hasEbayConnected: updatedUser.hasEbayConnected,
                        ebayUserId: updatedUser.ebayUserId,
                        ebayTokenExpiry: updatedUser.ebayTokenExpiry,
                        hasFaceIDEnabled: updatedUser.hasFaceIDEnabled,
                        lastFaceIDCheck: updatedUser.lastFaceIDCheck
                    )
                    
                    DispatchQueue.main.async {
                        self?.currentUser = newUser
                        self?.updateAnalysisLimit()
                        self?.updateListingLimit()
                    }
                }
                
                completion(true)
            }
        }
    }
    
    // MARK: - HELPER METHODS
    var needsUpgrade: Bool {
        guard let user = currentUser else { return false }
        return monthlyAnalysisCount >= user.monthlyAnalysisLimit || monthlyListingCount >= user.monthlyListingLimit
    }
    
    var upgradeMessage: String {
        guard let user = currentUser else { return "" }
        
        if user.currentPlan == .free {
            return "Upgrade to Starter ($19/month) for 100 analyses & 50 listings"
        } else if user.currentPlan == .starter {
            return "Upgrade to Pro ($49/month) for 400 analyses & 200 listings"
        } else {
            return "Contact support for enterprise pricing"
        }
    }
    
    func resetMonthlyUsage() {
        // For testing - resets usage
        monthlyAnalysisCount = 0
        monthlyListingCount = 0
        updateAnalysisLimit()
        updateListingLimit()
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
extension AuthService: ASAuthorizationControllerDelegate {
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
                        self?.trackUsageQuietly(action: "apple_sign_in")
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
extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - APPLE SIGN IN CRYPTO HELPERS
extension AuthService {
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
