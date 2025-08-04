//
//  Models.swift
//  ResellAI
//
//  Ultimate Consolidated Models - FAANG Level Architecture
//

import SwiftUI
import Foundation

// MARK: - CORE INVENTORY ITEM MODEL
struct InventoryItem: Identifiable, Codable {
    let id = UUID()
    var itemNumber: Int
    var inventoryCode: String = ""
    var name: String
    var category: String
    var purchasePrice: Double
    var suggestedPrice: Double
    var actualPrice: Double?
    var source: String
    var condition: String
    var title: String
    var description: String
    var keywords: [String]
    var status: ItemStatus
    var dateAdded: Date
    var dateListed: Date?
    var dateSold: Date?
    var imageData: Data?
    var additionalImageData: [Data]?
    var ebayURL: String?
    var resalePotential: Int?
    var marketNotes: String?
    
    // Market analysis fields
    var ebayCondition: EbayCondition?
    var marketConfidence: Double?
    var soldListingsCount: Int?
    var priceRange: EbayPriceRange?
    var lastMarketUpdate: Date?
    
    // AI analysis fields
    var aiConfidence: Double?
    var competitorCount: Int?
    var demandLevel: String?
    var listingStrategy: String?
    var sourcingTips: [String]?
    
    // Product identification
    var barcode: String?
    var brand: String = ""
    var exactModel: String = ""
    var styleCode: String = ""
    var size: String = ""
    var colorway: String = ""
    var releaseYear: String = ""
    var subcategory: String = ""
    var authenticationNotes: String = ""
    
    // Physical inventory management
    var storageLocation: String = ""
    var binNumber: String = ""
    var isPackaged: Bool = false
    var packagedDate: Date?
    
    init(itemNumber: Int, name: String, category: String, purchasePrice: Double,
         suggestedPrice: Double, source: String, condition: String, title: String,
         description: String, keywords: [String], status: ItemStatus, dateAdded: Date,
         actualPrice: Double? = nil, dateListed: Date? = nil, dateSold: Date? = nil,
         imageData: Data? = nil, additionalImageData: [Data]? = nil, ebayURL: String? = nil,
         resalePotential: Int? = nil, marketNotes: String? = nil,
         aiConfidence: Double? = nil, competitorCount: Int? = nil, demandLevel: String? = nil,
         listingStrategy: String? = nil, sourcingTips: [String]? = nil,
         barcode: String? = nil, brand: String = "", exactModel: String = "",
         styleCode: String = "", size: String = "", colorway: String = "",
         releaseYear: String = "", subcategory: String = "", authenticationNotes: String = "",
         storageLocation: String = "", binNumber: String = "", isPackaged: Bool = false,
         packagedDate: Date? = nil, ebayCondition: EbayCondition? = nil,
         marketConfidence: Double? = nil, soldListingsCount: Int? = nil,
         priceRange: EbayPriceRange? = nil, lastMarketUpdate: Date? = nil) {
        
        self.itemNumber = itemNumber
        self.name = name
        self.category = category
        self.purchasePrice = purchasePrice
        self.suggestedPrice = suggestedPrice
        self.actualPrice = actualPrice
        self.source = source
        self.condition = condition
        self.title = title
        self.description = description
        self.keywords = keywords
        self.status = status
        self.dateAdded = dateAdded
        self.dateListed = dateListed
        self.dateSold = dateSold
        self.imageData = imageData
        self.additionalImageData = additionalImageData
        self.ebayURL = ebayURL
        self.resalePotential = resalePotential
        self.marketNotes = marketNotes
        self.aiConfidence = aiConfidence
        self.competitorCount = competitorCount
        self.demandLevel = demandLevel
        self.listingStrategy = listingStrategy
        self.sourcingTips = sourcingTips
        self.barcode = barcode
        self.brand = brand
        self.exactModel = exactModel
        self.styleCode = styleCode
        self.size = size
        self.colorway = colorway
        self.releaseYear = releaseYear
        self.subcategory = subcategory
        self.authenticationNotes = authenticationNotes
        self.storageLocation = storageLocation
        self.binNumber = binNumber
        self.isPackaged = isPackaged
        self.packagedDate = packagedDate
        self.ebayCondition = ebayCondition
        self.marketConfidence = marketConfidence
        self.soldListingsCount = soldListingsCount
        self.priceRange = priceRange
        self.lastMarketUpdate = lastMarketUpdate
    }
}

