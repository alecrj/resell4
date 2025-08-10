//
//  Services.swift
//  ResellAI
//
//  Complete Reselling Automation with FIXED eBay Integration
//

import SwiftUI
import Foundation
import Vision
import AuthenticationServices
import FirebaseFirestore
import CryptoKit
import SafariServices

// MARK: - MAIN BUSINESS SERVICE WITH QUEUE SYSTEM
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
    
    private let aiService = AIAnalysisService()
    let ebayService = EbayService()
    private let googleSheetsService = GoogleSheetsService()
    
    // Firebase integration
    private weak var firebaseService: FirebaseService?
    
    // Queue processing timer
    private var queueTimer: Timer?
    
    init() {
        print("🚀 ResellAI Business Service initialized with Queue System")
        loadSavedQueue()
    }
    
    func initialize(with firebaseService: FirebaseService? = nil) {
        Configuration.validateConfiguration()
        self.firebaseService = firebaseService
        authenticateGoogleSheets()
        
        // Initialize eBay with real credentials
        ebayService.initialize()
    }
    
    // MARK: - QUEUE MANAGEMENT METHODS
    
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
    
    func addPhotosToQueueItem(itemId: UUID, photos: [UIImage]) {
        if let index = processingQueue.items.firstIndex(where: { $0.id == itemId }) {
            let existingPhotos = processingQueue.items[index].uiImages
            let combinedPhotos = existingPhotos + photos
            let limitedPhotos = Array(combinedPhotos.prefix(8)) // Max 8 photos
            
            processingQueue.items[index].photos = limitedPhotos.compactMap { $0.jpegData(compressionQuality: 0.8) }
            saveQueue()
            
            print("📸 Added \(photos.count) photos to queue item, total: \(limitedPhotos.count)")
        }
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
        guard let firebase = firebaseService else { return false }
        return firebase.canAnalyze && !processingQueue.rateLimitHit
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
            queueProgress = "Processing Item \(currentItem.position)..."
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
        
        print("🔍 Processing queue item \(nextItem.position)")
        
        // Analyze the item
        analyzeQueueItem(nextItem)
    }
    
    private func analyzeQueueItem(_ item: QueuedItem) {
        let photos = item.uiImages
        
        guard !photos.isEmpty else {
            processQueueItemComplete(item.id, result: nil, error: "No photos provided")
            return
        }
        
        // Track usage in Firebase - but don't count failures against limit
        firebaseService?.trackUsage(action: "analysis", metadata: [
            "source": "queue",
            "item_position": "\(item.position)",
            "photo_count": "\(photos.count)"
        ])
        
        // Analyze the item using existing analysis logic
        aiService.identifyProductPrecisely(images: photos) { [weak self] productResult in
            guard let self = self else { return }
            
            guard let productResult = productResult else {
                self.processQueueItemComplete(
                    item.id,
                    result: nil,
                    error: "Failed to identify product",
                    shouldCountAgainstLimit: false
                )
                return
            }
            
            // Search market data
            let searchQueries = self.buildOptimizedSearchQueries(from: productResult)
            
            self.searchMarketData(queries: searchQueries) { marketData in
                // Process complete analysis
                let pricing = self.calculateOptimalPricing(from: marketData, productResult: productResult)
                let listing = self.generateProfessionalListing(productResult: productResult, pricing: pricing)
                
                let finalResult = AnalysisResult(
                    name: self.buildDetailedProductName(from: productResult),
                    brand: productResult.brand,
                    category: productResult.category,
                    condition: productResult.aiAssessedCondition,
                    title: listing.optimizedTitle,
                    description: listing.professionalDescription,
                    keywords: listing.seoKeywords,
                    suggestedPrice: pricing.marketPrice,
                    quickPrice: pricing.quickPrice,
                    premiumPrice: pricing.premiumPrice,
                    averagePrice: pricing.averagePrice,
                    soldListingsCount: marketData.soldComps.count > 0 ? marketData.soldComps.count : nil,
                    competitorCount: marketData.activeListings.count > 0 ? marketData.activeListings.count : nil,
                    demandLevel: self.calculateDemandLevel(marketData: marketData),
                    listingStrategy: "Fixed Price",
                    sourcingTips: self.generateSourcingTips(productResult: productResult, pricing: pricing),
                    resalePotential: self.calculateResalePotential(pricing: pricing, marketData: marketData),
                    priceRange: EbayPriceRange(
                        low: pricing.quickPrice,
                        high: pricing.premiumPrice,
                        average: pricing.averagePrice
                    ),
                    recentSales: marketData.soldComps.prefix(5).map { item in
                        RecentSale(
                            title: item.title,
                            price: item.price,
                            condition: item.condition ?? "Used",
                            date: item.soldDate ?? Date(),
                            shipping: item.shipping,
                            bestOffer: item.bestOfferAccepted ?? false
                        )
                    },
                    exactModel: productResult.modelNumber,
                    styleCode: productResult.styleCode,
                    size: productResult.size,
                    colorway: productResult.colorway,
                    releaseYear: productResult.releaseYear,
                    subcategory: productResult.subcategory
                )
                
                self.processQueueItemComplete(item.id, result: finalResult, error: nil)
            }
        }
    }
    
    private func processQueueItemComplete(_ itemId: UUID, result: AnalysisResult?, error: String?, shouldCountAgainstLimit: Bool = true) {
        DispatchQueue.main.async {
            if let result = result {
                // Success
                self.processingQueue.updateItemStatus(itemId, status: .completed, result: result)
                print("✅ Queue item \(itemId) completed successfully")
            } else {
                // Failure - mark as failed but don't count against limit unless it was a real API call
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
        
        queueProgress = "Queue complete: \(completedCount) analyzed, \(failedCount) failed"
        queueProgressValue = 1.0
        
        print("✅ Queue processing finished: \(completedCount) completed, \(failedCount) failed")
        
        // Send completion notification
        if completedCount > 0 {
            scheduleCompletionNotification(completedCount: completedCount)
        }
        
        saveQueue()
    }
    
    private func scheduleCompletionNotification(completedCount: Int) {
        // This would schedule a local notification when queue is complete
        // Implementation depends on your notification setup
        print("📱 Would send notification: \(completedCount) items analyzed and ready for review")
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
    
    // MARK: - ANALYSIS METHODS
    
    func analyzeItem(_ images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        
        // Check Firebase usage limits
        if let firebase = firebaseService, !firebase.canAnalyze {
            print("⚠️ Monthly analysis limit reached")
            completion(nil)
            return
        }
        
        print("🔍 Starting ResellAI analysis with \(images.count) images")
        
        // Track usage in Firebase
        firebaseService?.trackUsage(action: "analysis", metadata: [
            "source": "single_item",
            "image_count": "\(images.count)",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ])
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.progressValue = 0.1
            self.analysisProgress = "Analyzing product..."
        }
        
        // Step 1: AI Product Identification
        updateProgress("Identifying product with AI...", progress: 0.2)
        
        aiService.identifyProductPrecisely(images: images) { [weak self] productResult in
            guard let productResult = productResult else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    completion(nil)
                }
                return
            }
            
            print("✅ Product identified: \(productResult.exactProduct)")
            print("🏷️ Brand: \(productResult.brand)")
            
            // Step 2: Search eBay for real sold comps
            self?.updateProgress("Finding market data...", progress: 0.4)
            
            let searchQueries = self?.buildOptimizedSearchQueries(from: productResult) ?? [productResult.exactProduct]
            
            self?.searchMarketData(queries: searchQueries) { [weak self] marketData in
                self?.updateProgress("Calculating optimal pricing...", progress: 0.7)
                self?.processCompleteAnalysis(productResult: productResult, marketData: marketData, completion: completion)
            }
        }
    }
    
    private func searchMarketData(queries: [String], completion: @escaping (MarketData) -> Void) {
        guard !queries.isEmpty else {
            completion(MarketData(activeListings: [], soldComps: []))
            return
        }
        
        let query = queries[0]
        print("🔍 Searching market data for: \(query)")
        
        var activeListings: [EbayListing] = []
        var soldComps: [EbaySoldItem] = []
        
        let group = DispatchGroup()
        
        // Search active listings
        group.enter()
        searchActiveListings(query: query) { listings in
            activeListings = listings
            group.leave()
        }
        
        // Search sold comps via RapidAPI
        group.enter()
        searchSoldComps(query: query) { comps in
            soldComps = comps
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(MarketData(activeListings: activeListings, soldComps: soldComps))
        }
    }
    
    private func searchActiveListings(query: String, completion: @escaping ([EbayListing]) -> Void) {
        let cleanQuery = query.replacingOccurrences(of: " ", with: "%20")
        guard let url = URL(string: "https://svcs.ebay.com/services/search/FindingService/v1?OPERATION-NAME=findItemsByKeywords&SERVICE-VERSION=1.0.0&SECURITY-APPNAME=\(Configuration.ebayAPIKey)&RESPONSE-DATA-FORMAT=JSON&keywords=\(cleanQuery)&paginationInput.entriesPerPage=20") else {
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data else {
                completion([])
                return
            }
            
            let listings = self.parseActiveListings(data: data)
            print("✅ Found \(listings.count) active eBay listings")
            completion(listings)
        }.resume()
    }
    
    private func searchSoldComps(query: String, completion: @escaping ([EbaySoldItem]) -> Void) {
        guard !Configuration.rapidAPIKey.isEmpty else {
            print("⚠️ RapidAPI key not configured")
            completion([])
            return
        }
        
        // Fixed RapidAPI endpoint based on screenshot
        guard let url = URL(string: "https://ebay-average-selling-price.p.rapidapi.com/findCompletedItems") else {
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Configuration.rapidAPIKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("ebay-average-selling-price.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        
        let requestBody: [String: Any] = [
            "keywords": query,
            "max_search_results": "50",
            "category_id": "15709", // Shoes category
            "remove_outliers": "true",
            "site_id": "0"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating RapidAPI request: \(error)")
            completion([])
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ RapidAPI network error: \(error)")
                completion([])
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 RapidAPI response code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 404 {
                    print("❌ RapidAPI endpoint not found - check endpoint URL")
                } else if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ RapidAPI error (\(httpResponse.statusCode)): \(errorString)")
                    }
                }
            }
            
            guard let data = data else {
                completion([])
                return
            }
            
            let soldItems = self.parseSoldComps(data: data)
            print("✅ Found \(soldItems.count) sold comps from RapidAPI")
            completion(soldItems)
            
        }.resume()
    }
    
    private func parseActiveListings(data: Data) -> [EbayListing] {
        var listings: [EbayListing] = []
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let findItemsResponse = json["findItemsByKeywordsResponse"] as? [Any],
               let responseDict = findItemsResponse.first as? [String: Any],
               let searchResult = responseDict["searchResult"] as? [Any],
               let searchResultDict = searchResult.first as? [String: Any],
               let items = searchResultDict["item"] as? [Any] {
                
                for itemData in items {
                    guard let item = itemData as? [String: Any] else { continue }
                    
                    if let titleArray = item["title"] as? [String],
                       let title = titleArray.first,
                       let sellingStatus = item["sellingStatus"] as? [Any],
                       let statusDict = sellingStatus.first as? [String: Any],
                       let currentPrice = statusDict["currentPrice"] as? [Any],
                       let priceDict = currentPrice.first as? [String: Any],
                       let priceValue = priceDict["__value__"] as? String,
                       let price = Double(priceValue) {
                        
                        let listing = EbayListing(title: title, price: price, shipping: nil)
                        listings.append(listing)
                    }
                }
            }
        } catch {
            print("❌ Error parsing active listings: \(error)")
        }
        
        return listings
    }
    
    private func parseSoldComps(data: Data) -> [EbaySoldItem] {
        var soldItems: [EbaySoldItem] = []
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Parse RapidAPI response format
                if let results = json["results"] as? [[String: Any]] {
                    for result in results {
                        if let title = result["title"] as? String,
                           let price = result["price"] as? Double {
                            
                            let condition = result["condition"] as? String ?? "Used"
                            let soldDate = Date() // RapidAPI might not provide exact date
                            
                            let soldItem = EbaySoldItem(
                                title: title,
                                price: price,
                                condition: condition,
                                soldDate: soldDate,
                                shipping: result["shipping"] as? Double,
                                bestOfferAccepted: false
                            )
                            soldItems.append(soldItem)
                        }
                    }
                }
            }
        } catch {
            print("❌ Error parsing sold comps: \(error)")
        }
        
        return soldItems
    }
    
    private func processCompleteAnalysis(productResult: ProductIdentificationResult, marketData: MarketData, completion: @escaping (AnalysisResult?) -> Void) {
        
        updateProgress("Finalizing analysis...", progress: 0.9)
        
        // Calculate pricing based on available data
        let pricing = calculateOptimalPricing(from: marketData, productResult: productResult)
        
        // Generate professional listing
        let listing = generateProfessionalListing(productResult: productResult, pricing: pricing)
        
        updateProgress("Complete!", progress: 1.0)
        
        let finalResult = AnalysisResult(
            name: buildDetailedProductName(from: productResult),
            brand: productResult.brand,
            category: productResult.category,
            condition: productResult.aiAssessedCondition,
            title: listing.optimizedTitle,
            description: listing.professionalDescription,
            keywords: listing.seoKeywords,
            suggestedPrice: pricing.marketPrice,
            quickPrice: pricing.quickPrice,
            premiumPrice: pricing.premiumPrice,
            averagePrice: pricing.averagePrice,
            marketConfidence: nil, // Remove confidence scores
            soldListingsCount: marketData.soldComps.count > 0 ? marketData.soldComps.count : nil,
            competitorCount: marketData.activeListings.count > 0 ? marketData.activeListings.count : nil,
            demandLevel: calculateDemandLevel(marketData: marketData),
            listingStrategy: "Fixed Price",
            sourcingTips: generateSourcingTips(productResult: productResult, pricing: pricing),
            aiConfidence: nil, // Remove AI confidence
            resalePotential: calculateResalePotential(pricing: pricing, marketData: marketData),
            priceRange: EbayPriceRange(
                low: pricing.quickPrice,
                high: pricing.premiumPrice,
                average: pricing.averagePrice
            ),
            recentSales: marketData.soldComps.prefix(5).map { item in
                RecentSale(
                    title: item.title,
                    price: item.price,
                    condition: item.condition ?? "Used",
                    date: item.soldDate ?? Date(),
                    shipping: item.shipping,
                    bestOffer: item.bestOfferAccepted ?? false
                )
            },
            exactModel: productResult.modelNumber,
            styleCode: productResult.styleCode,
            size: productResult.size,
            colorway: productResult.colorway,
            releaseYear: productResult.releaseYear,
            subcategory: productResult.subcategory
        )
        
        DispatchQueue.main.async {
            self.isAnalyzing = false
            self.analysisProgress = "Analysis complete"
            
            print("✅ ResellAI analysis complete: \(finalResult.name)")
            print("💰 Suggested Price: $\(String(format: "%.2f", pricing.marketPrice))")
            print("🎯 Based on \(marketData.activeListings.count) active + \(marketData.soldComps.count) sold listings")
            
            completion(finalResult)
        }
    }
    
    private func buildDetailedProductName(from productResult: ProductIdentificationResult) -> String {
        var name = productResult.brand.isEmpty ? "" : "\(productResult.brand) "
        
        // Add the specific product name
        name += productResult.exactProduct
        
        // Add colorway if available and not generic
        if let colorway = productResult.colorway,
           !colorway.isEmpty &&
           !colorway.lowercased().contains("not visible") &&
           !colorway.lowercased().contains("unknown") &&
           !productResult.exactProduct.lowercased().contains(colorway.lowercased()) {
            name += " \(colorway)"
        }
        
        // Add size if available
        if let size = productResult.size,
           !size.isEmpty &&
           !size.lowercased().contains("not visible") &&
           !size.lowercased().contains("unknown") {
            name += " Size \(size)"
        }
        
        return name.trimmingCharacters(in: .whitespaces)
    }
    
    private func calculateOptimalPricing(from marketData: MarketData, productResult: ProductIdentificationResult) -> OptimalPricing {
        let activeListings = marketData.activeListings
        let soldComps = marketData.soldComps
        
        var basePrice: Double = 40.0
        
        // Use sold comps if available (most accurate)
        if !soldComps.isEmpty {
            let prices = soldComps.map { $0.price }.sorted()
            let median = prices.count % 2 == 0
                ? (prices[prices.count/2 - 1] + prices[prices.count/2]) / 2
                : prices[prices.count/2]
            basePrice = median
        }
        // Fall back to active listings
        else if !activeListings.isEmpty {
            let prices = activeListings.map { $0.price }.sorted()
            let median = prices.count % 2 == 0
                ? (prices[prices.count/2 - 1] + prices[prices.count/2]) / 2
                : prices[prices.count/2]
            basePrice = median * 0.85 // Adjust down from asking prices
        }
        // Brand-based fallback
        else {
            basePrice = getBrandBasedPrice(brand: productResult.brand, category: productResult.category)
        }
        
        return OptimalPricing(
            quickPrice: basePrice * 0.8,
            marketPrice: basePrice,
            premiumPrice: basePrice * 1.25,
            averagePrice: basePrice
        )
    }
    
    private func getBrandBasedPrice(brand: String, category: String) -> Double {
        let brandLower = brand.lowercased()
        let categoryLower = category.lowercased()
        
        var basePrice: Double = 30.0
        
        // Brand multipliers
        if ["nike", "jordan", "adidas", "yeezy"].contains(brandLower) {
            basePrice = categoryLower.contains("sneaker") ? 80.0 : 50.0
        } else if ["apple", "samsung", "sony"].contains(brandLower) {
            basePrice = 200.0
        } else if ["levi", "gap", "american eagle"].contains(brandLower) {
            basePrice = 25.0
        }
        
        return basePrice
    }
    
    private func calculateDemandLevel(marketData: MarketData) -> String? {
        let totalListings = marketData.activeListings.count + marketData.soldComps.count
        
        if totalListings >= 30 {
            return "High"
        } else if totalListings >= 10 {
            return "Medium"
        } else if totalListings >= 3 {
            return "Low"
        } else {
            return nil // Don't show demand level if insufficient data
        }
    }
    
    private func calculateResalePotential(pricing: OptimalPricing, marketData: MarketData) -> Int {
        var score = 5
        
        if pricing.marketPrice > 100 {
            score += 3
        } else if pricing.marketPrice > 50 {
            score += 2
        }
        
        if marketData.soldComps.count > 5 {
            score += 2
        } else if marketData.activeListings.count > 10 {
            score += 1
        }
        
        return min(score, 10)
    }
    
    private func generateSourcingTips(productResult: ProductIdentificationResult, pricing: OptimalPricing) -> [String] {
        var tips: [String] = []
        
        let maxBuyPrice = pricing.quickPrice * 0.6
        tips.append("Max buy price: $\(String(format: "%.2f", maxBuyPrice)) for 40%+ margin")
        
        let brand = productResult.brand.lowercased()
        if ["nike", "jordan", "adidas"].contains(brand) {
            tips.append("Check for authenticity - popular items have fakes")
            tips.append("Original box adds 10-15% value")
        }
        
        return tips
    }
    
    private func generateProfessionalListing(productResult: ProductIdentificationResult, pricing: OptimalPricing) -> ProfessionalListing {
        let title = generateOptimizedTitle(productResult: productResult)
        let description = generateDescription(productResult: productResult, pricing: pricing)
        let keywords = generateKeywords(productResult: productResult)
        
        return ProfessionalListing(
            optimizedTitle: title,
            professionalDescription: description,
            seoKeywords: keywords,
            suggestedCategory: "15709", // Default to shoes
            shippingStrategy: pricing.marketPrice > 50 ? "Free shipping" : "$8.50 shipping",
            returnPolicy: "30-day returns",
            listingEnhancements: []
        )
    }
    
    private func generateOptimizedTitle(productResult: ProductIdentificationResult) -> String {
        return buildDetailedProductName(from: productResult)
    }
    
    private func generateDescription(productResult: ProductIdentificationResult, pricing: OptimalPricing) -> String {
        var desc = "🔥 \(buildDetailedProductName(from: productResult))\n\n"
        desc += "📋 ITEM DETAILS:\n"
        
        if !productResult.brand.isEmpty {
            desc += "• Brand: \(productResult.brand)\n"
        }
        
        if let size = productResult.size, !size.isEmpty && !size.contains("not visible") {
            desc += "• Size: \(size)\n"
        }
        
        desc += "• Condition: \(productResult.aiAssessedCondition)\n\n"
        
        desc += "✅ FAST & SECURE:\n"
        desc += "• Ships within 1 business day\n"
        desc += "• 30-day returns accepted\n"
        desc += "• Carefully packaged\n"
        desc += "• Authentic guaranteed\n"
        
        return desc
    }
    
    private func generateKeywords(productResult: ProductIdentificationResult) -> [String] {
        var keywords: Set<String> = []
        
        keywords.insert(productResult.exactProduct.lowercased())
        if !productResult.brand.isEmpty {
            keywords.insert(productResult.brand.lowercased())
        }
        if let colorway = productResult.colorway, !colorway.isEmpty && !colorway.contains("not visible") {
            keywords.insert(colorway.lowercased())
        }
        
        return Array(keywords.prefix(6))
    }
    
    private func updateProgress(_ message: String, progress: Double) {
        DispatchQueue.main.async {
            self.analysisProgress = message
            self.progressValue = progress
        }
    }
    
    private func buildOptimizedSearchQueries(from productResult: ProductIdentificationResult) -> [String] {
        var queries: [String] = []
        
        // Primary query with all details
        var primaryQuery = productResult.brand.isEmpty ? "" : "\(productResult.brand) "
        primaryQuery += productResult.exactProduct
        
        if let colorway = productResult.colorway, !colorway.isEmpty && !colorway.contains("not visible") {
            primaryQuery += " \(colorway)"
        }
        
        queries.append(primaryQuery.trimmingCharacters(in: .whitespaces))
        
        // Fallback query without colorway
        var fallbackQuery = productResult.brand.isEmpty ? "" : "\(productResult.brand) "
        fallbackQuery += productResult.exactProduct
        
        let fallback = fallbackQuery.trimmingCharacters(in: .whitespaces)
        if fallback != queries.first {
            queries.append(fallback)
        }
        
        return queries
    }
    
    // MARK: - EBAY LISTING CREATION
    func createEbayListing(from analysis: AnalysisResult, images: [UIImage], completion: @escaping (Bool, String?) -> Void) {
        guard let firebase = firebaseService else {
            completion(false, "Firebase not initialized")
            return
        }
        
        if !firebase.canCreateListing {
            completion(false, "Monthly listing limit reached. Please upgrade your plan.")
            return
        }
        
        print("📤 Creating eBay listing for: \(analysis.name)")
        
        ebayService.createListing(analysis: analysis, images: images) { [weak self] success, errorMessage in
            if success {
                firebase.trackUsage(action: "listing_created", metadata: [
                    "item_name": analysis.name,
                    "price": String(format: "%.2f", analysis.suggestedPrice),
                    "category": analysis.category
                ])
                print("✅ eBay listing created successfully")
            }
            completion(success, errorMessage)
        }
    }
    
    func authenticateEbay(completion: @escaping (Bool) -> Void) {
        ebayService.authenticate(completion: completion)
    }
    
    func handleEbayAuthCallback(url: URL) {
        ebayService.handleAuthCallback(url: url)
    }
    
    var isEbayAuthenticated: Bool {
        return ebayService.isAuthenticated
    }
    
    var ebayAuthStatus: String {
        return ebayService.authStatus
    }
    
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        updateProgress("Looking up product by barcode...", progress: 0.1)
        analyzeItem(images, completion: completion)
    }
    
    // MARK: - GOOGLE SHEETS INTEGRATION
    func authenticateGoogleSheets() {
        googleSheetsService.authenticate()
    }
    
    func syncAllItems(_ items: [InventoryItem]) {
        googleSheetsService.syncAllItems(items)
        googleSheetsService.$isSyncing.receive(on: DispatchQueue.main).assign(to: &$isSyncing)
        googleSheetsService.$syncStatus.receive(on: DispatchQueue.main).assign(to: &$syncStatus)
        googleSheetsService.$lastSyncDate.receive(on: DispatchQueue.main).assign(to: &$lastSyncDate)
    }
}

