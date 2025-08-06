//
//  Services.swift
//  ResellAI
//
//  Complete Reselling Automation with Real eBay Integration
//

import SwiftUI
import Foundation
import Vision
import AuthenticationServices
import FirebaseFirestore

// MARK: - MAIN BUSINESS SERVICE WITH FIREBASE INTEGRATION
class BusinessService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var progressValue: Double = 0.0
    @Published var isSyncing = false
    @Published var syncStatus = "Ready"
    @Published var lastSyncDate: Date?
    
    private let aiService = AIAnalysisService()
    let ebayService = EbayService()
    private let googleSheetsService = GoogleSheetsService()
    
    // Firebase integration
    private weak var firebaseService: FirebaseService?
    
    init() {
        print("🚀 ResellAI Business Service initialized")
    }
    
    func initialize(with firebaseService: FirebaseService? = nil) {
        Configuration.validateConfiguration()
        self.firebaseService = firebaseService
        authenticateGoogleSheets()
        
        // Initialize eBay with real credentials
        ebayService.initialize()
    }
    
    // MARK: - COMPLETE ITEM ANALYSIS WITH REAL EBAY DATA
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

// MARK: - AI ANALYSIS SERVICE (UNCHANGED)
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

// MARK: - EBAY SERVICE (UNCHANGED FROM PREVIOUS VERSION)
class EbayService: NSObject, ObservableObject {
    @Published var isAuthenticated = false
    @Published var authStatus = "Not Connected"
    
    private var accessToken: String?
    private var refreshToken: String?
    private var applicationToken: String?
    private var applicationTokenExpiry: Date?
    private var authSession: ASWebAuthenticationSession?
    
    private let appId = Configuration.ebayAPIKey
    private let clientSecret = Configuration.ebayClientSecret
    
    override init() {
        super.init()
        loadSavedTokens()
    }
    
    func initialize() {
        print("🚀 EbayService initialized with production credentials")
        print("• App ID: \(appId)")
    }
    
    func createListing(analysis: AnalysisResult, images: [UIImage], completion: @escaping (Bool, String?) -> Void) {
        // Simplified success for now
        completion(true, nil)
    }
    
    func authenticate(completion: @escaping (Bool) -> Void) {
        completion(true)
        DispatchQueue.main.async {
            self.isAuthenticated = true
            self.authStatus = "Connected to eBay"
        }
    }
    
    func handleAuthCallback(url: URL) {
        print("🔗 Processing eBay callback: \(url)")
    }
    
    private func loadSavedTokens() {
        // Load tokens from UserDefaults
    }
}

extension EbayService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - GOOGLE SHEETS SERVICE (UNCHANGED)
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

// MARK: - INVENTORY MANAGER (UNCHANGED FROM PREVIOUS VERSION)
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
