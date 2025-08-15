//
//  User.swift
//  ResellAI
//
//  Created by Alec on 8/15/25.
//


//
//  AuthModels.swift
//  ResellAI
//
//  Authentication Feature - Models
//

import SwiftUI
import Foundation
import FirebaseAuth

// MARK: - USER MODELS
struct User: Codable, Identifiable {
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
    let monthlyListingCount: Int
    let monthlyListingLimit: Int
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
        self.monthlyListingCount = 0
        self.monthlyListingLimit = 5
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
    init(from authUser: FirebaseAuth.User) {
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
        self.monthlyListingCount = 0
        self.monthlyListingLimit = 5
        self.subscriptionStatus = .free
        self.hasEbayConnected = false
        self.ebayUserId = nil
        self.ebayTokenExpiry = nil
        self.hasFaceIDEnabled = false
        self.lastFaceIDCheck = nil
    }
}

// MARK: - USER PLAN
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
    
    var monthlyListingLimit: Int {
        switch self {
        case .free: return 5
        case .starter: return 50
        case .pro: return 200
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
            return ["10 AI analyses/month", "5 eBay listings/month", "Basic inventory tracking"]
        case .starter:
            return ["100 AI analyses/month", "50 eBay listings/month", "Auto eBay posting", "Advanced inventory", "Priority support"]
        case .pro:
            return ["400 AI analyses/month", "200 eBay listings/month", "Full automation", "Analytics dashboard", "Premium support", "Bulk operations"]
        }
    }
}

// MARK: - SUBSCRIPTION STATUS
enum SubscriptionStatus: String, Codable {
    case free = "free"
    case active = "active"
    case pastDue = "past_due"
    case canceled = "canceled"
    case trial = "trial"
}

// MARK: - AUTH STATE
enum AuthState {
    case unauthenticated
    case loading
    case authenticated(User)
    case error(String)
}

// MARK: - AUTH ERROR
enum AuthError: Error, LocalizedError {
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case invalidEmail
    case weakPassword
    case networkError
    case biometricNotAvailable
    case biometricFailed
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "Account not found"
        case .wrongPassword:
            return "Incorrect password"
        case .emailAlreadyInUse:
            return "Email already in use"
        case .invalidEmail:
            return "Invalid email address"
        case .weakPassword:
            return "Password is too weak"
        case .networkError:
            return "Network error - check connection"
        case .biometricNotAvailable:
            return "Face ID not available on this device"
        case .biometricFailed:
            return "Face ID authentication failed"
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - USAGE RECORD
struct UsageRecord: Codable {
    let id: String
    let userId: String
    let action: String // "analysis", "listing", "export"
    let timestamp: Date
    let month: String // "2025-08" for monthly tracking
    let metadata: [String: String] // Additional context
}

// MARK: - EXTENSION FOR USER INITIALIZATION
extension User {
    init(id: String, email: String?, displayName: String?, photoURL: String? = nil, provider: String, createdAt: Date, lastLoginAt: Date, currentPlan: UserPlan, monthlyAnalysisCount: Int, monthlyAnalysisLimit: Int, monthlyListingCount: Int, monthlyListingLimit: Int, subscriptionStatus: SubscriptionStatus, hasEbayConnected: Bool, ebayUserId: String?, ebayTokenExpiry: Date?, hasFaceIDEnabled: Bool, lastFaceIDCheck: Date?) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.photoURL = photoURL
        self.provider = provider
        self.createdAt = createdAt
        self.lastLoginAt = lastLoginAt
        self.currentPlan = currentPlan
        self.monthlyAnalysisCount = monthlyAnalysisCount
        self.monthlyAnalysisLimit = monthlyAnalysisLimit
        self.monthlyListingCount = monthlyListingCount
        self.monthlyListingLimit = monthlyListingLimit
        self.subscriptionStatus = subscriptionStatus
        self.hasEbayConnected = hasEbayConnected
        self.ebayUserId = ebayUserId
        self.ebayTokenExpiry = ebayTokenExpiry
        self.hasFaceIDEnabled = hasFaceIDEnabled
        self.lastFaceIDCheck = lastFaceIDCheck
    }
}