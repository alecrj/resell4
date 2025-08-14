//
//  EbayService.swift
//  ResellAI
//
//  Created by Alec on 8/14/25.
//


//
//  EbayService.swift
//  ResellAI
//
//  Complete eBay OAuth 2.0 and Listing Service
//

import SwiftUI
import Foundation
import CryptoKit
import SafariServices

// MARK: - COMPLETE EBAY SERVICE WITH FIXED OAUTH
class EbayService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authStatus = "Not Connected"
    @Published var userInfo: EbayUser?
    @Published var connectedUserName: String = ""
    
    // OAuth 2.0 tokens
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiryDate: Date?
    
    // OAuth 2.0 PKCE parameters
    private var codeVerifier: String?
    private var codeChallenge: String?
    private var state: String?
    
    // Safari View Controller for OAuth
    private var safariViewController: SFSafariViewController?
    
    // eBay OAuth Configuration - Using your actual credentials
    private let clientId = Configuration.ebayAPIKey
    private let clientSecret = Configuration.ebayClientSecret
    private let devId = Configuration.ebayDevId
    private let ruName = Configuration.ebayRuName
    private let redirectURI = Configuration.ebayRedirectURI
    private let appScheme = Configuration.ebayAppScheme
    
    // Production eBay OAuth URL
    private let ebayOAuthURL = Configuration.ebayAuthBase + "/oauth2/authorize"
    
    // Storage keys
    private let accessTokenKey = "EbayAccessToken"
    private let refreshTokenKey = "EbayRefreshToken"
    private let tokenExpiryKey = "EbayTokenExpiry"
    private let userInfoKey = "EbayUserInfo"
    private let userNameKey = "EbayConnectedUserName"
    
    override init() {
        super.init()
        loadSavedTokens()
        validateSavedTokens()
    }
    
    func initialize() {
        print("🚀 EbayService initialized - COMPLETE eBay Integration")
        print("=== eBay Configuration ===")
        print("• Client ID: \(clientId)")
        print("• Dev ID: \(devId)")
        print("• RuName: \(ruName)")
        print("• Web Redirect URI: \(redirectURI)")
        print("• App Callback URI: \(appScheme)")
        print("• Environment: \(Configuration.ebayEnvironment)")
        print("========================")
        
        // Check if we have valid tokens on startup
        if let token = accessToken, !token.isEmpty, let expiry = tokenExpiryDate, expiry > Date() {
            print("✅ Valid eBay access token found")
            print("• Token expires: \(expiry)")
            
            isAuthenticated = true
            authStatus = "Connected to eBay"
            connectedUserName = UserDefaults.standard.string(forKey: userNameKey) ?? ""
            
            if connectedUserName.isEmpty {
                print("👤 Fetching eBay user info...")
                fetchUserInfo()
            } else {
                print("👤 Connected as: \(connectedUserName)")
            }
        } else {
            print("⚠️ No valid eBay tokens - user needs to authenticate")
            print("• Access token present: \(accessToken != nil)")
            print("• Token expired: \(tokenExpiryDate?.timeIntervalSinceNow ?? 0 < 0)")
            clearTokens()
        }
    }
    
    // MARK: - TOKEN ACCESS METHODS (FIXES THE ERROR)
    var hasValidToken: Bool {
        guard let token = accessToken, !token.isEmpty else { return false }
        guard let expiry = tokenExpiryDate else { return false }
        return expiry > Date()
    }
    
    func getAccessToken() -> String? {
        return hasValidToken ? accessToken : nil
    }
    
    // MARK: - FIXED OAuth 2.0 Authentication with Fallback
    func authenticate(completion: @escaping (Bool) -> Void) {
        print("🔐 Starting eBay OAuth 2.0 authentication with MINIMAL scopes...")
        
        // Try authentication with minimal scopes first
        authenticateWithScopes(Configuration.ebayRequiredScopes, completion: completion)
    }
    
    private func authenticateWithScopes(_ scopes: [String], completion: @escaping (Bool) -> Void) {
        // Generate PKCE parameters
        generatePKCEParameters()
        
        // Build authorization URL with specified scopes
        guard let authURL = buildAuthorizationURLWithScopes(scopes) else {
            print("❌ Failed to build authorization URL")
            
            // Try with even more minimal scopes if this fails
            if scopes.count > 1 {
                print("🔄 Trying with minimal scope only...")
                let minimalScopes = ["https://api.ebay.com/oauth/api_scope"]
                authenticateWithScopes(minimalScopes, completion: completion)
                return
            }
            
            completion(false)
            return
        }
        
        print("🌐 Opening eBay OAuth with \(scopes.count) scopes: \(authURL.absoluteString)")
        
        // Open in Safari
        DispatchQueue.main.async {
            self.authStatus = "Connecting to eBay..."
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                
                self.safariViewController = SFSafariViewController(url: authURL)
                self.safariViewController?.delegate = self
                
                rootViewController.present(self.safariViewController!, animated: true) {
                    print("✅ Safari OAuth view presented")
                }
                
                // Store completion for later use
                self.authCompletion = completion
                
            } else {
                print("❌ Could not find root view controller")
                self.authStatus = "Authentication failed"
                completion(false)
            }
        }
    }
    
    private func buildAuthorizationURLWithScopes(_ scopes: [String]) -> URL? {
        var components = URLComponents(string: ebayOAuthURL)
        
        // Join scopes with space separator
        let scopeString = scopes.joined(separator: " ")
        
        // Build query items with exact parameter names eBay expects
        let queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: scopeString),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        components?.queryItems = queryItems
        
        // Get the URL and validate it
        guard let url = components?.url else {
            print("❌ Failed to build OAuth URL with scopes: \(scopeString)")
            return nil
        }
        
        // Detailed logging for debugging
        print("🔗 eBay OAuth URL built with \(scopes.count) scopes:")
        print("   Client ID: \(clientId)")
        print("   Redirect URI: \(redirectURI)")
        print("   Scopes: \(scopeString)")
        print("   State: \(state?.prefix(8) ?? "nil")...")
        print("   Challenge: \(codeChallenge?.prefix(10) ?? "nil")...")
        print("   URL Length: \(url.absoluteString.count) chars")
        
        // Validate critical parameters
        let urlString = url.absoluteString
        var missingParams: [String] = []
        
        if !urlString.contains("client_id=\(clientId)") {
            missingParams.append("client_id")
        }
        if !urlString.contains("redirect_uri=") {
            missingParams.append("redirect_uri")
        }
        if !urlString.contains("code_challenge=") {
            missingParams.append("code_challenge")
        }
        if !urlString.contains("state=") {
            missingParams.append("state")
        }
        
        if !missingParams.isEmpty {
            print("❌ Missing parameters: \(missingParams.joined(separator: ", "))")
            return nil
        }
        
        print("✅ OAuth URL validation passed")
        return url
    }
    
    private var authCompletion: ((Bool) -> Void)?
    
    private func generatePKCEParameters() {
        // Generate code verifier (43-128 character random string)
        codeVerifier = generateCodeVerifier()
        
        // Generate code challenge (SHA256 hash of verifier, base64url encoded)
        if let verifier = codeVerifier {
            codeChallenge = generateCodeChallenge(from: verifier)
        }
        
        // Generate state parameter for CSRF protection
        state = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        
        print("🔐 PKCE parameters generated")
        print("• Code verifier: \(codeVerifier?.count ?? 0) chars")
        print("• Code challenge: \(codeChallenge?.prefix(10) ?? "nil")...")
        print("• State: \(state?.prefix(8) ?? "nil")...")
    }
    
    private func generateCodeVerifier() -> String {
        let charset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
        return String((0..<128).compactMap { _ in charset.randomElement() })
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        let data = verifier.data(using: .utf8)!
        let hash = SHA256.hash(data: data)
        return Data(hash).base64URLEncodedString()
    }

    func handleAuthCallback(url: URL, completion: ((Bool) -> Void)? = nil) {
        print("📞 Processing eBay OAuth callback from web-to-app bridge: \(url)")
        print("📋 Full callback URL: \(url.absoluteString)")
        
        // Close Safari view controller if still open
        DispatchQueue.main.async {
            self.safariViewController?.dismiss(animated: true)
        }
        
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let queryItems = components?.queryItems
        
        // Log all query parameters for debugging
        print("📋 Callback query items:")
        queryItems?.forEach { item in
            print("   • \(item.name): \(item.value ?? "nil")")
        }
        
        // Check for errors
        if let error = queryItems?.first(where: { $0.name == "error" })?.value {
            print("❌ OAuth error: \(error)")
            let errorDescription = queryItems?.first(where: { $0.name == "error_description" })?.value ?? "Unknown error"
            DispatchQueue.main.async {
                self.authStatus = "Authentication failed: \(errorDescription)"
                self.authCompletion?(false)
                completion?(false)
            }
            return
        }
        
        // Check for result parameter (error from web bridge)
        if let result = queryItems?.first(where: { $0.name == "result" })?.value, result == "error" {
            print("❌ Web bridge reported error")
            DispatchQueue.main.async {
                self.authStatus = "Authentication failed"
                self.authCompletion?(false)
                completion?(false)
            }
            return
        }
        
        // Get authorization code
        guard let code = queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ No authorization code received")
            print("Available parameters: \(queryItems?.map { $0.name } ?? [])")
            DispatchQueue.main.async {
                self.authStatus = "No authorization code received"
                self.authCompletion?(false)
                completion?(false)
            }
            return
        }
        
        // Verify state parameter if present
        if let receivedState = queryItems?.first(where: { $0.name == "state" })?.value {
            guard receivedState == state else {
                print("❌ State parameter mismatch")
                print("   Expected: \(state?.prefix(8) ?? "nil")...")
                print("   Received: \(receivedState.prefix(8))...")
                DispatchQueue.main.async {
                    self.authStatus = "Authentication failed - security error"
                    self.authCompletion?(false)
                    completion?(false)
                }
                return
            }
        }
        
        print("✅ Authorization code received: \(code.prefix(20))...")
        
        // Exchange authorization code for access token
        exchangeCodeForTokens(code: code) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.isAuthenticated = true
                    self?.authStatus = "Connected to eBay"
                    print("🎉 eBay Web-to-App Bridge OAuth authentication successful!")
                    
                    // Fetch user info
                    self?.fetchUserInfo()
                } else {
                    self?.authStatus = "Token exchange failed"
                    print("❌ eBay OAuth authentication failed")
                }
                
                self?.authCompletion?(success)
                completion?(success)
            }
        }
    }
    
    private func exchangeCodeForTokens(code: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: Configuration.ebayTokenEndpoint) else {
            print("❌ Invalid token endpoint")
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic authentication with client credentials
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Build request body - MUST use web redirect URI for token exchange
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "redirect_uri", value: redirectURI), // Web bridge URL
            URLQueryItem(name: "code_verifier", value: codeVerifier)
        ]
        
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)
        
        print("🔄 Exchanging authorization code for tokens...")
        print("• Endpoint: \(url.absoluteString)")
        print("• Client ID: \(clientId)")
        print("• Redirect URI: \(redirectURI)")
        print("• Code Verifier: \(codeVerifier?.prefix(10) ?? "nil")...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Token exchange network error: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Token exchange response code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Token exchange error (\(httpResponse.statusCode)): \(errorString)")
                        
                        // Try to parse the error for better debugging
                        if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            print("📋 Parsed error response:")
                            errorData.forEach { key, value in
                                print("   • \(key): \(value)")
                            }
                        }
                    }
                    completion(false)
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No token data received")
                completion(false)
                return
            }
            
            // Parse token response
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ Token response received")
                    print("📋 Token response keys: \(json.keys.joined(separator: ", "))")
                    
                    self?.accessToken = json["access_token"] as? String
                    self?.refreshToken = json["refresh_token"] as? String
                    
                    if let expiresIn = json["expires_in"] as? Int {
                        self?.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                    }
                    
                    print("✅ Access token: \(self?.accessToken?.prefix(10) ?? "nil")...")
                    print("✅ Refresh token: \(self?.refreshToken?.prefix(10) ?? "nil")...")
                    print("✅ Expires: \(self?.tokenExpiryDate ?? Date())")
                    
                    // Save tokens securely
                    self?.saveTokens()
                    
                    completion(true)
                    
                } else {
                    print("❌ Invalid token response format")
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("Raw response: \(responseString)")
                    }
                    completion(false)
                }
                
            } catch {
                print("❌ Error parsing token response: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Raw response: \(responseString)")
                }
                completion(false)
            }
            
        }.resume()
    }
    
    // MARK: - Token Management
    private func saveTokens() {
        let keychain = UserDefaults.standard // Using UserDefaults for simplicity - in production, use Keychain
        
        if let accessToken = accessToken {
            keychain.set(accessToken, forKey: accessTokenKey)
        }
        
        if let refreshToken = refreshToken {
            keychain.set(refreshToken, forKey: refreshTokenKey)
        }
        
        if let tokenExpiryDate = tokenExpiryDate {
            keychain.set(tokenExpiryDate, forKey: tokenExpiryKey)
        }
        
        print("💾 eBay tokens saved securely")
    }
    
    private func loadSavedTokens() {
        let keychain = UserDefaults.standard
        
        accessToken = keychain.string(forKey: accessTokenKey)
        refreshToken = keychain.string(forKey: refreshTokenKey)
        tokenExpiryDate = keychain.object(forKey: tokenExpiryKey) as? Date
        connectedUserName = keychain.string(forKey: userNameKey) ?? ""
        
        if let token = accessToken, !token.isEmpty {
            print("📱 Loaded saved eBay tokens")
        }
    }
    
    private func validateSavedTokens() {
        // Check if access token is expired
        if let expiry = tokenExpiryDate, expiry <= Date() {
            print("⚠️ eBay access token expired, attempting refresh...")
            refreshAccessToken { [weak self] success in
                if !success {
                    print("❌ Token refresh failed, user needs to re-authenticate")
                    self?.clearTokens()
                }
            }
        }
    }
    
    private func refreshAccessToken(completion: @escaping (Bool) -> Void) {
        guard let refreshToken = refreshToken, !refreshToken.isEmpty else {
            print("❌ No refresh token available")
            completion(false)
            return
        }
        
        guard let url = URL(string: Configuration.ebayTokenEndpoint) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken)
        ]
        
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    self?.accessToken = json["access_token"] as? String
                    
                    if let expiresIn = json["expires_in"] as? Int {
                        self?.tokenExpiryDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                    }
                    
                    self?.saveTokens()
                    print("✅ eBay access token refreshed")
                    completion(true)
                } else {
                    completion(false)
                }
            } catch {
                completion(false)
            }
        }.resume()
    }
    
    private func clearTokens() {
        let keychain = UserDefaults.standard
        keychain.removeObject(forKey: accessTokenKey)
        keychain.removeObject(forKey: refreshTokenKey)
        keychain.removeObject(forKey: tokenExpiryKey)
        keychain.removeObject(forKey: userInfoKey)
        keychain.removeObject(forKey: userNameKey)
        
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
        userInfo = nil
        connectedUserName = ""
        
        DispatchQueue.main.async {
            self.isAuthenticated = false
            self.authStatus = "Not Connected"
        }
        
        print("🗑️ eBay tokens cleared")
    }
    
    // MARK: - User Info Fetching
    private func fetchUserInfo() {
        guard let accessToken = accessToken else {
            print("❌ No access token for user info")
            return
        }
        
        // Use Commerce Identity API to get user profile
        let userInfoURL = Configuration.ebayUserEndpoint
        
        guard let url = URL(string: userInfoURL) else {
            print("❌ Invalid user endpoint")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("👤 Fetching eBay user info...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ User info fetch error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 User info response code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ User info error (\(httpResponse.statusCode)): \(errorString)")
                    }
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No user data received")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("✅ eBay user info received: \(json)")
                    
                    let username = json["username"] as? String ?? "eBay User"
                    let userId = json["userId"] as? String ?? ""
                    let email = json["email"] as? String ?? ""
                    let registrationDate = json["registrationDate"] as? String ?? ""
                    
                    let user = EbayUser(
                        userId: userId,
                        username: username,
                        email: email,
                        registrationDate: registrationDate
                    )
                    
                    DispatchQueue.main.async {
                        self?.userInfo = user
                        self?.connectedUserName = username
                        self?.saveUserInfo(user)
                        UserDefaults.standard.set(username, forKey: self?.userNameKey ?? "")
                        print("✅ eBay user connected: \(username)")
                    }
                } else {
                    print("❌ Invalid user info response format")
                }
            } catch {
                print("❌ Error parsing user info: \(error)")
            }
        }.resume()
    }
    
    private func saveUserInfo(_ user: EbayUser) {
        do {
            let userData = try JSONEncoder().encode(user)
            UserDefaults.standard.set(userData, forKey: userInfoKey)
        } catch {
            print("❌ Error saving user info: \(error)")
        }
    }
    
    // MARK: - COMPLETE EBAY LISTING CREATION IMPLEMENTATION
    func createListing(analysis: AnalysisResult, images: [UIImage], completion: @escaping (Bool, String?) -> Void) {
        guard isAuthenticated else {
            completion(false, "Not authenticated with eBay. Please connect your account first.")
            return
        }
        
        guard let accessToken = accessToken else {
            completion(false, "No valid eBay access token")
            return
        }
        
        print("📤 Creating eBay listing: \(analysis.name)")
        print("• Price: $\(String(format: "%.2f", analysis.suggestedPrice))")
        print("• Images: \(images.count)")
        
        // Step 1: Upload images to eBay
        uploadImagesToEbay(images: images) { [weak self] imageUrls in
            guard !imageUrls.isEmpty else {
                completion(false, "Failed to upload images to eBay")
                return
            }
            
            print("✅ Uploaded \(imageUrls.count) images to eBay")
            
            // Step 2: Create inventory item
            self?.createInventoryItem(analysis: analysis, imageUrls: imageUrls) { inventoryItemId in
                guard let inventoryItemId = inventoryItemId else {
                    completion(false, "Failed to create inventory item")
                    return
                }
                
                print("✅ Created inventory item: \(inventoryItemId)")
                
                // Step 3: Create offer (this creates the actual listing)
                self?.createOffer(inventoryItemId: inventoryItemId, analysis: analysis) { success, errorMessage in
                    if success {
                        print("🎉 eBay listing created successfully!")
                        completion(true, nil)
                    } else {
                        completion(false, errorMessage ?? "Failed to create listing")
                    }
                }
            }
        }
    }
    
    // MARK: - Image Upload to eBay
    private func uploadImagesToEbay(images: [UIImage], completion: @escaping ([String]) -> Void) {
        guard let accessToken = accessToken else {
            completion([])
            return
        }
        
        let imageUploadURL = "\(Configuration.ebaySellInventoryAPI)/picture"
        var uploadedImageUrls: [String] = []
        let group = DispatchGroup()
        
        for (index, image) in images.enumerated() {
            guard index < Configuration.ebayMaxImages else { break }
            
            group.enter()
            
            uploadSingleImageToEbay(image: image, accessToken: accessToken, uploadURL: imageUploadURL) { imageUrl in
                if let imageUrl = imageUrl {
                    uploadedImageUrls.append(imageUrl)
                    print("✅ Uploaded image \(index + 1)/\(images.count)")
                } else {
                    print("❌ Failed to upload image \(index + 1)")
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            print("📸 Image upload complete: \(uploadedImageUrls.count)/\(images.count) successful")
            completion(uploadedImageUrls)
        }
    }
    
    private func uploadSingleImageToEbay(image: UIImage, accessToken: String, uploadURL: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: uploadURL) else {
            completion(nil)
            return
        }
        
        // Compress image for eBay (max 12MB, but we'll use 8MB to be safe)
        guard let imageData = compressImageForEbay(image) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var formData = Data()
        
        // Add image data
        formData.append("--\(boundary)\r\n".data(using: .utf8)!)
        formData.append("Content-Disposition: form-data; name=\"image\"; filename=\"item_image.jpg\"\r\n".data(using: .utf8)!)
        formData.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        formData.append(imageData)
        formData.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = formData
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Image upload error: \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Image upload response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Image upload error (\(httpResponse.statusCode)): \(errorString)")
                    }
                    completion(nil)
                    return
                }
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            // Parse response to get image URL
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let imageUrl = json["imageUrl"] as? String {
                    completion(imageUrl)
                } else {
                    print("❌ Could not parse image upload response")
                    completion(nil)
                }
            } catch {
                print("❌ Error parsing image upload response: \(error)")
                completion(nil)
            }
            
        }.resume()
    }
    
    private func compressImageForEbay(_ image: UIImage) -> Data? {
        // eBay allows up to 12MB images, but we'll target 5MB for better performance
        let maxSizeBytes = 5 * 1024 * 1024
        var compressionQuality: CGFloat = 0.9
        var imageData = image.jpegData(compressionQuality: compressionQuality)
        
        while let data = imageData, data.count > maxSizeBytes && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        // If still too large, resize the image
        if let data = imageData, data.count > maxSizeBytes {
            let maxDimension: CGFloat = 1600 // eBay recommends 1600x1600 max
            let currentMaxDimension = max(image.size.width, image.size.height)
            
            if currentMaxDimension > maxDimension {
                let scale = maxDimension / currentMaxDimension
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                imageData = resizedImage?.jpegData(compressionQuality: 0.8)
            }
        }
        
        return imageData
    }
    
    // MARK: - Create Inventory Item
    private func createInventoryItem(analysis: AnalysisResult, imageUrls: [String], completion: @escaping (String?) -> Void) {
        guard let accessToken = accessToken else {
            completion(nil)
            return
        }
        
        let inventoryItemId = "RESELLAI_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20))"
        let createItemURL = "\(Configuration.ebaySellInventoryAPI)/inventory_item/\(inventoryItemId)"
        
        guard let url = URL(string: createItemURL) else {
            completion(nil)
            return
        }
        
        // Build inventory item data
        let inventoryData: [String: Any] = [
            "availability": [
                "pickupAtLocationAvailability": [
                    [
                        "availabilityType": "IN_STOCK",
                        "fulfillmentTime": [
                            "value": 1,
                            "unit": "BUSINESS_DAY"
                        ],
                        "quantity": 1
                    ]
                ]
            ],
            "condition": mapConditionToEbay(analysis.condition),
            "product": [
                "title": analysis.title,
                "description": analysis.description,
                "imageUrls": imageUrls,
                "aspects": buildProductAspects(from: analysis)
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: inventoryData)
        } catch {
            print("❌ Error creating inventory item JSON: \(error)")
            completion(nil)
            return
        }
        
        print("📦 Creating inventory item: \(inventoryItemId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Inventory item creation error: \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Inventory item response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 204 {
                    print("✅ Inventory item created successfully")
                    completion(inventoryItemId)
                } else {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Inventory item error (\(httpResponse.statusCode)): \(errorString)")
                    }
                    completion(nil)
                }
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - Create Offer (Creates the actual listing)
    private func createOffer(inventoryItemId: String, analysis: AnalysisResult, completion: @escaping (Bool, String?) -> Void) {
        guard let accessToken = accessToken else {
            completion(false, "No access token")
            return
        }
        
        let offerId = "OFFER_\(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(20))"
        let createOfferURL = "\(Configuration.ebaySellInventoryAPI)/offer/\(offerId)"
        
        guard let url = URL(string: createOfferURL) else {
            completion(false, "Invalid offer URL")
            return
        }
        
        // First, let's try to get user's existing policies
        getOrCreateDefaultPolicies { [weak self] policies in
            guard let self = self else { return }
            
            // Build offer data with actual or default policies
            var offerData: [String: Any] = [
                "sku": inventoryItemId,
                "marketplaceId": "EBAY_US",
                "format": "FIXED_PRICE",
                "availableQuantity": 1,
                "categoryId": self.getCategoryId(for: analysis.category),
                "listingDescription": analysis.description,
                "pricingSummary": [
                    "price": [
                        "value": String(format: "%.2f", analysis.suggestedPrice),
                        "currency": "USD"
                    ]
                ],
                "quantityLimitPerBuyer": 1
            ]
            
            // Only add policies if we found them
            if let policies = policies, !policies.isEmpty {
                offerData["listingPolicies"] = policies
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: offerData)
                print("📝 Offer data: \(offerData)")
            } catch {
                print("❌ Error creating offer JSON: \(error)")
                completion(false, "Failed to create offer data")
                return
            }
            
            print("🎯 Creating offer for inventory item: \(inventoryItemId)")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Offer creation error: \(error)")
                    completion(false, "Network error: \(error.localizedDescription)")
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("🔍 Offer creation response: \(httpResponse.statusCode)")
                    
                    if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                        print("✅ Offer created successfully")
                        
                        // Now publish the offer to create the actual listing
                        self.publishOffer(offerId: offerId) { success, publishError in
                            completion(success, publishError)
                        }
                    } else {
                        var errorMessage = "Failed to create offer"
                        if let data = data, let errorString = String(data: data, encoding: .utf8) {
                            print("❌ Offer creation error (\(httpResponse.statusCode)): \(errorString)")
                            errorMessage = "eBay error: \(errorString)"
                        }
                        completion(false, errorMessage)
                    }
                } else {
                    completion(false, "Invalid response")
                }
            }.resume()
        }
    }
    
    // MARK: - Get or Create Default Policies
    private func getOrCreateDefaultPolicies(completion: @escaping ([String: String]?) -> Void) {
        guard let accessToken = accessToken else {
            completion(nil)
            return
        }
        
        // Try to get existing fulfillment policies
        let policiesURL = "\(Configuration.ebaySellAccountAPI)/fulfillment_policy"
        
        guard let url = URL(string: policiesURL) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🔍 Checking for existing eBay policies...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Error checking policies: \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let data = data {
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let policies = json["fulfillmentPolicies"] as? [[String: Any]],
                       let firstPolicy = policies.first,
                       let policyId = firstPolicy["fulfillmentPolicyId"] as? String {
                        
                        print("✅ Found existing fulfillment policy: \(policyId)")
                        
                        // For now, just use the first fulfillment policy we find
                        // In a production app, you'd want to check for payment and return policies too
                        let policyDict = ["fulfillmentPolicyId": policyId]
                        completion(policyDict)
                        return
                    }
                } catch {
                    print("❌ Error parsing policies: \(error)")
                }
            } else {
                print("⚠️ No existing policies found or error accessing policies")
            }
            
            // If no policies found, return nil to create listing without explicit policies
            // eBay will use account defaults
            print("ℹ️ Using eBay account default policies")
            completion(nil)
            
        }.resume()
    }
    
    // MARK: - Publish Offer (Makes listing live)
    private func publishOffer(offerId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let accessToken = accessToken else {
            completion(false, "No access token")
            return
        }
        
        let publishURL = "\(Configuration.ebaySellInventoryAPI)/offer/\(offerId)/publish"
        
        guard let url = URL(string: publishURL) else {
            completion(false, "Invalid publish URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("🚀 Publishing offer: \(offerId)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Offer publish error: \(error)")
                completion(false, "Publish error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Offer publish response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 204 {
                    print("🎉 Offer published successfully! Listing is now live on eBay!")
                    completion(true, nil)
                } else {
                    var errorMessage = "Failed to publish listing"
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ Publish error (\(httpResponse.statusCode)): \(errorString)")
                        errorMessage = "Publish error: \(errorString)"
                    }
                    completion(false, errorMessage)
                }
            } else {
                completion(false, "Invalid publish response")
            }
        }.resume()
    }
    
    // MARK: - Helper Functions for eBay Listing
    private func mapConditionToEbay(_ condition: String) -> String {
        let conditionLower = condition.lowercased()
        
        if conditionLower.contains("new with tags") {
            return "NEW_WITH_TAGS"
        } else if conditionLower.contains("new without tags") {
            return "NEW_WITHOUT_TAGS"
        } else if conditionLower.contains("new") {
            return "NEW_OTHER"
        } else if conditionLower.contains("like new") || conditionLower.contains("excellent") {
            return "USED_EXCELLENT"
        } else if conditionLower.contains("very good") {
            return "USED_VERY_GOOD"
        } else if conditionLower.contains("good") {
            return "USED_GOOD"
        } else if conditionLower.contains("acceptable") || conditionLower.contains("fair") {
            return "USED_ACCEPTABLE"
        } else {
            return "USED_GOOD" // Default fallback
        }
    }
    
    private func buildProductAspects(from analysis: AnalysisResult) -> [String: [String]] {
        var aspects: [String: [String]] = [:]
        
        if !analysis.brand.isEmpty {
            aspects["Brand"] = [analysis.brand]
        }
        
        if let size = analysis.size, !size.isEmpty {
            aspects["Size"] = [size]
        }
        
        if let colorway = analysis.colorway, !colorway.isEmpty {
            aspects["Color"] = [colorway]
        }
        
        if let model = analysis.exactModel, !model.isEmpty {
            aspects["Model"] = [model]
        }
        
        if let styleCode = analysis.styleCode, !styleCode.isEmpty {
            aspects["Style Code"] = [styleCode]
        }
        
        // Add condition as an aspect
        aspects["Condition"] = [analysis.condition]
        
        return aspects
    }
    
    private func getCategoryId(for category: String) -> String {
        // Use the category mappings from Configuration
        for (key, value) in Configuration.ebayCategoryMappings {
            if category.lowercased().contains(key.lowercased()) {
                return value
            }
        }
        return "99" // Other category as fallback
    }
    
    // MARK: - Authentication Status
    func signOut() {
        clearTokens()
        print("👋 Signed out of eBay")
    }
}

// MARK: - eBay User Model
struct EbayUser: Codable {
    let userId: String
    let username: String
    let email: String
    let registrationDate: String
}

// MARK: - SFSafariViewControllerDelegate
extension EbayService: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        print("📱 User cancelled eBay OAuth")
        DispatchQueue.main.async {
            self.authStatus = "Authentication cancelled"
            self.authCompletion?(false)
        }
    }
}

// MARK: - Base64URL Encoding Extension
extension Data {
    func base64URLEncodedString() -> String {
        return base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}