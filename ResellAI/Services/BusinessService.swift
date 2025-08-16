//
//  BusinessService.swift
//  ResellAI
//
//  Business Service with AI Analysis and Market Data
//

import SwiftUI
import Foundation
import Vision
import AuthenticationServices
import FirebaseFirestore
import CryptoKit
import SafariServices

// MARK: - BUSINESS SERVICE WITH AI AND MARKET DATA
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
    
    // Market data service
    private let marketDataService = EbayMarketDataService()
    
    // eBay Services
    let ebayService = EbayService()
    private let ebayListingService = EbayListingService()
    
    // Firebase integration
    private weak var firebaseService: FirebaseService?
    private weak var authService: AuthService?
    
    // Queue processing timer
    private var queueTimer: Timer?
    
    init() {
        print("🚀 ResellAI Business Service initialized with AI Analysis and Market Data")
        loadSavedQueue()
    }
    
    func initialize(with firebaseService: FirebaseService? = nil) {
        Configuration.validateConfiguration()
        self.firebaseService = firebaseService
        self.authService = firebaseService?.authService
        ebayService.initialize()
    }
    
    // MARK: - SINGLE ITEM ANALYSIS WITH MARKET DATA
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
            "ai_version": "gpt5_tiered"
        ])
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.progressValue = 0.1
            self.analysisProgress = "Analyzing with AI..."
        }
        
        updateProgress("Starting GPT-5 analysis...", progress: 0.2)
        
        // Step 1: AI Analysis
        aiService.analyzeItemWithMarketIntelligence(images: images) { [weak self] expertResult in
            guard let self = self, let expertResult = expertResult else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    self?.analysisProgress = "Analysis failed"
                    print("❌ AI analysis failed - no result returned")
                }
                completion(nil)
                return
            }
            
            self.updateProgress("Fetching market data...", progress: 0.6)
            
            // Step 2: Fetch Market Data
            let query = self.buildMarketQuery(from: expertResult)
            
            self.marketDataService.fetchSoldListings(
                query: query,
                category: expertResult.attributes.category,
                condition: expertResult.attributes.condition.grade
            ) { marketData in
                self.updateProgress("Calculating optimal pricing...", progress: 0.8)
                
                // Step 3: Combine AI + Market Data
                let finalResult = self.combineAnalysisWithMarketData(
                    expertResult: expertResult,
                    marketData: marketData
                )
                
                DispatchQueue.main.async {
                    self.isAnalyzing = false
                    self.analysisProgress = "Analysis complete"
                    self.progressValue = 1.0
                    
                    print("✅ AI + Market analysis complete: \(expertResult.attributes.name)")
                    print("🤖 Model used: \(expertResult.escalatedToGPT5 ? "GPT-5 Full" : "GPT-5 Mini")")
                    print("📊 Confidence: \(expertResult.confidence)")
                    
                    if let marketData = marketData {
                        print("💰 Market data: \(marketData.soldListings.count) comps found")
                        print("📈 Median price: $\(marketData.medianPrice ?? 0)")
                    } else {
                        print("⚠️ No market data available - using AI estimates")
                    }
                    
                    completion(finalResult)
                }
            }
        }
    }
    
    // MARK: - BUILD MARKET QUERY
    private func buildMarketQuery(from result: ExpertAnalysisResult) -> String {
        var components: [String] = []
        
        // Add brand if available
        if !result.attributes.brand.isEmpty && result.attributes.brand.lowercased() != "unknown" {
            components.append(result.attributes.brand)
        }
        
        // Add model if available
        if let model = result.attributes.model, !model.isEmpty {
            components.append(model)
        } else {
            // Use name if no specific model
            components.append(result.attributes.name)
        }
        
        // Add key identifiers
        if let styleCode = result.attributes.identifiers.styleCode {
            components.append(styleCode)
        }
        
        // Add size for footwear/apparel
        if let size = result.attributes.size {
            components.append("size \(size)")
        }
        
        // Add color if distinctive
        if let color = result.attributes.color,
           !["black", "white", "grey", "gray"].contains(color.lowercased()) {
            components.append(color)
        }
        
        // Build the query
        let query = components.joined(separator: " ")
        print("🔍 Market query: \(query)")
        return query
    }
    
    // MARK: - COMBINE ANALYSIS WITH MARKET DATA
    private func combineAnalysisWithMarketData(
        expertResult: ExpertAnalysisResult,
        marketData: MarketDataResult?
    ) -> AnalysisResult {
        
        // If we have market data, use it to refine pricing
        if let marketData = marketData, !marketData.soldListings.isEmpty {
            let tiers = marketData.priceTiers()
            
            // Create refined pricing based on real data
            let quickPrice = min(tiers.quickSell, expertResult.suggestedPrice.quickSale)
            let marketPrice = tiers.market
            let premiumPrice = max(tiers.premium, expertResult.suggestedPrice.premium)
            
            // Build enhanced description with market insights
            let enhancedDescription = buildEnhancedDescription(
                expertResult.listingContent.description,
                marketData: marketData,
                confidence: expertResult.confidence
            )
            
            return AnalysisResult(
                name: expertResult.attributes.name,
                brand: expertResult.attributes.brand,
                category: expertResult.attributes.category,
                condition: expertResult.attributes.condition.grade,
                title: expertResult.listingContent.title,
                description: enhancedDescription,
                keywords: expertResult.listingContent.keywords,
                suggestedPrice: marketPrice,
                quickPrice: quickPrice,
                premiumPrice: premiumPrice,
                averagePrice: marketData.averagePrice,
                marketConfidence: expertResult.confidence,
                soldListingsCount: marketData.soldListings.count,
                competitorCount: expertResult.marketAnalysis?.competitorCount,
                demandLevel: expertResult.marketAnalysis?.demandLevel,
                listingStrategy: "Data-driven pricing based on \(marketData.soldListings.count) recent sales",
                sourcingTips: generateSourcingTips(expertResult: expertResult, marketData: marketData),
                aiConfidence: expertResult.confidence,
                resalePotential: calculateResalePotential(marketPrice: marketPrice),
                priceRange: marketData.priceRange.map { EbayPriceRange(low: $0.min, high: $0.max, average: marketData.averagePrice ?? marketPrice) },
                recentSales: marketData.soldListings.prefix(5).map { listing in
                    RecentSale(
                        title: listing.title,
                        price: listing.price,
                        condition: listing.condition,
                        date: listing.soldDate
                    )
                },
                exactModel: expertResult.attributes.model,
                styleCode: expertResult.attributes.identifiers.styleCode,
                size: expertResult.attributes.size,
                colorway: expertResult.attributes.color,
                releaseYear: expertResult.attributes.yearReleased,
                subcategory: expertResult.attributes.category
            )
        } else {
            // No market data - use AI estimates only
            return expertResult.toAnalysisResult()
        }
    }
    
    // MARK: - HELPER METHODS
    
    private func buildEnhancedDescription(_ original: String, marketData: MarketDataResult, confidence: Double) -> String {
        var enhanced = original
        
        if marketData.isEstimate {
            enhanced += "\n\n📊 Market Analysis: Based on current listings (estimated sold prices)"
        } else {
            enhanced += "\n\n📊 Market Analysis: Based on \(marketData.soldListings.count) recent sales"
        }
        
        if let range = marketData.priceRange {
            enhanced += "\n• Recent sales range: $\(Int(range.min)) - $\(Int(range.max))"
        }
        
        if let median = marketData.medianPrice {
            enhanced += "\n• Median sold price: $\(Int(median))"
        }
        
        if confidence > 0.9 {
            enhanced += "\n• High confidence identification (AI: \(Int(confidence * 100))%)"
        }
        
        return enhanced
    }
    
    private func generateSourcingTips(expertResult: ExpertAnalysisResult, marketData: MarketDataResult?) -> [String] {
        var tips: [String] = []
        
        // Price-based tips
        if let median = marketData?.medianPrice {
            if median > 100 {
                tips.append("High-value item - ensure authenticity before listing")
            }
            
            if median > 50 {
                tips.append("Source for under $\(Int(median * 0.3)) for good margins")
            }
        }
        
        // Demand-based tips
        if let demandLevel = expertResult.marketAnalysis?.demandLevel {
            switch demandLevel {
            case "High":
                tips.append("High demand - sells quickly at market price")
            case "Low":
                tips.append("Lower demand - price competitively for faster sale")
            default:
                break
            }
        }
        
        // Brand-based tips
        if Configuration.luxuryBrands.contains(where: { $0.lowercased() == expertResult.attributes.brand.lowercased() }) {
            tips.append("Luxury brand - verify authenticity and include proof")
        }
        
        if Configuration.hypeBrands.contains(where: { $0.lowercased() == expertResult.attributes.brand.lowercased() }) {
            tips.append("Hype brand - highlight exclusivity and condition")
        }
        
        return tips
    }
    
    private func calculateResalePotential(marketPrice: Double) -> Int {
        if marketPrice > 200 { return 10 }
        if marketPrice > 100 { return 8 }
        if marketPrice > 50 { return 6 }
        if marketPrice > 25 { return 4 }
        return 2
    }
    
    // MARK: - QUEUE PROCESSING (Kept from original)
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
        
        print("🧠 Processing queue item \(nextItem.position) with AI + Market Data")
        
        // Analyze the item using AI + Market Data
        analyzeQueueItem(nextItem)
    }
    
    private func analyzeQueueItem(_ item: QueuedItem) {
        let photos = item.uiImages
        
        guard !photos.isEmpty else {
            processQueueItemComplete(item.id, result: nil, error: "No photos provided")
            return
        }
        
        // Use the enhanced analyzeItem method that includes market data
        analyzeItem(photos) { [weak self] result in
            self?.processQueueItemComplete(item.id, result: result, error: result == nil ? "Analysis failed" : nil)
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
        print("📱 Would send notification: \(completedCount) items analyzed with AI + Market Data")
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
        print("• Using AI analysis + Market data")
        
        ebayListingService.createListing(analysis: analysis, images: images, accessToken: accessToken) { [weak self] success, errorMessage in
            if success {
                authService.trackUsage(action: "listing_created", metadata: [
                    "item_name": analysis.name,
                    "price": String(format: "%.2f", analysis.suggestedPrice),
                    "category": analysis.category,
                    "ai_version": "gpt5_tiered",
                    "market_data": analysis.soldListingsCount != nil ? "yes" : "no"
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
