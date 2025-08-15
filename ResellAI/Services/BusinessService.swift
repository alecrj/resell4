//
//  BusinessService.swift
//  ResellAI
//
//  Main Business Service - Safe Update (Uses Both OAuth + Listing Services)
//

import SwiftUI
import Foundation
import Vision
import AuthenticationServices
import FirebaseFirestore
import CryptoKit
import SafariServices

// MARK: - MAIN BUSINESS SERVICE (SAFE - USES BOTH SERVICES)
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
    
    // ✅ KEEP YOUR WORKING OAUTH SERVICE UNTOUCHED
    let ebayService = EbayService()
    
    // ✅ NEW LISTING SERVICE (SEPARATE)
    private let ebayListingService = EbayListingService()
    
    private let googleSheetsService = GoogleSheetsService()
    
    // Firebase integration
    private weak var firebaseService: FirebaseService?
    
    // Queue processing timer
    private var queueTimer: Timer?
    
    init() {
        print("🚀 ResellAI Business Service initialized with Safe Architecture")
        loadSavedQueue()
    }
    
    func initialize(with firebaseService: FirebaseService? = nil) {
        Configuration.validateConfiguration()
        self.firebaseService = firebaseService
        authenticateGoogleSheets()
        
        // ✅ INITIALIZE YOUR WORKING OAUTH SERVICE (UNCHANGED)
        ebayService.initialize()
    }
    
    // ✅ OAUTH METHODS - DELEGATE TO YOUR WORKING SERVICE
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
            marketConfidence: nil,
            soldListingsCount: marketData.soldComps.count > 0 ? marketData.soldComps.count : nil,
            competitorCount: marketData.activeListings.count > 0 ? marketData.activeListings.count : nil,
            demandLevel: calculateDemandLevel(marketData: marketData),
            listingStrategy: "Fixed Price",
            sourcingTips: generateSourcingTips(productResult: productResult, pricing: pricing),
            aiConfidence: nil,
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
    
    // ✅ REAL EBAY LISTING CREATION - USES NEW LISTING SERVICE
    func createEbayListing(from analysis: AnalysisResult, images: [UIImage], completion: @escaping (Bool, String?) -> Void) {
        guard let firebase = firebaseService else {
            completion(false, "Firebase not initialized")
            return
        }
        
        if !firebase.canCreateListing {
            completion(false, "Monthly listing limit reached. Please upgrade your plan.")
            return
        }
        
        // ✅ CHECK IF WE HAVE VALID OAUTH TOKEN FROM YOUR WORKING SERVICE
        guard ebayService.isAuthenticated else {
            completion(false, "Please connect your eBay account first")
            return
        }
        
        guard let accessToken = ebayService.getAccessToken() else {
            completion(false, "No valid eBay access token")
            return
        }
        
        print("📤 Creating eBay listing for: \(analysis.name)")
        print("• Using OAuth token from working service: \(accessToken.prefix(10))...")
        
        // ✅ USE NEW LISTING SERVICE WITH TOKEN FROM OAUTH SERVICE
        ebayListingService.createListing(analysis: analysis, images: images, accessToken: accessToken) { [weak self] success, errorMessage in
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

struct EbaySoldItem {
    let title: String
    let price: Double
    let condition: String?
    let soldDate: Date?
    let shipping: Double?
    let bestOfferAccepted: Bool?
}
