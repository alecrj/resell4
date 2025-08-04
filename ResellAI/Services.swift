//
//  Services.swift
//  ResellAI
//
//  Ultimate Consolidated Services - FAANG Level Architecture
//

import SwiftUI
import Foundation
import Vision

// MARK: - UNIFIED BUSINESS SERVICE
class BusinessService: ObservableObject {
    // Published properties for UI binding
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 8
    @Published var isSyncing = false
    @Published var syncStatus = "Ready"
    @Published var lastSyncDate: Date?
    
    // Internal services
    private let aiService = AIAnalysisService()
    private let ebayService = EbayService()
    private let googleSheetsService = GoogleSheetsService()
    
    init() {
        print("🚀 Business Service initialized")
    }
    
    func initialize() {
        Configuration.validateConfiguration()
        authenticateGoogleSheets()
    }
    
    // MARK: - AI ANALYSIS
    func analyzeItem(_ images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        
        print("🔍 Starting AI analysis with \(images.count) images")
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.currentStep = 0
            self.totalSteps = 8
        }
        
        aiService.analyzeItem(images: images) { [weak self] result in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                self?.analysisProgress = "Complete"
                completion(result)
            }
        }
        
        // Bind AI service progress
        aiService.$analysisProgress.receive(on: DispatchQueue.main).assign(to: &$analysisProgress)
        aiService.$currentStep.receive(on: DispatchQueue.main).assign(to: &$currentStep)
    }
    
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.analysisProgress = "Scanning barcode..."
        }
        
        aiService.analyzeBarcodeItem(barcode, images: images) { [weak self] result in
            DispatchQueue.main.async {
                self?.isAnalyzing = false
                completion(result)
            }
        }
    }
    
    // MARK: - GOOGLE SHEETS INTEGRATION
    func authenticateGoogleSheets() {
        googleSheetsService.authenticate()
    }
    
    func syncAllItems(_ items: [InventoryItem]) {
        googleSheetsService.syncAllItems(items)
        // Bind sync status
        googleSheetsService.$isSyncing.receive(on: DispatchQueue.main).assign(to: &$isSyncing)
        googleSheetsService.$syncStatus.receive(on: DispatchQueue.main).assign(to: &$syncStatus)
        googleSheetsService.$lastSyncDate.receive(on: DispatchQueue.main).assign(to: &$lastSyncDate)
    }
    
    // MARK: - EBAY INTEGRATION
    func createEbayListing(for item: InventoryItem, completion: @escaping (Bool, String?) -> Void) {
        ebayService.createListing(for: item, completion: completion)
    }
    
    func searchEbayComps(for query: String, completion: @escaping ([EbaySoldListing]) -> Void) {
        ebayService.searchSoldListings(query: query, completion: completion)
    }
}

// MARK: - AI ANALYSIS SERVICE
class AIAnalysisService: ObservableObject {
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 8
    
    private let openAIService = OpenAIService()
    
