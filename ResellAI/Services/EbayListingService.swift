//
//  EbayListingService.swift
//  ResellAI
//
//  Created by Alec on 8/14/25.
//


//
//  EbayListingService.swift
//  ResellAI
//
//  Real eBay Listing Creation - Separate from OAuth Service
//

import SwiftUI
import Foundation

// MARK: - EBAY LISTING SERVICE (SEPARATE FROM OAUTH)
class EbayListingService: ObservableObject {
    
    // MARK: - REAL EBAY LISTING CREATION
    func createListing(analysis: AnalysisResult, images: [UIImage], accessToken: String, completion: @escaping (Bool, String?) -> Void) {
        
        print("📤 Creating REAL eBay listing: \(analysis.name)")
        print("• Price: $\(String(format: "%.2f", analysis.suggestedPrice))")
        print("• Images: \(images.count)")
        print("• Using access token: \(accessToken.prefix(10))...")
        
        // Check if policies are configured, if not try to create them first
        if Configuration.ebayFulfillmentPolicyId.isEmpty || 
           Configuration.ebayPaymentPolicyId.isEmpty || 
           Configuration.ebayReturnPolicyId.isEmpty {
            print("🔧 Setting up eBay policies first...")
            setupDefaultPolicies(accessToken: accessToken) { [weak self] success, error in
                if success {
                    print("✅ Policies configured, proceeding with listing...")
                    self?.proceedWithListingCreation(analysis: analysis, images: images, accessToken: accessToken, completion: completion)
                } else {
                    print("⚠️ Policy setup failed, attempting listing anyway: \(error ?? "Unknown error")")
                    // Try to proceed anyway - policies might already exist
                    self?.proceedWithListingCreation(analysis: analysis, images: images, accessToken: accessToken, completion: completion)
                }
            }
        } else {
            print("✅ Policies already configured, proceeding with listing...")
            proceedWithListingCreation(analysis: analysis, images: images, accessToken: accessToken, completion: completion)
        }
    }
    