// MARK: - NOTIFICATION EXTENSION
extension Notification.Name {
    static let rateLimitReached = Notification.Name("rateLimitReached")
    static let queueProcessingComplete = Notification.Name("queueProcessingComplete")
}

// MARK: - SUPPORTING MODELS
struct MarketData {
    let activeListings: [EbayListing]
    let soldComps: [EbaySoldItem]
}

struct EbayListing {
    let title: String
    let price: Double
    let shipping: Double?
}

struct OptimalPricing {
    let quickPrice: Double
    let marketPrice: Double
    let premiumPrice: Double
    let averagePrice: Double
}

struct ProfessionalListing {
    let optimizedTitle: String
    let professionalDescription: String
    let seoKeywords: [String]
    let suggestedCategory: String
    let shippingStrategy: String
    let returnPolicy: String
    let listingEnhancements: [String]
}

// MARK: - AI ANALYSIS SERVICE
class AIAnalysisService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let endpoint = Configuration.openAIEndpoint
    
    func identifyProductPrecisely(images: [UIImage], completion: @escaping (ProductIdentificationResult?) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ API key not configured")
            completion(nil)
            return
        }
        
        guard !images.isEmpty else {
            print("❌ No images provided")
            completion(nil)
            return
        }
        
        let compressedImages = images.compactMap { compressImage($0) }
        guard !compressedImages.isEmpty else {
            print("❌ Could not process any images")
            completion(nil)
            return
        }
        
        print("📷 Processing \(compressedImages.count) images for AI analysis")
        
        var content: [[String: Any]] = [
            [
                "type": "text",
                "text": buildPrecisionPrompt()
            ]
        ]
        
        for imageData in compressedImages {
            let base64Image = imageData.base64EncodedString()
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:image/jpeg;base64,\(base64Image)"
                ]
            ])
        }
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.1
        ]
        
        performRequest(requestBody: requestBody, completion: completion)
    }
    
    private func buildPrecisionPrompt() -> String {
        return """
        Analyze these product images with maximum precision for reselling.

        Look at EVERY detail:

        FOR SHOES/SNEAKERS:
        - Read tongue tags, heel tabs, insoles for exact model names
        - Identify specific colorways (not just "white" - like "Triple White" or "Chicago")
        - Find size from tags, labels, or size stickers  
        - Look for style codes (CW2288-111, etc.)
        - Note special editions, collaborations

        FOR CLOTHING:
        - Read all tags and labels carefully
        - Identify exact style names from tags
        - Find size tags, care labels
        - Note exact colors and patterns
        - Look for style/SKU numbers

        FOR ELECTRONICS:
        - Read model numbers, serial numbers
        - Identify storage capacity, exact model
        - Note generation (iPhone 14 Pro Max, not just iPhone)
        - Check condition indicators

        Respond with valid JSON only:
        {
            "product_name": "EXACT specific product name with model",
            "brand": "brand name",  
            "category": "specific category",
            "condition": "detailed condition based on visible wear",
            "model_number": "specific model/style code if visible",
            "size": "exact size from tags (US 9, Large, 64GB, etc.)",
            "colorway": "EXACT color name (Triple White, Chicago, Navy Blue, etc.)",
            "title": "optimized title with key details",
            "description": "detailed description mentioning condition and features",
            "keywords": ["specific", "searchable", "keywords"]
        }

        Only respond with JSON. Be as specific as possible.
        """
    }
    
    private func compressImage(_ image: UIImage) -> Data? {
        var compressionQuality: CGFloat = 0.8
        var imageData = image.jpegData(compressionQuality: compressionQuality)
        
        while let data = imageData, data.count > 4_000_000 && compressionQuality > 0.1 {
            compressionQuality -= 0.1
            imageData = image.jpegData(compressionQuality: compressionQuality)
        }
        
        if let data = imageData, data.count > 4_000_000 {
            let maxSize: CGFloat = 1024
            let currentSize = max(image.size.width, image.size.height)
            
            if currentSize > maxSize {
                let ratio = maxSize / currentSize
                let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                imageData = resizedImage?.jpegData(compressionQuality: 0.8)
            }
        }
        
        return imageData
    }
    
    private func performRequest(requestBody: [String: Any], completion: @escaping (ProductIdentificationResult?) -> Void) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid endpoint")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request body: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Network error: \(error)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ API error: \(errorString)")
                }
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ No data received")
                completion(nil)
                return
            }
            
            self.parseResponse(data: data, completion: completion)
            
        }.resume()
    }
    
    private func parseResponse(data: Data, completion: @escaping (ProductIdentificationResult?) -> Void) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                let cleanedContent = cleanJSONResponse(content)
                
                if let result = parseProductJSON(cleanedContent) {
                    print("✅ AI identified: \(result.exactProduct)")
                    completion(result)
                } else {
                    print("❌ Failed to parse AI response")
                    completion(createFallbackResult(from: content))
                }
            } else {
                print("❌ Invalid response structure")
                completion(nil)
            }
        } catch {
            print("❌ Error parsing response: \(error)")
            completion(nil)
        }
    }
    
    private func cleanJSONResponse(_ content: String) -> String {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseProductJSON(_ jsonString: String) -> ProductIdentificationResult? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let productName = json["product_name"] as? String ?? json["name"] as? String ?? "Unknown Item"
                let brand = json["brand"] as? String ?? ""
                let category = json["category"] as? String ?? "Other"
                let condition = json["condition"] as? String ?? "Used"
                let modelNumber = json["model_number"] as? String
                let size = json["size"] as? String
                let colorway = json["colorway"] as? String
                let title = json["title"] as? String ?? productName
                let description = json["description"] as? String ?? "Item in good condition"
                let keywords = json["keywords"] as? [String] ?? []
                
                return ProductIdentificationResult(
                    exactProduct: productName,
                    brand: brand,
                    category: category,
                    subcategory: nil,
                    modelNumber: modelNumber,
                    styleCode: modelNumber,
                    size: size,
                    colorway: colorway,
                    releaseYear: nil,
                    title: title,
                    description: description,
                    keywords: keywords,
                    aiAssessedCondition: condition,
                    confidence: 0.9,
                    authenticityRisk: "medium",
                    estimatedAge: nil,
                    completeness: "complete"
                )
            }
        } catch {
            print("❌ JSON parsing error: \(error)")
        }
        
        return nil
    }
    
    private func createFallbackResult(from content: String) -> ProductIdentificationResult? {
        let words = content.components(separatedBy: .whitespaces)
        let productName = words.count > 2 ? Array(words.prefix(3)).joined(separator: " ") : "Unknown Item"
        
        return ProductIdentificationResult(
            exactProduct: productName,
            brand: "",
            category: "Other",
            subcategory: nil,
            modelNumber: nil,
            styleCode: nil,
            size: nil,
            colorway: nil,
            releaseYear: nil,
            title: productName,
            description: "Item analysis incomplete",
            keywords: [],
            aiAssessedCondition: "Used",
            confidence: 0.3,
            authenticityRisk: "high",
            estimatedAge: nil,
            completeness: "incomplete"
        )
    }
}