    func analyzeItem(images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        let analysisSteps = [
            "Processing images...",
            "Identifying item...",
            "Analyzing condition...",
            "Researching market...",
            "Calculating pricing...",
            "Generating description...",
            "Creating listing strategy...",
            "Finalizing analysis..."
        ]
        
        var currentStepIndex = 0
        
        func nextStep() {
            DispatchQueue.main.async {
                if currentStepIndex < analysisSteps.count {
                    self.analysisProgress = analysisSteps[currentStepIndex]
                    self.currentStep = currentStepIndex + 1
                    currentStepIndex += 1
                }
            }
        }
        
        // Step 1: Process images
        nextStep()
        let processedImages = processImagesForAnalysis(images)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Step 2: OpenAI Analysis
            nextStep()
            self.openAIService.analyzeWithOpenAI(images: processedImages) { [weak self] openAIResult in
                guard let openAIResult = openAIResult else {
                    completion(nil)
                    return
                }
                
                // Step 3: Condition analysis
                nextStep()
                
                // Step 4: Market research
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    nextStep()
                    self?.searchEbayMarketData(for: openAIResult.name) { marketData in
                        // Step 5: Pricing calculation
                        nextStep()
                        let pricingData = self?.calculatePricing(from: marketData) ?? (50.0, 75.0, 100.0)
                        
                        // Step 6: Description generation
                        nextStep()
                        
                        // Step 7: Listing strategy
                        nextStep()
                        
                        // Step 8: Finalize
                        nextStep()
                        
                        // Create final result
                        let finalResult = AnalysisResult(
                            name: openAIResult.name,
                            brand: openAIResult.brand,
                            category: openAIResult.category,
                            condition: openAIResult.condition,
                            title: openAIResult.title,
                            description: openAIResult.description,
                            keywords: openAIResult.keywords,
                            suggestedPrice: pricingData.1,
                            quickPrice: pricingData.0,
                            premiumPrice: pricingData.2,
                            averagePrice: pricingData.1,
                            marketConfidence: 0.85,
                            soldListingsCount: marketData.count,
                            competitorCount: min(marketData.count, 50),
                            demandLevel: marketData.count > 10 ? "High" : "Medium",
                            listingStrategy: "Standard auction with Buy It Now",
                            sourcingTips: ["Check thrift stores", "Look for similar brands", "Monitor seasonal trends"],
                            aiConfidence: 0.9,
                            resalePotential: Int(pricingData.1 / 10),
                            priceRange: EbayPriceRange(
                                low: pricingData.0,
                                high: pricingData.2,
                                average: pricingData.1
                            ),
                            recentSales: marketData.prefix(5).map { listing in
                                RecentSale(
                                    title: listing.title,
                                    price: listing.price,
                                    condition: listing.condition,
                                    date: listing.soldDate,
                                    shipping: listing.shippingCost,
                                    bestOffer: listing.bestOffer
                                )
                            }
                        )
                        
                        completion(finalResult)
                    }
                }
            }
        }
    }
    
    func analyzeBarcodeItem(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        // Enhanced barcode analysis
        analysisProgress = "Looking up barcode..."
        
        // First try to get product info from barcode
        lookupBarcodeProduct(barcode) { [weak self] barcodeResult in
            if let productInfo = barcodeResult {
                // Use barcode info + image analysis
                self?.analyzeItem(images: images) { result in
                    if var result = result {
                        // Create enhanced result with barcode data
                        let enhancedResult = AnalysisResult(
                            name: productInfo.name,
                            brand: productInfo.brand,
                            category: result.category,
                            condition: result.condition,
                            title: result.title,
                            description: result.description,
                            keywords: result.keywords,
                            suggestedPrice: result.suggestedPrice,
                            quickPrice: result.quickPrice,
                            premiumPrice: result.premiumPrice,
                            averagePrice: result.averagePrice,
                            marketConfidence: result.marketConfidence,
                            soldListingsCount: result.soldListingsCount,
                            competitorCount: result.competitorCount,
                            demandLevel: result.demandLevel,
                            listingStrategy: result.listingStrategy,
                            sourcingTips: result.sourcingTips,
                            aiConfidence: result.aiConfidence,
                            resalePotential: result.resalePotential,
                            priceRange: result.priceRange,
                            recentSales: result.recentSales,
                            exactModel: productInfo.model.isEmpty ? result.exactModel : productInfo.model,
                            styleCode: result.styleCode,
                            size: result.size,
                            colorway: result.colorway,
                            releaseYear: result.releaseYear,
                            subcategory: result.subcategory
                        )
                        completion(enhancedResult)
                    } else {
                        completion(nil)
                    }
                }
            } else {
                // Fall back to regular image analysis
                self?.analyzeItem(images: images, completion: completion)
            }
        }
    }
    
    private func processImagesForAnalysis(_ images: [UIImage]) -> [UIImage] {
        return images.compactMap { image in
            optimizeImageForAnalysis(image)
        }
    }
    
    private func optimizeImageForAnalysis(_ image: UIImage) -> UIImage? {
        // Resize and optimize image for analysis
        let targetSize = CGSize(width: 800, height: 800)
        
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: targetSize))
        let optimizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return optimizedImage
    }
    
    private func searchEbayMarketData(for itemName: String, completion: @escaping ([EbaySoldListing]) -> Void) {
        // Mock eBay API call - replace with real implementation
        let mockListings = [
            EbaySoldListing(
                title: "\(itemName) - Similar Item 1",
                price: 45.99,
                condition: "Used",
                soldDate: Date().addingTimeInterval(-86400 * 3),
                shippingCost: 8.50,
                bestOffer: false,
                auction: false,
                watchers: 12
            ),
            EbaySoldListing(
                title: "\(itemName) - Similar Item 2",
                price: 62.00,
                condition: "Like New",
                soldDate: Date().addingTimeInterval(-86400 * 7),
                shippingCost: 0,
                bestOffer: true,
                auction: false,
                watchers: 8
            ),
            EbaySoldListing(
                title: "\(itemName) - Similar Item 3",
                price: 38.50,
                condition: "Good",
                soldDate: Date().addingTimeInterval(-86400 * 12),
                shippingCost: 12.99,
                bestOffer: false,
                auction: true,
                watchers: 15
            )
        ]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            completion(mockListings)
        }
    }
    
    private func calculatePricing(from marketData: [EbaySoldListing]) -> (Double, Double, Double) {
        guard !marketData.isEmpty else {
            return (25.0, 45.0, 75.0) // Default pricing
        }
        
        let prices = marketData.map { $0.price }
        let avgPrice = prices.reduce(0, +) / Double(prices.count)
        
        let quickPrice = avgPrice * 0.85  // Quick sale
        let premiumPrice = avgPrice * 1.25 // Premium price
        
        return (quickPrice, avgPrice, premiumPrice)
    }
    
    private func lookupBarcodeProduct(_ barcode: String, completion: @escaping (BarcodeProductInfo?) -> Void) {
        // Mock barcode lookup - replace with real API
        let mockProduct = BarcodeProductInfo(
            name: "Nike Air Force 1",
            brand: "Nike",
            model: "Air Force 1 Low '07",
            category: "Sneakers"
        )
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(mockProduct)
        }
    }
}