// MARK: - ITEM STATUS ENUM
enum ItemStatus: String, CaseIterable, Codable {
    case sourced = "Sourced"
    case photographed = "Photographed"
    case toList = "To List"
    case listed = "Listed"
    case sold = "Sold"
    
    var color: Color {
        switch self {
        case .sourced: return .gray
        case .photographed: return .orange
        case .toList: return .blue
        case .listed: return .green
        case .sold: return .purple
        }
    }
    
    var systemImage: String {
        switch self {
        case .sourced: return "cart.fill"
        case .photographed: return "camera.fill"
        case .toList: return "list.bullet"
        case .listed: return "network"
        case .sold: return "checkmark.circle.fill"
        }
    }
}

// MARK: - EBAY CONDITION ENUM
enum EbayCondition: String, CaseIterable, Codable {
    case newWithTags = "New with tags"
    case newWithoutTags = "New without tags"
    case newOther = "New other"
    case likeNew = "Like New"
    case excellent = "Excellent"
    case veryGood = "Very Good"
    case good = "Good"
    case acceptable = "Acceptable"
    case forParts = "For parts or not working"
    
    var ebayConditionID: String {
        switch self {
        case .newWithTags: return "1000"
        case .newWithoutTags: return "1500"
        case .newOther: return "1750"
        case .likeNew: return "2000"
        case .excellent: return "2500"
        case .veryGood: return "3000"
        case .good: return "4000"
        case .acceptable: return "5000"
        case .forParts: return "7000"
        }
    }
    
    var priceMultiplier: Double {
        switch self {
        case .newWithTags: return 1.0
        case .newWithoutTags: return 0.95
        case .newOther: return 0.9
        case .likeNew: return 0.85
        case .excellent: return 0.8
        case .veryGood: return 0.7
        case .good: return 0.6
        case .acceptable: return 0.5
        case .forParts: return 0.3
        }
    }
}

// MARK: - ANALYSIS RESULT MODEL
struct AnalysisResult: Identifiable, Codable {
    let id = UUID()
    let name: String
    let brand: String
    let category: String
    let condition: String
    let title: String
    let description: String
    let keywords: [String]
    let suggestedPrice: Double
    let quickPrice: Double
    let premiumPrice: Double
    let averagePrice: Double?
    let marketConfidence: Double?
    let soldListingsCount: Int?
    let competitorCount: Int?
    let demandLevel: String?
    let listingStrategy: String?
    let sourcingTips: [String]?
    let aiConfidence: Double?
    let resalePotential: Int?
    let priceRange: EbayPriceRange?
    let recentSales: [RecentSale]
    
    // Product details
    let exactModel: String?
    let styleCode: String?
    let size: String?
    let colorway: String?
    let releaseYear: String?
    let subcategory: String?
    
    init(name: String, brand: String, category: String, condition: String, title: String,
         description: String, keywords: [String], suggestedPrice: Double, quickPrice: Double,
         premiumPrice: Double, averagePrice: Double? = nil, marketConfidence: Double? = nil,
         soldListingsCount: Int? = nil, competitorCount: Int? = nil, demandLevel: String? = nil,
         listingStrategy: String? = nil, sourcingTips: [String]? = nil, aiConfidence: Double? = nil,
         resalePotential: Int? = nil, priceRange: EbayPriceRange? = nil, recentSales: [RecentSale] = [],
         exactModel: String? = nil, styleCode: String? = nil, size: String? = nil,
         colorway: String? = nil, releaseYear: String? = nil, subcategory: String? = nil) {
        
        self.name = name
        self.brand = brand
        self.category = category
        self.condition = condition
        self.title = title
        self.description = description
        self.keywords = keywords
        self.suggestedPrice = suggestedPrice
        self.quickPrice = quickPrice
        self.premiumPrice = premiumPrice
        self.averagePrice = averagePrice
        self.marketConfidence = marketConfidence
        self.soldListingsCount = soldListingsCount
        self.competitorCount = competitorCount
        self.demandLevel = demandLevel
        self.listingStrategy = listingStrategy
        self.sourcingTips = sourcingTips
        self.aiConfidence = aiConfidence
        self.resalePotential = resalePotential
        self.priceRange = priceRange
        self.recentSales = recentSales
        self.exactModel = exactModel
        self.styleCode = styleCode
        self.size = size
        self.colorway = colorway
        self.releaseYear = releaseYear
        self.subcategory = subcategory
    }
}

