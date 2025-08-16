//
//  EbayMarketDataService.swift
//  ResellAI
//
//  Created by Alec on 8/16/25.
//


//
//  EbayMarketDataService.swift
//  ResellAI
//
//  eBay Market Data Service - Fetches Real Sold Listings
//

import SwiftUI
import Foundation

// MARK: - EBAY MARKET DATA SERVICE
class EbayMarketDataService: ObservableObject {
    @Published var isLoading = false
    @Published var lastError: String?
    
    // OAuth token management
    private var appToken: String?
    private var tokenExpiry: Date?
    
    // API endpoints
    private let tokenEndpoint = "https://api.ebay.com/identity/v1/oauth2/token"
    private let insightsEndpoint = "https://api.ebay.com/buy/marketplace_insights/v1_beta/item_sales/search"
    private let browseEndpoint = "https://api.ebay.com/buy/browse/v1/item_summary/search"
    
    // Client credentials
    private let clientId = Configuration.ebayAPIKey
    private let clientSecret = Configuration.ebayClientSecret
    
    // MARK: - PUBLIC METHODS
    
    /// Fetch sold listings for an item
    func fetchSoldListings(
        query: String,
        category: String? = nil,
        condition: String? = nil,
        completion: @escaping (MarketDataResult?) -> Void
    ) {
        print("📊 Fetching eBay market data for: \(query)")
        
        // Ensure we have a valid token
        ensureValidToken { [weak self] success in
            if !success {
                print("❌ Failed to get eBay app token")
                completion(nil)
                return
            }
            
            // Try Marketplace Insights first
            self?.fetchFromMarketplaceInsights(
                query: query,
                category: category,
                condition: condition
            ) { insightsResult in
                if let result = insightsResult, !result.soldListings.isEmpty {
                    print("✅ Found \(result.soldListings.count) sold items from Insights API")
                    completion(result)
                } else {
                    // Fallback to Browse API for active listings
                    print("⚠️ No sold data found, falling back to active listings")
                    self?.fetchFromBrowseAPI(
                        query: query,
                        category: category,
                        condition: condition,
                        completion: completion
                    )
                }
            }
        }
    }
    
    // MARK: - OAUTH TOKEN MANAGEMENT
    
    private func ensureValidToken(completion: @escaping (Bool) -> Void) {
        // Check if we have a valid token
        if let token = appToken, let expiry = tokenExpiry, expiry > Date() {
            print("✅ Using cached eBay app token")
            completion(true)
            return
        }
        
        // Get a new token
        print("🔐 Requesting new eBay app token...")
        requestAppToken(completion: completion)
    }
    