// MARK: - OPENAI SERVICE
class OpenAIService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let endpoint = Configuration.openAIEndpoint
    
    func analyzeWithOpenAI(images: [UIImage], completion: @escaping (OpenAIAnalysisResult?) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ OpenAI API key not configured")
            completion(nil)
            return
        }
        
        // Convert images to base64
        let base64Images = images.compactMap { image in
            image.jpegData(compressionQuality: 0.8)?.base64EncodedString()
        }
        
        guard !base64Images.isEmpty else {
            completion(nil)
            return
        }
        
        let prompt = """
        Analyze this item for reselling on eBay. Provide a JSON response with:
        {
            "name": "Product name",
            "brand": "Brand name",
            "category": "Category",
            "condition": "Condition description",
            "title": "eBay listing title (80 chars max)",
            "description": "Detailed description for listing",
            "keywords": ["keyword1", "keyword2", "keyword3"]
        }
        
        Focus on:
        - Accurate product identification
        - Marketable condition assessment
        - SEO-optimized title and keywords
        - Compelling description highlighting key features
        """
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": prompt
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": "data:image/jpeg;base64,\(base64Images[0])"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": Configuration.openAIMaxTokens,
            "temperature": 0.1
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request body: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI API error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ No data received from OpenAI")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    
                    // Parse the JSON response from GPT
                    if let jsonData = content.data(using: .utf8),
                       let analysisData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                        
                        let result = OpenAIAnalysisResult(
                            name: analysisData["name"] as? String ?? "Unknown Item",
                            brand: analysisData["brand"] as? String ?? "",
                            category: analysisData["category"] as? String ?? "Other",
                            condition: analysisData["condition"] as? String ?? "Used",
                            title: analysisData["title"] as? String ?? "Item for Sale",
                            description: analysisData["description"] as? String ?? "Item in good condition",
                            keywords: analysisData["keywords"] as? [String] ?? []
                        )
                        
                        completion(result)
                    } else {
                        print("❌ Could not parse OpenAI response as JSON")
                        completion(nil)
                    }
                } else {
                    print("❌ Unexpected OpenAI response format")
                    completion(nil)
                }
            } catch {
                print("❌ Error parsing OpenAI response: \(error)")
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - EBAY SERVICE
class EbayService: ObservableObject {
    private let apiKey = Configuration.ebayAPIKey
    private let findingAPIBase = Configuration.ebayFindingAPIBase
    
    func searchSoldListings(query: String, completion: @escaping ([EbaySoldListing]) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ eBay API key not configured")
            completion([])
            return
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        
        var components = URLComponents(string: findingAPIBase)!
        components.queryItems = [
            URLQueryItem(name: "OPERATION-NAME", value: "findCompletedItems"),
            URLQueryItem(name: "SERVICE-VERSION", value: "1.0.0"),
            URLQueryItem(name: "SECURITY-APPNAME", value: apiKey),
            URLQueryItem(name: "RESPONSE-DATA-FORMAT", value: "JSON"),
            URLQueryItem(name: "keywords", value: encodedQuery),
            URLQueryItem(name: "itemFilter(0).name", value: "SoldItemsOnly"),
            URLQueryItem(name: "itemFilter(0).value", value: "true"),
            URLQueryItem(name: "itemFilter(1).name", value: "ListingType"),
            URLQueryItem(name: "itemFilter(1).value", value: "FixedPrice"),
            URLQueryItem(name: "sortOrder", value: "EndTimeSoonest"),
            URLQueryItem(name: "paginationInput.entriesPerPage", value: "20")
        ]
        
        guard let url = components.url else {
            print("❌ Invalid eBay API URL")
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ eBay API error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("❌ No data received from eBay")
                completion([])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let listings = self.parseEbayResponse(json)
                    DispatchQueue.main.async {
                        completion(listings)
                    }
                } else {
                    print("❌ Invalid eBay response format")
                    completion([])
                }
            } catch {
                print("❌ Error parsing eBay response: \(error)")
                completion([])
            }
        }.resume()
    }
    
    func createListing(for item: InventoryItem, completion: @escaping (Bool, String?) -> Void) {
        // Mock eBay listing creation - implement with eBay Trading API
        print("🏷️ Creating eBay listing for: \(item.name)")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Simulate success
            completion(true, "https://ebay.com/itm/123456789")
        }
    }
    
    private func parseEbayResponse(_ json: [String: Any]) -> [EbaySoldListing] {
        // Parse eBay Finding API JSON response
        var listings: [EbaySoldListing] = []
        
        if let findCompletedItemsResponse = json["findCompletedItemsResponse"] as? [[String: Any]],
           let response = findCompletedItemsResponse.first,
           let searchResult = response["searchResult"] as? [[String: Any]],
           let result = searchResult.first,
           let items = result["item"] as? [[String: Any]] {
            
            for itemData in items {
                if let title = itemData["title"] as? [String],
                   let sellingStatus = itemData["sellingStatus"] as? [[String: Any]],
                   let status = sellingStatus.first,
                   let currentPrice = status["currentPrice"] as? [[String: Any]],
                   let price = currentPrice.first,
                   let priceValue = price["__value__"] as? String,
                   let priceDouble = Double(priceValue),
                   let condition = itemData["condition"] as? [[String: Any]],
                   let conditionData = condition.first,
                   let conditionName = conditionData["conditionDisplayName"] as? [String],
                   let endTime = itemData["listingInfo"] as? [[String: Any]],
                   let listingInfo = endTime.first,
                   let endTimeString = listingInfo["endTime"] as? [String] {
                    
                    let dateFormatter = ISO8601DateFormatter()
                    let soldDate = dateFormatter.date(from: endTimeString.first ?? "") ?? Date()
                    
                    let listing = EbaySoldListing(
                        title: title.first ?? "",
                        price: priceDouble,
                        condition: conditionName.first ?? "",
                        soldDate: soldDate,
                        shippingCost: nil,
                        bestOffer: false,
                        auction: false,
                        watchers: nil
                    )
                    
                    listings.append(listing)
                }
            }
        }
        
        return listings
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
            print("❌ Google Sheets script URL not configured")
            return
        }
        
        print("📊 Google Sheets service authenticated")
        syncStatus = "Connected"
    }
    
    func syncAllItems(_ items: [InventoryItem]) {
        guard !scriptURL.isEmpty else {
            print("❌ Google Sheets not configured")
            return
        }
        
        DispatchQueue.main.async {
            self.isSyncing = true
            self.syncStatus = "Syncing..."
        }
        
        let csvData = convertItemsToCSV(items)
        uploadToGoogleSheets(csvData) { [weak self] success in
            DispatchQueue.main.async {
                self?.isSyncing = false
                if success {
                    self?.syncStatus = "Synced"
                    self?.lastSyncDate = Date()
                } else {
                    self?.syncStatus = "Sync Failed"
                }
            }
        }
    }
    
    func syncSingleItem(_ item: InventoryItem) {
        syncAllItems([item])
    }
    
    private func convertItemsToCSV(_ items: [InventoryItem]) -> String {
        var csv = "Item Number,Inventory Code,Name,Category,Brand,Purchase Price,Suggested Price,Actual Price,Source,Condition,Status,Date Added,Date Listed,Date Sold,eBay URL,Storage Location\n"
        
        for item in items {
            let row = [
                "\(item.itemNumber)",
                csvEscape(item.inventoryCode),
                csvEscape(item.name),
                csvEscape(item.category),
                csvEscape(item.brand),
                String(format: "%.2f", item.purchasePrice),
                String(format: "%.2f", item.suggestedPrice),
                item.actualPrice.map { String(format: "%.2f", $0) } ?? "",
                csvEscape(item.source),
                csvEscape(item.condition),
                csvEscape(item.status.rawValue),
                formatDate(item.dateAdded),
                item.dateListed.map(formatDate) ?? "",
                item.dateSold.map(formatDate) ?? "",
                csvEscape(item.ebayURL ?? ""),
                csvEscape(item.storageLocation)
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
    
    private func uploadToGoogleSheets(_ csvData: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: scriptURL) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "action": "updateData",
            "spreadsheetId": spreadsheetID,
            "data": csvData
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating Google Sheets request: \(error)")
            completion(false)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ Google Sheets sync error: \(error)")
                completion(false)
                return
            }
            
            completion(true)
        }.resume()
    }
}

