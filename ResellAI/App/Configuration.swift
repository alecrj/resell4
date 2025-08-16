//
//  Configuration.swift
//  ResellAI
//
//  Configuration with GPT-5 Integration
//

import Foundation

// MARK: - Configuration with GPT-5
struct Configuration {
    
    // MARK: - API Keys from Environment Variables
    static let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    
    static let rapidAPIKey = ProcessInfo.processInfo.environment["RAPID_API_KEY"] ?? ""
    
    // ✅ KEEP YOUR WORKING EBAY CREDENTIALS (WITH ENV FALLBACKS)
    static let ebayAPIKey = ProcessInfo.processInfo.environment["EBAY_API_KEY"] ?? "AlecRodr-resell-PRD-d0bc91504-be3e553a"
    static let ebayClientSecret = ProcessInfo.processInfo.environment["EBAY_CLIENT_SECRET"] ?? "PRD-0bc91504af12-57f0-49aa-8bb7-763a"
    static let ebayDevId = ProcessInfo.processInfo.environment["EBAY_DEV_ID"] ?? "7b77d928-4c43-4d2c-ad86-a0ea503437ae"
    static let ebayEnvironment = "PRODUCTION"
    
    // ✅ CORRECT OAUTH REDIRECT URIS - USING YOUR DOMAIN
    static let ebayRedirectURI = ProcessInfo.processInfo.environment["EBAY_REDIRECT_URI"] ?? "https://resellaiapp.com/ebay-callback.html"
    static let ebayAppScheme = "resellai://auth/ebay"
    static let ebayRuName = ProcessInfo.processInfo.environment["EBAY_RU_NAME"] ?? "Alec_Rodriguez-AlecRodr-resell-yinuaueco"
    
    // eBay Seller Policies (OPTIONAL - WILL AUTO-CREATE IF EMPTY)
    static let ebayFulfillmentPolicyId = ProcessInfo.processInfo.environment["EBAY_FULFILLMENT_POLICY_ID"] ?? ""
    static let ebayPaymentPolicyId = ProcessInfo.processInfo.environment["EBAY_PAYMENT_POLICY_ID"] ?? ""
    static let ebayReturnPolicyId = ProcessInfo.processInfo.environment["EBAY_RETURN_POLICY_ID"] ?? ""
    
    // MARK: - API Endpoints
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions" // Legacy endpoint
    static let gpt5Endpoint = "https://api.openai.com/v1/responses" // GPT-5 endpoint
    
    // eBay API endpoints (Production)
    static let ebayProductionAPIBase = "https://api.ebay.com"
    static let ebayAuthBase = "https://auth.ebay.com"
    static let ebayTokenEndpoint = "https://api.ebay.com/identity/v1/oauth2/token"
    static let ebayUserEndpoint = "https://apiz.ebay.com/commerce/identity/v1/user/"
    
    // eBay Browse API (for market data)
    static let ebayBrowseAPI = "https://api.ebay.com/buy/browse/v1"
    
    // eBay Finding API (legacy, but still useful)
    static let ebayFindingAPIBase = "https://svcs.ebay.com/services/search/FindingService/v1"
    
    // eBay Sell API endpoints (PRODUCTION)
    static let ebaySellInventoryAPI = "https://api.ebay.com/sell/inventory/v1"
    static let ebaySellAccountAPI = "https://api.ebay.com/sell/account/v1"
    static let ebaySellFulfillmentAPI = "https://api.ebay.com/sell/fulfillment/v1"
    static let ebaySellMarketingAPI = "https://api.ebay.com/sell/marketing/v1"
    
    // MARK: - App Configuration
    static let appName = "ResellAI"
    static let version = "1.0.0"
    static let maxPhotos = 8
    static let defaultShippingCost = 8.50
    static let defaultEbayFeeRate = 0.1325
    static let defaultPayPalFeeRate = 0.0349
    
    // MARK: - GPT-5 AI Configuration
    static let aiModel = "gpt-5-mini" // Primary model for cost efficiency
    static let aiModelFull = "gpt-5" // Escalation model for complex/luxury items
    static let aiNanoModel = "gpt-5-nano" // Ultra-fast for simple items
    static let aiEndpoint = gpt5Endpoint // Use GPT-5 endpoint
    
    // Confidence thresholds
    static let aiConfidenceThreshold = 0.88 // Auto-accept threshold for easy items
    static let aiCrossCheckThreshold = 0.70 // Trigger eBay validation
    static let aiRetryThreshold = 0.65 // Request more photos
    
    // Response format
    static let aiResponseFormat = "json_object" // Force JSON output
    