    private func requestAppToken(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: tokenEndpoint) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic auth with client credentials
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Request body with marketplace insights scope
        let scope = "https://api.ebay.com/oauth/api_scope/buy.marketplace.insights"
        let body = "grant_type=client_credentials&scope=\(scope.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = body.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Token request error: \(error)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("❌ No token data received")
                completion(false)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let token = json["access_token"] as? String,
                       let expiresIn = json["expires_in"] as? Int {
                        self?.appToken = token
                        self?.tokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 300)) // Buffer 5 min
                        print("✅ Got eBay app token, expires in \(expiresIn)s")
                        completion(true)
                    } else {
                        print("❌ Token response missing required fields")
                        if let error = json["error"] as? String {
                            print("Error: \(error)")
                            if let desc = json["error_description"] as? String {
                                print("Description: \(desc)")
                            }
                        }
                        completion(false)
                    }
                }
            } catch {
                print("❌ Failed to parse token response: \(error)")
                completion(false)
            }
        }.resume()
    }
    
    // MARK: - MARKETPLACE INSIGHTS API
    
    private func fetchFromMarketplaceInsights(
        query: String,
        category: String?,
        condition: String?,
        completion: @escaping (MarketDataResult?) -> Void
    ) {
        guard let token = appToken else {
            completion(nil)
            return
        }
        
        var components = URLComponents(string: insightsEndpoint)!
        
        // Build query parameters
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "filter", value: "marketplaceIds:{EBAY_US}")
        ]
        
        // Add category if provided
        if let category = category,
           let categoryId = Configuration.ebayCategoryMappings[category] {
            queryItems.append(URLQueryItem(name: "category_ids", value: categoryId))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 Calling Marketplace Insights API: \(url)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Insights API Response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 403 {
                    print("❌ Access denied - Marketplace Insights API not available")
                    print("💡 This is normal if your app doesn't have Insights access yet")
                    completion(nil)
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No data from Insights API")
                completion(nil)
                return
            }
            
            // Parse the response
            if let result = self?.parseInsightsResponse(data, condition: condition) {
                completion(result)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func parseInsightsResponse(_ data: Data, condition: String?) -> MarketDataResult? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let itemSales = json["itemSales"] as? [[String: Any]] {
                
                var soldListings: [SoldListing] = []
                
                for item in itemSales {
                    if let title = item["title"] as? String,
                       let priceDict = item["price"] as? [String: Any],
                       let priceValue = priceDict["value"] as? String,
                       let price = Double(priceValue),
                       let transactionDate = item["transactionDate"] as? String {
                        
                        let itemCondition = item["condition"] as? String ?? "Unknown"
                        let conditionId = item["conditionId"] as? String
                        
                        // Filter by condition if specified
                        if let targetCondition = condition {
                            let conditionMatch = itemCondition.lowercased().contains(targetCondition.lowercased())
                            if !conditionMatch { continue }
                        }
                        
                        let listing = SoldListing(
                            title: title,
                            price: price,
                            soldDate: ISO8601DateFormatter().date(from: transactionDate) ?? Date(),
                            condition: itemCondition,
                            conditionId: conditionId
                        )
                        
                        soldListings.append(listing)
                    }
                }
                
                print("✅ Parsed \(soldListings.count) sold listings from Insights")
                return MarketDataResult(soldListings: soldListings, isEstimate: false)
            }
        } catch {
            print("❌ Error parsing Insights response: \(error)")
        }
        
        return nil
    }
    
    // MARK: - BROWSE API FALLBACK
    
    private func fetchFromBrowseAPI(
        query: String,
        category: String?,
        condition: String?,
        completion: @escaping (MarketDataResult?) -> Void
    ) {
        guard let token = appToken else {
            completion(nil)
            return
        }
        
        var components = URLComponents(string: browseEndpoint)!
        
        // Build query parameters
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "50")
        ]
        
        // Add category filter
        if let category = category,
           let categoryId = Configuration.ebayCategoryMappings[category] {
            queryItems.append(URLQueryItem(name: "category_ids", value: categoryId))
        }
        
        // Add condition filter
        if let condition = condition {
            let conditionFilter = "condition:{\(condition)}"
            queryItems.append(URLQueryItem(name: "filter", value: conditionFilter))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        print("🔍 Calling Browse API as fallback: \(url)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data else {
                print("❌ No data from Browse API")
                completion(nil)
                return
            }
            
            // Parse active listings
            if let result = self?.parseBrowseResponse(data) {
                completion(result)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    private func parseBrowseResponse(_ data: Data) -> MarketDataResult? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let itemSummaries = json["itemSummaries"] as? [[String: Any]] {
                
                var activeListings: [ActiveListing] = []
                
                for item in itemSummaries {
                    if let title = item["title"] as? String,
                       let priceDict = item["price"] as? [String: Any],
                       let priceValue = priceDict["value"] as? String,
                       let price = Double(priceValue) {
                        
                        let condition = item["condition"] as? String ?? "Unknown"
                        
                        let listing = ActiveListing(
                            title: title,
                            price: price,
                            condition: condition
                        )
                        
                        activeListings.append(listing)
                    }
                }
                
                print("✅ Found \(activeListings.count) active listings from Browse API")
                
                // Convert active listings to estimated sold prices
                let estimatedSold = activeListings.map { active in
                    SoldListing(
                        title: active.title,
                        price: active.price * 0.85, // Assume 85% of asking price
                        soldDate: Date(),
                        condition: active.condition,
                        conditionId: nil
                    )
                }
                
                return MarketDataResult(soldListings: estimatedSold, isEstimate: true)
            }
        } catch {
            print("❌ Error parsing Browse response: \(error)")
        }
        
        return nil
    }
}

// MARK: - DATA MODELS

struct MarketDataResult {
    let soldListings: [SoldListing]
    let isEstimate: Bool // true if using Browse API fallback
    
    var prices: [Double] {
        soldListings.map { $0.price }
    }
    
    var medianPrice: Double? {
        let sorted = prices.sorted()
        guard !sorted.isEmpty else { return nil }
        
        let count = sorted.count
        if count % 2 == 0 {
            return (sorted[count/2 - 1] + sorted[count/2]) / 2
        } else {
            return sorted[count/2]
        }
    }
    
    var averagePrice: Double? {
        guard !prices.isEmpty else { return nil }
        return prices.reduce(0, +) / Double(prices.count)
    }
    
    var priceRange: (min: Double, max: Double)? {
        guard let min = prices.min(), let max = prices.max() else { return nil }
        return (min, max)
    }
    
    func priceTiers() -> PriceTiers {
        let sorted = prices.sorted()
        let median = medianPrice ?? 0
        
        // Calculate percentiles
        let p25 = percentile(sorted, 0.25) ?? median * 0.85
        let p75 = percentile(sorted, 0.75) ?? median * 1.15
        
        return PriceTiers(
            quickSell: p25,
            market: median,
            premium: p75,
            dataPoints: prices.count,
            isEstimate: isEstimate
        )
    }
    
    private func percentile(_ sorted: [Double], _ p: Double) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let index = Double(sorted.count - 1) * p
        let lower = Int(index)
        let upper = lower + 1
        let weight = index - Double(lower)
        
        if upper >= sorted.count {
            return sorted[lower]
        }
        
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }
}

struct SoldListing {
    let title: String
    let price: Double
    let soldDate: Date
    let condition: String
    let conditionId: String?
}

struct ActiveListing {
    let title: String
    let price: Double
    let condition: String
}

struct PriceTiers {
    let quickSell: Double
    let market: Double
    let premium: Double
    let dataPoints: Int
    let isEstimate: Bool
}