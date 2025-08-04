//
//  Services.swift
//  ResellAI
//
//  Business Services with Real API Integration
//

import SwiftUI
import Foundation
import Vision

// MARK: - UNIFIED BUSINESS SERVICE
class BusinessService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 6
    @Published var isSyncing = false
    @Published var syncStatus = "Ready"
    @Published var lastSyncDate: Date?
    
    private let aiService = AIAnalysisService()
    private let rapidAPIService = RapidAPIService()
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
            self.totalSteps = 6
        }
        
        // Step 1: AI Image Analysis
        updateProgress("Analyzing images with AI...", step: 1)
        
        aiService.analyzeWithOpenAI(images: images) { [weak self] aiResult in
            guard let aiResult = aiResult else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    completion(nil)
                }
                return
            }
            
            // Step 2: Search eBay sold comps
            self?.updateProgress("Searching eBay sold comps...", step: 2)
            
            let searchQuery = "\(aiResult.brand) \(aiResult.name)".trimmingCharacters(in: .whitespaces)
            
            self?.rapidAPIService.searchSoldItems(query: searchQuery) { soldItems in
                // Step 3: Calculate pricing
                self?.updateProgress("Calculating pricing strategy...", step: 3)
                
                let pricing = self?.calculatePricing(from: soldItems, basePrice: 50.0) ?? (30.0, 50.0, 75.0)
                
                // Step 4: Generate listing details
                self?.updateProgress("Generating listing strategy...", step: 4)
                
                // Step 5: Market analysis
                self?.updateProgress("Analyzing market conditions...", step: 5)
                
                // Step 6: Finalize
                self?.updateProgress("Finalizing analysis...", step: 6)
                
                let finalResult = AnalysisResult(
                    name: aiResult.name,
                    brand: aiResult.brand,
                    category: aiResult.category,
                    condition: aiResult.condition,
                    title: self?.generateEbayTitle(aiResult) ?? aiResult.title,
                    description: aiResult.description,
                    keywords: aiResult.keywords,
                    suggestedPrice: pricing.1,
                    quickPrice: pricing.0,
                    premiumPrice: pricing.2,
                    averagePrice: pricing.1,
                    marketConfidence: soldItems.isEmpty ? 0.3 : 0.8,
                    soldListingsCount: soldItems.count,
                    competitorCount: min(soldItems.count * 3, 100),
                    demandLevel: self?.calculateDemandLevel(soldItems.count) ?? "Medium",
                    listingStrategy: "Buy It Now with Best Offer",
                    sourcingTips: self?.generateSourcingTips(for: aiResult.category) ?? [],
                    aiConfidence: 0.85,
                    resalePotential: Int(pricing.1 / 10),
                    priceRange: EbayPriceRange(
                        low: pricing.0,
                        high: pricing.2,
                        average: pricing.1
                    ),
                    recentSales: soldItems.prefix(5).map { item in
                        RecentSale(
                            title: item.title,
                            price: item.price,
                            condition: item.condition ?? "Used",
                            date: item.soldDate ?? Date().addingTimeInterval(-86400 * 7),
                            shipping: item.shipping,
                            bestOffer: item.bestOfferAccepted ?? false
                        )
                    }
                )
                
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    self?.analysisProgress = "Complete"
                    completion(finalResult)
                }
            }
        }
    }
    
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        updateProgress("Looking up barcode...", step: 1)
        
        // For now, fall back to regular image analysis
        // Could integrate UPC database lookup here
        analyzeItem(images, completion: completion)
    }
    
    private func updateProgress(_ message: String, step: Int) {
        DispatchQueue.main.async {
            self.analysisProgress = message
            self.currentStep = step
        }
    }
    
    private func calculatePricing(from soldItems: [EbaySoldItem], basePrice: Double) -> (Double, Double, Double) {
        guard !soldItems.isEmpty else {
            return (basePrice * 0.7, basePrice, basePrice * 1.3)
        }
        
        let prices = soldItems.compactMap { $0.price }
        guard !prices.isEmpty else {
            return (basePrice * 0.7, basePrice, basePrice * 1.3)
        }
        
        let sortedPrices = prices.sorted()
        let count = sortedPrices.count
        
        let median = count % 2 == 0
            ? (sortedPrices[count/2 - 1] + sortedPrices[count/2]) / 2
            : sortedPrices[count/2]
        
        let quickPrice = median * 0.85
        let premiumPrice = median * 1.2
        
        return (quickPrice, median, premiumPrice)
    }
    
    private func calculateDemandLevel(_ soldCount: Int) -> String {
        switch soldCount {
        case 0...2: return "Low"
        case 3...10: return "Medium"
        case 11...25: return "High"
        default: return "Very High"
        }
    }
    
    private func generateEbayTitle(_ aiResult: OpenAIAnalysisResult) -> String {
        var title = ""
        
        if !aiResult.brand.isEmpty {
            title += aiResult.brand + " "
        }
        
        title += aiResult.name
        
        if !aiResult.condition.isEmpty && aiResult.condition.lowercased() != "used" {
            title += " - " + aiResult.condition
        }
        
        return String(title.prefix(80))
    }
    
    private func generateSourcingTips(for category: String) -> [String] {
        let categoryLower = category.lowercased()
        
        if categoryLower.contains("shoe") || categoryLower.contains("sneaker") {
            return ["Check thrift stores for vintage styles", "Look for limited releases", "Verify authenticity"]
        } else if categoryLower.contains("electronic") {
            return ["Test all functions before buying", "Check for original accessories", "Research model numbers"]
        } else if categoryLower.contains("clothing") {
            return ["Check for designer labels", "Inspect for stains or damage", "Know popular brands"]
        } else {
            return ["Research before buying", "Check completed listings", "Verify condition"]
        }
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

// MARK: - AI ANALYSIS SERVICE
class AIAnalysisService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let endpoint = Configuration.openAIEndpoint
    
    func analyzeWithOpenAI(images: [UIImage], completion: @escaping (OpenAIAnalysisResult?) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ OpenAI API key not configured")
            completion(nil)
            return
        }
        
        guard let firstImage = images.first,
              let imageData = firstImage.jpegData(compressionQuality: 0.8) else {
            print("❌ Could not process image")
            completion(nil)
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        let prompt = """
        Analyze this item for reselling on eBay. Respond with ONLY valid JSON in this exact format:
        {
            "name": "specific product name",
            "brand": "brand name or empty string",
            "category": "product category",
            "condition": "condition assessment",
            "title": "eBay listing title under 80 characters",
            "description": "detailed product description",
            "keywords": ["keyword1", "keyword2", "keyword3"]
        }
        
        Requirements:
        - Be specific about the product (model, size, color if visible)
        - Use proper eBay condition terms (New, Like New, Very Good, Good, Acceptable)
        - Make title searchable and under 80 characters
        - Include 3-5 relevant keywords for searching
        - No extra text, just the JSON
        """
        
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
                                "url": "data:image/jpeg;base64,\(base64Image)"
                            ]
                        ]
                    ]
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.1
        ]
        
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid OpenAI endpoint")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request body: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ OpenAI network error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                print("❌ No data received from OpenAI")
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    
                    // Check for API errors
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        print("❌ OpenAI API error: \(message)")
                        completion(nil)
                        return
                    }
                    
                    // Parse successful response
                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        print("📝 OpenAI response: \(content)")
                        
                        // Parse the JSON content
                        if let contentData = content.data(using: .utf8) {
                            do {
                                if let analysisJson = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                                    let result = OpenAIAnalysisResult(
                                        name: analysisJson["name"] as? String ?? "Unknown Item",
                                        brand: analysisJson["brand"] as? String ?? "",
                                        category: analysisJson["category"] as? String ?? "Other",
                                        condition: analysisJson["condition"] as? String ?? "Used",
                                        title: analysisJson["title"] as? String ?? "Item for Sale",
                                        description: analysisJson["description"] as? String ?? "Item in good condition",
                                        keywords: analysisJson["keywords"] as? [String] ?? []
                                    )
                                    
                                    print("✅ Parsed OpenAI result: \(result.name) by \(result.brand)")
                                    completion(result)
                                } else {
                                    print("❌ Content is not valid JSON object")
                                    completion(nil)
                                }
                            } catch {
                                print("❌ Error parsing content as JSON: \(error)")
                                completion(nil)
                            }
                        } else {
                            print("❌ Could not convert content to data")
                            completion(nil)
                        }
                    } else {
                        print("❌ Unexpected OpenAI response structure")
                        completion(nil)
                    }
                } else {
                    print("❌ Response is not valid JSON")
                    completion(nil)
                }
            } catch {
                print("❌ Error parsing OpenAI response: \(error)")
                completion(nil)
            }
        }.resume()
    }
}

