//
//  FirebaseService.swift
//  ResellAI
//
//  Updated Firebase Service - Delegates Auth to AuthService
//

import SwiftUI
import Foundation
import FirebaseCore
import FirebaseFirestore

// MARK: - FIREBASE SERVICE (UPDATED TO USE AUTH SERVICE)
class FirebaseService: ObservableObject {
    // Delegate auth to AuthService
    @Published var authService = AuthService()
    
    // Expose auth properties for backward compatibility
    var currentUser: User? { authService.currentUser }
    var isAuthenticated: Bool { authService.isAuthenticated }
    var isLoading: Bool { authService.isLoading }
    var authError: String? { authService.authError }
    
    // Usage tracking (delegated to AuthService)
    var monthlyAnalysisCount: Int { authService.monthlyAnalysisCount }
    var monthlyListingCount: Int { authService.monthlyListingCount }
    var canAnalyze: Bool { authService.canAnalyze }
    var canCreateListing: Bool { authService.canCreateListing }
    var daysUntilReset: Int { authService.daysUntilReset }
    
    // Face ID (delegated to AuthService)
    var isFaceIDEnabled: Bool { authService.isFaceIDEnabled }
    var isFaceIDAvailable: Bool { authService.isFaceIDAvailable }
    
    // Firebase instances
    private let db = Firestore.firestore()
    
    init() {
        print("🔥 Firebase Service initialized with AuthService delegation")
        configureFirebase()
    }
    
    private func configureFirebase() {
        // Firebase should be configured in App delegate, but we'll check here
        if FirebaseApp.app() == nil {
            print("⚠️ Firebase not configured - run FirebaseApp.configure() in App delegate")
        } else {
            print("✅ Firebase configured successfully")
        }
        
        // Configure Google Sign In through AuthService
        print("✅ Google Sign In configured via AuthService")
    }
    
    // MARK: - AUTH DELEGATION METHODS (FOR BACKWARD COMPATIBILITY)
    func signInWithApple() {
        authService.signInWithApple()
    }
    
    func signInWithGoogle() {
        authService.signInWithGoogle()
    }
    
    func signInWithEmail(_ email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        authService.signInWithEmail(email, password: password, completion: completion)
    }
    
    func createAccount(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        authService.createAccount(email: email, password: password, completion: completion)
    }
    
    func enableFaceID(completion: @escaping (Bool, String?) -> Void) {
        authService.enableFaceID(completion: completion)
    }
    
    func authenticateWithFaceID(completion: @escaping (Bool, String?) -> Void) {
        authService.authenticateWithFaceID(completion: completion)
    }
    
    func disableFaceID() {
        authService.disableFaceID()
    }
    
    func signOut() {
        authService.signOut()
    }
    
    func trackUsage(action: String, metadata: [String: String] = [:]) {
        authService.trackUsage(action: action, metadata: metadata)
    }
    
    func upgradePlan(to plan: UserPlan, completion: @escaping (Bool) -> Void) {
        authService.upgradePlan(to: plan, completion: completion)
    }
    
    var needsUpgrade: Bool {
        return authService.needsUpgrade
    }
    
    var upgradeMessage: String {
        return authService.upgradeMessage
    }
    
    func resetMonthlyUsage() {
        authService.resetMonthlyUsage()
    }
    
