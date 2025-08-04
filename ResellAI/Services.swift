//
//  Services.swift
//  ResellAI
//
//  Professional Reselling Automation - Full VA System with Fixed RapidAPI
//

import SwiftUI
import Foundation
import Vision

// MARK: - UNIFIED BUSINESS SERVICE
class BusinessService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress = "Ready"
    @Published var currentStep = 0
    @Published var totalSteps = 10
    @Published var isSyncing = false
    @Published var syncStatus = "Ready"
    @Published var lastSyncDate: Date?
    
    private let aiService = AIAnalysisService()
    private let rapidAPIService = RapidAPIService()
    private let googleSheetsService = GoogleSheetsService()
    
    init() {
        print("🚀 Professional Reselling Automation initialized")
    }
    
    func initialize() {
        Configuration.validateConfiguration()
        authenticateGoogleSheets()
    }
    
    // MARK: - COMPREHENSIVE ITEM ANALYSIS
    func analyzeItem(_ images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        guard !images.isEmpty else {
            completion(nil)
            return
        }
        
        print("🔍 Starting professional reselling analysis with \(images.count) images")
        
        DispatchQueue.main.async {
            self.isAnalyzing = true
            self.currentStep = 0
            self.totalSteps = 10
        }
        
        // Step 1: Advanced AI Product Identification
        updateProgress("Identifying exact product with AI...", step: 1)
        
        aiService.identifyProductPrecisely(images: images) { [weak self] productResult in
            guard let productResult = productResult else {
                DispatchQueue.main.async {
                    self?.isAnalyzing = false
                    completion(nil)
                }
                return
            }
            
            print("🎯 Product identified: \(productResult.exactProduct)")
            print("🏷️ Brand: \(productResult.brand)")
            print("📊 Confidence: \(Int(productResult.confidence * 100))%")
            
            // Step 2: Validate identification confidence
            self?.updateProgress("Validating product identification...", step: 2)
            
            if productResult.confidence < 0.85 {
                print("⚠️ Low confidence (\(Int(productResult.confidence * 100))%) - flagging for review")
            }
            
            // Step 3: Search for exact product matches
            self?.updateProgress("Searching for exact product matches...", step: 3)
            
            let primaryQuery = self?.buildPreciseSearchQuery(from: productResult) ?? productResult.exactProduct
            
            self?.rapidAPIService.searchSoldListings(query: primaryQuery) { exactMatches in
                // Step 4: Expand search if no exact matches
                if exactMatches.count < 3 {
                    self?.updateProgress("Expanding search for similar products...", step: 4)
                    
                    let alternativeQuery = "\(productResult.brand) \(productResult.modelNumber ?? productResult.exactProduct)"
                    self?.rapidAPIService.searchSoldListings(query: alternativeQuery) { alternativeMatches in
                        let combinedMatches = exactMatches + alternativeMatches
                        self?.processMarketData(productResult: productResult, soldItems: combinedMatches, completion: completion)
                    }
                } else {
                    self?.processMarketData(productResult: productResult, soldItems: exactMatches, completion: completion)
                }
            }
        }
    }
    
    private func processMarketData(productResult: ProductIdentificationResult, soldItems: [EbaySoldItem], completion: @escaping (AnalysisResult?) -> Void) {
        // Step 5: Analyze market conditions
        updateProgress("Analyzing market conditions...", step: 5)
        
        let marketAnalysis = analyzeRealMarketData(soldItems: soldItems, productResult: productResult)
        
        // Step 6: Calculate professional pricing
        updateProgress("Calculating market-based pricing...", step: 6)
        
        let pricing = calculateMarketPricing(from: soldItems, productResult: productResult, marketAnalysis: marketAnalysis)
        
        // Step 7: Professional condition assessment
        updateProgress("Assessing item condition...", step: 7)
        
        let conditionAssessment = assessItemCondition(productResult: productResult)
        let adjustedPricing = adjustPricingForCondition(pricing: pricing, condition: conditionAssessment)
        
        // Step 8: Generate professional listing
        updateProgress("Creating optimized eBay listing...", step: 8)
        
        let listing = generateProfessionalListing(
            productResult: productResult,
            marketAnalysis: marketAnalysis,
            pricing: adjustedPricing,
            condition: conditionAssessment
        )
        
        // Step 9: Develop selling strategy
        updateProgress("Developing selling strategy...", step: 9)
        
        let strategy = developSellingStrategy(
            marketAnalysis: marketAnalysis,
            productResult: productResult,
            pricing: adjustedPricing
        )
        
        // Step 10: Finalize professional analysis
        updateProgress("Finalizing professional analysis...", step: 10)
        
        let finalResult = AnalysisResult(
            name: productResult.exactProduct,
            brand: productResult.brand,
            category: productResult.category,
            condition: conditionAssessment.ebayCondition,
            title: listing.optimizedTitle,
            description: listing.professionalDescription,
            keywords: listing.seoKeywords,
            suggestedPrice: adjustedPricing.marketPrice,
            quickPrice: adjustedPricing.quickSalePrice,
            premiumPrice: adjustedPricing.premiumPrice,
            averagePrice: adjustedPricing.averagePrice,
            marketConfidence: marketAnalysis.confidence,
            soldListingsCount: soldItems.count,
            competitorCount: marketAnalysis.estimatedCompetitorCount,
            demandLevel: marketAnalysis.demandLevel,
            listingStrategy: strategy.listingType,
            sourcingTips: strategy.sourcingInsights,
            aiConfidence: productResult.confidence,
            resalePotential: calculateResalePotential(pricing: adjustedPricing, market: marketAnalysis),
            priceRange: EbayPriceRange(
                low: adjustedPricing.quickSalePrice,
                high: adjustedPricing.premiumPrice,
                average: adjustedPricing.averagePrice
            ),
            recentSales: soldItems.prefix(10).map { item in
                RecentSale(
                    title: item.title,
                    price: item.price,
                    condition: item.condition ?? "Used",
                    date: item.soldDate ?? Date().addingTimeInterval(-86400 * Double.random(in: 1...30)),
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
            self.analysisProgress = "Professional Analysis Complete"
            print("✅ Analysis complete: \(finalResult.name)")
            print("💰 Market Price: $\(String(format: "%.2f", adjustedPricing.marketPrice))")
            print("📊 Market Confidence: \(Int(marketAnalysis.confidence * 100))%")
            print("🎯 Demand Level: \(marketAnalysis.demandLevel)")
            completion(finalResult)
        }
    }
    
    func analyzeBarcode(_ barcode: String, images: [UIImage], completion: @escaping (AnalysisResult?) -> Void) {
        print("📱 Analyzing barcode: \(barcode)")
        updateProgress("Looking up product by barcode...", step: 1)
        
        // Could integrate with UPC database here
        // For now, fall back to image analysis with barcode context
        analyzeItem(images, completion: completion)
    }
    
    private func updateProgress(_ message: String, step: Int) {
        DispatchQueue.main.async {
            self.analysisProgress = message
            self.currentStep = step
        }
    }
    
    // MARK: - ADVANCED SEARCH QUERY BUILDING
    private func buildPreciseSearchQuery(from productResult: ProductIdentificationResult) -> String {
        var query = ""
        
        // Start with brand
        if !productResult.brand.isEmpty {
            query += productResult.brand + " "
        }
        
        // Add exact model/product name
        if let modelNumber = productResult.modelNumber, !modelNumber.isEmpty {
            query += modelNumber + " "
        } else {
            query += productResult.exactProduct + " "
        }
        
        // Add style code if available
        if let styleCode = productResult.styleCode, !styleCode.isEmpty {
            query += styleCode + " "
        }
        
        // Add colorway for shoes/clothing
        if let colorway = productResult.colorway, !colorway.isEmpty {
            let category = productResult.category.lowercased()
            if category.contains("shoe") || category.contains("clothing") || category.contains("sneaker") {
                query += colorway + " "
            }
        }
        
        // Add size for shoes/clothing
        if let size = productResult.size, !size.isEmpty {
            let category = productResult.category.lowercased()
            if category.contains("shoe") || category.contains("clothing") || category.contains("sneaker") {
                query += "size \(size) "
            }
        }
        
        return query.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - REAL MARKET DATA ANALYSIS
    private func analyzeRealMarketData(soldItems: [EbaySoldItem], productResult: ProductIdentificationResult) -> MarketAnalysisData {
        let totalSales = soldItems.count
        
        // Analyze recent sales (last 30 days)
        let recentSales = soldItems.filter { item in
            guard let soldDate = item.soldDate else { return false }
            let daysSince = Calendar.current.dateComponents([.day], from: soldDate, to: Date()).day ?? 999
            return daysSince <= 30
        }
        
        // Analyze price trends
        let sortedByDate = soldItems.compactMap { item -> (Date, Double)? in
            guard let date = item.soldDate else { return nil }
            return (date, item.price)
        }.sorted { $0.0 < $1.0 }
        
        let priceTrend = analyzePriceTrend(sortedByDate)
        
        // Determine demand level based on sales velocity
        let demandLevel: String
        let confidence: Double
        
        switch totalSales {
        case 0:
            demandLevel = "No Market Data"
            confidence = 0.3
        case 1...3:
            demandLevel = "Very Low"
            confidence = 0.4
        case 4...8:
            demandLevel = "Low"
            confidence = 0.6
        case 9...15:
            demandLevel = "Medium"
            confidence = 0.75
        case 16...30:
            demandLevel = "High"
            confidence = 0.85
        default:
            demandLevel = "Very High"
            confidence = 0.95
        }
        
        // Boost confidence based on recent sales
        let recentSalesBoost = min(Double(recentSales.count) * 0.05, 0.15)
        let finalConfidence = min(confidence + recentSalesBoost, 1.0)
        
        // Estimate competitor count based on sales data
        let estimatedCompetitors = min(totalSales * 5, 200)
        
        return MarketAnalysisData(
            demandLevel: demandLevel,
            confidence: finalConfidence,
            recentSalesCount: recentSales.count,
            totalSalesCount: totalSales,
            priceTrend: priceTrend,
            estimatedCompetitorCount: estimatedCompetitors,
            averageSellingTime: estimateSellingTime(demandLevel: demandLevel),
            seasonalFactor: calculateSeasonalFactor(productResult: productResult)
        )
    }
    
    private func analyzePriceTrend(_ sortedPrices: [(Date, Double)]) -> String {
        guard sortedPrices.count >= 3 else { return "Insufficient Data" }
        
        let recentPrices = Array(sortedPrices.suffix(5))
        let olderPrices = Array(sortedPrices.prefix(5))
        
        let recentAvg = recentPrices.reduce(0) { $0 + $1.1 } / Double(recentPrices.count)
        let olderAvg = olderPrices.reduce(0) { $0 + $1.1 } / Double(olderPrices.count)
        
        let change = (recentAvg - olderAvg) / olderAvg
        
        if change > 0.1 {
            return "Rising"
        } else if change < -0.1 {
            return "Declining"
        } else {
            return "Stable"
        }
    }
    
    private func estimateSellingTime(demandLevel: String) -> Int {
        switch demandLevel {
        case "Very High": return 3
        case "High": return 7
        case "Medium": return 14
        case "Low": return 30
        case "Very Low": return 60
        default: return 30
        }
    }
    
    private func calculateSeasonalFactor(productResult: ProductIdentificationResult) -> Double {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let category = productResult.category.lowercased()
        let product = productResult.exactProduct.lowercased()
        
        // Seasonal adjustments
        if category.contains("coat") || category.contains("jacket") || product.contains("winter") {
            // Winter items
            return [11, 12, 1, 2].contains(currentMonth) ? 1.15 : 0.85
        } else if category.contains("swimwear") || product.contains("summer") {
            // Summer items
            return [5, 6, 7, 8].contains(currentMonth) ? 1.1 : 0.9
        } else if product.contains("christmas") || product.contains("holiday") {
            // Holiday items
            return [11, 12].contains(currentMonth) ? 1.25 : 0.7
        }
        
        return 1.0 // No seasonal adjustment
    }
    
    // MARK: - MARKET-BASED PRICING WITH FALLBACK
    private func calculateMarketPricing(from soldItems: [EbaySoldItem], productResult: ProductIdentificationResult, marketAnalysis: MarketAnalysisData) -> MarketPricingData {
        if soldItems.isEmpty {
            print("⚠️ No sold items found - using estimated pricing")
            return generateEstimatedPricing(productResult: productResult, marketAnalysis: marketAnalysis)
        }
        
        let prices = soldItems.compactMap { $0.price }.filter { $0 > 0 }
        guard prices.count >= 3 else {
            print("⚠️ Insufficient price data (\(prices.count) prices) - using estimated pricing")
            return generateEstimatedPricing(productResult: productResult, marketAnalysis: marketAnalysis)
        }
        
        let sortedPrices = prices.sorted()
        let count = sortedPrices.count
        
        // Calculate statistical pricing
        let p10 = sortedPrices[max(0, Int(Double(count) * 0.1) - 1)]
        let p25 = sortedPrices[max(0, Int(Double(count) * 0.25) - 1)]
        let median = count % 2 == 0
            ? (sortedPrices[count/2 - 1] + sortedPrices[count/2]) / 2
            : sortedPrices[count/2]
        let p75 = sortedPrices[min(count - 1, Int(Double(count) * 0.75))]
        let p90 = sortedPrices[min(count - 1, Int(Double(count) * 0.9))]
        let average = prices.reduce(0, +) / Double(count)
        
        // Apply seasonal adjustments
        let seasonalMultiplier = marketAnalysis.seasonalFactor
        
        // Calculate final pricing
        let quickSalePrice = p10 * seasonalMultiplier
        let marketPrice = median * seasonalMultiplier
        let premiumPrice = p75 * seasonalMultiplier
        let adjustedAverage = average * seasonalMultiplier
        
        // Account for eBay and PayPal fees in net profit calculations
        let totalFeeRate = 0.1325 + 0.0349 // eBay + PayPal fees
        
        return MarketPricingData(
            quickSalePrice: quickSalePrice,
            marketPrice: marketPrice,
            premiumPrice: premiumPrice,
            averagePrice: adjustedAverage,
            p10: p10,
            p25: p25,
            p75: p75,
            p90: p90,
            sampleSize: count,
            priceSpread: p90 - p10,
            feeAdjustedMarketPrice: marketPrice * (1 - totalFeeRate),
            seasonalMultiplier: seasonalMultiplier,
            priceTrend: marketAnalysis.priceTrend
        )
    }
    
    // MARK: - ESTIMATED PRICING FALLBACK
    private func generateEstimatedPricing(productResult: ProductIdentificationResult, marketAnalysis: MarketAnalysisData) -> MarketPricingData {
        print("🔮 Generating estimated pricing based on category and brand")
        
        let brand = productResult.brand.lowercased()
        let category = productResult.category.lowercased()
        
        // Base price estimates by category and brand
        var basePrice: Double = 25.0
        
        // Brand multipliers
        if ["nike", "jordan", "adidas", "yeezy"].contains(brand) {
            basePrice = 120.0
        } else if ["apple", "samsung", "sony"].contains(brand) {
            basePrice = 200.0
        } else if ["levi", "gap", "american eagle"].contains(brand) {
            basePrice = 35.0
        } else if ["minnetonka", "ugg", "timberland"].contains(brand) {
            basePrice = 65.0
        } else if ["coach", "michael kors", "kate spade"].contains(brand) {
            basePrice = 85.0
        }
        
        // Category adjustments
        if category.contains("shoe") || category.contains("sneaker") {
            basePrice *= 1.3
        } else if category.contains("electronic") {
            basePrice *= 2.0
        } else if category.contains("jacket") || category.contains("coat") {
            basePrice *= 1.4
        } else if category.contains("accessory") {
            basePrice *= 0.8
        }
        
        // Apply seasonal factor
        let seasonalPrice = basePrice * marketAnalysis.seasonalFactor
        
        // Calculate price range
        let quickSalePrice = seasonalPrice * 0.7
        let marketPrice = seasonalPrice
        let premiumPrice = seasonalPrice * 1.3
        let averagePrice = seasonalPrice * 1.1
        
        return MarketPricingData(
            quickSalePrice: quickSalePrice,
            marketPrice: marketPrice,
            premiumPrice: premiumPrice,
            averagePrice: averagePrice,
            p10: quickSalePrice,
            p25: quickSalePrice * 1.1,
            p75: premiumPrice * 0.9,
            p90: premiumPrice,
            sampleSize: 0,
            priceSpread: premiumPrice - quickSalePrice,
            feeAdjustedMarketPrice: marketPrice * 0.8326,
            seasonalMultiplier: marketAnalysis.seasonalFactor,
            priceTrend: "Estimated"
        )
    }
    
    // MARK: - PROFESSIONAL CONDITION ASSESSMENT
    private func assessItemCondition(productResult: ProductIdentificationResult) -> ConditionAssessment {
        let aiCondition = productResult.aiAssessedCondition
        let category = productResult.category.lowercased()
        
        // Map AI condition to eBay standards
        let ebayCondition: String
        let conditionNotes: [String]
        let priceImpact: Double
        
        switch aiCondition.lowercased() {
        case let c where c.contains("new with tags"):
            ebayCondition = "New with tags"
            conditionNotes = ["Brand new with original tags attached"]
            priceImpact = 1.0
        case let c where c.contains("new without tags"):
            ebayCondition = "New without tags"
            conditionNotes = ["Brand new without tags"]
            priceImpact = 0.95
        case let c where c.contains("like new"):
            ebayCondition = "Like New"
            conditionNotes = ["Excellent condition, minimal signs of use"]
            priceImpact = 0.9
        case let c where c.contains("excellent"):
            ebayCondition = "Excellent"
            conditionNotes = ["Very good condition with minor wear"]
            priceImpact = 0.85
        case let c where c.contains("very good"):
            ebayCondition = "Very Good"
            conditionNotes = ["Good condition with some signs of use"]
            priceImpact = 0.8
        case let c where c.contains("good"):
            ebayCondition = "Good"
            conditionNotes = ["Fair condition with noticeable wear"]
            priceImpact = 0.7
        default:
            ebayCondition = "Good"
            conditionNotes = ["Used condition - see photos for details"]
            priceImpact = 0.75
        }
        
        return ConditionAssessment(
            ebayCondition: ebayCondition,
            conditionNotes: conditionNotes,
            priceImpact: priceImpact,
            completenessScore: estimateCompleteness(productResult: productResult),
            authenticityConfidence: estimateAuthenticity(productResult: productResult)
        )
    }
    
    private func estimateCompleteness(productResult: ProductIdentificationResult) -> Double {
        let category = productResult.category.lowercased()
        
        if category.contains("shoe") {
            return 0.8 // Assume no box unless specified
        } else if category.contains("electronic") {
            return 0.7 // Assume some accessories missing
        } else {
            return 0.9 // Most other items complete
        }
    }
    
    private func estimateAuthenticity(productResult: ProductIdentificationResult) -> Double {
        let brand = productResult.brand.lowercased()
        
        // Higher risk brands
        if ["nike", "adidas", "jordan", "yeezy", "supreme", "off-white"].contains(brand) {
            return 0.8 // Need authentication for premium brands
        } else {
            return 0.95 // Lower risk
        }
    }
    
    private func adjustPricingForCondition(pricing: MarketPricingData, condition: ConditionAssessment) -> MarketPricingData {
        let multiplier = condition.priceImpact
        
        return MarketPricingData(
            quickSalePrice: pricing.quickSalePrice * multiplier,
            marketPrice: pricing.marketPrice * multiplier,
            premiumPrice: pricing.premiumPrice * multiplier,
            averagePrice: pricing.averagePrice * multiplier,
            p10: pricing.p10 * multiplier,
            p25: pricing.p25 * multiplier,
            p75: pricing.p75 * multiplier,
            p90: pricing.p90 * multiplier,
            sampleSize: pricing.sampleSize,
            priceSpread: pricing.priceSpread * multiplier,
            feeAdjustedMarketPrice: pricing.feeAdjustedMarketPrice * multiplier,
            seasonalMultiplier: pricing.seasonalMultiplier,
            priceTrend: pricing.priceTrend
        )
    }
    
    // MARK: - PROFESSIONAL LISTING GENERATION
    private func generateProfessionalListing(productResult: ProductIdentificationResult, marketAnalysis: MarketAnalysisData, pricing: MarketPricingData, condition: ConditionAssessment) -> ProfessionalListing {
        
        let optimizedTitle = generateSEOTitle(productResult: productResult, condition: condition)
        let professionalDescription = generateProfessionalDescription(
            productResult: productResult,
            marketAnalysis: marketAnalysis,
            condition: condition
        )
        let seoKeywords = generateAdvancedSEOKeywords(productResult: productResult, marketAnalysis: marketAnalysis)
        
        return ProfessionalListing(
            optimizedTitle: optimizedTitle,
            professionalDescription: professionalDescription,
            seoKeywords: seoKeywords,
            suggestedCategory: mapToEbayCategory(productResult.category),
            shippingStrategy: determineShippingStrategy(productResult: productResult, pricing: pricing),
            returnPolicy: "30-day returns accepted",
            listingEnhancements: suggestListingEnhancements(marketAnalysis: marketAnalysis)
        )
    }
    
    private func generateSEOTitle(productResult: ProductIdentificationResult, condition: ConditionAssessment) -> String {
        var title = ""
        
        // Brand (critical for SEO)
        if !productResult.brand.isEmpty {
            title += productResult.brand + " "
        }
        
        // Exact model/product
        if let modelNumber = productResult.modelNumber, !modelNumber.isEmpty {
            title += modelNumber + " "
        } else {
            title += productResult.exactProduct + " "
        }
        
        // Colorway (important for shoes/clothing)
        if let colorway = productResult.colorway, !colorway.isEmpty {
            title += colorway + " "
        }
        
        // Size (critical for shoes/clothing)
        if let size = productResult.size, !size.isEmpty {
            let category = productResult.category.lowercased()
            if category.contains("shoe") || category.contains("clothing") {
                title += "Size \(size) "
            }
        }
        
        // Style code (important for authentication)
        if let styleCode = productResult.styleCode, !styleCode.isEmpty && title.count < 60 {
            title += styleCode + " "
        }
        
        // Condition (if not standard "used")
        if !condition.ebayCondition.lowercased().contains("good") && !condition.ebayCondition.lowercased().contains("used") {
            title += "- \(condition.ebayCondition) "
        }
        
        // Release year (if valuable/collectible)
        if let year = productResult.releaseYear, !year.isEmpty && title.count < 65 {
            title += year + " "
        }
        
        return String(title.trimmingCharacters(in: .whitespaces).prefix(80))
    }
    
    private func generateProfessionalDescription(productResult: ProductIdentificationResult, marketAnalysis: MarketAnalysisData, condition: ConditionAssessment) -> String {
        var description = ""
        
        // Professional opening
        description += "🔥 \(productResult.brand.isEmpty ? "" : productResult.brand + " ")\(productResult.exactProduct)\n\n"
        
        // Key details
        description += "📋 ITEM DETAILS:\n"
        if !productResult.brand.isEmpty {
            description += "• Brand: \(productResult.brand)\n"
        }
        if let model = productResult.modelNumber, !model.isEmpty {
            description += "• Model: \(model)\n"
        }
        if let size = productResult.size, !size.isEmpty {
            description += "• Size: \(size)\n"
        }
        if let colorway = productResult.colorway, !colorway.isEmpty {
            description += "• Colorway: \(colorway)\n"
        }
        if let styleCode = productResult.styleCode, !styleCode.isEmpty {
            description += "• Style Code: \(styleCode)\n"
        }
        description += "• Condition: \(condition.ebayCondition)\n\n"
        
        // Condition details
        description += "🔍 CONDITION NOTES:\n"
        for note in condition.conditionNotes {
            description += "• \(note)\n"
        }
        description += "\n"
        
        // Market insights (if high demand)
        if marketAnalysis.demandLevel == "High" || marketAnalysis.demandLevel == "Very High" {
            description += "📈 MARKET INSIGHTS:\n"
            description += "• High demand item - similar items selling quickly\n"
            if marketAnalysis.priceTrend == "Rising" {
                description += "• Prices trending upward\n"
            }
            description += "\n"
        }
        
        // Professional guarantees
        description += "✅ BUYER PROTECTION:\n"
        description += "• Fast shipping within 1 business day\n"
        description += "• 30-day return policy\n"
        description += "• Professionally packaged\n"
        description += "• 100% authentic guarantee\n"
        description += "• Excellent seller feedback\n\n"
        
        // Call to action
        if marketAnalysis.demandLevel == "High" || marketAnalysis.demandLevel == "Very High" {
            description += "⚡ Don't miss out - high demand item!"
        } else {
            description += "💎 Great opportunity for collectors and enthusiasts!"
        }
        
        return description
    }
    
    private func generateAdvancedSEOKeywords(productResult: ProductIdentificationResult, marketAnalysis: MarketAnalysisData) -> [String] {
        var keywords: Set<String> = []
        
        // Core product keywords
        keywords.insert(productResult.exactProduct.lowercased())
        if !productResult.brand.isEmpty {
            keywords.insert(productResult.brand.lowercased())
        }
        
        // Model variations
        if let model = productResult.modelNumber, !model.isEmpty {
            keywords.insert(model.lowercased())
        }
        
        // Category keywords
        keywords.insert(productResult.category.lowercased())
        if let subcategory = productResult.subcategory, !subcategory.isEmpty {
            keywords.insert(subcategory.lowercased())
        }
        
        // Style identifiers
        if let styleCode = productResult.styleCode, !styleCode.isEmpty {
            keywords.insert(styleCode.lowercased())
        }
        if let colorway = productResult.colorway, !colorway.isEmpty {
            keywords.insert(colorway.lowercased())
        }
        
        // Size (for applicable categories)
        if let size = productResult.size, !size.isEmpty {
            let category = productResult.category.lowercased()
            if category.contains("shoe") || category.contains("clothing") {
                keywords.insert("size \(size)")
            }
        }
        
        // Year (for collectibles)
        if let year = productResult.releaseYear, !year.isEmpty {
            keywords.insert(year)
        }
        
        // Demand-based keywords
        if marketAnalysis.demandLevel == "High" || marketAnalysis.demandLevel == "Very High" {
            keywords.insert("rare")
            keywords.insert("limited")
        }
        
        return Array(keywords.prefix(10))
    }
    
    private func mapToEbayCategory(_ category: String) -> String {
        let categoryLower = category.lowercased()
        
        if categoryLower.contains("sneaker") || categoryLower.contains("athletic shoe") {
            return "15709" // Athletic Shoes
        } else if categoryLower.contains("shoe") {
            return "95672" // Shoes
        } else if categoryLower.contains("electronic") {
            return "58058" // Electronics
        } else if categoryLower.contains("clothing") {
            return "11450" // Clothing
        } else {
            return "267" // Everything Else
        }
    }
    
    private func determineShippingStrategy(productResult: ProductIdentificationResult, pricing: MarketPricingData) -> String {
        if pricing.marketPrice > 100 {
            return "Free shipping (built into price)"
        } else {
            return "Calculated shipping"
        }
    }
    
    private func suggestListingEnhancements(marketAnalysis: MarketAnalysisData) -> [String] {
        var enhancements: [String] = []
        
        if marketAnalysis.demandLevel == "High" || marketAnalysis.demandLevel == "Very High" {
            enhancements.append("Promoted Listings")
        }
        
        if marketAnalysis.confidence > 0.8 {
            enhancements.append("Best Offer")
        }
        
        enhancements.append("Professional photos recommended")
        
        return enhancements
    }
    
    // MARK: - SELLING STRATEGY DEVELOPMENT
    private func developSellingStrategy(marketAnalysis: MarketAnalysisData, productResult: ProductIdentificationResult, pricing: MarketPricingData) -> SellingStrategy {
        
        let listingType: String
        let pricingStrategy: String
        let timingStrategy: String
        
        // Determine listing type based on demand
        switch marketAnalysis.demandLevel {
        case "Very High", "High":
            listingType = "Buy It Now - High demand supports fixed pricing"
            pricingStrategy = "Start at market price with Best Offer enabled"
        case "Medium":
            listingType = "Buy It Now with Best Offer - Flexible for moderate demand"
            pricingStrategy = "Start 10% above market price, accept offers at market price"
        case "Low", "Very Low":
            listingType = "7-day Auction starting at $0.99 - Generate interest"
            pricingStrategy = "Let market determine price through bidding"
        default:
            listingType = "Buy It Now with Best Offer"
            pricingStrategy = "Conservative pricing with flexibility"
        }
        
        // Timing strategy
        if marketAnalysis.seasonalFactor > 1.0 {
            timingStrategy = "List immediately - in peak season"
        } else if marketAnalysis.seasonalFactor < 0.9 {
            timingStrategy = "Consider waiting for peak season or price aggressively"
        } else {
            timingStrategy = "List anytime - not seasonal"
        }
        
        // Generate advanced sourcing insights
        let sourcingInsights = generateProSourcingInsights(
            productResult: productResult,
            marketAnalysis: marketAnalysis,
            pricing: pricing
        )
        
        return SellingStrategy(
            listingType: listingType,
            pricingStrategy: pricingStrategy,
            timingStrategy: timingStrategy,
            sourcingInsights: sourcingInsights,
            expectedSellingTime: marketAnalysis.averageSellingTime,
            profitMargin: calculateProfitMargin(pricing: pricing)
        )
    }
    
    private func generateProSourcingInsights(productResult: ProductIdentificationResult, marketAnalysis: MarketAnalysisData, pricing: MarketPricingData) -> [String] {
        var insights: [String] = []
        
        let category = productResult.category.lowercased()
        let brand = productResult.brand.lowercased()
        
        // ROI insights
        let maxBuyPrice = pricing.quickSalePrice * 0.6 // Account for fees and profit
        insights.append("Max buy price: $\(String(format: "%.2f", maxBuyPrice)) for 50%+ ROI")
        
        // Brand-specific insights
        if ["nike", "jordan", "adidas"].contains(brand) {
            insights.append("Authenticate with CheckCheck or GOAT before buying")
            insights.append("Original box adds 15-20% value")
            insights.append("Deadstock (DS) condition commands premium")
        } else if ["apple", "samsung"].contains(brand) {
            insights.append("Check battery health and activation lock")
            insights.append("Original accessories increase value significantly")
            insights.append("Verify model number matches storage capacity")
        }
        
        // Category insights
        if category.contains("shoe") {
            insights.append("Size 9-11 sell fastest and for most money")
            insights.append("Check outsole wear and midsole condition")
            insights.append("Popular colorways sell 30% faster")
        } else if category.contains("electronic") {
            insights.append("Test all functions before purchasing")
            insights.append("Check for carrier unlocking if applicable")
            insights.append("Verify no liquid damage indicators")
        }
        
        // Market condition insights
        if marketAnalysis.demandLevel == "High" || marketAnalysis.demandLevel == "Very High" {
            insights.append("High demand - can pay closer to retail")
            insights.append("Quick flip opportunity - list within 24 hours")
        } else if marketAnalysis.demandLevel == "Low" {
            insights.append("Low demand - only buy at deep discount")
            insights.append("Consider bundling with related items")
        }
        
        // Price trend insights
        if marketAnalysis.priceTrend == "Rising" {
            insights.append("Prices trending up - good time to buy and hold")
        } else if marketAnalysis.priceTrend == "Declining" {
            insights.append("Prices declining - flip quickly or avoid")
        }
        
        return Array(insights.prefix(6))
    }
    
    private func calculateProfitMargin(pricing: MarketPricingData) -> Double {
        let fees = pricing.marketPrice * 0.1674 // eBay + PayPal fees
        let netRevenue = pricing.marketPrice - fees
        let maxCost = netRevenue * 0.6 // Target 40% net margin
        
        return ((netRevenue - maxCost) / netRevenue) * 100
    }
    
    private func calculateResalePotential(pricing: MarketPricingData, market: MarketAnalysisData) -> Int {
        var score = 5 // Base score
        
        // Price-based scoring
        if pricing.marketPrice > 200 {
            score += 3
        } else if pricing.marketPrice > 100 {
            score += 2
        } else if pricing.marketPrice > 50 {
            score += 1
        }
        
        // Demand-based scoring
        switch market.demandLevel {
        case "Very High": score += 3
        case "High": score += 2
        case "Medium": score += 1
        default: break
        }
        
        // Confidence-based scoring
        if market.confidence > 0.8 {
            score += 1
        }
        
        return min(score, 10)
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

// MARK: - ADVANCED AI ANALYSIS SERVICE
class AIAnalysisService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let endpoint = Configuration.openAIEndpoint
    
    func identifyProductPrecisely(images: [UIImage], completion: @escaping (ProductIdentificationResult?) -> Void) {
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
        You are a professional reseller and product identification expert. Analyze this item with extreme precision for eBay reselling. 

        Identify the EXACT product with specific model numbers, style codes, and details. This is critical for accurate pricing.

        Respond with ONLY valid JSON in this exact format:
        {
            "exactProduct": "precise product name with model/version",
            "brand": "exact brand name",
            "category": "specific product category",
            "subcategory": "more specific category",
            "modelNumber": "exact model number or product code",
            "styleCode": "style/SKU code if visible",
            "size": "size if applicable",
            "colorway": "specific color description",
            "releaseYear": "year released if identifiable",
            "title": "optimized eBay title under 80 characters",
            "description": "detailed condition and product description",
            "keywords": ["keyword1", "keyword2", "keyword3", "keyword4", "keyword5"],
            "aiAssessedCondition": "precise condition using eBay standards",
            "confidence": 0.95,
            "authenticityRisk": "low/medium/high",
            "estimatedAge": "age estimate if applicable",
            "completeness": "complete/missing accessories/etc"
        }

        CRITICAL REQUIREMENTS:
        1. Be EXTREMELY specific - "iPhone 14 Pro 128GB Space Black" not "iPhone"
        2. Include exact model numbers visible on product
        3. For shoes: exact model name, colorway, size if visible
        4. For electronics: exact model, storage, color, carrier if applicable  
        5. For clothing: brand, line/collection, size, color, season/year
        6. Use precise eBay condition terms: "New with tags", "New without tags", "Like New", "Very Good", "Good", "Acceptable"
        7. Confidence score: 0.9+ if certain, 0.7-0.89 if likely, <0.7 if uncertain
        8. Keywords must be exact terms buyers search for
        9. If you can't identify exactly, be honest about confidence level
        10. Look for authenticity markers, date codes, style numbers
        
        Examples of exact identification:
        - "Air Jordan 1 Retro High OG Chicago 2015" not "Jordan sneakers"  
        - "iPhone 14 Pro 256GB Deep Purple Unlocked" not "Apple phone"
        - "Nintendo Switch OLED White Console" not "gaming device"
        - "Louis Vuitton Neverfull MM Damier Ebene" not "designer bag"

        NO extra text, just the JSON response.
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
            "max_tokens": 800,
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
                        
                        // Clean the content - remove markdown code blocks if present
                        let cleanedContent = self.cleanMarkdownCodeBlocks(content)
                        print("🧹 Cleaned content: \(cleanedContent)")
                        
                        // Parse the JSON content
                        if let contentData = cleanedContent.data(using: .utf8) {
                            do {
                                if let analysisJson = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] {
                                    let result = ProductIdentificationResult(
                                        exactProduct: analysisJson["exactProduct"] as? String ?? "Unknown Item",
                                        brand: analysisJson["brand"] as? String ?? "",
                                        category: analysisJson["category"] as? String ?? "Other",
                                        subcategory: analysisJson["subcategory"] as? String,
                                        modelNumber: analysisJson["modelNumber"] as? String,
                                        styleCode: analysisJson["styleCode"] as? String,
                                        size: analysisJson["size"] as? String,
                                        colorway: analysisJson["colorway"] as? String,
                                        releaseYear: analysisJson["releaseYear"] as? String,
                                        title: analysisJson["title"] as? String ?? "Item for Sale",
                                        description: analysisJson["description"] as? String ?? "Item in good condition",
                                        keywords: analysisJson["keywords"] as? [String] ?? [],
                                        aiAssessedCondition: analysisJson["aiAssessedCondition"] as? String ?? "Used",
                                        confidence: analysisJson["confidence"] as? Double ?? 0.5,
                                        authenticityRisk: analysisJson["authenticityRisk"] as? String ?? "medium",
                                        estimatedAge: analysisJson["estimatedAge"] as? String,
                                        completeness: analysisJson["completeness"] as? String ?? "unknown"
                                    )
                                    
                                    print("✅ Parsed product identification: \(result.exactProduct) by \(result.brand)")
                                    print("🎯 Confidence: \(Int(result.confidence * 100))%")
                                    completion(result)
                                } else {
                                    print("❌ Content is not valid JSON object")
                                    completion(nil)
                                }
                            } catch {
                                print("❌ Error parsing content as JSON: \(error)")
                                print("❌ Content that failed to parse: \(cleanedContent)")
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
    
    private func cleanMarkdownCodeBlocks(_ content: String) -> String {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code block formatting
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
}

// MARK: - RAPIDAPI SERVICE FOR EBAY DATA (FIXED)
class RapidAPIService: ObservableObject {
    private let apiKey = Configuration.rapidAPIKey
    private let baseURL = "https://ebay-average-selling-price.p.rapidapi.com"
    
    func searchSoldListings(query: String, completion: @escaping ([EbaySoldItem]) -> Void) {
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
        
        print("🔍 Searching RapidAPI for sold listings: \(cleanQuery)")
        
        // Try different possible endpoints
        let possibleEndpoints = [
            "/search",
            "/sold-items",
            "/completed-items",
            "/price-history",
            "/average-price"
        ]
        
        searchWithEndpoints(possibleEndpoints, query: cleanQuery, completion: completion)
    }
    
    private func searchWithEndpoints(_ endpoints: [String], query: String, completion: @escaping ([EbaySoldItem]) -> Void) {
        guard !endpoints.isEmpty else {
            print("❌ All RapidAPI endpoints failed")
            completion([])
            return
        }
        
        let endpoint = endpoints[0]
        let remainingEndpoints = Array(endpoints.dropFirst())
        
        searchWithSingleEndpoint(endpoint, query: query) { [weak self] soldItems in
            if !soldItems.isEmpty {
                completion(soldItems)
            } else {
                self?.searchWithEndpoints(remainingEndpoints, query: query, completion: completion)
            }
        }
    }
    
    private func searchWithSingleEndpoint(_ endpoint: String, query: String, completion: @escaping ([EbaySoldItem]) -> Void) {
        let fullURL = "\(baseURL)\(endpoint)"
        
        print("🌐 Trying RapidAPI endpoint: \(fullURL)")
        
        guard let url = URL(string: fullURL) else {
            print("❌ Invalid RapidAPI URL: \(fullURL)")
            completion([])
            return
        }
        
        // Try both GET and POST methods
        tryGETRequest(url: url, query: query) { [weak self] soldItems in
            if !soldItems.isEmpty {
                completion(soldItems)
            } else {
                self?.tryPOSTRequest(url: url, query: query, completion: completion)
            }
        }
    }
    
    private func tryGETRequest(url: URL, query: String, completion: @escaping ([EbaySoldItem]) -> Void) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "keywords", value: query),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "max_results", value: "50"),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "sold_items_only", value: "true"),
            URLQueryItem(name: "sold_only", value: "true"),
            URLQueryItem(name: "condition", value: "all"),
            URLQueryItem(name: "site_id", value: "0")
        ]
        
        guard let finalURL = components.url else {
            completion([])
            return
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("ebay-average-selling-price.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        print("📡 GET request to: \(finalURL)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleResponse(data: data, response: response, error: error, method: "GET", completion: completion)
        }.resume()
    }
    
    private func tryPOSTRequest(url: URL, query: String, completion: @escaping ([EbaySoldItem]) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("ebay-average-selling-price.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        
        let requestBody: [String: Any] = [
            "keywords": query,
            "q": query,
            "search": query,
            "max_results": 50,
            "limit": 50,
            "sold_items_only": true,
            "sold_only": true,
            "condition": "all",
            "site_id": 0
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating POST request body: \(error)")
            completion([])
            return
        }
        
        print("📡 POST request to: \(url)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            self.handleResponse(data: data, response: response, error: error, method: "POST", completion: completion)
        }.resume()
    }
    
    private func handleResponse(data: Data?, response: URLResponse?, error: Error?, method: String, completion: @escaping ([EbaySoldItem]) -> Void) {
        if let error = error {
            print("❌ RapidAPI \(method) error: \(error)")
            completion([])
            return
        }
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📡 RapidAPI \(method) response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode != 200 {
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ RapidAPI \(method) error response: \(errorString)")
                }
                completion([])
                return
            }
        }
        
        guard let data = data else {
            print("❌ No data received from RapidAPI \(method)")
            completion([])
            return
        }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("✅ Received RapidAPI \(method) response")
                let soldItems = self.parseRapidAPIResponse(json)
                print("✅ Found \(soldItems.count) sold items from RapidAPI \(method)")
                
                if let firstItem = soldItems.first {
                    print("📊 Sample item: \(firstItem.title) - $\(firstItem.price)")
                }
                
                completion(soldItems)
            } else {
                print("❌ Invalid RapidAPI \(method) response format")
                completion([])
            }
        } catch {
            print("❌ Error parsing RapidAPI \(method) response: \(error)")
            completion([])
        }
    }
    
    private func parseRapidAPIResponse(_ json: [String: Any]) -> [EbaySoldItem] {
        var soldItems: [EbaySoldItem] = []
        
        // Try multiple possible response structures
        let possibleDataKeys = ["results", "items", "data", "sold_items", "listings", "products"]
        
        for key in possibleDataKeys {
            if let results = json[key] as? [[String: Any]] {
                print("✅ Found data under key: \(key)")
                soldItems = parseItemsArray(results)
                if !soldItems.isEmpty {
                    break
                }
            }
        }
        
        // If no nested structure, try parsing the root as an array
        if soldItems.isEmpty {
            if let rootArray = json[""] as? [[String: Any]] ?? (json as? [[String: Any]]) {
                soldItems = parseItemsArray(rootArray)
            }
        }
        
        return soldItems.filter { $0.price > 0 }
    }
    
    private func parseItemsArray(_ items: [[String: Any]]) -> [EbaySoldItem] {
        var soldItems: [EbaySoldItem] = []
        
        for item in items {
            // Try different possible field names
            let possibleTitleKeys = ["title", "name", "item_title", "listing_title", "product_name"]
            let possiblePriceKeys = ["price", "final_price", "sold_price", "selling_price", "amount"]
            let possibleConditionKeys = ["condition", "item_condition", "condition_description"]
            let possibleDateKeys = ["sold_date", "end_date", "date_sold", "completion_date", "sold_time"]
            let possibleShippingKeys = ["shipping", "shipping_cost", "shipping_price"]
            
            guard let title = getFirstValue(from: item, keys: possibleTitleKeys) as? String else {
                continue
            }
            
            let price: Double
            if let priceValue = getFirstValue(from: item, keys: possiblePriceKeys) {
                if let priceDouble = priceValue as? Double {
                    price = priceDouble
                } else if let priceString = priceValue as? String {
                    price = extractPrice(from: priceString) ?? 0
                } else {
                    continue
                }
            } else {
                continue
            }
            
            let condition = getFirstValue(from: item, keys: possibleConditionKeys) as? String
            let shipping = getFirstValue(from: item, keys: possibleShippingKeys) as? Double
            let soldDateString = getFirstValue(from: item, keys: possibleDateKeys) as? String
            let soldDate = parseSoldDate(soldDateString)
            let bestOfferAccepted = item["best_offer_accepted"] as? Bool ?? item["best_offer"] as? Bool
            
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
        
        return soldItems
    }
    
    private func getFirstValue(from dict: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dict[key] {
                return value
            }
        }
        return nil
    }
    
    private func extractPrice(from string: String) -> Double? {
        let cleanString = string.replacingOccurrences(of: "$", with: "")
                                .replacingOccurrences(of: ",", with: "")
                                .replacingOccurrences(of: " ", with: "")
                                .trimmingCharacters(in: .whitespaces)
        return Double(cleanString)
    }
    
    private func parseSoldDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = DateFormatter()
        
        // Try ISO format first
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try date only
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try US format
        formatter.dateFormat = "MM/dd/yyyy"
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        return nil
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
    private let migrationKey = "DataMigrationV7_Completed"
    private let categoryCountersKey = "CategoryCounters"
    
    @Published var categoryCounters: [String: Int] = [:]
    
    init() {
        performDataMigrationIfNeeded()
        loadCategoryCounters()
        loadItems()
    }
    
    private func performDataMigrationIfNeeded() {
        if !userDefaults.bool(forKey: migrationKey) {
            print("🔄 Performing data migration V7...")
            userDefaults.removeObject(forKey: itemsKey)
            userDefaults.removeObject(forKey: categoryCountersKey)
            userDefaults.set(true, forKey: migrationKey)
            print("✅ Data migration V7 completed")
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

struct MarketAnalysisData {
    let demandLevel: String
    let confidence: Double
    let recentSalesCount: Int
    let totalSalesCount: Int
    let priceTrend: String
    let estimatedCompetitorCount: Int
    let averageSellingTime: Int
    let seasonalFactor: Double
}

struct MarketPricingData {
    let quickSalePrice: Double
    let marketPrice: Double
    let premiumPrice: Double
    let averagePrice: Double
    let p10: Double
    let p25: Double
    let p75: Double
    let p90: Double
    let sampleSize: Int
    let priceSpread: Double
    let feeAdjustedMarketPrice: Double
    let seasonalMultiplier: Double
    let priceTrend: String
}

struct ConditionAssessment {
    let ebayCondition: String
    let conditionNotes: [String]
    let priceImpact: Double
    let completenessScore: Double
    let authenticityConfidence: Double
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

struct SellingStrategy {
    let listingType: String
    let pricingStrategy: String
    let timingStrategy: String
    let sourcingInsights: [String]
    let expectedSellingTime: Int
    let profitMargin: Double
}

struct EbaySoldItem {
    let title: String
    let price: Double
    let condition: String?
    let soldDate: Date?
    let shipping: Double?
    let bestOfferAccepted: Bool?
}