// MARK: - INVENTORY MANAGER SERVICE
class InventoryManager: ObservableObject {
    @Published var items: [InventoryItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let itemsKey = "SavedInventoryItems"
    private let migrationKey = "DataMigrationV5_Completed"
    private let categoryCountersKey = "CategoryCounters"
    
    @Published var categoryCounters: [String: Int] = [:]
    
    init() {
        performDataMigrationIfNeeded()
        loadCategoryCounters()
        loadItems()
    }
    
    // MARK: - Data Migration
    private func performDataMigrationIfNeeded() {
        if !userDefaults.bool(forKey: migrationKey) {
            print("🔄 Performing data migration V5...")
            
            // Clear old data
            userDefaults.removeObject(forKey: itemsKey)
            userDefaults.removeObject(forKey: categoryCountersKey)
            
            // Mark migration complete
            userDefaults.set(true, forKey: migrationKey)
            print("✅ Data migration V5 completed")
        }
    }
    
    // MARK: - Inventory Code Generation
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
        
        if lowercased.contains("shirt") || lowercased.contains("top") {
            return .tshirts
        } else if lowercased.contains("jacket") || lowercased.contains("coat") {
            return .jackets
        } else if lowercased.contains("jean") || lowercased.contains("denim") {
            return .jeans
        } else if lowercased.contains("pant") || lowercased.contains("trouser") {
            return .workPants
        } else if lowercased.contains("dress") || lowercased.contains("skirt") {
            return .dresses
        } else if lowercased.contains("shoe") || lowercased.contains("sneaker") || lowercased.contains("boot") {
            return .shoes
        } else if lowercased.contains("accessory") || lowercased.contains("bag") || lowercased.contains("watch") {
            return .accessories
        } else if lowercased.contains("electronic") || lowercased.contains("phone") || lowercased.contains("computer") {
            return .electronics
        } else if lowercased.contains("collectible") || lowercased.contains("vintage") {
            return .collectibles
        } else if lowercased.contains("home") || lowercased.contains("garden") {
            return .home
        } else if lowercased.contains("book") || lowercased.contains("media") {
            return .books
        } else if lowercased.contains("toy") || lowercased.contains("game") {
            return .toys
        } else if lowercased.contains("sport") || lowercased.contains("outdoor") {
            return .sports
        } else {
            return .other
        }
    }
    
