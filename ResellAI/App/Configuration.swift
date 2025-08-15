//
//  Configuration.swift
//  ResellAI
//
//  Fixed Configuration with Working eBay OAuth Settings
//

import Foundation

// MARK: - Fixed Configuration with Working eBay OAuth
struct Configuration {
    
    // MARK: - API Keys from Environment Variables
    static let openAIKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    
    static let googleScriptURL = ProcessInfo.processInfo.environment["GOOGLE_SCRIPT_URL"] ?? ""
    
    static let rapidAPIKey = ProcessInfo.processInfo.environment["RAPID_API_KEY"] ?? ""
    
    static let spreadsheetID = ProcessInfo.processInfo.environment["SPREADSHEET_ID"] ?? ""
    
    static let googleCloudAPIKey = ProcessInfo.processInfo.environment["GOOGLE_CLOUD_API_KEY"] ?? ""
    
    // ✅ WORKING EBAY CREDENTIALS - KEEP THESE EXACT VALUES
    static let ebayAPIKey = ProcessInfo.processInfo.environment["EBAY_API_KEY"] ?? "AlecRodr-resell-PRD-d0bc91504-be3e553a"
    static let ebayClientSecret = ProcessInfo.processInfo.environment["EBAY_CLIENT_SECRET"] ?? "PRD-0bc91504af12-57f0-49aa-8bb7-763a"
    static let ebayDevId = ProcessInfo.processInfo.environment["EBAY_DEV_ID"] ?? "7b77d928-4c43-4d2c-ad86-a0ea503437ae"
    static let ebayEnvironment = "PRODUCTION"
    
    // ✅ WORKING OAUTH REDIRECT URIS - THESE WERE WORKING
    static let ebayRedirectURI = ProcessInfo.processInfo.environment["EBAY_REDIRECT_URI"] ?? "https://resellaiapp.com/ebay-callback.html"
    static let ebayAppScheme = "resellai://auth/ebay"
    static let ebayRuName = ProcessInfo.processInfo.environment["EBAY_RU_NAME"] ?? "Alec_Rodriguez-AlecRodr-resell-yinuaueco"
    
    // eBay Seller Policies (OPTIONAL - WILL AUTO-CREATE IF EMPTY)
    static let ebayFulfillmentPolicyId = ProcessInfo.processInfo.environment["EBAY_FULFILLMENT_POLICY_ID"] ?? ""
    static let ebayPaymentPolicyId = ProcessInfo.processInfo.environment["EBAY_PAYMENT_POLICY_ID"] ?? ""
    static let ebayReturnPolicyId = ProcessInfo.processInfo.environment["EBAY_RETURN_POLICY_ID"] ?? ""
    
    // MARK: - API Endpoints
    static let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
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
    static let openAIMaxTokens = 4000
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
    
    static var configurationStatus: String {
        if isFullyConfigured {
            return "All systems ready"
        } else {
            var missing: [String] = []
            if openAIKey.isEmpty { missing.append("OpenAI") }
            if ebayAPIKey.isEmpty { missing.append("eBay API Key") }
            if ebayClientSecret.isEmpty { missing.append("eBay Client Secret") }
            if ebayDevId.isEmpty { missing.append("eBay Dev ID") }
            return "Missing: \(missing.joined(separator: ", "))"
        }
    }
    
    // MARK: - Development Helpers
    static func validateConfiguration() {
        print("🔧 ResellAI Configuration Status:")
        print("✅ OpenAI: \(openAIKey.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ eBay API Key: \(ebayAPIKey.isEmpty ? "❌ Missing" : "✅ \(ebayAPIKey)")")
        print("✅ eBay Client Secret: \(ebayClientSecret.isEmpty ? "❌ Missing" : "✅ Configured")")
        print("✅ eBay Dev ID: \(ebayDevId.isEmpty ? "❌ Missing" : "✅ \(ebayDevId)")")
        print("✅ eBay RuName: \(ebayRuName.isEmpty ? "❌ Missing" : "✅ \(ebayRuName)")")
        print("✅ eBay Fulfillment Policy: \(ebayFulfillmentPolicyId.isEmpty ? "⚠️ Will auto-create" : "✅ Configured")")
        print("✅ eBay Payment Policy: \(ebayPaymentPolicyId.isEmpty ? "⚠️ Will auto-create" : "✅ Configured")")
        print("✅ eBay Return Policy: \(ebayReturnPolicyId.isEmpty ? "⚠️ Will auto-create" : "✅ Configured")")
        print("✅ Environment: \(ebayEnvironment)")
        print("📊 Overall Status: \(configurationStatus)")
        
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
            print("• Fulfillment Policy: \(ebayFulfillmentPolicyId.isEmpty ? "Will auto-create" : ebayFulfillmentPolicyId)")
            print("• Payment Policy: \(ebayPaymentPolicyId.isEmpty ? "Will auto-create" : ebayPaymentPolicyId)")
            print("• Return Policy: \(ebayReturnPolicyId.isEmpty ? "Will auto-create" : ebayReturnPolicyId)")
        }
    }
    
    // MARK: - eBay Category Mappings
    static let ebayCategoryMappings: [String: String] = [
        "Sneakers": "15709",
        "Shoes": "15709",
        "Athletic Shoes": "15709",
        "Clothing": "11450",
        "Electronics": "58058",
        "Smartphones": "9355",
        "Cell Phones": "9355",
        "Accessories": "169291",
        "Home": "11700",
        "Collectibles": "1",
        "Books": "267",
        "Toys": "220",
        "Sports": "888",
        "Other": "99"
    ]
    
    // MARK: - eBay Condition Mappings
    static let ebayConditionMappings: [String: String] = [
        "New with tags": "NEW_WITH_TAGS",
        "New without tags": "NEW_WITHOUT_TAGS",
        "New other": "NEW_OTHER",
        "Like New": "USED_EXCELLENT",
        "Excellent": "USED_EXCELLENT",
        "Very Good": "USED_VERY_GOOD",
        "Good": "USED_GOOD",
        "Acceptable": "USED_ACCEPTABLE",
        "For parts or not working": "FOR_PARTS_OR_NOT_WORKING"
    ]
}
