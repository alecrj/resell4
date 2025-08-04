//
//  ContentView.swift
//  ResellAI
//
//  Ultimate Consolidated Views - FAANG Level Architecture
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import MessageUI

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var businessService = BusinessService()
    
    var body: some View {
        VStack(spacing: 0) {
            BusinessHeader()
            BusinessTabView()
                .environmentObject(inventoryManager)
                .environmentObject(businessService)
        }
        .onAppear {
            Configuration.validateConfiguration()
            businessService.initialize()
        }
    }
}

// MARK: - BUSINESS HEADER
struct BusinessHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ResellAI")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("Ultimate Reselling Tool")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Configuration.isFullyConfigured ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(Configuration.isFullyConfigured ? "Ready" : "Setup")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Configuration.isFullyConfigured ? .green : .orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill((Configuration.isFullyConfigured ? Color.green : Color.orange).opacity(0.1))
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator))
                .opacity(0.3),
            alignment: .bottom
        )
    }
}

// MARK: - BUSINESS TAB VIEW
struct BusinessTabView: View {
    var body: some View {
        TabView {
            AnalysisView()
                .tabItem {
                    Image(systemName: "viewfinder")
                    Text("Analyze")
                }
            
            DashboardView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Dashboard")
                }
            
            InventoryView()
                .tabItem {
                    Image(systemName: "list.bullet.rectangle.portrait")
                    Text("Inventory")
                }
            
            StorageView()
                .tabItem {
                    Image(systemName: "archivebox.fill")
                    Text("Storage")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape.fill")
                    Text("Settings")
                }
        }
        .accentColor(.accentColor)
    }
}

// MARK: - ANALYSIS VIEW
struct AnalysisView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var businessService: BusinessService
    
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var analysisResult: AnalysisResult?
    @State private var showingItemForm = false
    @State private var showingDirectListing = false
    @State private var showingBarcodeLookup = false
    @State private var scannedBarcode: String?
    @State private var isAnalyzing = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    if capturedImages.isEmpty {
                        // Camera section
                        CameraSection(
                            onCamera: { showingCamera = true },
                            onLibrary: { showingPhotoLibrary = true },
                            onBarcode: { showingBarcodeLookup = true },
                            onAnalyze: analyzeImages,
                            hasPhotos: !capturedImages.isEmpty,
                            isAnalyzing: isAnalyzing,
                            isConfigured: Configuration.isFullyConfigured,
                            onReset: resetAnalysis
                        )
                    } else {
                        // Photo grid
                        PhotoGrid(images: capturedImages, onRemove: removeImage)
                        
                        // Analysis button
                        AnalysisButton(
                            isAnalyzing: isAnalyzing,
                            isConfigured: Configuration.isFullyConfigured,
                            onAction: analyzeImages
                        )
                        
                        // Reset button
                        if !isAnalyzing {
                            Button("Start Over", action: resetAnalysis)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Analysis progress
                    if isAnalyzing {
                        AnalysisProgress(
                            progress: businessService.analysisProgress,
                            currentStep: businessService.currentStep,
                            totalSteps: businessService.totalSteps
                        )
                    }
                    
                    // Analysis result
                    if let analysisResult = analysisResult {
                        AnalysisResultView(
                            analysis: analysisResult,
                            onAddToInventory: addToInventory,
                            onDirectListing: { showingDirectListing = true }
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Analyze Item")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingCamera) {
            ResellAICameraView { images in
                capturedImages.append(contentsOf: images)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            ResellAIPhotoLibraryView { images in
                capturedImages.append(contentsOf: images)
            }
        }
        .sheet(isPresented: $showingItemForm) {
            if let analysisResult = analysisResult {
                ItemFormView(analysisResult: analysisResult) { item in
                    let _ = inventoryManager.addItem(item)
                    resetAnalysis()
                }
            }
        }
        .sheet(isPresented: $showingDirectListing) {
            if let analysisResult = analysisResult {
                DirectListingView(analysisResult: analysisResult)
            }
        }
        .sheet(isPresented: $showingBarcodeLookup) {
            ResellAIBarcodeScannerView { barcode in
                scannedBarcode = barcode
                analyzeBarcodeItem(barcode)
            }
        }
    }
    
    private func analyzeImages() {
        guard !capturedImages.isEmpty else { return }
        
        isAnalyzing = true
        businessService.analyzeItem(capturedImages) { result in
            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
            }
        }
    }
    
    private func analyzeBarcodeItem(_ barcode: String) {
        isAnalyzing = true
        businessService.analyzeBarcode(barcode, images: capturedImages) { result in
            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
            }
        }
    }
    
    private func addToInventory() {
        guard let analysisResult = analysisResult else { return }
        showingItemForm = true
    }
    
    private func removeImage(at index: Int) {
        capturedImages.remove(at: index)
    }
    
    private func resetAnalysis() {
        capturedImages = []
        analysisResult = nil
        scannedBarcode = nil
    }
}