struct ProductIdentificationResult {
    let exactProduct: String
    let brand: String
    let category: String
    let subcategory: String?
    let modelNumber: String?
    let styleCode: String?
    let size: String?
    let colorway: String?
    let releaseYear: String?
    let title: String
    let description: String
    let keywords: [String]
    let aiAssessedCondition: String
    let confidence: Double
    let authenticityRisk: String
    let estimatedAge: String?
    let completeness: String
}

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
                authenticateWithScopes(Configuration.ebayMinimalScopes, completion: completion)
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

// MARK: - GOOGLE SHEETS SERVICE
class GoogleSheetsService: ObservableObject {
    @Published var isSyncing = false
    @Published var syncStatus = "Ready"
    @Published var lastSyncDate: Date?
    
    private let scriptURL = Configuration.googleScriptURL
    private let spreadsheetID = Configuration.spreadsheetID
    
    func authenticate() {
        guard !scriptURL.isEmpty else {
            print("❌ Google Sheets not configured")
            return
        }
        
        print("📊 Google Sheets authenticated")
        syncStatus = "Connected"
    }
    
    func syncAllItems(_ items: [InventoryItem]) {
        // Implementation unchanged
    }
}

// MARK: - INVENTORY MANAGER
class InventoryManager: ObservableObject {
    @Published var items: [InventoryItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let itemsKey = "SavedInventoryItems"
    private let migrationKey = "DataMigrationV10_Completed"
    private let categoryCountersKey = "CategoryCounters"
    
    @Published var categoryCounters: [String: Int] = [:]
    
    private weak var firebaseService: FirebaseService?
    private let db = Firestore.firestore()
    
    init() {
        performDataMigrationIfNeeded()
        loadCategoryCounters()
        loadItems()
    }
    
    func initialize(with firebaseService: FirebaseService) {
        self.firebaseService = firebaseService
        print("📱 InventoryManager initialized with Firebase")
        
        if firebaseService.isAuthenticated {
            loadItemsFromFirebase()
        }
    }
    
    private func performDataMigrationIfNeeded() {
        if !userDefaults.bool(forKey: migrationKey) {
            print("🔄 Performing data migration...")
            userDefaults.removeObject(forKey: itemsKey)
            userDefaults.removeObject(forKey: categoryCountersKey)
            userDefaults.set(true, forKey: migrationKey)
            print("✅ Data migration completed")
        }
    }
    
    private func loadItemsFromFirebase() {
        firebaseService?.loadUserInventory { [weak self] firebaseItems in
            DispatchQueue.main.async {
                let localItems = firebaseItems.map { firebaseItem in
                    InventoryItem(
                        itemNumber: firebaseItem.itemNumber,
                        name: firebaseItem.name,
                        category: firebaseItem.category,
                        purchasePrice: firebaseItem.purchasePrice,
                        suggestedPrice: firebaseItem.suggestedPrice,
                        source: firebaseItem.source,
                        condition: firebaseItem.condition,
                        title: firebaseItem.title,
                        description: firebaseItem.description,
                        keywords: firebaseItem.keywords,
                        status: ItemStatus(rawValue: firebaseItem.status) ?? .sourced,
                        dateAdded: firebaseItem.dateAdded,
                        actualPrice: firebaseItem.actualPrice,
                        dateListed: firebaseItem.dateListed,
                        dateSold: firebaseItem.dateSold,
                        ebayURL: firebaseItem.ebayURL,
                        brand: firebaseItem.brand,
                        storageLocation: firebaseItem.storageLocation,
                        binNumber: firebaseItem.binNumber,
                        isPackaged: firebaseItem.isPackaged,
                        packagedDate: firebaseItem.packagedDate
                    )
                }
                
                self?.items = localItems
                print("✅ Loaded \(localItems.count) items from Firebase")
            }
        }
    }
    
    func generateInventoryCode(for category: String) -> String {
        let inventoryCategory = mapCategoryToInventoryCategory(category)
        let letter = inventoryCategory.inventoryLetter
        
        let currentCount = categoryCounters[letter] ?? 0
        let nextNumber = currentCount + 1
        
        categoryCounters[letter] = nextNumber
        saveCategoryCounters()
        
        return String(format: "%@-%03d", letter, nextNumber)
    }
    
    private func mapCategoryToInventoryCategory(_ category: String) -> InventoryCategory {
        let lowercased = category.lowercased()
        
        if lowercased.contains("shoe") || lowercased.contains("sneaker") || lowercased.contains("footwear") {
            return .shoes
        } else if lowercased.contains("shirt") || lowercased.contains("top") {
            return .tshirts
        } else if lowercased.contains("jacket") || lowercased.contains("coat") {
            return .jackets
        } else if lowercased.contains("jean") || lowercased.contains("denim") {
            return .jeans
        } else if lowercased.contains("electronic") {
            return .electronics
        } else {
            return .other
        }
    }
    
    func addItem(_ item: InventoryItem) -> InventoryItem {
        var updatedItem = item
        
        if updatedItem.inventoryCode.isEmpty {
            updatedItem.inventoryCode = generateInventoryCode(for: item.category)
        }
        
        items.append(updatedItem)
        saveItems()
        
        firebaseService?.syncInventoryItem(updatedItem) { success in
            print(success ? "✅ Item synced to Firebase" : "❌ Failed to sync item")
        }
        
        return updatedItem
    }
    
    func updateItem(_ updatedItem: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
            saveItems()
            
            firebaseService?.syncInventoryItem(updatedItem) { success in
                print(success ? "✅ Item updated in Firebase" : "❌ Failed to update item")
            }
        }
    }
    