    private func proceedWithListingCreation(analysis: AnalysisResult, images: [UIImage], accessToken: String, completion: @escaping (Bool, String?) -> Void) {
        // Step 1: Upload images to eBay
        uploadImagesToEbay(images: images, accessToken: accessToken) { [weak self] imageUrls, error in
            if let error = error {
                print("❌ Image upload failed: \(error)")
                completion(false, "Failed to upload images: \(error)")
                return
            }
            
            print("✅ Images uploaded to eBay: \(imageUrls.count) URLs")
            
            // Step 2: Create inventory item
            self?.createInventoryItem(analysis: analysis, imageUrls: imageUrls, accessToken: accessToken) { inventoryItemGroupKey, error in
                if let error = error {
                    print("❌ Inventory item creation failed: \(error)")
                    completion(false, "Failed to create inventory item: \(error)")
                    return
                }
                
                guard let inventoryItemGroupKey = inventoryItemGroupKey else {
                    completion(false, "No inventory item key returned")
                    return
                }
                
                print("✅ Inventory item created: \(inventoryItemGroupKey)")
                
                // Step 3: Create offer for the inventory item
                self?.createOffer(inventoryItemGroupKey: inventoryItemGroupKey, analysis: analysis, accessToken: accessToken) { offerId, error in
                    if let error = error {
                        print("❌ Offer creation failed: \(error)")
                        completion(false, "Failed to create offer: \(error)")
                        return
                    }
                    
                    guard let offerId = offerId else {
                        completion(false, "No offer ID returned")
                        return
                    }
                    
                    print("✅ Offer created: \(offerId)")
                    
                    // Step 4: Publish the listing
                    self?.publishListing(offerId: offerId, accessToken: accessToken) { success, error in
                        if success {
                            print("🎉 eBay listing published successfully!")
                            completion(true, nil)
                        } else {
                            print("❌ Failed to publish listing: \(error ?? "Unknown error")")
                            completion(false, error ?? "Failed to publish listing")
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - STEP 1: UPLOAD IMAGES TO EBAY
    private func uploadImagesToEbay(images: [UIImage], accessToken: String, completion: @escaping ([String], String?) -> Void) {
        print("📸 Uploading \(images.count) images to eBay...")
        
        let dispatchGroup = DispatchGroup()
        var uploadedUrls: [String] = []
        var uploadError: String?
        
        for (index, image) in images.enumerated() {
            dispatchGroup.enter()
            
            uploadSingleImageToEbay(image: image, imageName: "image_\(index + 1).jpg", accessToken: accessToken) { url, error in
                if let url = url {
                    uploadedUrls.append(url)
                    print("✅ Image \(index + 1) uploaded: \(url)")
                } else {
                    uploadError = error ?? "Failed to upload image \(index + 1)"
                    print("❌ Image \(index + 1) upload failed: \(uploadError ?? "Unknown error")")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if let error = uploadError, uploadedUrls.isEmpty {
                completion([], error)
            } else {
                completion(uploadedUrls, nil)
            }
        }
    }
    
    private func uploadSingleImageToEbay(image: UIImage, imageName: String, accessToken: String, completion: @escaping (String?, String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil, "Failed to convert image to data")
            return
        }
        
        let uploadUrl = "https://api.ebay.com/sell/inventory/v1/media"
        guard let url = URL(string: uploadUrl) else {
            completion(nil, "Invalid upload URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let mediaRequest = [
            "mediaType": "IMAGE",
            "fileName": imageName,
            "binary": imageData.base64EncodedString()
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: mediaRequest)
        } catch {
            completion(nil, "Failed to encode media request")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, "Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
                    completion(nil, errorMessage)
                    return
                }
            }
            
            guard let data = data else {
                completion(nil, "No response data")
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let mediaUri = json["mediaUri"] as? String {
                    completion(mediaUri, nil)
                } else {
                    completion(nil, "Invalid response format")
                }
            } catch {
                completion(nil, "Failed to parse response")
            }
        }.resume()
    }
    
    // MARK: - STEP 2: CREATE INVENTORY ITEM
    private func createInventoryItem(analysis: AnalysisResult, imageUrls: [String], accessToken: String, completion: @escaping (String?, String?) -> Void) {
        print("📦 Creating eBay inventory item...")
        
        let inventoryItemGroupKey = "ResellAI_\(UUID().uuidString.prefix(8))"
        let sku = "RA_\(UUID().uuidString.prefix(8))"
        
        let createUrl = "https://api.ebay.com/sell/inventory/v1/inventory_item_group/\(inventoryItemGroupKey)"
        guard let url = URL(string: createUrl) else {
            completion(nil, "Invalid inventory URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Map category to eBay category ID
        let categoryId = Configuration.ebayCategoryMappings[analysis.category] ?? "99" // Default to "Other"
        
        let inventoryItem = [
            "title": analysis.title,
            "description": formatDescriptionForEbay(analysis.description),
            "aspects": [
                "Brand": [analysis.brand.isEmpty ? "Unbranded" : analysis.brand],
                "Condition": [analysis.condition],
                "Type": [analysis.category]
            ],
            "imageUrls": imageUrls,
            "availability": [
                "shipToLocationAvailability": [
                    "quantity": 1
                ]
            ],
            "condition": mapConditionForEbay(analysis.condition),
            "conditionDescription": analysis.condition,
            "packageWeightAndSize": [
                "dimensions": [
                    "height": 6.0,
                    "length": 12.0,
                    "width": 9.0,
                    "unit": "INCH"
                ],
                "packageType": "PACKAGE",
                "weight": [
                    "value": 1.0,
                    "unit": "POUND"
                ]
            ]
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: inventoryItem)
        } catch {
            completion(nil, "Failed to encode inventory item")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, "Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📦 Inventory item response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 || httpResponse.statusCode == 204 {
                    print("✅ Inventory item created successfully")
                    completion(inventoryItemGroupKey, nil)
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
                    print("❌ Inventory item creation failed: \(errorMessage)")
                    completion(nil, errorMessage)
                }
            } else {
                completion(nil, "No HTTP response")
            }
        }.resume()
    }
    
    // MARK: - STEP 3: CREATE OFFER
    private func createOffer(inventoryItemGroupKey: String, analysis: AnalysisResult, accessToken: String, completion: @escaping (String?, String?) -> Void) {
        print("💰 Creating eBay offer...")
        
        let offerId = "ResellAI_Offer_\(UUID().uuidString.prefix(8))"
        
        let createUrl = "https://api.ebay.com/sell/inventory/v1/offer"
        guard let url = URL(string: createUrl) else {
            completion(nil, "Invalid offer URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Map category to eBay category ID
        let categoryId = Configuration.ebayCategoryMappings[analysis.category] ?? "99"
        
        let offer = [
            "sku": inventoryItemGroupKey,
            "marketplaceId": "EBAY_US",
            "format": "FIXED_PRICE",
            "pricingSummary": [
                "price": [
                    "value": String(format: "%.2f", analysis.suggestedPrice),
                    "currency": "USD"
                ]
            ],
            "quantityLimitPerBuyer": 1,
            "categoryId": categoryId,
            "merchantLocationKey": "default",
            "tax": [
                "applyTax": true,
                "thirdPartyTaxCategory": "true"
            ],
            "listingDescription": formatDescriptionForEbay(analysis.description),
            "listingPolicies": [
                "fulfillmentPolicyId": getDefaultFulfillmentPolicy(),
                "paymentPolicyId": getDefaultPaymentPolicy(),
                "returnPolicyId": getDefaultReturnPolicy()
            ]
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: offer)
        } catch {
            completion(nil, "Failed to encode offer")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, "Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("💰 Offer response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                    guard let data = data else {
                        completion(nil, "No response data")
                        return
                    }
                    
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let returnedOfferId = json["offerId"] as? String {
                            print("✅ Offer created: \(returnedOfferId)")
                            completion(returnedOfferId, nil)
                        } else {
                            completion(nil, "Invalid offer response format")
                        }
                    } catch {
                        completion(nil, "Failed to parse offer response")
                    }
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
                    print("❌ Offer creation failed: \(errorMessage)")
                    completion(nil, errorMessage)
                }
            } else {
                completion(nil, "No HTTP response")
            }
        }.resume()
    }
    
    // MARK: - STEP 4: PUBLISH LISTING
    private func publishListing(offerId: String, accessToken: String, completion: @escaping (Bool, String?) -> Void) {
        print("🚀 Publishing eBay listing...")
        
        let publishUrl = "https://api.ebay.com/sell/inventory/v1/offer/\(offerId)/publish"
        guard let url = URL(string: publishUrl) else {
            completion(false, "Invalid publish URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(false, "Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🚀 Publish response: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
                    print("🎉 eBay listing published successfully!")
                    completion(true, nil)
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
                    print("❌ Listing publish failed: \(errorMessage)")
                    completion(false, errorMessage)
                }
            } else {
                completion(false, "No HTTP response")
            }
        }.resume()
    }
    
    // MARK: - POLICY MANAGEMENT
    func setupDefaultPolicies(accessToken: String, completion: @escaping (Bool, String?) -> Void) {
        print("🔧 Setting up default eBay policies...")
        
        // Create default fulfillment policy
        createDefaultFulfillmentPolicy(accessToken: accessToken) { [weak self] policyId, error in
            if let error = error {
                completion(false, "Failed to create fulfillment policy: \(error)")
                return
            }
            
            print("✅ Fulfillment policy ready: \(policyId ?? "default")")
            
            // Create default payment policy
            self?.createDefaultPaymentPolicy(accessToken: accessToken) { paymentPolicyId, error in
                if let error = error {
                    completion(false, "Failed to create payment policy: \(error)")
                    return
                }
                
                print("✅ Payment policy ready: \(paymentPolicyId ?? "default")")
                
                // Create default return policy
                self?.createDefaultReturnPolicy(accessToken: accessToken) { returnPolicyId, error in
                    if let error = error {
                        completion(false, "Failed to create return policy: \(error)")
                        return
                    }
                    
                    print("✅ Return policy ready: \(returnPolicyId ?? "default")")
                    print("🎉 All eBay policies configured successfully!")
                    completion(true, nil)
                }
            }
        }
    }
    
    private func createDefaultFulfillmentPolicy(accessToken: String, completion: @escaping (String?, String?) -> Void) {
        let url = "https://api.ebay.com/sell/account/v1/fulfillment_policy"
        guard let requestUrl = URL(string: url) else {
            completion(nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let policy = [
            "name": "ResellAI Default Shipping",
            "description": "Standard shipping policy for ResellAI listings",
            "marketplaceId": "EBAY_US",
            "categoryTypes": [
                [
                    "name": "ALL_EXCLUDING_MOTORS_VEHICLES",
                    "default": true
                ]
            ],
            "handlingTime": [
                "value": 1,
                "unit": "DAY"
            ],
            "shippingOptions": [
                [
                    "optionType": "DOMESTIC",
                    "costType": "FLAT_RATE",
                    "shippingServices": [
                        [
                            "serviceName": "USPSGround",
                            "cost": [
                                "value": "8.50",
                                "currency": "USD"
                            ]
                        ]
                    ]
                ]
            ]
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: policy)
        } catch {
            completion(nil, "Failed to encode policy")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let policyId = json["fulfillmentPolicyId"] as? String {
                        completion(policyId, nil)
                    } else {
                        completion("created", nil)
                    }
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
                    completion(nil, errorMessage)
                }
            }
        }.resume()
    }
    