// MARK: - CAMERA SECTION
struct CameraSection: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void
    let onBarcode: () -> Void
    let onAnalyze: () -> Void
    let hasPhotos: Bool
    let isAnalyzing: Bool
    let isConfigured: Bool
    let onReset: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Take or select photos of your item")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 16) {
                ActionButton(
                    icon: "camera.fill",
                    title: "Camera",
                    color: .blue,
                    action: onCamera
                )
                
                ActionButton(
                    icon: "photo.on.rectangle",
                    title: "Photos",
                    color: .green,
                    action: onLibrary
                )
                
                ActionButton(
                    icon: "barcode.viewfinder",
                    title: "Scan",
                    color: .orange,
                    action: onBarcode
                )
            }
            
            if hasPhotos {
                Button(action: onAnalyze) {
                    HStack(spacing: 8) {
                        if isAnalyzing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                            Text("Analyzing...")
                        } else {
                            Image(systemName: "brain.head.profile")
                            Text("Analyze Item")
                        }
                    }
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isConfigured ? Color.accentColor : Color.gray)
                    )
                }
                .disabled(isAnalyzing || !isConfigured)
                
                if !isAnalyzing {
                    Button("Start Over", action: onReset)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - ACTION BUTTON
struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
            )
        }
    }
}

// MARK: - PHOTO GRID
struct PhotoGrid: View {
    let images: [UIImage]
    let onRemove: (Int) -> Void
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(12)
                    
                    Button(action: { onRemove(index) }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            }
        }
    }
}

// MARK: - ANALYSIS BUTTON
struct AnalysisButton: View {
    let isAnalyzing: Bool
    let isConfigured: Bool
    let onAction: () -> Void
    
    var body: some View {
        Button(action: onAction) {
            HStack(spacing: 8) {
                if isAnalyzing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Analyzing...")
                } else {
                    Image(systemName: "brain.head.profile")
                    Text("Analyze Item")
                }
            }
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isConfigured ? Color.accentColor : Color.gray)
            )
        }
        .disabled(isAnalyzing || !isConfigured)
    }
}

// MARK: - ANALYSIS PROGRESS
struct AnalysisProgress: View {
    let progress: String
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            Text(progress)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.primary)
            
            Text("Step \(currentStep) of \(totalSteps)")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - ANALYSIS RESULT VIEW
struct AnalysisResultView: View {
    let analysis: AnalysisResult
    let onAddToInventory: () -> Void
    let onDirectListing: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Item identification
            ItemIdentificationCard(analysis: analysis)
            
            // Market analysis
            MarketAnalysisCard(analysis: analysis)
            
            // Pricing recommendations
            PricingCard(analysis: analysis)
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Add to Inventory", action: onAddToInventory)
                    .buttonStyle(PrimaryButtonStyle())
                
                Button("List on eBay", action: onDirectListing)
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
}

// MARK: - ITEM IDENTIFICATION CARD
struct ItemIdentificationCard: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Item Identification")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(analysis.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                if !analysis.brand.isEmpty {
                    Label(analysis.brand, systemImage: "tag.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                if !analysis.category.isEmpty {
                    Label(analysis.category, systemImage: "folder.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                
                if !analysis.condition.isEmpty {
                    Label(analysis.condition, systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - MARKET ANALYSIS CARD
struct MarketAnalysisCard: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Analysis")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                MarketStat(
                    title: "Sold Items",
                    value: "\(analysis.soldListingsCount ?? 0)",
                    color: .blue
                )
                
                MarketStat(
                    title: "Avg Price",
                    value: "$\(Int(analysis.averagePrice ?? 0))",
                    color: .green
                )
                
                MarketStat(
                    title: "Confidence",
                    value: "\(Int((analysis.marketConfidence ?? 0) * 100))%",
                    color: .purple
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - MARKET STAT
struct MarketStat: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - PRICING CARD
struct PricingCard: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pricing Strategy")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                PriceOption(
                    title: "Quick Sale",
                    price: analysis.quickPrice,
                    subtitle: "Sells Fast",
                    color: .red
                )
                
                PriceOption(
                    title: "Market",
                    price: analysis.suggestedPrice,
                    subtitle: "Best Value",
                    color: .green,
                    isHighlighted: true
                )
                
                PriceOption(
                    title: "Premium",
                    price: analysis.premiumPrice,
                    subtitle: "Max Profit",
                    color: .blue
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - PRICE OPTION
struct PriceOption: View {
    let title: String
    let price: Double
    let subtitle: String
    let color: Color
    let isHighlighted: Bool
    
    init(title: String, price: Double, subtitle: String, color: Color, isHighlighted: Bool = false) {
        self.title = title
        self.price = price
        self.subtitle = subtitle
        self.color = color
        self.isHighlighted = isHighlighted
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isHighlighted ? .white : color)
            
            Text("$\(Int(price))")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(isHighlighted ? .white : color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(isHighlighted ? .white.opacity(0.8) : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isHighlighted ? color : color.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color, lineWidth: isHighlighted ? 0 : 1)
        )
    }
}

// MARK: - DASHBOARD VIEW
struct DashboardView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats overview
                    DashboardStats(inventoryManager: inventoryManager)
                    
                    // Recent items
                    RecentItemsCard(items: Array(inventoryManager.recentItems.prefix(3)))
                    
                    // Quick actions
                    QuickActionsCard()
                }
                .padding(20)
            }
            .navigationTitle("Dashboard")
        }
    }
}