// MARK: - EBAY PRICE RANGE
struct EbayPriceRange: Codable {
    let low: Double
    let high: Double
    let average: Double
    
    var spread: Double {
        return high - low
    }
    
    var isWideSpread: Bool {
        return spread > (average * 0.5)
    }
}

// MARK: - RECENT SALE
struct RecentSale: Codable {
    let title: String
    let price: Double
    let condition: String
    let date: Date
    let shipping: Double?
    let bestOffer: Bool
    
    init(title: String, price: Double, condition: String, date: Date, shipping: Double? = nil, bestOffer: Bool = false) {
        self.title = title
        self.price = price
        self.condition = condition
        self.date = date
        self.shipping = shipping
        self.bestOffer = bestOffer
    }
    
    var totalPrice: Double {
        return price + (shipping ?? 0)
    }
    
    var daysAgo: Int {
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
    }
}

// MARK: - EBAY SOLD LISTING
struct EbaySoldListing: Codable {
    let title: String
    let price: Double
    let condition: String
    let soldDate: Date
    let shippingCost: Double?
    let bestOffer: Bool
    let auction: Bool
    let watchers: Int?
    
    var totalPrice: Double {
        return price + (shippingCost ?? 0)
    }
    
    var isRecentSale: Bool {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return soldDate >= thirtyDaysAgo
    }
}

// MARK: - INVENTORY CATEGORY
enum InventoryCategory: String, CaseIterable {
    case tshirts = "T-Shirts & Tops"
    case jackets = "Jackets & Outerwear"
    case jeans = "Jeans & Denim"
    case workPants = "Work Pants"
    case dresses = "Dresses & Skirts"
    case shoes = "Shoes & Footwear"
    case accessories = "Accessories"
    case electronics = "Electronics"
    case collectibles = "Collectibles"
    case home = "Home & Garden"
    case books = "Books & Media"
    case toys = "Toys & Games"
    case sports = "Sports & Outdoors"
    case other = "Other Items"
    
    var inventoryLetter: String {
        switch self {
        case .tshirts: return "A"
        case .jackets: return "B"
        case .jeans: return "C"
        case .workPants: return "D"
        case .dresses: return "E"
        case .shoes: return "F"
        case .accessories: return "G"
        case .electronics: return "H"
        case .collectibles: return "I"
        case .home: return "J"
        case .books: return "K"
        case .toys: return "L"
        case .sports: return "M"
        case .other: return "Z"
        }
    }
    
    var systemImage: String {
        switch self {
        case .tshirts: return "tshirt.fill"
        case .jackets: return "jacket.fill"
        case .jeans: return "pants.fill"
        case .workPants: return "pants.fill"
        case .dresses: return "dress.fill"
        case .shoes: return "shoe.fill"
        case .accessories: return "bag.fill"
        case .electronics: return "iphone"
        case .collectibles: return "star.fill"
        case .home: return "house.fill"
        case .books: return "book.fill"
        case .toys: return "gamecontroller.fill"
        case .sports: return "sportscourt.fill"
        case .other: return "cube.box.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .tshirts: return .blue
        case .jackets: return .brown
        case .jeans: return .indigo
        case .workPants: return .gray
        case .dresses: return .pink
        case .shoes: return .black
        case .accessories: return .purple
        case .electronics: return .orange
        case .collectibles: return .yellow
        case .home: return .green
        case .books: return .red
        case .toys: return .cyan
        case .sports: return .mint
        case .other: return .secondary
        }
    }
    
