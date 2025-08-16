//
//  AnalysisService.swift
//  ResellAI
//
//  GPT-5 Analysis System - Fixed for Real API
//

import SwiftUI
import Foundation
import Vision

// MARK: - ANALYSIS SERVICE WITH GPT-5
class AIAnalysisService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let endpoint = "https://api.openai.com/v1/responses"
    
    // MARK: - MAIN ANALYSIS FUNCTION
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
        
        print("🧠 Starting GPT-5 analysis with \(images.count) images")
        
        // For now, single-stage analysis with gpt-5-mini
        // We'll add two-stage pipeline in next chat
        analyzeWithGPT5(images: images, completion: completion)
    }
    
    // MARK: - GPT-5 ANALYSIS
    private func analyzeWithGPT5(images: [UIImage], completion: @escaping (ExpertAnalysisResult?) -> Void) {
        let prompt = buildAnalysisPrompt()
        let model = "gpt-5-mini" // Start with mini for cost efficiency
        
        performGPT5Analysis(
            model: model,
            images: images,
            prompt: prompt,
            completion: completion
        )
    }
    
    // MARK: - GPT-5 API CALL (FIXED)
    private func performGPT5Analysis(
        model: String,
        images: [UIImage],
        prompt: String,
        completion: @escaping (ExpertAnalysisResult?) -> Void
    ) {
        guard let url = URL(string: endpoint) else {
            completion(nil)
            return
        }
        
        // Build input with prompt and images
        var inputParts: [String] = [prompt]
        
        // Add images (max 5)
        let imagesToProcess = images.prefix(5)
        for (index, image) in imagesToProcess.enumerated() {
            if let imageData = compressImage(image) {
                let base64Image = imageData.base64EncodedString()
                inputParts.append("\n\n[Image \(index + 1)]:\ndata:image/jpeg;base64,\(base64Image)")
            }
        }
        
        let fullInput = inputParts.joined()
        
        // Build request body for GPT-5 Responses API
        let requestBody: [String: Any] = [
            "model": model,
            "input": fullInput,
            "reasoning": [
                "effort": "medium"  // Start with medium, will adjust based on item type
            ],
            "text": [
                "verbosity": "medium"
            ]
            // Note: format specification might be different for json_object
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ Error creating request: \(error)")
            completion(nil)
            return
        }
        
        print("🚀 Calling \(model) with medium reasoning effort")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        print("❌ API Error: \(errorString)")
                    }
                    completion(nil)
                    return
                }
            }
            
            guard let data = data else {
                print("❌ No response data")
                completion(nil)
                return
            }
            
            // Parse the response
            if let result = self?.parseGPT5Response(data) {
                completion(result)
            } else {
                completion(nil)
            }
        }.resume()
    }
    
    // MARK: - BUILD ANALYSIS PROMPT
    private func buildAnalysisPrompt() -> String {
        return """
        You are a product-identification expert for resale. Analyze the provided product images and return ONLY a valid JSON object (no other text) with this exact structure:
        
        {
            "attributes": {
                "brand": "exact brand name",
                "model": "model name or null",
                "name": "full product name",
                "category": "product category",
                "size": "size or null",
                "color": "primary color",
                "material": "material or null",
                "condition": {
                    "grade": "New/Like New/Good/Fair/Poor",
                    "score": 1-10,
                    "details": "condition description"
                },
                "defects": ["list of defects or empty array"],
                "identifiers": {
                    "styleCode": "style code or null",
                    "upc": "UPC or null",
                    "sku": "SKU or null",
                    "serialNumber": "serial or null"
                },
                "yearReleased": "year or null",
                "collaboration": "collab name or null",
                "specialEdition": "special edition or null"
            },
            "confidence": 0.0-1.0,
            "evidence": ["specific visual elements that led to identification"],
            "suggestedPrice": {
                "quickSale": price in USD,
                "market": price in USD,
                "premium": price in USD,
                "reasoning": "pricing explanation based on condition and market"
            },
            "listingContent": {
                "title": "eBay title (70-80 chars max)",
                "description": "professional eBay description with condition details",
                "keywords": ["keyword1", "keyword2", "keyword3"],
                "bulletPoints": ["key feature 1", "key feature 2", "key feature 3"]
            },
            "marketAnalysis": {
                "demandLevel": "High/Medium/Low",
                "competitorCount": estimated number or null,
                "recentSales": estimated number or null,
                "seasonalFactors": "seasonal notes or null"
            }
        }
        
        Instructions:
        - Be precise and accurate in identification
        - Never invent style codes or identifiers - leave null if not visible
        - Base condition assessment on visible wear, defects, and overall appearance
        - Provide realistic pricing based on condition and typical resale values
        - Create an eBay-optimized title with key searchable terms
        - Include specific evidence for your identification
        
        IMPORTANT: Return ONLY the JSON object, no additional text or explanation.
        """
    }
    
    // MARK: - PARSE GPT-5 RESPONSE
    private func parseGPT5Response(_ data: Data) -> ExpertAnalysisResult? {
        do {
            // GPT-5 responses have a different structure
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let outputText = json["output_text"] as? String {
                
                // Parse the JSON from output_text
                if let jsonData = outputText.data(using: .utf8) {
                    let parsedData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                    
                    // Convert to ExpertAnalysisResult
                    if let result = parseToExpertResult(parsedData) {
                        print("✅ Parsed analysis result: \(result.attributes.name)")
                        print("📊 Confidence: \(result.confidence)")
                        print("💰 Market price: $\(result.suggestedPrice.market)")
                        return result
                    }
                }
            }
        } catch {
            print("❌ Parse error: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw response: \(responseString.prefix(500))...")
            }
        }
        
        return nil
    }
    
    // MARK: - CONVERT TO EXPERT RESULT
    private func parseToExpertResult(_ json: [String: Any]?) -> ExpertAnalysisResult? {
        guard let json = json,
              let attributes = json["attributes"] as? [String: Any],
              let suggestedPrice = json["suggestedPrice"] as? [String: Any],
              let listingContent = json["listingContent"] as? [String: Any] else {
            return nil
        }
        
        // Parse attributes
        let brand = attributes["brand"] as? String ?? ""
        let model = attributes["model"] as? String
        let name = attributes["name"] as? String ?? "Unknown Item"
        let category = attributes["category"] as? String ?? "Other"
        let size = attributes["size"] as? String
        let color = attributes["color"] as? String
        let material = attributes["material"] as? String
        
        // Parse condition
        let conditionData = attributes["condition"] as? [String: Any] ?? [:]
        let conditionGrade = conditionData["grade"] as? String ?? "Good"
        let conditionScore = conditionData["score"] as? Int ?? 7
        let conditionDetails = conditionData["details"] as? String ?? ""
        
        // Parse identifiers
        let identifiersData = attributes["identifiers"] as? [String: Any] ?? [:]
        let styleCode = identifiersData["styleCode"] as? String
        let upc = identifiersData["upc"] as? String
        let sku = identifiersData["sku"] as? String
        let serialNumber = identifiersData["serialNumber"] as? String
        
        // Parse other attributes
        let defects = attributes["defects"] as? [String] ?? []
        let yearReleased = attributes["yearReleased"] as? String
        let collaboration = attributes["collaboration"] as? String
        let specialEdition = attributes["specialEdition"] as? String
        
        // Parse main response data
        let confidence = json["confidence"] as? Double ?? 0.7
        let evidence = json["evidence"] as? [String] ?? []
        
        // Parse pricing
        let quickSale = suggestedPrice["quickSale"] as? Double ?? 0
        let market = suggestedPrice["market"] as? Double ?? 0
        let premium = suggestedPrice["premium"] as? Double ?? 0
        let reasoning = suggestedPrice["reasoning"] as? String ?? ""
        
        // Parse listing content
        let title = listingContent["title"] as? String ?? ""
        let description = listingContent["description"] as? String ?? ""
        let keywords = listingContent["keywords"] as? [String] ?? []
        let bulletPoints = listingContent["bulletPoints"] as? [String] ?? []
        
        // Parse market analysis
        let marketAnalysis = json["marketAnalysis"] as? [String: Any]
        let demandLevel = marketAnalysis?["demandLevel"] as? String
        let competitorCount = marketAnalysis?["competitorCount"] as? Int
        let recentSales = marketAnalysis?["recentSales"] as? Int
        let seasonalFactors = marketAnalysis?["seasonalFactors"] as? String
        
        // Create ExpertAnalysisResult
        let itemAttributes = ExpertAnalysisResult.ItemAttributes(
            brand: brand,
            model: model,
            name: name,
            category: category,
            size: size,
            color: color,
            material: material,
            condition: ExpertAnalysisResult.ConditionGrade(
                grade: conditionGrade,
                score: conditionScore,
                details: conditionDetails
            ),
            defects: defects,
            identifiers: ExpertAnalysisResult.ItemIdentifiers(
                styleCode: styleCode,
                upc: upc,
                sku: sku,
                serialNumber: serialNumber
            ),
            yearReleased: yearReleased,
            collaboration: collaboration,
            specialEdition: specialEdition
        )
        
        let pricingStrategy = ExpertAnalysisResult.PricingStrategy(
            quickSale: quickSale,
            market: market,
            premium: premium,
            reasoning: reasoning
        )
        
        let content = ExpertAnalysisResult.ListingContent(
            title: title,
            description: description,
            keywords: keywords,
            bulletPoints: bulletPoints
        )
        
        let insights = marketAnalysis != nil ? ExpertAnalysisResult.MarketInsights(
            demandLevel: demandLevel ?? "Medium",
            competitorCount: competitorCount,
            recentSales: recentSales,
            seasonalFactors: seasonalFactors
        ) : nil
        
        return ExpertAnalysisResult(
            attributes: itemAttributes,
            confidence: confidence,
            evidence: evidence,
            suggestedPrice: pricingStrategy,
            listingContent: content,
            marketAnalysis: insights,
            escalatedToGPT5: false // Will implement escalation in next chat
        )
    }
    
    // MARK: - IMAGE COMPRESSION
    private func compressImage(_ image: UIImage) -> Data? {
        let maxDimension: CGFloat = 1024
        
        let size = image.size
        let ratio = min(maxDimension/size.width, maxDimension/size.height, 1.0)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let resizedImage: UIImage
        if ratio < 1.0 {
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            resizedImage = image
        }
        
        // Compress to ~750KB max per image
        var compression: CGFloat = 0.8
        var data = resizedImage.jpegData(compressionQuality: compression)
        
        while let imageData = data, imageData.count > 750_000, compression > 0.3 {
            compression -= 0.1
            data = resizedImage.jpegData(compressionQuality: compression)
        }
        
        return data
    }
}