// MARK: - DASHBOARD STATS
struct DashboardStats: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Business Overview")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Total Items",
                    value: "\(inventoryManager.items.count)",
                    color: .blue
                )
                
                StatCard(
                    title: "Listed",
                    value: "\(inventoryManager.listedItems)",
                    color: .green
                )
                
                StatCard(
                    title: "Sold",
                    value: "\(inventoryManager.soldItems)",
                    color: .purple
                )
                
                StatCard(
                    title: "Total Value",
                    value: "$\(Int(inventoryManager.totalEstimatedValue))",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - STAT CARD
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - RECENT ITEMS CARD
struct RecentItemsCard: View {
    let items: [InventoryItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(items) { item in
                RecentItemRow(item: item)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - RECENT ITEM ROW
struct RecentItemRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(Int(item.suggestedPrice))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(item.status.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - QUICK ACTIONS CARD
struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                QuickActionButton(
                    title: "Analyze New Item",
                    icon: "viewfinder",
                    color: .blue
                ) {
                    // Navigate to analysis tab
                }
                
                QuickActionButton(
                    title: "View Inventory",
                    icon: "list.bullet",
                    color: .green
                ) {
                    // Navigate to inventory tab
                }
                
                QuickActionButton(
                    title: "Export Data",
                    icon: "square.and.arrow.up",
                    color: .purple
                ) {
                    // Show export options
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - QUICK ACTION BUTTON
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemBackground))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - INVENTORY VIEW
struct InventoryView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    
    @State private var searchText = ""
    @State private var selectedStatus: ItemStatus?
    @State private var selectedCategory = ""
    @State private var showingFilters = false
    
    var filteredItems: [InventoryItem] {
        inventoryManager.items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText) ||
                item.brand.localizedCaseInsensitiveContains(searchText) ||
                item.category.localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = selectedStatus == nil || item.status == selectedStatus
            let matchesCategory = selectedCategory.isEmpty || item.category == selectedCategory
            
            return matchesSearch && matchesStatus && matchesCategory
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(
                                title: "All",
                                isSelected: selectedStatus == nil
                            ) {
                                selectedStatus = nil
                            }
                            
                            ForEach(ItemStatus.allCases, id: \.self) { status in
                                FilterChip(
                                    title: status.rawValue,
                                    isSelected: selectedStatus == status
                                ) {
                                    selectedStatus = status
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Items list
                if filteredItems.isEmpty {
                    EmptyInventoryView()
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            InventoryItemRow(item: item)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                inventoryManager.deleteItem(filteredItems[index])
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilters) {
            InventoryFiltersView(
                selectedStatus: $selectedStatus,
                selectedCategory: $selectedCategory
            )
        }
    }
}

// MARK: - SEARCH BAR
struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search inventory...", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground))
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - FILTER CHIP
struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.accentColor : Color(.systemGray5))
                )
        }
    }
}

// MARK: - INVENTORY ITEM ROW
struct InventoryItemRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Item image placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(item.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(item.inventoryCode)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Price and status
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(Int(item.suggestedPrice))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text(item.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(item.status.color.opacity(0.2))
                    )
                    .foregroundColor(item.status.color)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - EMPTY INVENTORY VIEW
struct EmptyInventoryView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Items Found")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Start by analyzing your first item!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - STORAGE VIEW
struct StorageView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    StorageOverview(inventoryManager: inventoryManager)
                    StorageByCategory(inventoryManager: inventoryManager)
                }
                .padding(20)
            }
            .navigationTitle("Storage")
        }
    }
}

