//
//  AnalysisService.swift
//  ResellAI
//
//  GPT-5 Tiered Analysis System - Fixed for Responses API
//

import SwiftUI
import Foundation
import Vision

// MARK: - AI ANALYSIS SERVICE WITH GPT-5
class AIAnalysisService: ObservableObject {
    private let apiKey = Configuration.openAIKey
    private let responsesEndpoint = "https://api.openai.com/v1/responses"
    
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
        
        // Step 1: Try GPT-5-mini first
        analyzeWithGPT5Mini(images: images) { [weak self] miniResult in
            guard let miniResult = miniResult else {
                print("❌ GPT-5-mini analysis failed")
                completion(nil)
                return
            }
            
            // Step 2: Check if we need to escalate
            if self?.shouldEscalateToFullGPT5(result: miniResult, images: images) == true {
                print("⬆️ Escalating to GPT-5 full for better accuracy")
                self?.analyzeWithGPT5Full(images: images, previousResult: miniResult) { fullResult in
                    completion(fullResult ?? miniResult)
                }
            } else {
                print("✅ GPT-5-mini result sufficient (confidence: \(miniResult.confidence))")
                completion(miniResult)
            }
        }
    }
    
    // MARK: - GPT-5-MINI ANALYSIS
    private func analyzeWithGPT5Mini(images: [UIImage], completion: @escaping (ExpertAnalysisResult?) -> Void) {
        let prompt = buildAnalysisPrompt(detailed: false)
        
        performGPT5Analysis(
            model: "gpt-5-mini",
            images: images,
            prompt: prompt,
            reasoning: "minimal",
            verbosity: "low",
            retries: 2
        ) { [weak self] responseData in
            if let result = self?.parseAnalysisResponse(responseData, escalated: false) {
                completion(result)
            } else {
                completion(nil)
            }
        }
    }
    
    // MARK: - GPT-5 FULL ANALYSIS
    private func analyzeWithGPT5Full(images: [UIImage], previousResult: ExpertAnalysisResult?, completion: @escaping (ExpertAnalysisResult?) -> Void) {
        let prompt = buildAnalysisPrompt(detailed: true, previousResult: previousResult)
        
        performGPT5Analysis(
            model: "gpt-5",
            images: images,
            prompt: prompt,
            reasoning: "medium",
            verbosity: "medium",
            retries: 3
        ) { [weak self] responseData in
            if let result = self?.parseAnalysisResponse(responseData, escalated: true) {
                completion(result)
            } else {
                // Fallback to previous result if full analysis fails
                completion(previousResult)
            }
        }
    }
    
    // MARK: - ESCALATION LOGIC
    private func shouldEscalateToFullGPT5(result: ExpertAnalysisResult, images: [UIImage]) -> Bool {
        // Check confidence threshold
        if result.confidence < Configuration.aiConfidenceThreshold {
            print("📊 Low confidence: \(result.confidence) < \(Configuration.aiConfidenceThreshold)")
            return true
        }
        
        // Check for luxury brands
        let brandLower = result.attributes.brand.lowercased()
        if Configuration.luxuryBrands.contains(where: { $0.lowercased() == brandLower }) {
            print("💎 Luxury brand detected: \(result.attributes.brand)")
            return true
        }
        
        // Check for high-value categories
        let highValueCategories = ["Watches", "Jewelry", "Handbags", "Designer", "Collectibles", "Art"]
        if highValueCategories.contains(where: { result.attributes.category.contains($0) }) {
            print("💰 High-value category: \(result.attributes.category)")
            return true
        }
        
        // Check for conflicting or missing critical attributes
        if result.attributes.brand.isEmpty || result.attributes.name.contains("Unknown") {
            print("⚠️ Missing critical attributes")
            return true
        }
        
        // Check if price suggests high value (> $500)
        if result.suggestedPrice.market > 500 {
            print("💸 High suggested price: $\(result.suggestedPrice.market)")
            return true
        }
        
        return false
    }
    
    // MARK: - GPT-5 API CALL (FIXED FOR NEW RESPONSES FORMAT)
    private func performGPT5Analysis(
        model: String,
        images: [UIImage],
        prompt: String,
        reasoning: String,
        verbosity: String,
        retries: Int,
        completion: @escaping (Data?) -> Void
    ) {
        guard let url = URL(string: responsesEndpoint) else {
            completion(nil)
            return
        }
        
        // Prepare images
        let imageInputs = images.prefix(4).compactMap { image -> [String: Any]? in
            guard let imageData = compressImage(image) else { return nil }
            return [
                "type": "image",
                "image": [
                    "url": "data:image/jpeg;base64,\(imageData.base64EncodedString())",
                    "detail": "high"
                ]
            ]
        }
        
        // Build request body for new Responses API - FIXED FORMAT
        let requestBody: [String: Any] = [
            "model": model,
            "input": [
                [
                    "type": "text",
                    "text": prompt
                ]
            ] + imageInputs,
            "reasoning": [
                "effort": reasoning
            ],
            "text": [
                "verbosity": verbosity,
                "format": "json_object"  // FIXED: moved format to text.format
            ],
            "max_tokens": Configuration.aiMaxTokens,
            "temperature": Configuration.aiTemperature
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
        
        print("🚀 Calling \(model) with reasoning: \(reasoning)")
        
        performRequestWithRetry(request: request, retries: retries, completion: completion)
    }
    
    // MARK: - REQUEST WITH RETRY
    private func performRequestWithRetry(request: URLRequest, retries: Int, completion: @escaping (Data?) -> Void) {
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("❌ Network error: \(error.localizedDescription)")
                if retries > 0 {
                    print("🔄 Retrying... (\(retries) attempts left)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self?.performRequestWithRetry(request: request, retries: retries - 1, completion: completion)
                    }
                } else {
                    completion(nil)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 API Response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 429 {
                    print("⚠️ Rate limited, waiting...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self?.performRequestWithRetry(request: request, retries: retries - 1, completion: completion)
                    }
                    return
                }
                
                if httpResponse.statusCode != 200 {
                    if let data = data, let error = String(data: data, encoding: .utf8) {
                        print("❌ API Error: \(error)")
                    }
                    if retries > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self?.performRequestWithRetry(request: request, retries: retries - 1, completion: completion)
                        }
                    } else {
                        completion(nil)
                    }
                    return
                }
            }
            
            completion(data)
        }.resume()
    }
    
    // MARK: - BUILD ANALYSIS PROMPT
    private func buildAnalysisPrompt(detailed: Bool, previousResult: ExpertAnalysisResult? = nil) -> String {
        let basePrompt = """
        Analyze these product images and return a JSON object with this exact structure:
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
            "evidence": ["reasons for identification"],
            "suggestedPrice": {
                "quickSale": price in USD,
                "market": price in USD,
                "premium": price in USD,
                "reasoning": "pricing explanation"
            },
            "listingContent": {
                "title": "eBay title (80 chars max)",
                "description": "professional eBay description",
                "keywords": ["keyword1", "keyword2"],
                "bulletPoints": ["key feature 1", "key feature 2"]
            },
            "marketAnalysis": {
                "demandLevel": "High/Medium/Low",
                "competitorCount": estimated number or null,
                "recentSales": estimated number or null,
                "seasonalFactors": "seasonal notes or null"
            }
        }
        """
        
        if detailed {
            return basePrompt + """
            
            IMPORTANT: This is a HIGH-VALUE or COMPLEX item requiring maximum accuracy.
            - Examine all visible details including tags, labels, logos, and markings
            - Cross-reference design elements with known authentic versions
            - Be extremely precise with model identification and year
            - Consider rarity and special editions
            - Provide comprehensive market analysis
            """
        } else {
            return basePrompt + """
            
            Analyze quickly but accurately. Focus on:
            - Clear brand and model identification
            - Accurate condition assessment
            - Realistic pricing based on condition
            - Professional eBay listing content
            """
        }
    }
    
    // MARK: - PARSE RESPONSE
    private func parseAnalysisResponse(_ data: Data?, escalated: Bool) -> ExpertAnalysisResult? {
        guard let data = data else { return nil }
        
        do {
            // For GPT-5 responses API, the structure is different
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let outputText = json["output_text"] as? String {
                
                // Parse the JSON from output_text
                if let jsonData = outputText.data(using: .utf8) {
                    var result = try JSONDecoder().decode(ExpertAnalysisResult.self, from: jsonData)
                    
                    // Update escalation flag
                    result = ExpertAnalysisResult(
                        attributes: result.attributes,
                        confidence: result.confidence,
                        evidence: result.evidence,
                        suggestedPrice: result.suggestedPrice,
                        listingContent: result.listingContent,
                        marketAnalysis: result.marketAnalysis,
                        escalatedToGPT5: escalated
                    )
                    
                    print("✅ Parsed analysis result: \(result.attributes.name)")
                    print("📊 Confidence: \(result.confidence)")
                    print("💰 Suggested price: $\(result.suggestedPrice.market)")
                    
                    return result
                }
            }
        } catch {
            print("❌ Parse error: \(error)")
            
            // Try to extract any text and create a minimal result
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Raw response: \(responseString.prefix(200))...")
            }
        }
        
        return nil
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
        
        var compression: CGFloat = 0.8
        var data = resizedImage.jpegData(compressionQuality: compression)
        
        while let imageData = data, imageData.count > 750_000, compression > 0.3 {
            compression -= 0.1
            data = resizedImage.jpegData(compressionQuality: compression)
        }
        
        return data
    }
}