    // MARK: - INVENTORY SYNC (FIXED FOR TIMESTAMPS)
    func syncInventoryItem(_ item: InventoryItem, completion: @escaping (Bool) -> Void) {
        guard let user = currentUser else {
            completion(false)
            return
        }
        
        print("☁️ Syncing inventory item: \(item.name)")
        
        // Convert InventoryItem to Firestore-compatible dictionary manually
        let itemData: [String: Any] = [
            "id": item.id.uuidString,
            "userId": user.id,
            "itemNumber": item.itemNumber,
            "inventoryCode": item.inventoryCode,
            "name": item.name,
            "category": item.category,
            "brand": item.brand,
            "purchasePrice": item.purchasePrice,
            "suggestedPrice": item.suggestedPrice,
            "actualPrice": item.actualPrice ?? NSNull(),
            "source": item.source,
            "condition": item.condition,
            "title": item.title,
            "description": item.description,
            "keywords": item.keywords,
            "status": item.status.rawValue,
            "dateAdded": Timestamp(date: item.dateAdded),
            "dateListed": item.dateListed != nil ? Timestamp(date: item.dateListed!) : NSNull(),
            "dateSold": item.dateSold != nil ? Timestamp(date: item.dateSold!) : NSNull(),
            "imageURLs": [], // TODO: Upload images to Firebase Storage
            "ebayItemId": NSNull(),
            "ebayURL": item.ebayURL ?? NSNull(),
            "marketConfidence": item.marketConfidence ?? NSNull(),
            "soldListingsCount": item.soldListingsCount ?? NSNull(),
            "demandLevel": item.demandLevel ?? NSNull(),
            "aiConfidence": item.aiConfidence ?? NSNull(),
            "resalePotential": item.resalePotential ?? NSNull(),
            "storageLocation": item.storageLocation,
            "binNumber": item.binNumber,
            "isPackaged": item.isPackaged,
            "packagedDate": item.packagedDate != nil ? Timestamp(date: item.packagedDate!) : NSNull(),
            "createdAt": Timestamp(),
            "updatedAt": Timestamp(),
            "syncStatus": "synced"
        ]
        
        db.collection("inventory").document(item.id.uuidString).setData(itemData) { error in
            if let error = error {
                print("❌ Error syncing inventory item: \(error)")
                completion(false)
            } else {
                print("✅ Inventory item synced to Firestore")
                completion(true)
            }
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
                    if let item = self.parseFirebaseInventoryItem(from: doc.data()) {
                        items.append(item)
                    }
                }
                
                print("✅ Loaded \(items.count) inventory items from Firestore")
                completion(items)
            }
    }
    
    private func parseFirebaseInventoryItem(from data: [String: Any]) -> FirebaseInventoryItem? {
        guard let id = data["id"] as? String,
              let userId = data["userId"] as? String,
              let itemNumber = data["itemNumber"] as? Int,
              let name = data["name"] as? String else { return nil }
        
        return FirebaseInventoryItem(
            id: id,
            userId: userId,
            itemNumber: itemNumber,
            inventoryCode: data["inventoryCode"] as? String ?? "",
            name: name,
            category: data["category"] as? String ?? "",
            brand: data["brand"] as? String ?? "",
            purchasePrice: data["purchasePrice"] as? Double ?? 0,
            suggestedPrice: data["suggestedPrice"] as? Double ?? 0,
            actualPrice: data["actualPrice"] as? Double,
            source: data["source"] as? String ?? "",
            condition: data["condition"] as? String ?? "",
            title: data["title"] as? String ?? "",
            description: data["description"] as? String ?? "",
            keywords: data["keywords"] as? [String] ?? [],
            status: data["status"] as? String ?? "sourced",
            dateAdded: (data["dateAdded"] as? Timestamp)?.dateValue() ?? Date(),
            dateListed: (data["dateListed"] as? Timestamp)?.dateValue(),
            dateSold: (data["dateSold"] as? Timestamp)?.dateValue(),
            imageURLs: data["imageURLs"] as? [String] ?? [],
            ebayItemId: data["ebayItemId"] as? String,
            ebayURL: data["ebayURL"] as? String,
            marketConfidence: data["marketConfidence"] as? Double,
            soldListingsCount: data["soldListingsCount"] as? Int,
            demandLevel: data["demandLevel"] as? String,
            aiConfidence: data["aiConfidence"] as? Double,
            resalePotential: data["resalePotential"] as? Int,
            storageLocation: data["storageLocation"] as? String ?? "",
            binNumber: data["binNumber"] as? String ?? "",
            isPackaged: data["isPackaged"] as? Bool ?? false,
            packagedDate: (data["packagedDate"] as? Timestamp)?.dateValue(),
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date(),
            syncStatus: data["syncStatus"] as? String ?? "synced"
        )
    }
}

// MARK: - FIREBASE INVENTORY ITEM MODEL (KEPT FOR COMPATIBILITY)
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