// MARK: - STORAGE OVERVIEW
struct StorageOverview: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(
                    title: "Total Items",
                    value: "\(inventoryManager.items.count)",
                    color: .blue
                )
                
                StatCard(
                    title: "Packaged",
                    value: "\(inventoryManager.getPackagedItems().count)",
                    color: .green
                )
                
                StatCard(
                    title: "Ready to Ship",
                    value: "\(inventoryManager.getItemsReadyToList().count)",
                    color: .orange
                )
                
                StatCard(
                    title: "Categories",
                    value: "\(inventoryManager.getCategoryBreakdown().count)",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - STORAGE BY CATEGORY
struct StorageByCategory: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage by Category")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(inventoryManager.getInventoryOverview(), id: \.letter) { overview in
                CategoryStorageCard(overview: overview)
            }
        }
    }
}

// MARK: - CATEGORY STORAGE CARD
struct CategoryStorageCard: View {
    let overview: (letter: String, category: String, count: Int, items: [InventoryItem])
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Category \(overview.letter)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(overview.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(overview.category)
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - SETTINGS VIEW
struct SettingsView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var businessService: BusinessService
    
    @State private var showingExport = false
    @State private var showingAPIConfig = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Business") {
                    SettingsRow(
                        title: "Export Data",
                        icon: "square.and.arrow.up",
                        color: .blue
                    ) {
                        showingExport = true
                    }
                    
                    SettingsRow(
                        title: "API Configuration",
                        icon: "network",
                        color: .green
                    ) {
                        showingAPIConfig = true
                    }
                }
                
                Section("App") {
                    SettingsRow(
                        title: "About ResellAI",
                        icon: "info.circle",
                        color: .gray
                    ) {
                        showingAbout = true
                    }
                }
                
                Section("Data") {
                    Button("Clear All Data") {
                        // Implement clear data functionality
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingExport) {
            ExportView()
                .environmentObject(inventoryManager)
        }
        .sheet(isPresented: $showingAPIConfig) {
            APIConfigView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
}

// MARK: - SETTINGS ROW
struct SettingsRow: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - SUPPORTING VIEWS (Placeholder implementations)

struct ResellAICameraView: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: ([UIImage]) -> Void
        
        init(completion: @escaping ([UIImage]) -> Void) {
            self.completion = completion
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                completion([image])
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct ResellAIPhotoLibraryView: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: ([UIImage]) -> Void
        
        init(completion: @escaping ([UIImage]) -> Void) {
            self.completion = completion
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                completion([image])
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

struct ResellAIBarcodeScannerView: View {
    let completion: (String) -> Void
    
    var body: some View {
        Text("Barcode Scanner Placeholder")
            .onAppear {
                // Simulate barcode scan
                completion("123456789")
            }
    }
}

struct ItemFormView: View {
    let analysisResult: AnalysisResult
    let completion: (InventoryItem) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Item Form Placeholder")
                Button("Save") {
                    // Create item from analysis result
                    let item = InventoryItem(
                        itemNumber: 1,
                        name: analysisResult.name,
                        category: analysisResult.category,
                        purchasePrice: 0,
                        suggestedPrice: analysisResult.suggestedPrice,
                        source: "Analysis",
                        condition: analysisResult.condition,
                        title: analysisResult.title,
                        description: analysisResult.description,
                        keywords: analysisResult.keywords,
                        status: .toList,
                        dateAdded: Date()
                    )
                    completion(item)
                }
            }
            .navigationTitle("Add Item")
        }
    }
}

struct DirectListingView: View {
    let analysisResult: AnalysisResult
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Direct eBay Listing Placeholder")
                Text("Would create eBay listing for: \(analysisResult.name)")
            }
            .navigationTitle("List on eBay")
        }
    }
}

struct InventoryFiltersView: View {
    @Binding var selectedStatus: ItemStatus?
    @Binding var selectedCategory: String
    
    var body: some View {
        NavigationView {
            Form {
                Section("Status") {
                    ForEach(ItemStatus.allCases, id: \.self) { status in
                        Button(status.rawValue) {
                            selectedStatus = status
                        }
                    }
                }
            }
            .navigationTitle("Filters")
        }
    }
}

struct ExportView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Export Options Placeholder")
                Button("Export CSV") {
                    let csv = inventoryManager.exportToCSV()
                    print("CSV Export: \(csv)")
                }
            }
            .navigationTitle("Export Data")
        }
    }
}

struct APIConfigView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("API Configuration Placeholder")
                Text("Status: \(Configuration.configurationStatus)")
            }
            .navigationTitle("API Settings")
        }
    }
}

struct AboutView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("ResellAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Version \(Configuration.version)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("The ultimate reselling business tool powered by AI")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .padding()
            }
            .navigationTitle("About")
        }
    }
}

// MARK: - BUTTON STYLES
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Color.accentColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - EXTENSIONS
extension ItemStatus {
    var statusColor: Color {
        switch self {
        case .toList: return .blue
        case .listed: return .green
        case .sold: return .purple
        case .photographed: return .orange
        case .sourced: return .gray
        }
    }
}

// MARK: - PREVIEW
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