    // MARK: - CRUD Operations
    func addItem(_ item: InventoryItem) -> InventoryItem {
        var updatedItem = item
        
        if updatedItem.inventoryCode.isEmpty {
            updatedItem.inventoryCode = generateInventoryCode(for: item.category)
        }
        
        items.append(updatedItem)
        saveItems()
        print("✅ Added item: \(updatedItem.name) [\(updatedItem.inventoryCode)]")
        
        return updatedItem
    }
    
    func updateItem(_ updatedItem: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == updatedItem.id }) {
            items[index] = updatedItem
            saveItems()
            print("✅ Updated item: \(updatedItem.name)")
        }
    }
    
    func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
        print("🗑️ Deleted item: \(item.name)")
    }
    
    // MARK: - Data Persistence
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            userDefaults.set(data, forKey: itemsKey)
            print("💾 Saved \(items.count) items")
        } catch {
            print("❌ Error saving items: \(error)")
        }
    }
    
    private func loadItems() {
        guard let data = userDefaults.data(forKey: itemsKey) else {
            print("📱 No saved items found")
            return
        }
        
        do {
            items = try JSONDecoder().decode([InventoryItem].self, from: data)
            print("📂 Loaded \(items.count) items")
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
            print("❌ Error loading category counters: \(error)")
            categoryCounters = [:]
        }
    }
    
    // MARK: - Computed Properties
    var nextItemNumber: Int {
        (items.map { $0.itemNumber }.max() ?? 0) + 1
    }
    
    var itemsToList: Int {
        items.filter { $0.status == .toList }.count
    }
    
    var listedItems: Int {
        items.filter { $0.status == .listed }.count
    }
    
    var soldItems: Int {
        items.filter { $0.status == .sold }.count
    }
    
    var totalInvestment: Double {
        items.reduce(0) { $0 + $1.purchasePrice }
    }
    
    var totalProfit: Double {
        items.filter { $0.status == .sold }.reduce(0) { $0 + $1.profit }
    }
    
    var totalEstimatedValue: Double {
        items.reduce(0) { $0 + $1.suggestedPrice }
    }
    
    var averageROI: Double {
        let soldItems = items.filter { $0.status == .sold && $0.roi > 0 }
        guard !soldItems.isEmpty else { return 0 }
        return soldItems.reduce(0) { $0 + $1.roi } / Double(soldItems.count)
    }
    
    var recentItems: [InventoryItem] {
        items.sorted { $0.dateAdded > $1.dateAdded }
    }
    
    // MARK: - Analytics
    func getCategoryBreakdown() -> [String: Int] {
        let categories = Dictionary(grouping: items, by: { $0.category })
        return categories.mapValues { $0.count }
    }
    
    func getBestPerformingBrands() -> [String: Double] {
        let brands = Dictionary(grouping: items.filter { !$0.brand.isEmpty }, by: { $0.brand })
        return brands.mapValues { items in
            items.reduce(0) { $0 + $1.estimatedROI } / Double(items.count)
        }
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
        var csv = "Item Number,Inventory Code,Name,Category,Brand,Purchase Price,Suggested Price,Actual Price,Source,Condition,Status,Date Added,Date Listed,Date Sold,eBay URL,Storage Location\n"
        
        for item in items {
            let row = [
                "\(item.itemNumber)",
                csvEscape(item.inventoryCode),
                csvEscape(item.name),
                csvEscape(item.category),
                csvEscape(item.brand),
                String(format: "%.2f", item.purchasePrice),
                String(format: "%.2f", item.suggestedPrice),
                item.actualPrice.map { String(format: "%.2f", $0) } ?? "",
                csvEscape(item.source),
                csvEscape(item.condition),
                csvEscape(item.status.rawValue),
                formatDate(item.dateAdded),
                item.dateListed.map(formatDate) ?? "",
                item.dateSold.map(formatDate) ?? "",
                csvEscape(item.ebayURL ?? ""),
                csvEscape(item.storageLocation)
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

// MARK: - SUPPORTING MODELS

struct OpenAIAnalysisResult {
    let name: String
    let brand: String
    let category: String
    let condition: String
    let title: String
    let description: String
    let keywords: [String]
}

struct BarcodeProductInfo {
    let name: String
    let brand: String
    let model: String
    let category: String
}
