//
//  AnalysisService.swift
//  ResellAI
//
//  AI Analysis with Market Intelligence
//

import SwiftUI
import Foundation
import Vision
import FirebaseFirestore

// MARK: - AI ANALYSIS SERVICE
class AIAnalysisService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let endpoint = Configuration.openAIEndpoint
    
    func analyzeItemWithMarketIntelligence(images: [UIImage], completion: @escaping (ExpertAnalysisResult?) -> Void) {
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
        
        print("🧠 Starting AI analysis with \(compressedImages.count) images")
        
        var content: [[String: Any]] = [
            [
                "type": "text",
                "text": buildExpertAnalysisPrompt()
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
            "model": Configuration.aiModel,
            "messages": [
                [
                    "role": "user",
                    "content": content
                ]
            ],
            "max_tokens": Configuration.aiMaxTokens,
            "temperature": Configuration.aiTemperature
        ]
        
        performExpertAnalysis(requestBody: requestBody, completion: completion)
    }
    
    private func buildExpertAnalysisPrompt() -> String {
        return """
        You are an expert product analyst and reseller with deep knowledge across:
        • Sneakers: Jordan, Nike, Adidas, Yeezy, collaborations, OG vs retro releases
        • Streetwear: Supreme, Off-White, Fear of God, vintage pieces, limited drops
        • Electronics: iPhones, gaming consoles, GPUs, specific model significance
        • Luxury: Rolex, LV, Gucci, authentication points, production years
        • Collectibles: Pokémon, vintage toys, limited editions, grading importance
        
        Analyze these images like you're a professional reseller evaluating an item to flip.
        
        IDENTIFICATION PROCESS:
        1. Look at EVERY detail in the images - tags, labels, serial numbers, colorways
        2. Identify the EXACT model, not just brand (e.g., "Air Jordan 1 High OG 'Chicago' 2015 retro" not just "Jordan 1")
        3. Check for authentication markers, production codes, special features
        4. Assess condition with reseller precision (small scuffs matter on expensive items)
        5. Note size if visible (crucial for sneaker/clothing values)
        
        MARKET INTELLIGENCE:
        Consider these factors like a market expert:
        • RARITY: Limited production, collaboration status, special releases
        • HYPE LEVEL: Current demand, trending status, influencer impact  
        • HISTORICAL SIGNIFICANCE: OG release vs retro, anniversary editions, first colorways
        • CONDITION IMPACT: How condition affects THIS specific item (deadstock vs worn matters more for Jordans than basic Nikes)
        • SIZE DYNAMICS: Popular sizes command premiums on hyped items
        • SEASONAL TRENDS: Holiday releases, back-to-school, summer drops
        • COLLABORATION PREMIUM: Off-White, Travis Scott, Fragment, etc. add massive value
        • AGE & VINTAGE VALUE: Some items appreciate, others depreciate
        
        PRICING STRATEGY:
        Provide three price points:
        • QUICK SALE: Move within 3-7 days (conservative but fast)
        • MARKET PRICE: Fair market value for normal 2-4 week sale
        • PATIENT SALE: Wait for right buyer, maximize profit (2-3+ months)
        
        RESPOND IN VALID JSON:
        {
            "exact_product_name": "Full specific name with year, colorway, special edition details",
            "brand": "Brand name",
            "category": "Specific category",
            "condition_assessment": "Detailed condition with reseller perspective",
            "size": "Size if visible",
            "year_released": "Release year if known",
            "collaboration": "Collaboration details if applicable",
            "rarity_level": "Common/Limited/Rare/Grail",
            "hype_status": "Dead/Low/Medium/High/Extreme",
            "quick_sale_price": 45.00,
            "market_price": 65.00,
            "patient_sale_price": 95.00,
            "price_reasoning": "Detailed explanation of why it's worth this much - consider collaboration, rarity, condition impact, size, trends",
            "authenticity_confidence": "High/Medium/Low with reason",
            "key_selling_points": ["Feature 1", "Feature 2", "Feature 3"],
            "condition_notes": ["Any flaws or wear patterns"],
            "sourcing_advice": "Maximum buy price and where to find similar items",
            "listing_title": "SEO-optimized eBay title",
            "listing_description": "Professional description highlighting key value drivers",
            "profit_potential": "1-10 score based on demand vs supply",
            "seasonal_factors": "Any timing considerations for selling",
            "comparable_sales": "What similar items have sold for recently",
            "red_flags": ["Any authenticity or condition concerns"]
        }
        
        Be as specific as possible. Instead of "Nike sneaker worth $80" say "2019 Nike Air Max 1 'Anniversary' retro in white/red colorway, excellent condition with minimal heel drag, worth $125 because it's the OG colorway that started the Air Max line, popular size, and condition is crucial for this model since creasing and sole yellowing significantly impact value."
        
        Think like you're explaining to another reseller WHY this item is worth what you're pricing it at.
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
    
    private func performExpertAnalysis(requestBody: [String: Any], completion: @escaping (ExpertAnalysisResult?) -> Void) {
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
            
            self.parseExpertAnalysis(data: data, completion: completion)
            
        }.resume()
    }
    
    private func parseExpertAnalysis(data: Data, completion: @escaping (ExpertAnalysisResult?) -> Void) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                let cleanedContent = cleanJSONResponse(content)
                
                if let result = parseExpertJSON(cleanedContent) {
                    print("✅ AI analysis complete: \(result.exactProductName)")
                    print("💰 Market Price: $\(String(format: "%.2f", result.marketPrice))")
                    print("🎯 Reasoning: \(result.priceReasoning)")
                    completion(result)
                } else {
                    print("❌ Failed to parse AI analysis")
                    completion(createFallbackAnalysis(from: content))
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
    
    private func parseExpertJSON(_ jsonString: String) -> ExpertAnalysisResult? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                let exactProductName = json["exact_product_name"] as? String ?? "Unknown Item"
                let brand = json["brand"] as? String ?? ""
                let category = json["category"] as? String ?? "Other"
                let conditionAssessment = json["condition_assessment"] as? String ?? "Used"
                let size = json["size"] as? String
                let yearReleased = json["year_released"] as? String
                let collaboration = json["collaboration"] as? String
                let rarityLevel = json["rarity_level"] as? String ?? "Common"
                let hypeStatus = json["hype_status"] as? String ?? "Low"
                
                let quickSalePrice = json["quick_sale_price"] as? Double ?? 25.0
                let marketPrice = json["market_price"] as? Double ?? 45.0
                let patientSalePrice = json["patient_sale_price"] as? Double ?? 65.0
                
                let priceReasoning = json["price_reasoning"] as? String ?? "Market analysis based on similar items"
                let authenticityConfidence = json["authenticity_confidence"] as? String ?? "Medium"
                let keySellingPoints = json["key_selling_points"] as? [String] ?? []
                let conditionNotes = json["condition_notes"] as? [String] ?? []
                let sourcingAdvice = json["sourcing_advice"] as? String ?? "Research similar items"
                let listingTitle = json["listing_title"] as? String ?? exactProductName
                let listingDescription = json["listing_description"] as? String ?? "Quality item in good condition"
                let profitPotential = json["profit_potential"] as? Int ?? 5
                let seasonalFactors = json["seasonal_factors"] as? String
                let comparableSales = json["comparable_sales"] as? String
                let redFlags = json["red_flags"] as? [String] ?? []
                
                return ExpertAnalysisResult(
                    exactProductName: exactProductName,
                    brand: brand,
                    category: category,
                    conditionAssessment: conditionAssessment,
                    size: size,
                    yearReleased: yearReleased,
                    collaboration: collaboration,
                    rarityLevel: rarityLevel,
                    hypeStatus: hypeStatus,
                    quickSalePrice: quickSalePrice,
                    marketPrice: marketPrice,
                    patientSalePrice: patientSalePrice,
                    priceReasoning: priceReasoning,
                    authenticityConfidence: authenticityConfidence,
                    keySellingPoints: keySellingPoints,
                    conditionNotes: conditionNotes,
                    sourcingAdvice: sourcingAdvice,
                    listingTitle: listingTitle,
                    listingDescription: listingDescription,
                    profitPotential: profitPotential,
                    seasonalFactors: seasonalFactors,
                    comparableSales: comparableSales,
                    redFlags: redFlags
                )
            }
        } catch {
            print("❌ JSON parsing error: \(error)")
        }
        
        return nil
    }
    
    private func createFallbackAnalysis(from content: String) -> ExpertAnalysisResult? {
        let words = content.components(separatedBy: .whitespaces)
        let productName = words.count > 2 ? Array(words.prefix(3)).joined(separator: " ") : "Unknown Item"
        
        return ExpertAnalysisResult(
            exactProductName: productName,
            brand: "",
            category: "Other",
            conditionAssessment: "Used - condition assessment incomplete",
            size: nil,
            yearReleased: nil,
            collaboration: nil,
            rarityLevel: "Unknown",
            hypeStatus: "Unknown",
            quickSalePrice: 15.0,
            marketPrice: 25.0,
            patientSalePrice: 35.0,
            priceReasoning: "Analysis incomplete - using conservative estimates",
            authenticityConfidence: "Low - insufficient data",
            keySellingPoints: [],
            conditionNotes: ["Analysis incomplete"],
            sourcingAdvice: "Research item thoroughly before purchasing",
            listingTitle: productName,
            listingDescription: "Item needs additional research",
            profitPotential: 3,
            seasonalFactors: nil,
            comparableSales: nil,
            redFlags: ["Analysis incomplete"]
        )
    }
}

// MARK: - EXPERT ANALYSIS RESULT MODEL
struct ExpertAnalysisResult: Identifiable, Codable {
    let id = UUID()
    let exactProductName: String
    let brand: String
    let category: String
    let conditionAssessment: String
    let size: String?
    let yearReleased: String?
    let collaboration: String?
    let rarityLevel: String
    let hypeStatus: String
    let quickSalePrice: Double
    let marketPrice: Double
    let patientSalePrice: Double
    let priceReasoning: String
    let authenticityConfidence: String
    let keySellingPoints: [String]
    let conditionNotes: [String]
    let sourcingAdvice: String
    let listingTitle: String
    let listingDescription: String
    let profitPotential: Int
    let seasonalFactors: String?
    let comparableSales: String?
    let redFlags: [String]
    
    // Convert to AnalysisResult for compatibility
    func toAnalysisResult() -> AnalysisResult {
        return AnalysisResult(
            name: exactProductName,
            brand: brand,
            category: category,
            condition: conditionAssessment,
            title: listingTitle,
            description: listingDescription,
            keywords: extractKeywords(),
            suggestedPrice: marketPrice,
            quickPrice: quickSalePrice,
            premiumPrice: patientSalePrice,
            averagePrice: marketPrice,
            marketConfidence: authenticityConfidenceScore(),
            soldListingsCount: nil,
            competitorCount: nil,
            demandLevel: hypeStatus,
            listingStrategy: "Fixed Price",
            sourcingTips: [sourcingAdvice],
            aiConfidence: authenticityConfidenceScore(),
            resalePotential: profitPotential,
            priceRange: EbayPriceRange(
                low: quickSalePrice,
                high: patientSalePrice,
                average: marketPrice
            ),
            recentSales: [],
            exactModel: extractModel(),
            styleCode: nil,
            size: size,
            colorway: extractColorway(),
            releaseYear: yearReleased,
            subcategory: category
        )
    }
    
    private func extractKeywords() -> [String] {
        var keywords: Set<String> = []
        
        let nameWords = exactProductName.lowercased().components(separatedBy: .whitespaces)
        keywords.formUnion(nameWords.filter { $0.count > 2 })
        
        if !brand.isEmpty {
            keywords.insert(brand.lowercased())
        }
        
        if let collaboration = collaboration, !collaboration.isEmpty {
            keywords.insert(collaboration.lowercased())
        }
        
        return Array(keywords.prefix(8))
    }
    
    private func authenticityConfidenceScore() -> Double {
        switch authenticityConfidence.lowercased() {
        case "high": return 0.9
        case "medium": return 0.7
        case "low": return 0.4
        default: return 0.6
        }
    }
    
    private func extractModel() -> String? {
        // Try to extract model from product name
        let components = exactProductName.components(separatedBy: " ")
        if components.count > 2 {
            return components[1...2].joined(separator: " ")
        }
        return nil
    }
    
    private func extractColorway() -> String? {
        // Look for quoted colorway or color terms
        if exactProductName.contains("'") {
            let components = exactProductName.components(separatedBy: "'")
            if components.count >= 3 {
                return components[1]
            }
        }
        
        // Look for common color patterns
        let colorTerms = ["white", "black", "red", "blue", "green", "yellow", "pink", "gray", "grey"]
        let words = exactProductName.lowercased().components(separatedBy: .whitespaces)
        let foundColors = words.filter { colorTerms.contains($0) }
        
        if !foundColors.isEmpty {
            return foundColors.joined(separator: "/").capitalized
        }
        
        return nil
    }
}
