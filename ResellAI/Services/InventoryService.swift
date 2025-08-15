//
//  InventoryService.swift
//  ResellAI
//
//  Inventory Management Service
//

import SwiftUI
import Foundation

// MARK: - INVENTORY SERVICE
class InventoryService: ObservableObject {
    @Published var items: [InventoryItem] = []
    @Published var isLoading = false
    @Published var lastError: String?
    
    // Filtering and sorting
    @Published var searchText = ""
    @Published var selectedCategory: String = "All"
    @Published var selectedStatus: ItemStatus?
    @Published var sortOption: SortOption = .dateAdded
    
    // Statistics
    @Published var statistics: InventoryStatistics?
    
    // Firebase integration
    private weak var firebaseService: FirebaseService?
    
    // Persistence key
    private let storageKey = "SavedInventoryItems"
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case name = "Name"
        case price = "Price"
        case roi = "ROI"
        case status = "Status"
    }
    
    init() {
        loadSavedItems()
        updateStatistics()
    }
    
    func initialize(with firebaseService: FirebaseService) {
        self.firebaseService = firebaseService
        
        // Load any synced items from Firebase
        syncFromFirebase()
    }
    
    // MARK: - COMPUTED PROPERTIES
    
    var filteredItems: [InventoryItem] {
        var filtered = items
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.brand.localizedCaseInsensitiveContains(searchText) ||
                item.title.localizedCaseInsensitiveContains(searchText) ||
                item.inventoryCode.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply category filter
        if selectedCategory != "All" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // Apply status filter
        if let status = selectedStatus {
            filtered = filtered.filter { $0.status == status }
        }
        
        // Apply sorting
        switch sortOption {
        case .dateAdded:
            filtered.sort { $0.dateAdded > $1.dateAdded }
        case .name:
            filtered.sort { $0.name < $1.name }
        case .price:
            filtered.sort { $0.suggestedPrice > $1.suggestedPrice }
        case .roi:
            filtered.sort { $0.estimatedROI > $1.estimatedROI }
        case .status:
            filtered.sort { $0.status.rawValue < $1.status.rawValue }
        }
        
        return filtered
    }
    
    var categories: [String] {
        let allCategories = items.map { $0.category }
        let uniqueCategories = Array(Set(allCategories)).sorted()
        return ["All"] + uniqueCategories
    }
    
    var totalInventoryValue: Double {
        return items.reduce(0) { $0 + $1.suggestedPrice }
    }
    
    var totalInvestment: Double {
        return items.reduce(0) { $0 + $1.purchasePrice }
    }
    
    var totalProfit: Double {
        return items.filter { $0.status == .sold }.reduce(0) { $0 + $1.profit }
    }
    
    var averageROI: Double {
        let soldItems = items.filter { $0.status == .sold }
        guard !soldItems.isEmpty else { return 0 }
        let totalROI = soldItems.reduce(0) { $0 + $1.roi }
        return totalROI / Double(soldItems.count)
    }
    
    // MARK: - ITEM MANAGEMENT
    
    func addItem(from analysis: AnalysisResult, images: [UIImage], purchasePrice: Double, source: String) {
        let itemNumber = getNextItemNumber()
        let inventoryCode = generateInventoryCode(category: analysis.category, itemNumber: itemNumber)
        
        let newItem = InventoryItem(
            itemNumber: itemNumber,
            name: analysis.name,
            category: analysis.category,
            purchasePrice: purchasePrice,
            suggestedPrice: analysis.suggestedPrice,
            source: source,
            condition: analysis.condition,
            title: analysis.title,
            description: analysis.description,
            keywords: analysis.keywords,
            status: .sourced,
            dateAdded: Date(),
            imageData: images.first?.jpegData(compressionQuality: 0.8),
            additionalImageData: Array(images.dropFirst()).compactMap { $0.jpegData(compressionQuality: 0.8) },
            resalePotential: analysis.resalePotential,
            marketNotes: "AI Analysis: \(analysis.demandLevel ?? "Unknown demand")",
            aiConfidence: analysis.aiConfidence,
            competitorCount: analysis.competitorCount,
            demandLevel: analysis.demandLevel,
            listingStrategy: analysis.listingStrategy,
            sourcingTips: analysis.sourcingTips,
            brand: analysis.brand,
            exactModel: analysis.exactModel ?? "",
            size: analysis.size ?? "",
            colorway: analysis.colorway ?? "",
            releaseYear: analysis.releaseYear ?? "",
            subcategory: analysis.subcategory ?? analysis.category,
            marketConfidence: analysis.marketConfidence,
            soldListingsCount: analysis.soldListingsCount,
            priceRange: analysis.priceRange
        )
        
        items.append(newItem)
        saveItems()
        updateStatistics()
        
        // Sync to Firebase if available
        firebaseService?.syncInventoryItem(newItem) { success in
            if success {
                print("✅ Item synced to Firebase")
            }
        }
        
        print("📦 Added item to inventory: \(newItem.name)")
    }
    
    func updateItem(_ item: InventoryItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
            updateStatistics()
            
            // Sync update to Firebase
            firebaseService?.syncInventoryItem(item) { success in
                if success {
                    print("✅ Item update synced to Firebase")
                }
            }
        }
    }
    
    func deleteItem(_ item: InventoryItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
        updateStatistics()
    }
    
    func markAsListed(_ item: InventoryItem, ebayURL: String? = nil) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].status = .listed
            items[index].dateListed = Date()
            items[index].ebayURL = ebayURL
            saveItems()
            updateStatistics()
            
            // Sync to Firebase
            firebaseService?.syncInventoryItem(items[index]) { _ in }
        }
    }
    
    func markAsSold(_ item: InventoryItem, soldPrice: Double) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].status = .sold
            items[index].dateSold = Date()
            items[index].actualPrice = soldPrice
            saveItems()
            updateStatistics()
            
            // Sync to Firebase
            firebaseService?.syncInventoryItem(items[index]) { _ in }
        }
    }
    
    // MARK: - HELPER METHODS
    
    private func getNextItemNumber() -> Int {
        let maxNumber = items.map { $0.itemNumber }.max() ?? 0
        return maxNumber + 1
    }
    
    private func generateInventoryCode(category: String, itemNumber: Int) -> String {
        let categoryLetter = getCategoryLetter(for: category)
        return "\(categoryLetter)\(String(format: "%04d", itemNumber))"
    }
    
    private func getCategoryLetter(for category: String) -> String {
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
    
    // MARK: - STATISTICS
    
    private func updateStatistics() {
        let totalItems = items.count
        let listedItems = items.filter { $0.status == .listed }.count
        let soldItems = items.filter { $0.status == .sold }.count
        
        statistics = InventoryStatistics(
            totalItems: totalItems,
            listedItems: listedItems,
            soldItems: soldItems,
            totalInvestment: totalInvestment,
            totalProfit: totalProfit,
            averageROI: averageROI,
            estimatedValue: totalInventoryValue
        )
    }
    
    // MARK: - PERSISTENCE
    
    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: storageKey)
            print("💾 Saved \(items.count) inventory items")
        } catch {
            print("❌ Error saving inventory: \(error)")
            lastError = "Failed to save inventory"
        }
    }
    
    private func loadSavedItems() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            print("📦 No saved inventory found")
            return
        }
        
        do {
            items = try JSONDecoder().decode([InventoryItem].self, from: data)
            print("📦 Loaded \(items.count) inventory items")
        } catch {
            print("❌ Error loading inventory: \(error)")
            lastError = "Failed to load inventory"
        }
    }
    
    // MARK: - FIREBASE SYNC
    
    private func syncFromFirebase() {
        guard let firebaseService = firebaseService else { return }
        
        isLoading = true
        
        firebaseService.loadUserInventory { [weak self] firebaseItems in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                // Merge Firebase items with local items
                // This is a simple implementation - you might want more sophisticated merging
                print("📥 Loaded \(firebaseItems.count) items from Firebase")
                
                // For now, we'll just log the count
                // In a full implementation, you'd convert FirebaseInventoryItem to InventoryItem
                // and merge with local data
            }
        }
    }
    
    // MARK: - EXPORT METHODS
    
    func exportToCSV() -> String {
        var csv = "Item #,Code,Name,Brand,Category,Purchase Price,Suggested Price,Actual Price,Status,ROI %,Date Added,Date Listed,Date Sold\n"
        
        for item in items {
            let row = [
                "\(item.itemNumber)",
                item.inventoryCode,
                item.name,
                item.brand,
                item.category,
                String(format: "%.2f", item.purchasePrice),
                String(format: "%.2f", item.suggestedPrice),
                item.actualPrice != nil ? String(format: "%.2f", item.actualPrice!) : "",
                item.status.rawValue,
                String(format: "%.1f", item.roi),
                ISO8601DateFormatter().string(from: item.dateAdded),
                item.dateListed != nil ? ISO8601DateFormatter().string(from: item.dateListed!) : "",
                item.dateSold != nil ? ISO8601DateFormatter().string(from: item.dateSold!) : ""
            ].joined(separator: ",")
            
            csv += row + "\n"
        }
        
        return csv
    }
    
    // MARK: - SEARCH AND FILTER
    
    func search(_ query: String) {
        searchText = query
    }
    
    func filterByCategory(_ category: String) {
        selectedCategory = category
    }
    
    func filterByStatus(_ status: ItemStatus?) {
        selectedStatus = status
    }
    
    func sort(by option: SortOption) {
        sortOption = option
    }
    
    func resetFilters() {
        searchText = ""
        selectedCategory = "All"
        selectedStatus = nil
        sortOption = .dateAdded
    }
}