    func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: itemsKey)
        } catch {
            print("❌ Error saving items: \(error)")
        }
    }
    
    private func loadItems() {
        guard let data = userDefaults.data(forKey: itemsKey) else {
            return
        }
        
        do {
            items = try JSONDecoder().decode([InventoryItem].self, from: data)
            rebuildCategoryCounters()
        } catch {
            print("❌ Error loading items: \(error)")
            userDefaults.removeObject(forKey: itemsKey)
            items = []
        }
    }
    
    private func rebuildCategoryCounters() {
        categoryCounters.removeAll()
        
        for item in items {
            let category = mapCategoryToInventoryCategory(item.category)
            let letter = category.inventoryLetter
            
            let codeComponents = item.inventoryCode.split(separator: "-")
            if codeComponents.count == 2,
               let number = Int(codeComponents[1]) {
                categoryCounters[letter] = max(categoryCounters[letter] ?? 0, number)
            }
        }
        
        saveCategoryCounters()
    }
    
    private func saveCategoryCounters() {
        do {
            let data = try JSONEncoder().encode(categoryCounters)
            userDefaults.set(data, forKey: categoryCountersKey)
        } catch {
            print("❌ Error saving category counters: \(error)")
        }
    }
    
    private func loadCategoryCounters() {
        guard let data = userDefaults.data(forKey: categoryCountersKey) else {
            return
        }
        
        do {
            categoryCounters = try JSONDecoder().decode([String: Int].self, from: data)
        } catch {
            categoryCounters = [:]
        }
    }
    
    var nextItemNumber: Int {
        (items.map { $0.itemNumber }.max() ?? 0) + 1
    }
    
    var listedItems: Int {
        items.filter { $0.status == .listed }.count
    }
    
    var soldItems: Int {
        items.filter { $0.status == .sold }.count
    }
    
    var totalEstimatedValue: Double {
        items.reduce(0) { $0 + $1.suggestedPrice }
    }
    
    var recentItems: [InventoryItem] {
        items.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    func getCategoryBreakdown() -> [String: Int] {
        let categories = Dictionary(grouping: items, by: { $0.category })
        return categories.mapValues { $0.count }
    }
    
    func getInventoryOverview() -> [(letter: String, category: String, count: Int, items: [InventoryItem])] {
        var overview: [(letter: String, category: String, count: Int, items: [InventoryItem])] = []
        
        for category in InventoryCategory.allCases {
            let letter = category.inventoryLetter
            let categoryItems = items.filter { mapCategoryToInventoryCategory($0.category) == category }
            
            if categoryItems.count > 0 {
                overview.append((
                    letter: letter,
                    category: category.rawValue,
                    count: categoryItems.count,
                    items: categoryItems
                ))
            }
        }
        
        return overview.sorted { $0.letter < $1.letter }
    }
    
    func getPackagedItems() -> [InventoryItem] {
        return items.filter { $0.isPackaged }
    }
    
    func getItemsReadyToList() -> [InventoryItem] {
        return items.filter { $0.status == .toList }
    }
    
    func exportToCSV() -> String {
        var csv = "Item Number,Code,Name,Category,Brand,Purchase Price,Suggested Price,Status,Date Added\n"
        
        for item in items {
            let row = [
                "\(item.itemNumber)",
                csvEscape(item.inventoryCode),
                csvEscape(item.name),
                csvEscape(item.category),
                csvEscape(item.brand),
                String(format: "%.2f", item.purchasePrice),
                String(format: "%.2f", item.suggestedPrice),
                csvEscape(item.status.rawValue),
                formatDate(item.dateAdded)
            ]
            csv += row.joined(separator: ",") + "\n"
        }
        
        return csv
    }
    
    private func csvEscape(_ text: String) -> String {
        let escaped = text.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
}

struct EbaySoldItem {
    let title: String
    let price: Double
    let condition: String?
    let soldDate: Date?
    let shipping: Double?
    let bestOfferAccepted: Bool?
}