    private func createDefaultPaymentPolicy(accessToken: String, completion: @escaping (String?, String?) -> Void) {
        let url = "https://api.ebay.com/sell/account/v1/payment_policy"
        guard let requestUrl = URL(string: url) else {
            completion(nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let policy = [
            "name": "ResellAI Default Payment",
            "description": "Standard payment policy for ResellAI listings",
            "marketplaceId": "EBAY_US",
            "categoryTypes": [
                [
                    "name": "ALL_EXCLUDING_MOTORS_VEHICLES",
                    "default": true
                ]
            ],
            "paymentMethods": [
                [
                    "paymentMethodType": "PAYPAL",
                    "recipientAccountReference": [
                        "referenceId": "paypal",
                        "referenceType": "PAYPAL_EMAIL"
                    ]
                ]
            ]
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: policy)
        } catch {
            completion(nil, "Failed to encode policy")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let policyId = json["paymentPolicyId"] as? String {
                        completion(policyId, nil)
                    } else {
                        completion("created", nil)
                    }
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
                    completion(nil, errorMessage)
                }
            }
        }.resume()
    }
    
    private func createDefaultReturnPolicy(accessToken: String, completion: @escaping (String?, String?) -> Void) {
        let url = "https://api.ebay.com/sell/account/v1/return_policy"
        guard let requestUrl = URL(string: url) else {
            completion(nil, "Invalid URL")
            return
        }
        
        var request = URLRequest(url: requestUrl)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let policy = [
            "name": "ResellAI Default Returns",
            "description": "Standard return policy for ResellAI listings",
            "marketplaceId": "EBAY_US",
            "categoryTypes": [
                [
                    "name": "ALL_EXCLUDING_MOTORS_VEHICLES",
                    "default": true
                ]
            ],
            "returnsAccepted": true,
            "returnPeriod": [
                "value": 30,
                "unit": "DAY"
            ],
            "returnMethod": "REPLACEMENT",
            "returnShippingCostPayer": "BUYER"
        ] as [String: Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: policy)
        } catch {
            completion(nil, "Failed to encode policy")
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 201 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let policyId = json["returnPolicyId"] as? String {
                        completion(policyId, nil)
                    } else {
                        completion("created", nil)
                    }
                } else {
                    let errorMessage = data.flatMap { String(data: $0, encoding: .utf8) } ?? "HTTP \(httpResponse.statusCode)"
                    completion(nil, errorMessage)
                }
            }
        }.resume()
    }
    
    // MARK: - HELPER METHODS
    private func formatDescriptionForEbay(_ description: String) -> String {
        // Format description with HTML for eBay
        var formatted = description
        formatted = formatted.replacingOccurrences(of: "\n", with: "<br>")
        formatted = formatted.replacingOccurrences(of: "•", with: "&#8226;")
        return formatted
    }
    
    private func mapConditionForEbay(_ condition: String) -> String {
        return Configuration.ebayConditionMappings[condition] ?? "USED_GOOD"
    }
    
    private func getDefaultFulfillmentPolicy() -> String {
        if !Configuration.ebayFulfillmentPolicyId.isEmpty {
            return Configuration.ebayFulfillmentPolicyId
        }
        
        print("⚠️ No fulfillment policy configured - will attempt to use default")
        return "default_fulfillment"
    }
    
    private func getDefaultPaymentPolicy() -> String {
        if !Configuration.ebayPaymentPolicyId.isEmpty {
            return Configuration.ebayPaymentPolicyId
        }
        
        print("⚠️ No payment policy configured - will attempt to use default")
        return "default_payment"
    }
    
    private func getDefaultReturnPolicy() -> String {
        if !Configuration.ebayReturnPolicyId.isEmpty {
            return Configuration.ebayReturnPolicyId
        }
        
        print("⚠️ No return policy configured - will attempt to use default")
        return "default_return"
    }
}