    var storageTips: [String] {
        switch self {
        case .tshirts:
            return ["Fold neatly to prevent wrinkles", "Sort by size and brand", "Use clear bins for visibility"]
        case .jackets:
            return ["Hang on sturdy hangers", "Use garment bags for premium items", "Store in cool, dry place"]
        case .jeans:
            return ["Fold along seams", "Stack by waist size", "Keep premium brands separate"]
        case .workPants:
            return ["Hang to maintain crease", "Group by brand", "Check for stains before storing"]
        case .dresses:
            return ["Use padded hangers", "Cover with garment bags", "Store by season"]
        case .shoes:
            return ["Keep in original boxes when possible", "Stuff with paper to maintain shape", "Take photos of boxes"]
        case .accessories:
            return ["Use small compartments", "Keep pairs together", "Store jewelry safely"]
        case .electronics:
            return ["Keep in anti-static bags", "Store with all accessories", "Test before storing"]
        case .collectibles:
            return ["Use protective sleeves", "Control temperature and humidity", "Document condition carefully"]
        case .home:
            return ["Wrap fragile items carefully", "Group by function", "Store in original packaging if possible"]
        case .books:
            return ["Store upright when possible", "Keep away from moisture", "Group by genre or author"]
        case .toys:
            return ["Keep all pieces together", "Clean before storing", "Check for recalls"]
        case .sports:
            return ["Clean equipment thoroughly", "Check for wear and damage", "Store in dry conditions"]
        case .other:
            return ["Label clearly", "Take detailed photos", "Research proper storage methods"]
        }
    }
    
    var averageMargin: Double {
        switch self {
        case .tshirts: return 200.0
        case .jackets: return 150.0
        case .jeans: return 180.0
        case .workPants: return 120.0
        case .dresses: return 250.0
        case .shoes: return 300.0
        case .accessories: return 400.0
        case .electronics: return 80.0
        case .collectibles: return 500.0
        case .home: return 100.0
        case .books: return 300.0
        case .toys: return 200.0
        case .sports: return 150.0
        case .other: return 150.0
        }
    }
}

// MARK: - INVENTORY STATISTICS
struct InventoryStatistics: Codable {
    let totalItems: Int
    let listedItems: Int
    let soldItems: Int
    let totalInvestment: Double
    let totalProfit: Double
    let averageROI: Double
    let estimatedValue: Double
    
    var sellThroughRate: Double {
        guard totalItems > 0 else { return 0 }
        return Double(soldItems) / Double(totalItems) * 100
    }
    
    var averageItemValue: Double {
        guard totalItems > 0 else { return 0 }
        return estimatedValue / Double(totalItems)
    }
    
    var profitMargin: Double {
        guard totalInvestment > 0 else { return 0 }
        return (totalProfit / totalInvestment) * 100
    }
    
    var itemsInProgress: Int {
        return totalItems - soldItems
    }
}

// MARK: - BUSINESS METRICS
struct BusinessMetrics: Codable {
    let monthlyRevenue: Double
    let monthlyProfit: Double
    let monthlyExpenses: Double
    let averageSellingTime: Double
    let topPerformingCategory: String
    let inventoryTurnover: Double
    let customerSatisfactionScore: Double
    
    var profitMargin: Double {
        guard monthlyRevenue > 0 else { return 0 }
        return (monthlyProfit / monthlyRevenue) * 100
    }
    
    var expenseRatio: Double {
        guard monthlyRevenue > 0 else { return 0 }
        return (monthlyExpenses / monthlyRevenue) * 100
    }
}

// MARK: - MARKET ANALYSIS
struct MarketAnalysis: Codable {
    let productName: String
    let averageSalePrice: Double
    let priceRange: EbayPriceRange
    let salesVolume: Int
    let competitionLevel: CompetitionLevel
    let seasonalTrends: SeasonalTrends?
    let recommendedAction: RecommendedAction
    let confidenceScore: Double
    
