//
//  BusinessService.swift
//  ResellAI
//
//  Business Service with AI Analysis
//

import SwiftUI
import Foundation
import Vision
import AuthenticationServices
import FirebaseFirestore
import CryptoKit
import SafariServices

// MARK: - BUSINESS SERVICE WITH AI
class BusinessService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var progressValue: Double = 0.0
    @Published var isSyncing = false
    @Published var syncStatus = "Ready"
    @Published var lastSyncDate: Date?
    
    // Queue System
    @Published var processingQueue = ProcessingQueue()
    @Published var isProcessingQueue = false
    @Published var queueProgress = "Queue Ready"
    @Published var queueProgressValue: Double = 0.0
    
    // AI service
    private let aiService = AIAnalysisService()
    
    // eBay Services
    let ebayService = EbayService()
    private let ebayListingService = EbayListingService()
    
    // Firebase integration
    private weak var firebaseService: FirebaseService?
    private weak var authService: AuthService?
    
    // Queue processing timer
    private var queueTimer: Timer?
    
    init() {
        print("🚀 ResellAI Business Service initialized with AI Analysis")
        loadSavedQueue()
    }
    
    func initialize(with firebaseService: FirebaseService? = nil) {
        Configuration.validateConfiguration()
        self.firebaseService = firebaseService
        self.authService = firebaseService?.authService
        ebayService.initialize()
    }
    
    // MARK: - SINGLE ITEM ANALYSIS
    func analyzeItem(_ images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        
        // Check AuthService usage limits
        if let authService = authService, !authService.canAnalyze {
            print("⚠️ Monthly analysis limit reached")
            completion(nil)
            return
        }
        
        print("🧠 Starting ResellAI analysis with \(images.count) images")
        
        // Track usage in AuthService
        authService?.trackUsage(action: "analysis", metadata: [
            "source": "single_item",
            "image_count": "\(images.count)",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "ai_version": "v2"
        ])
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.progressValue = 0.1
            self.analysisProgress = "Analyzing with AI..."
        }
        
        // Use AI analysis that handles both identification and pricing
        updateProgress("AI analyzing product...", progress: 0.3)
        
        aiService.analyzeItemWithMarketIntelligence(images: images) { [weak self] expertResult in
            guard let expertResult = expertResult else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    self?.analysisProgress = "Analysis failed"
                }
                completion(nil)
                return
            }
            
            // Convert expert result to standard format
            self?.updateProgress("Finalizing analysis...", progress: 0.9)
            
            let finalResult = expertResult.toAnalysisResult()
            
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                self?.analysisProgress = "Analysis complete"
                self?.progressValue = 1.0
                
                print("✅ AI analysis complete: \(expertResult.exactProductName)")
                print("💰 Quick Sale: $\(String(format: "%.2f", expertResult.quickSalePrice))")
                print("💰 Market Price: $\(String(format: "%.2f", expertResult.marketPrice))")
                print("💰 Patient Sale: $\(String(format: "%.2f", expertResult.patientSalePrice))")
                print("🎯 Reasoning: \(expertResult.priceReasoning)")
                print("🔥 Hype Status: \(expertResult.hypeStatus)")
                print("💎 Rarity: \(expertResult.rarityLevel)")
                
                completion(finalResult)
            }
        }
    }
    
    // MARK: - QUEUE PROCESSING
    func addItemToQueue(photos: [UIImage]) -> UUID {
        let itemId = processingQueue.addItem(photos: photos)
        saveQueue()
        
        print("📱 Added item to queue: \(processingQueue.items.count) total items")
        
        // Auto-start processing if user has available analyses and nothing is currently processing
        if !processingQueue.isProcessing && canProcessQueue() {
            startProcessingQueue()
        }
        
        return itemId
    }
    
    func startProcessingQueue() {
        guard !processingQueue.isProcessing else { return }
        guard canProcessQueue() else {
            print("⚠️ Cannot process queue - no available analyses or rate limit hit")
            return
        }
        
        processingQueue.isProcessing = true
        isProcessingQueue = true
        queueProgress = "Starting queue processing..."
        
        print("🔄 Starting queue processing with \(processingQueue.pendingItems.count) pending items")
        
        // Start processing timer
        startQueueProcessingTimer()
        
        // Process first item
        processNextQueueItem()
        
        saveQueue()
    }
    
    func pauseProcessingQueue() {
        processingQueue.isProcessing = false
        isProcessingQueue = false
        queueProgress = "Queue paused"
        
        // Stop timer
        queueTimer?.invalidate()
        queueTimer = nil
        
        print("⏸️ Queue processing paused")
        saveQueue()
    }
    
    func removeFromQueue(itemId: UUID) {
        processingQueue.removeItem(itemId)
        saveQueue()
        
        print("🗑️ Removed item from queue")
        
        // If we removed the currently processing item, move to next
        if processingQueue.currentlyProcessing == itemId {
            processingQueue.currentlyProcessing = nil
            if processingQueue.isProcessing {
                processNextQueueItem()
            }
        }
    }
    
    func retryQueueItem(itemId: UUID) {
        if let index = processingQueue.items.firstIndex(where: { $0.id == itemId }) {
            processingQueue.items[index].status = .pending
            processingQueue.items[index].errorMessage = nil
            processingQueue.items[index].wasCountedAgainstLimit = false
            
            print("🔄 Retrying queue item")
            
            // If queue is processing and nothing is currently being processed, start this item
            if processingQueue.isProcessing && processingQueue.currentlyProcessing == nil {
                processNextQueueItem()
            }
            
            saveQueue()
        }
    }
    
    func clearQueue() {
        pauseProcessingQueue()
        processingQueue.clear()
        queueProgress = "Queue cleared"
        queueProgressValue = 0.0
        saveQueue()
        
        print("🗑️ Queue cleared")
    }
    
    // MARK: - PRIVATE QUEUE PROCESSING METHODS
    
    private func canProcessQueue() -> Bool {
        guard let authService = authService else { return false }
        return authService.canAnalyze && !processingQueue.rateLimitHit
    }
    
    private func startQueueProcessingTimer() {
        queueTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateQueueProgress()
        }
    }
    
    private func updateQueueProgress() {
        let totalItems = processingQueue.items.count
        let completedItems = processingQueue.completedItems.count + processingQueue.failedItems.count
        
        if totalItems > 0 {
            queueProgressValue = Double(completedItems) / Double(totalItems)
        }
        
        if let currentId = processingQueue.currentlyProcessing,
           let currentItem = processingQueue.items.first(where: { $0.id == currentId }) {
            queueProgress = "AI analyzing Item \(currentItem.position)..."
        } else if completedItems == totalItems && totalItems > 0 {
            queueProgress = "Queue complete!"
        }
    }
    
    private func processNextQueueItem() {
        // Check if we can still process
        guard canProcessQueue() else {
            handleRateLimitReached()
            return
        }
        
        // Get next item to process
        guard let nextItem = processingQueue.nextItemToProcess else {
            // No more items to process
            finishQueueProcessing()
            return
        }
        
        // Mark item as processing
        processingQueue.currentlyProcessing = nextItem.id
        processingQueue.updateItemStatus(nextItem.id, status: .processing)
        
        print("🧠 Processing queue item \(nextItem.position) with AI")
        
        // Analyze the item using AI
        analyzeQueueItem(nextItem)
    }
    
    private func analyzeQueueItem(_ item: QueuedItem) {
        let photos = item.uiImages
        
        guard !photos.isEmpty else {
            processQueueItemComplete(item.id, result: nil, error: "No photos provided")
            return
        }
        
        // Track usage in AuthService
        authService?.trackUsage(action: "analysis", metadata: [
            "source": "queue",
            "item_position": "\(item.position)",
            "photo_count": "\(photos.count)",
            "ai_version": "v2"
        ])
        
        // Use AI analysis
        aiService.analyzeItemWithMarketIntelligence(images: photos) { [weak self] expertResult in
            guard let self = self else { return }
            
            guard let expertResult = expertResult else {
                self.processQueueItemComplete(
                    item.id,
                    result: nil,
                    error: "AI analysis failed",
                    shouldCountAgainstLimit: false
                )
                return
            }
            
            // Convert to standard AnalysisResult format
            let finalResult = expertResult.toAnalysisResult()
            
            print("✅ Queue item analysis complete: \(expertResult.exactProductName)")
            print("💰 Expert pricing: $\(String(format: "%.2f", expertResult.marketPrice))")
            
            self.processQueueItemComplete(item.id, result: finalResult, error: nil)
        }
    }
    
    private func processQueueItemComplete(_ itemId: UUID, result: AnalysisResult?, error: String?, shouldCountAgainstLimit: Bool = true) {
        DispatchQueue.main.async {
            if let result = result {
                // Success
                self.processingQueue.updateItemStatus(itemId, status: .completed, result: result)
                print("✅ Queue item \(itemId) completed successfully")
            } else {
                // Failure
                self.processingQueue.updateItemStatus(itemId, status: .failed, error: error)
                
                if let index = self.processingQueue.items.firstIndex(where: { $0.id == itemId }) {
                    self.processingQueue.items[index].wasCountedAgainstLimit = shouldCountAgainstLimit
                }
                
                print("❌ Queue item \(itemId) failed: \(error ?? "Unknown error")")
            }
            
            // Clear currently processing
            self.processingQueue.currentlyProcessing = nil
            
            // Save queue state
            self.saveQueue()
            
            // Process next item after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.processingQueue.isProcessing {
                    self.processNextQueueItem()
                }
            }
        }
    }
    
    private func handleRateLimitReached() {
        processingQueue.rateLimitHit = true
        processingQueue.isProcessing = false
        isProcessingQueue = false
        
        queueTimer?.invalidate()
        queueTimer = nil
        
        queueProgress = "Rate limit reached - queue paused"
        
        print("⚠️ Rate limit reached, queue processing paused")
        
        // Send notification about rate limit
        NotificationCenter.default.post(name: .rateLimitReached, object: nil)
        
        saveQueue()
    }
    
    private func finishQueueProcessing() {
        processingQueue.isProcessing = false
        isProcessingQueue = false
        processingQueue.currentlyProcessing = nil
        processingQueue.rateLimitHit = false
        
        queueTimer?.invalidate()
        queueTimer = nil
        
        let completedCount = processingQueue.completedItems.count
        let failedCount = processingQueue.failedItems.count
        
        queueProgress = "AI complete: \(completedCount) analyzed, \(failedCount) failed"
        queueProgressValue = 1.0
        
        print("✅ Queue processing finished: \(completedCount) completed, \(failedCount) failed")
        
        // Send completion notification
        if completedCount > 0 {
            scheduleCompletionNotification(completedCount: completedCount)
        }
        
        saveQueue()
    }
    
    private func scheduleCompletionNotification(completedCount: Int) {
        print("📱 Would send notification: \(completedCount) items analyzed with AI")
    }
    
    // MARK: - QUEUE PERSISTENCE
    
    private func saveQueue() {
        do {
            let data = try JSONEncoder().encode(processingQueue)
            UserDefaults.standard.set(data, forKey: "ProcessingQueue")
        } catch {
            print("❌ Error saving queue: \(error)")
        }
    }
    
    private func loadSavedQueue() {
        guard let data = UserDefaults.standard.data(forKey: "ProcessingQueue") else {
            return
        }
        
        do {
            processingQueue = try JSONDecoder().decode(ProcessingQueue.self, from: data)
            print("📱 Loaded saved queue with \(processingQueue.items.count) items")
            
            // Reset processing state on app restart
            processingQueue.isProcessing = false
            processingQueue.currentlyProcessing = nil
            isProcessingQueue = false
            
        } catch {
            print("❌ Error loading saved queue: \(error)")
            processingQueue = ProcessingQueue()
        }
    }
    
    // MARK: - EBAY INTEGRATION
    
    func authenticateEbay(completion: @escaping (Bool) -> Void) {
        ebayService.authenticate(completion: completion)
    }
    
    func handleEbayAuthCallback(url: URL) {
        print("🔗 BusinessService handling eBay OAuth callback: \(url)")
        
        ebayService.handleAuthCallback(url: url) { [weak self] (success: Bool) in
            DispatchQueue.main.async {
                if success {
                    print("✅ eBay OAuth completed successfully in BusinessService")
                    self?.objectWillChange.send()
                    print("🔍 eBay authenticated: \(self?.ebayService.isAuthenticated ?? false)")
                    print("🔍 eBay user: \(self?.ebayService.connectedUserName ?? "Unknown")")
                } else {
                    print("❌ eBay OAuth failed in BusinessService")
                }
            }
        }
    }
    
    var isEbayAuthenticated: Bool {
        return ebayService.isAuthenticated
    }
    
    var ebayAuthStatus: String {
        return ebayService.authStatus
    }
    
    func createEbayListing(from analysis: AnalysisResult, images: [UIImage], completion: @escaping (Bool, String?) -> Void) {
        guard let authService = authService else {
            completion(false, "Auth service not initialized")
            return
        }
        
        if !authService.canCreateListing {
            completion(false, "Monthly listing limit reached. Please upgrade your plan.")
            return
        }
        
        guard ebayService.isAuthenticated else {
            completion(false, "Please connect your eBay account first")
            return
        }
        
        guard let accessToken = ebayService.getAccessToken() else {
            completion(false, "No valid eBay access token")
            return
        }
        
        print("📤 Creating eBay listing for: \(analysis.name)")
        print("• Using AI analysis result")
        
        ebayListingService.createListing(analysis: analysis, images: images, accessToken: accessToken) { [weak self] success, errorMessage in
            if success {
                authService.trackUsage(action: "listing_created", metadata: [
                    "item_name": analysis.name,
                    "price": String(format: "%.2f", analysis.suggestedPrice),
                    "category": analysis.category,
                    "ai_version": "v2"
                ])
                print("✅ eBay listing created successfully")
            }
            completion(success, errorMessage)
        }
    }
    
    // MARK: - HELPER METHODS
    
    private func updateProgress(_ message: String, progress: Double) {
        DispatchQueue.main.async {
            self.analysisProgress = message
            self.progressValue = progress
        }
    }
    
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        updateProgress("Looking up product by barcode...", progress: 0.1)
        analyzeItem(images, completion: completion)
    }
}

// MARK: - NOTIFICATION EXTENSION
extension Notification.Name {
    static let rateLimitReached = Notification.Name("rateLimitReached")
    static let queueProcessingComplete = Notification.Name("queueProcessingComplete")
}