    // MARK: - Luxury & High-Value Brands (Auto-escalate to GPT-5)
    static let luxuryBrands = [
        // Fashion Houses
        "Louis Vuitton", "Gucci", "Chanel", "Hermès", "Prada", "Balenciaga",
        "Burberry", "Dior", "Fendi", "Versace", "Saint Laurent", "Bottega Veneta",
        "Valentino", "Givenchy", "Celine", "Loewe", "Balmain", "Alexander McQueen",
        
        // Watches
        "Rolex", "Patek Philippe", "Audemars Piguet", "Richard Mille", "Omega",
        "Cartier", "Vacheron Constantin", "Jaeger-LeCoultre", "IWC", "Breitling",
        
        // Jewelry
        "Tiffany & Co.", "Van Cleef & Arpels", "Bulgari", "Harry Winston",
        
        // Streetwear/Hype
        "Supreme", "Off-White", "Fear of God", "Chrome Hearts", "Vlone",
        "Palace", "BAPE", "Yeezy", "Travis Scott", "Fragment"
    ]
    
    // Easy categories for gpt-5-mini
    static let easyCategories = [
        "Books", "DVDs", "CDs", "Video Games", "Board Games",
        "Sealed Electronics", "New in Box Items", "Trading Cards with Text"
    ]
    
    // MARK: - Business Rules
    static let minimumROIThreshold = 50.0
    static let preferredROIThreshold = 100.0
    static let maxBuyPriceMultiplier = 0.6
    static let quickSalePriceMultiplier = 0.85
    static let premiumPriceMultiplier = 1.15
    
    // MARK: - eBay Specific Settings
    static let ebayMaxImages = 8
    static let ebayDefaultShippingTime = 3
    static let ebayDefaultReturnPeriod = 30
    static let ebayListingDuration = 7
    
    // MARK: - eBay OAuth Scopes (PRODUCTION READY)
    static let ebayRequiredScopes: [String] = [
        "https://api.ebay.com/oauth/api_scope",
        "https://api.ebay.com/oauth/api_scope/sell.inventory",
        "https://api.ebay.com/oauth/api_scope/sell.account",
        "https://api.ebay.com/oauth/api_scope/sell.fulfillment",
        "https://api.ebay.com/oauth/api_scope/commerce.identity.readonly"
    ]
    
    // MARK: - Rate Limiting
    static let ebayAPICallsPerSecond = 5
    static let openAICallsPerMinute = 500 // GPT-5 rate limits
    static let rapidAPICallsPerMinute = 100
    
    // MARK: - Configuration Validation
    static var isFullyConfigured: Bool {
        return !openAIKey.isEmpty &&
               !ebayAPIKey.isEmpty &&
               !ebayClientSecret.isEmpty
    }
    
    static var isEbayConfigured: Bool {
        return !ebayAPIKey.isEmpty &&
               !ebayClientSecret.isEmpty &&
               !ebayDevId.isEmpty
    }
    
    static var isAIReady: Bool {
        return !openAIKey.isEmpty && openAIKey.count > 20
    }
    
    static var configurationStatus: String {
        if isFullyConfigured {
            return "GPT-5 Ready - All systems operational"
        } else {
            var missing: [String] = []
            if openAIKey.isEmpty { missing.append("OpenAI API Key") }
            if ebayAPIKey.isEmpty { missing.append("eBay API Key") }
            if ebayClientSecret.isEmpty { missing.append("eBay Client Secret") }
            if ebayDevId.isEmpty { missing.append("eBay Dev ID") }
            return "Missing: \(missing.joined(separator: ", "))"
        }
    }
    