    var isHighDemand: Bool {
        return salesVolume > 20 && competitionLevel != .high
    }
    
    var profitPotential: ProfitPotential {
        if averageSalePrice > 100 && competitionLevel == .low {
            return .high
        } else if averageSalePrice > 50 && competitionLevel != .high {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - COMPETITION LEVEL
enum CompetitionLevel: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Few similar listings - great opportunity"
        case .medium: return "Moderate competition - price competitively"
        case .high: return "Many similar listings - consider alternatives"
        }
    }
}

// MARK: - SEASONAL TRENDS
struct SeasonalTrends: Codable {
    let peakSeason: Season
    let bestMonths: [Int]
    let worstMonths: [Int]
    let seasonalMultiplier: Double
    
    var isCurrentlyPeakSeason: Bool {
        let currentMonth = Calendar.current.component(.month, from: Date())
        return bestMonths.contains(currentMonth)
    }
}

// MARK: - SEASON
enum Season: String, CaseIterable, Codable {
    case spring = "Spring"
    case summer = "Summer"
    case fall = "Fall"
    case winter = "Winter"
    
    var months: [Int] {
        switch self {
        case .spring: return [3, 4, 5]
        case .summer: return [6, 7, 8]
        case .fall: return [9, 10, 11]
        case .winter: return [12, 1, 2]
        }
    }
}

// MARK: - RECOMMENDED ACTION
enum RecommendedAction: String, CaseIterable, Codable {
    case listImmediately = "List Immediately"
    case waitForSeason = "Wait for Peak Season"
    case bundleWithOthers = "Bundle with Similar Items"
    case holdForAppreciation = "Hold for Appreciation"
    case sellQuickly = "Sell Quickly"
    case researchMore = "Research More"
    
    var systemImage: String {
        switch self {
        case .listImmediately: return "bolt.fill"
        case .waitForSeason: return "calendar.clock"
        case .bundleWithOthers: return "square.stack.3d.up"
        case .holdForAppreciation: return "bank.fill"
        case .sellQuickly: return "speedometer"
        case .researchMore: return "magnifyingglass"
        }
    }
    
    var color: Color {
        switch self {
        case .listImmediately: return .green
        case .waitForSeason: return .blue
        case .bundleWithOthers: return .purple
        case .holdForAppreciation: return .orange
        case .sellQuickly: return .red
        case .researchMore: return .gray
        }
    }
}

// MARK: - PROFIT POTENTIAL
enum ProfitPotential: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: Color {
        switch self {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        }
    }
    
    var systemImage: String {
        switch self {
        case .low: return "chart.line.downtrend.xyaxis"
        case .medium: return "chart.line.flattrend.xyaxis"
        case .high: return "chart.line.uptrend.xyaxis"
        }
    }
}

// MARK: - LISTING PERFORMANCE
struct ListingPerformance: Codable {
    let views: Int
    let watchers: Int
    let questions: Int
    let offers: Int
    let daysListed: Int
    let impressions: Int
    
    var viewToWatcherRatio: Double {
        guard views > 0 else { return 0 }
        return Double(watchers) / Double(views) * 100
    }
    
    var engagementScore: Double {
        let totalEngagement = watchers + questions + offers
        guard views > 0 else { return 0 }
        return Double(totalEngagement) / Double(views) * 100
    }
    
    var performanceLevel: PerformanceLevel {
        if viewToWatcherRatio > 10 && engagementScore > 5 {
            return .excellent
        } else if viewToWatcherRatio > 5 && engagementScore > 2 {
            return .good
        } else if viewToWatcherRatio > 2 {
            return .fair
        } else {
            return .poor
        }
    }
}

// MARK: - PERFORMANCE LEVEL
enum PerformanceLevel: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"
    
    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    var recommendations: [String] {
        switch self {
        case .excellent:
            return ["Great job! Consider raising price slightly", "Use this listing as a template"]
        case .good:
            return ["Good performance", "Consider promoting to boost visibility"]
        case .fair:
            return ["Update photos for better appeal", "Revise title for better SEO", "Consider price adjustment"]
        case .poor:
            return ["Revise listing completely", "Check pricing against competition", "Add more detailed photos", "Improve title and description"]
        }
    }
}