// MARK: - RAPIDAPI SERVICE FOR EBAY SOLD COMPS
class RapidAPIService: ObservableObject {
    private let apiKey = Configuration.rapidAPIKey
    private let baseURL = "https://ebay-average-selling-price.p.rapidapi.com"
    
    func searchSoldItems(query: String, completion: @escaping ([EbaySoldItem]) -> Void) {
        guard !apiKey.isEmpty else {
            print("❌ RapidAPI key not configured")
            completion([])
            return
        }
        
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard !cleanQuery.isEmpty else {
            print("❌ Empty search query")
            completion([])
            return
        }
        
        print("🔍 Searching eBay sold comps for: \(cleanQuery)")
        
        let endpoint = "\(baseURL)/findCompletedItems"
        
        var components = URLComponents(string: endpoint)!
        components.queryItems = [
            URLQueryItem(name: "keywords", value: cleanQuery),
            URLQueryItem(name: "max_search_results", value: "20"),
            URLQueryItem(name: "category_id", value: "9355"), // Collectibles, but can be adjusted
            URLQueryItem(name: "site_id", value: "0") // US site
        ]
        
        guard let url = components.url else {
            print("❌ Invalid RapidAPI URL")
            completion([])
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("ebay-average-selling-price.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ RapidAPI network error: \(error)")
                completion([])
                return
            }
            
            guard let data = data else {
                print("❌ No data received from RapidAPI")
                completion([])
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let soldItems = self.parseRapidAPIResponse(json)
                    print("✅ Found \(soldItems.count) sold items")
                    completion(soldItems)
                } else {
                    print("❌ Invalid RapidAPI response format")
                    completion([])
                }
            } catch {
                print("❌ Error parsing RapidAPI response: \(error)")
                completion([])
            }
        }.resume()
    }
    
    private func parseRapidAPIResponse(_ json: [String: Any]) -> [EbaySoldItem] {
        var soldItems: [EbaySoldItem] = []
        
        // Parse based on RapidAPI eBay Average Selling Price response structure
        if let results = json["results"] as? [[String: Any]] {
            for result in results {
                if let title = result["title"] as? String,
                   let priceString = result["price"] as? String,
                   let price = extractPrice(from: priceString) {
                    
                    let condition = result["condition"] as? String
                    let shipping = extractPrice(from: result["shipping"] as? String ?? "")
                    let soldDateString = result["sold_date"] as? String
                    let soldDate = parseSoldDate(soldDateString)
                    let bestOfferAccepted = result["best_offer_accepted"] as? Bool
                    
                    let soldItem = EbaySoldItem(
                        title: title,
                        price: price,
                        condition: condition,
                        soldDate: soldDate,
                        shipping: shipping,
                        bestOfferAccepted: bestOfferAccepted
                    )
                    
                    soldItems.append(soldItem)
                }
            }
        }
        
        return soldItems
    }
    
    private func extractPrice(from string: String) -> Double? {
        let cleanString = string.replacingOccurrences(of: "$", with: "")
                                .replacingOccurrences(of: ",", with: "")
                                .trimmingCharacters(in: .whitespaces)
        return Double(cleanString)
    }
    
    private func parseSoldDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try alternative format
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: dateString)
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
        request.timeoutInterval = 30
        
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
            
            print("✅ Google Sheets sync completed")
            completion(true)
        }.resume()
    }
}

// MARK: - INVENTORY MANAGER SERVICE
class InventoryManager: ObservableObject {
    @Published var items: [InventoryItem] = []
    
    private let userDefaults = UserDefaults.standard
    private let itemsKey = "SavedInventoryItems"
    private let migrationKey = "DataMigrationV6_Completed"
    private let categoryCountersKey = "CategoryCounters"
    
    @Published var categoryCounters: [String: Int] = [:]
    
    init() {
        performDataMigrationIfNeeded()
        loadCategoryCounters()
        loadItems()
    }
    
    private func performDataMigrationIfNeeded() {
        if !userDefaults.bool(forKey: migrationKey) {
            print("🔄 Performing data migration V6...")
            userDefaults.removeObject(forKey: itemsKey)
            userDefaults.removeObject(forKey: categoryCountersKey)
            userDefaults.set(true, forKey: migrationKey)
            print("✅ Data migration V6 completed")
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

struct EbaySoldItem {
    let title: String
    let price: Double
    let condition: String?
    let soldDate: Date?
    let shipping: Double?
    let bestOfferAccepted: Bool?
}