    // MARK: - Development Helpers
    static func validateConfiguration() {
        print("🔧 ResellAI Configuration Status:")
        print("✅ OpenAI (GPT-5): \(openAIKey.isEmpty ? "❌ Missing" : "✅ Configured")")
        
        if isAIReady {
            print("\n🧠 GPT-5 AI System Ready!")
            print("📊 Models Available:")
            print("  • GPT-5-mini: Fast, cost-efficient triage")
            print("  • GPT-5: High accuracy for complex/luxury items")
            print("  • GPT-5-nano: Ultra-fast for simple items")
            print("🎯 Confidence Thresholds:")
            print("  • Auto-accept: \(aiConfidenceThreshold) (easy items)")
            print("  • Cross-check: \(aiCrossCheckThreshold) (validate with eBay)")
            print("  • Retry: \(aiRetryThreshold) (need more photos)")
            print("💎 Luxury brands configured: \(luxuryBrands.count) brands")
            print("📚 Easy categories: \(easyCategories.count) types")
        }
        
        print("\n✅ eBay API Key: \(ebayAPIKey.isEmpty ? "❌ Missing" : "✅ \(ebayAPIKey)")")
        print("✅ eBay Client Secret: \(ebayClientSecret.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ eBay Dev ID: \(ebayDevId.isEmpty ? "❌ Missing" : "✅ \(ebayDevId)")")
        print("✅ eBay RuName: \(ebayRuName.isEmpty ? "❌ Missing" : "✅ \(ebayRuName)")")
        print("✅ eBay Fulfillment Policy: \(ebayFulfillmentPolicyId.isEmpty ? "⚠️ Will auto-create" : "✅ Configured")")
        print("✅ eBay Payment Policy: \(ebayPaymentPolicyId.isEmpty ? "⚠️ Will auto-create" : "✅ Configured")")
        print("✅ eBay Return Policy: \(ebayReturnPolicyId.isEmpty ? "⚠️ Will auto-create" : "✅ Configured")")
        print("✅ Environment: \(ebayEnvironment)")
        print("\n📊 Overall Status: \(configurationStatus)")
        
        if isEbayConfigured {
            print("\n🎉 eBay Production OAuth 2.0 Integration Ready!")
            print("• Client ID: \(ebayAPIKey)")
            print("• Dev ID: \(ebayDevId)")
            print("• RuName: \(ebayRuName)")
            print("• Environment: \(ebayEnvironment)")
            print("• Web Redirect URI: \(ebayRedirectURI)")
            print("• App Callback URI: \(ebayAppScheme)")
            print("• OAuth Endpoint: \(ebayAuthBase)")
            print("• Token Endpoint: \(ebayTokenEndpoint)")
            print("• User Endpoint: \(ebayUserEndpoint)")
            print("• Inventory API: \(ebaySellInventoryAPI)")
            print("• Scopes: \(ebayRequiredScopes.count) required scopes")
        }
        
        if isFullyConfigured {
            print("\n🚀 ResellAI Configuration Complete!")
            print("• AI: ✅ GPT-5 ready for product analysis")
            print("• eBay Integration: ✅ Production OAuth 2.0 ready")
            print("• Auto-listing: ✅ Photos to eBay listings automatically")
            print("• Two-stage pipeline: ✅ Cost-efficient with accuracy")
        }
    }
    
    // MARK: - eBay Category Mappings
    static let ebayCategoryMappings: [String: String] = [
        "Sneakers": "15709",
        "Shoes": "15709",
        "Athletic Shoes": "15709",
        "Running Shoes": "15709",
        "Basketball Shoes": "15709",
        "Skateboarding Shoes": "15709",
        "Boots": "11498",
        "Clothing": "11450",
        "Streetwear": "155206",
        "Vintage": "175759",
        "T-Shirts": "15687",
        "Hoodies": "155183",
        "Jackets": "11484",
        "Pants": "11554",
        "Jeans": "11483",
        "Electronics": "58058",
        "Smartphones": "9355",
        "Cell Phones": "9355",
        "Gaming": "139973",
        "Consoles": "139971",
        "Apple": "9355",
        "Samsung": "9355",
        "Accessories": "169291",
        "Watches": "14324",
        "Jewelry": "281",
        "Bags": "169291",
        "Home": "11700",
        "Collectibles": "1",
        "Trading Cards": "261328",
        "Pokemon": "2536",
        "Sports Cards": "212",
        "Books": "267",
        "Toys": "220",
        "Action Figures": "246",
        "Sports": "888",
        "Memorabilia": "64482",
        "Other": "99"
    ]
    
    // MARK: - eBay Condition Mappings
    static let ebayConditionMappings: [String: String] = [
        "New with tags": "NEW_WITH_TAGS",
        "New without tags": "NEW_WITHOUT_TAGS",
        "New other": "NEW_OTHER",
        "Deadstock": "NEW_WITH_TAGS",
        "VNDS": "NEW_WITHOUT_TAGS",
        "Like New": "USED_EXCELLENT",
        "Excellent": "USED_EXCELLENT",
        "Very Good": "USED_VERY_GOOD",
        "Good": "USED_GOOD",
        "Fair": "USED_ACCEPTABLE",
        "Acceptable": "USED_ACCEPTABLE",
        "Poor": "FOR_PARTS_OR_NOT_WORKING",
        "For parts or not working": "FOR_PARTS_OR_NOT_WORKING"
    ]
    
    // MARK: - AI Categories
    static let aiCategories = [
        "Sneakers & Footwear",
        "Streetwear & Fashion",
        "Electronics & Tech",
        "Luxury Goods",
        "Collectibles & Trading Cards",
        "Vintage & Rare Items",
        "Gaming & Consoles",
        "Sports Memorabilia",
        "Watches & Jewelry",
        "Art & Antiques",
        "Books & Media",
        "Home & Garden",
        "Toys & Games"
    ]
    
    // MARK: - Hype Brand Recognition
    static let hypeBrands = [
        "Off-White", "Supreme", "Fear of God", "Stone Island", "Yeezy",
        "Travis Scott", "Fragment", "Kaws", "Virgil Abloh", "Palace",
        "A Bathing Ape", "Comme des Garcons", "Rick Owens", "Chrome Hearts",
        "Vetements", "Raf Simons", "Undercover", "Neighborhood", "WTAPS"
    ]
}