// MARK: - EXPENSE TRACKING
struct Expense: Identifiable, Codable {
    let id = UUID()
    let category: ExpenseCategory
    let amount: Double
    let description: String
    let date: Date
    let isDeductible: Bool
    let receipt: Data?
    
    var formattedAmount: String {
        return String(format: "$%.2f", amount)
    }
}

// MARK: - EXPENSE CATEGORY
enum ExpenseCategory: String, CaseIterable, Codable {
    case inventory = "Inventory"
    case shipping = "Shipping"
    case fees = "Platform Fees"
    case supplies = "Supplies"
    case marketing = "Marketing"
    case travel = "Travel"
    case equipment = "Equipment"
    case software = "Software"
    case other = "Other"
    
    var systemImage: String {
        switch self {
        case .inventory: return "cart.fill"
        case .shipping: return "box.fill"
        case .fees: return "creditcard.fill"
        case .supplies: return "bag.fill"
        case .marketing: return "megaphone.fill"
        case .travel: return "car.fill"
        case .equipment: return "camera.fill"
        case .software: return "laptopcomputer"
        case .other: return "ellipsis.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .inventory: return .blue
        case .shipping: return .brown
        case .fees: return .red
        case .supplies: return .green
        case .marketing: return .purple
        case .travel: return .orange
        case .equipment: return .gray
        case .software: return .cyan
        case .other: return .secondary
        }
    }
    
    var isDeductibleByDefault: Bool {
        return true // Most reselling expenses are deductible
    }
}

// MARK: - COMPUTED PROPERTIES FOR INVENTORY ITEM
extension InventoryItem {
    var profit: Double {
        guard let actualPrice = actualPrice else { return 0 }
        return actualPrice - purchasePrice - estimatedFees
    }
    
    var roi: Double {
        guard purchasePrice > 0 else { return 0 }
        return (profit / purchasePrice) * 100
    }
    
    var estimatedProfit: Double {
        return suggestedPrice - purchasePrice - estimatedFees
    }
    
    var estimatedROI: Double {
        guard purchasePrice > 0 else { return 0 }
        return (estimatedProfit / purchasePrice) * 100
    }
    
    var estimatedFees: Double {
        let ebayFee = suggestedPrice * Configuration.defaultEbayFeeRate
        let paypalFee = (suggestedPrice * Configuration.defaultPayPalFeeRate) + 0.49
        return ebayFee + paypalFee + Configuration.defaultShippingCost
    }
    
    var daysInInventory: Int {
        return Calendar.current.dateComponents([.day], from: dateAdded, to: Date()).day ?? 0
    }
    
    var isStale: Bool {
        return daysInInventory > 90
    }
    
    var statusColor: Color {
        return status.color
    }
    
    var categoryLetter: String {
        let lowercased = category.lowercased()
        
        if lowercased.contains("shirt") || lowercased.contains("top") {
            return "A"
        } else if lowercased.contains("jacket") || lowercased.contains("coat") {
            return "B"
        } else if lowercased.contains("jean") || lowercased.contains("denim") {
            return "C"
        } else if lowercased.contains("pant") || lowercased.contains("trouser") {
            return "D"
        } else if lowercased.contains("dress") || lowercased.contains("skirt") {
            return "E"
        } else if lowercased.contains("shoe") || lowercased.contains("sneaker") || lowercased.contains("boot") {
            return "F"
        } else if lowercased.contains("accessory") || lowercased.contains("bag") || lowercased.contains("watch") {
            return "G"
        } else if lowercased.contains("electronic") || lowercased.contains("phone") || lowercased.contains("computer") {
            return "H"
        } else if lowercased.contains("collectible") || lowercased.contains("vintage") {
            return "I"
        } else {
            return "Z"
        }
    }
    
    var formattedPurchasePrice: String {
        return String(format: "$%.2f", purchasePrice)
    }
    
    var formattedSuggestedPrice: String {
        return String(format: "$%.2f", suggestedPrice)
    }
    
    var formattedActualPrice: String {
        guard let actualPrice = actualPrice else { return "N/A" }
        return String(format: "$%.2f", actualPrice)
    }
    
    var formattedProfit: String {
        return String(format: "$%.2f", profit)
    }
    
    var formattedROI: String {
        return String(format: "%.1f%%", roi)
    }
    
    var marketConfidenceLevel: String {
        guard let confidence = marketConfidence else { return "Unknown" }
        
        if confidence >= 0.8 {
            return "High"
        } else if confidence >= 0.6 {
            return "Medium"
        } else {
            return "Low"
        }
    }
    
    var demandIndicator: String {
        guard let soldCount = soldListingsCount else { return "Unknown" }
        
        if soldCount >= 20 {
            return "High Demand"
        } else if soldCount >= 10 {
            return "Medium Demand"
        } else if soldCount >= 5 {
            return "Low Demand"
        } else {
            return "Very Low Demand"
        }
    }
    
    var competitionLevel: String {
        guard let competitors = competitorCount else { return "Unknown" }
        
        if competitors >= 50 {
            return "High Competition"
        } else if competitors >= 20 {
            return "Medium Competition"
        } else {
            return "Low Competition"
        }
    }
    
    var shouldQuickSell: Bool {
        return daysInInventory > 60 || demandLevel == "Low"
    }
    
    var qualityScore: Double {
        var score = 0.0
        
        // Base on condition
        if condition.lowercased().contains("new") {
            score += 40
        } else if condition.lowercased().contains("excellent") {
            score += 35
        } else if condition.lowercased().contains("good") {
            score += 25
        } else {
            score += 15
        }
        
        // Brand recognition
        if !brand.isEmpty && ["Nike", "Adidas", "Apple", "Samsung", "Louis Vuitton", "Gucci", "Rolex"].contains(brand) {
            score += 30
        } else if !brand.isEmpty {
            score += 15
        }
        
        // Market confidence
        if let confidence = marketConfidence {
            score += confidence * 30
        }
        
        return min(score, 100)
    }
}

// MARK: - ANALYSIS RESULT EXTENSIONS
extension AnalysisResult {
    var confidenceLevel: String {
        guard let confidence = aiConfidence else { return "Unknown" }
        
        if confidence >= 0.9 {
            return "Very High"
        } else if confidence >= 0.8 {
            return "High"
        } else if confidence >= 0.7 {
            return "Medium"
        } else if confidence >= 0.6 {
            return "Low"
        } else {
            return "Very Low"
        }
    }
    
    var marketStrength: String {
        guard let soldCount = soldListingsCount else { return "Unknown" }
        
        if soldCount >= 30 {
            return "Strong Market"
        } else if soldCount >= 15 {
            return "Moderate Market"
        } else if soldCount >= 5 {
            return "Weak Market"
        } else {
            return "Very Weak Market"
        }
    }
    
    var profitMargin: Double {
        return ((suggestedPrice - (suggestedPrice * 0.15)) / suggestedPrice) * 100
    }
    
    var recommendedListingDuration: Int {
        guard let demand = demandLevel else { return 7 }
        
        switch demand.lowercased() {
        case "high":
            return 3
        case "medium":
            return 7
        case "low":
            return 10
        default:
            return 7
        }
    }
    
    var isSeasonalItem: Bool {
        let seasonalKeywords = ["christmas", "halloween", "summer", "winter", "spring", "fall", "holiday", "seasonal"]
        let itemText = "\(name) \(description) \(keywords.joined(separator: " "))".lowercased()
        
        return seasonalKeywords.contains { keyword in
            itemText.contains(keyword)
        }
    }
    
    var formattedSuggestedPrice: String {
        return String(format: "$%.2f", suggestedPrice)
    }
    
    var formattedQuickPrice: String {
        return String(format: "$%.2f", quickPrice)
    }
    
    var formattedPremiumPrice: String {
        return String(format: "$%.2f", premiumPrice)
    }
}
