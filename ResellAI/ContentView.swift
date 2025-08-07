//
//  ContentView.swift
//  ResellAI
//
//  Complete Reselling Automation with WORKING Web-to-App Bridge OAuth
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import MessageUI
import LocalAuthentication

// MARK: - MAIN CONTENT VIEW WITH FIREBASE
struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var businessService = BusinessService()
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                AuthenticatedAppView()
                    .environmentObject(firebaseService)
                    .environmentObject(inventoryManager)
                    .environmentObject(businessService)
            } else {
                FirebaseAuthView()
                    .environmentObject(firebaseService)
            }
        }
        .onAppear {
            Configuration.validateConfiguration()
            
            // Initialize services with Firebase
            businessService.initialize(with: firebaseService)
            inventoryManager.initialize(with: firebaseService)
        }
        .onOpenURL { url in
            print("📱 App received URL: \(url)")
            
            // Handle eBay OAuth callback from web-to-app bridge
            if url.scheme == "resellai" && url.host == "auth" {
                if url.path == "/ebay" || url.path.contains("ebay") {
                    print("✅ Processing eBay OAuth callback from web bridge")
                    print("📞 Callback URL: \(url.absoluteString)")
                    
                    // Handle the OAuth callback
                    businessService.handleEbayAuthCallback(url: url)
                }
            }
        }
    }
}

// MARK: - AUTHENTICATED APP VIEW
struct AuthenticatedAppView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        VStack(spacing: 0) {
            BusinessHeader()
            BusinessTabView()
        }
    }
}

// MARK: - BUSINESS HEADER WITH USER INFO
struct BusinessHeader: View {
    @EnvironmentObject var firebaseService: FirebaseService
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ResellAI")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let user = firebaseService.currentUser {
                        Text("Welcome, \(user.displayName ?? "User")")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Configuration.isFullyConfigured ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        
                        Text(Configuration.isFullyConfigured ? "Ready" : "Setup")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Configuration.isFullyConfigured ? .green : .orange)
                    }
                    
                    if let user = firebaseService.currentUser {
                        Text("\(firebaseService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
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

// MARK: - BUSINESS TAB VIEW WITH QUEUE
struct BusinessTabView: View {
    var body: some View {
        TabView {
            AnalysisView()
                .tabItem {
                    Image(systemName: "viewfinder")
                    Text("Analyze")
                }
            
            QueueView()
                .tabItem {
                    Image(systemName: "tray.full")
                    Text("Queue")
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

// MARK: - ANALYSIS VIEW WITH FIXED MULTI-PHOTO
struct AnalysisView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var businessService: BusinessService
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var analysisResult: AnalysisResult?
    @State private var showingItemForm = false
    @State private var showingEbayAuth = false
    @State private var showingBarcodeLookup = false
    @State private var showingUsageLimit = false
    @State private var scannedBarcode: String?
    @State private var isAnalyzing = false
    @State private var isCreatingListing = false
    @State private var listingStatus = ""
    
    // PhotosPicker state
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Usage status
                    if let user = firebaseService.currentUser {
                        UsageStatusCard(
                            analysisCount: firebaseService.monthlyAnalysisCount,
                            analysisLimit: user.monthlyAnalysisLimit,
                            listingCount: firebaseService.monthlyListingCount,
                            listingLimit: user.monthlyListingLimit,
                            plan: user.currentPlan,
                            canAnalyze: firebaseService.canAnalyze,
                            canCreateListing: firebaseService.canCreateListing,
                            daysUntilReset: firebaseService.daysUntilReset
                        ) {
                            showingUsageLimit = true
                        }
                    }
                    
                    if capturedImages.isEmpty {
                        // Camera section
                        CameraSection(
                            onCamera: { showingCamera = true },
                            onLibrary: { showingPhotoLibrary = true },
                            onBarcode: { showingBarcodeLookup = true },
                            onAnalyze: analyzeImages,
                            hasPhotos: !capturedImages.isEmpty,
                            isAnalyzing: isAnalyzing,
                            isConfigured: Configuration.isFullyConfigured && firebaseService.canAnalyze,
                            onReset: resetAnalysis
                        )
                    } else {
                        // Photo grid with remove functionality
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(capturedImages.count) photo\(capturedImages.count == 1 ? "" : "s") selected")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, image in
                                    ZStack(alignment: .topTrailing) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(height: 120)
                                            .clipped()
                                            .cornerRadius(12)
                                        
                                        Button(action: {
                                            capturedImages.remove(at: index)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.6))
                                                .clipShape(Circle())
                                        }
                                        .padding(8)
                                    }
                                }
                                
                                // Add more photos button (up to 8 total)
                                if capturedImages.count < 8 {
                                    Button(action: { showingPhotoLibrary = true }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "plus")
                                                .font(.title)
                                            Text("Add More")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.blue)
                                        .frame(height: 120)
                                        .frame(maxWidth: .infinity)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(12)
                                    }
                                }
                            }
                        }
                        
                        // Analysis button
                        AnalysisButton(
                            isAnalyzing: isAnalyzing,
                            isConfigured: Configuration.isFullyConfigured && firebaseService.canAnalyze,
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
                        CleanAnalysisProgress(
                            progress: businessService.analysisProgress,
                            progressValue: businessService.progressValue
                        )
                    }
                    
                    // Analysis result
                    if let analysisResult = analysisResult {
                        CleanAnalysisResultView(
                            analysis: analysisResult,
                            images: capturedImages,
                            isEbayAuthenticated: businessService.isEbayAuthenticated,
                            isCreatingListing: isCreatingListing,
                            listingStatus: listingStatus,
                            canCreateListing: firebaseService.canCreateListing,
                            onAddToInventory: addToInventory,
                            onAuthenticateEbay: authenticateEbay,
                            onCreateEbayListing: createEbayListing
                        )
                    }
                }
                .padding(20)
            }
            .navigationTitle("Analyze & List")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showingCamera) {
            CameraView { images in
                capturedImages.append(contentsOf: images)
            }
        }
        .sheet(isPresented: $showingPhotoLibrary) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 8 - capturedImages.count,
                matching: .images
            ) {
                Text("Select Photos")
            }
        }
        .sheet(isPresented: $showingItemForm) {
            if let analysisResult = analysisResult {
                ItemFormView(analysisResult: analysisResult) { item in
                    let addedItem = inventoryManager.addItem(item)
                    firebaseService.syncInventoryItem(addedItem) { _ in }
                    resetAnalysis()
                }
            }
        }
        .sheet(isPresented: $showingBarcodeLookup) {
            BarcodeScannerView { barcode in
                scannedBarcode = barcode
                analyzeBarcodeItem(barcode)
            }
        }
        .sheet(isPresented: $showingUsageLimit) {
            UsageLimitView()
        }
        .onChange(of: selectedItems) { items in
            Task {
                var newImages: [UIImage] = []
                
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        newImages.append(image)
                    }
                }
                
                DispatchQueue.main.async {
                    capturedImages.append(contentsOf: newImages)
                    selectedItems = []
                }
            }
        }
    }
    
    private func analyzeImages() {
        guard !capturedImages.isEmpty else { return }
        
        if !firebaseService.canAnalyze {
            showingUsageLimit = true
            return
        }
        
        isAnalyzing = true
        businessService.analyzeItem(capturedImages) { result in
            DispatchQueue.main.async {
                self.analysisResult = result
                self.isAnalyzing = false
            }
        }
    }
    
    private func analyzeBarcodeItem(_ barcode: String) {
        if !firebaseService.canAnalyze {
            showingUsageLimit = true
            return
        }
        
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
    
    private func authenticateEbay() {
        print("🔐 Starting eBay authentication from UI...")
        businessService.authenticateEbay { success in
            DispatchQueue.main.async {
                if success {
                    print("✅ eBay authentication successful!")
                } else {
                    print("❌ eBay authentication failed")
                }
            }
        }
    }
    
    private func createEbayListing() {
        guard let analysisResult = analysisResult else { return }
        
        if !firebaseService.canCreateListing {
            showingUsageLimit = true
            return
        }
        
        isCreatingListing = true
        listingStatus = "Creating eBay listing..."
        
        businessService.createEbayListing(from: analysisResult, images: capturedImages) { success, errorMessage in
            DispatchQueue.main.async {
                self.isCreatingListing = false
                
                if success {
                    self.listingStatus = "✅ Listed on eBay successfully!"
                    
                    let newItem = InventoryItem(
                        itemNumber: self.inventoryManager.nextItemNumber,
                        name: analysisResult.name,
                        category: analysisResult.category,
                        purchasePrice: 0,
                        suggestedPrice: analysisResult.suggestedPrice,
                        source: "Analysis",
                        condition: analysisResult.condition,
                        title: analysisResult.title,
                        description: analysisResult.description,
                        keywords: analysisResult.keywords,
                        status: .listed,
                        dateAdded: Date(),
                        dateListed: Date(),
                        brand: analysisResult.brand,
                        exactModel: analysisResult.exactModel ?? "",
                        styleCode: analysisResult.styleCode ?? "",
                        size: analysisResult.size ?? "",
                        colorway: analysisResult.colorway ?? "",
                        releaseYear: analysisResult.releaseYear ?? "",
                        subcategory: analysisResult.subcategory ?? ""
                    )
                    
                    let addedItem = self.inventoryManager.addItem(newItem)
                    self.firebaseService.syncInventoryItem(addedItem) { _ in }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.resetAnalysis()
                    }
                } else {
                    self.listingStatus = "❌ Failed to create listing: \(errorMessage ?? "Unknown error")"
                }
            }
        }
    }
    
    private func resetAnalysis() {
        capturedImages = []
        analysisResult = nil
        scannedBarcode = nil
        listingStatus = ""
        isCreatingListing = false
    }
}

// MARK: - QUEUE VIEW (INTEGRATED)
struct QueueView: View {
    @EnvironmentObject var businessService: BusinessService
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var inventoryManager: InventoryManager
    
    @State private var showingAddPhotos = false
    @State private var showingReviewView = false
    @State private var showingUsageLimit = false
    @State private var selectedItemForPhotos: UUID?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Queue header
                QueueHeaderView()
                
                if businessService.processingQueue.items.isEmpty {
                    EmptyQueueView()
                } else {
                    // Queue items
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(businessService.processingQueue.items.sorted { $0.position < $1.position }) { item in
                                QueueItemCard(item: item)
                            }
                        }
                        .padding()
                    }
                    
                    // Queue actions
                    QueueActionsView()
                }
            }
            .navigationTitle("Processing Queue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if businessService.processingQueue.items.count > 0 {
                        Button("Clear All") {
                            businessService.clearQueue()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddPhotos) {
            MultiPhotoPickerView { photos in
                businessService.addItemToQueue(photos: photos)
            }
        }
        .sheet(isPresented: $showingReviewView) {
            QueueReviewView()
        }
        .sheet(isPresented: $showingUsageLimit) {
            UsageLimitView()
        }
    }
    
    @ViewBuilder
    private func QueueHeaderView() -> some View {
        VStack(spacing: 12) {
            if businessService.processingQueue.isProcessing {
                QueueProcessingStatus()
            }
            
            if let user = firebaseService.currentUser {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Usage This Month")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(firebaseService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(firebaseService.canAnalyze ? .green : .red)
                    }
                    
                    Spacer()
                    
                    if !firebaseService.canAnalyze {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Limit Reached")
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Button("Upgrade") {
                                showingUsageLimit = true
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(8)
                        }
                    } else {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Queue Items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\(businessService.processingQueue.items.count)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func QueueProcessingStatus() -> some View {
        VStack(spacing: 8) {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                
                Text("Processing Queue...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if let currentId = businessService.processingQueue.currentlyProcessing,
                   let currentItem = businessService.processingQueue.items.first(where: { $0.id == currentId }) {
                    Text("Item \(currentItem.position)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            let totalItems = businessService.processingQueue.items.count
            let completedItems = businessService.processingQueue.completedItems.count + businessService.processingQueue.failedItems.count
            let progress = totalItems > 0 ? Double(completedItems) / Double(totalItems) : 0.0
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                Text("\(completedItems)/\(totalItems) processed")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let estimatedTime = businessService.processingQueue.estimatedTimeRemaining {
                    Text("~\(Int(estimatedTime/60))m remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func EmptyQueueView() -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "tray.full")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text("Queue is Empty")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Add items to analyze them in bulk. Perfect for processing multiple items from thrift stores or estate sales.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: { showingAddPhotos = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add First Item")
                }
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue)
                .cornerRadius(16)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func QueueActionsView() -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("Add Another Item") {
                    showingAddPhotos = true
                }
                .buttonStyle(SecondaryButtonStyle())
                
                if businessService.processingQueue.completedItems.count > 0 {
                    Button("Review Results") {
                        showingReviewView = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            
            if !businessService.processingQueue.isProcessing && businessService.processingQueue.pendingItems.count > 0 {
                Button("Start Processing Queue") {
                    businessService.startProcessingQueue()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!firebaseService.canAnalyze)
            } else if businessService.processingQueue.isProcessing {
                Button("Pause Queue") {
                    businessService.pauseProcessingQueue()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
}

// MARK: - QUEUE ITEM CARD
struct QueueItemCard: View {
    let item: QueuedItem
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Item \(item.position)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("\(item.photos.count) photo\(item.photos.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: item.status.systemImage)
                        .foregroundColor(item.status.color)
                    
                    Text(item.status.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(item.status.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.status.color.opacity(0.1))
                .cornerRadius(8)
            }
            
            if !item.uiImages.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                    ForEach(Array(item.uiImages.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipped()
                            .cornerRadius(8)
                    }
                }
            }
            
            if item.status == .completed, let result = item.analysisResult {
                QueueItemResultPreview(result: result)
            } else if item.status == .failed {
                QueueItemError(
                    errorMessage: item.errorMessage ?? "Analysis failed",
                    wasCountedAgainstLimit: item.wasCountedAgainstLimit
                ) {
                    businessService.retryQueueItem(itemId: item.id)
                }
            }
            
            HStack {
                if item.status == .pending || item.status == .failed {
                    Button("Remove") {
                        businessService.removeFromQueue(itemId: item.id)
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
                
                Spacer()
                
                if item.status == .processing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.6)
                        Text("Analyzing...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - QUEUE ITEM RESULT PREVIEW
struct QueueItemResultPreview: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer()
                
                Text("$\(Int(result.suggestedPrice))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            if !result.brand.isEmpty {
                Text(result.brand)
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - QUEUE ITEM ERROR
struct QueueItemError: View {
    let errorMessage: String
    let wasCountedAgainstLimit: Bool
    let onRetry: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                
                Text("Analysis Failed")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button("Retry", action: onRetry)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            Text(errorMessage)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !wasCountedAgainstLimit {
                Text("Not counted against your monthly limit")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - MULTI PHOTO PICKER (FIXED)
struct MultiPhotoPickerView: View {
    let completion: ([UIImage]) -> Void
    
    @State private var selectedPhotos: [UIImage] = []
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Select Photos")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(selectedPhotos.count)/8 photos selected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if !selectedPhotos.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { index, image in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .clipped()
                                        .cornerRadius(12)
                                    
                                    Button(action: {
                                        selectedPhotos.remove(at: index)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding(8)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
                
                VStack(spacing: 16) {
                    PhotosPicker(
                        selection: $selectedItems,
                        maxSelectionCount: 8 - selectedPhotos.count,
                        matching: .images
                    ) {
                        HStack {
                            Image(systemName: selectedPhotos.isEmpty ? "photo.badge.plus" : "plus.circle")
                            Text(selectedPhotos.isEmpty ? "Add Photos" : "Add More Photos")
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    .disabled(selectedPhotos.count >= 8)
                    
                    if !selectedPhotos.isEmpty {
                        Button("Add to Queue") {
                            completion(selectedPhotos)
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: selectedItems) { items in
            Task {
                var newPhotos: [UIImage] = []
                
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        newPhotos.append(image)
                    }
                }
                
                DispatchQueue.main.async {
                    selectedPhotos.append(contentsOf: newPhotos)
                    selectedItems = []
                }
            }
        }
    }
}

// MARK: - QUEUE REVIEW VIEW
struct QueueReviewView: View {
    @EnvironmentObject var businessService: BusinessService
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(businessService.processingQueue.completedItems) { item in
                        if let result = item.analysisResult {
                            QueueReviewItemCard(item: item, result: result)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Review Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - QUEUE REVIEW ITEM CARD
struct QueueReviewItemCard: View {
    let item: QueuedItem
    let result: AnalysisResult
    @EnvironmentObject var inventoryManager: InventoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let firstImage = item.uiImages.first {
                Image(uiImage: firstImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(result.name)
                    .font(.headline)
                    .fontWeight(.bold)
                
                if !result.brand.isEmpty {
                    Text(result.brand)
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Text("$\(Int(result.suggestedPrice))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 12) {
                Button("Add to Inventory") {
                    addToInventory()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                Button("List on eBay") {
                    // Handle eBay listing
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private func addToInventory() {
        let newItem = InventoryItem(
            itemNumber: inventoryManager.nextItemNumber,
            name: result.name,
            category: result.category,
            purchasePrice: 0,
            suggestedPrice: result.suggestedPrice,
            source: "Queue Analysis",
            condition: result.condition,
            title: result.title,
            description: result.description,
            keywords: result.keywords,
            status: .toList,
            dateAdded: Date(),
            brand: result.brand,
            exactModel: result.exactModel ?? "",
            styleCode: result.styleCode ?? "",
            size: result.size ?? "",
            colorway: result.colorway ?? "",
            releaseYear: result.releaseYear ?? "",
            subcategory: result.subcategory ?? ""
        )
        
        inventoryManager.addItem(newItem)
    }
}

// MARK: - SUPPORTING VIEWS (Camera, etc.)
struct CameraView: UIViewControllerRepresentable {
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

struct BarcodeScannerView: View {
    let completion: (String) -> Void
    
    var body: some View {
        VStack {
            Text("Barcode Scanner")
                .font(.title2)
                .padding()
            
            Text("Point camera at barcode")
                .foregroundColor(.secondary)
                .padding()
            
            Spacer()
            
            Button("Simulate Scan") {
                completion("123456789")
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                completion("123456789")
            }
        }
    }
}

// MARK: - USAGE STATUS CARD
struct UsageStatusCard: View {
    let analysisCount: Int
    let analysisLimit: Int
    let listingCount: Int
    let listingLimit: Int
    let plan: UserPlan
    let canAnalyze: Bool
    let canCreateListing: Bool
    let daysUntilReset: Int
    let onUpgrade: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monthly Usage")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(plan.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Analyses")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(analysisCount) / \(analysisLimit)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(canAnalyze ? .green : .red)
                }
                
                ProgressView(value: Double(analysisCount), total: Double(analysisLimit))
                    .progressViewStyle(LinearProgressViewStyle(tint: canAnalyze ? .green : .red))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("eBay Listings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(listingCount) / \(listingLimit)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(canCreateListing ? .green : .red)
                }
                
                ProgressView(value: Double(listingCount), total: Double(listingLimit))
                    .progressViewStyle(LinearProgressViewStyle(tint: canCreateListing ? .green : .red))
            }
            
            HStack {
                if !canAnalyze || !canCreateListing {
                    Text("Limits reached • Resets in \(daysUntilReset) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Upgrade", action: onUpgrade)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .cornerRadius(12)
                } else {
                    Text("Resets in \(daysUntilReset) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
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
            Text("Take photos of your item to get instant pricing and market analysis")
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

// MARK: - CLEAN ANALYSIS PROGRESS
struct CleanAnalysisProgress: View {
    let progress: String
    let progressValue: Double
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                ProgressView(value: progressValue)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
                
                Text(progress)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                    .animation(.easeInOut, value: progress)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

// MARK: - CLEAN ANALYSIS RESULT VIEW
struct CleanAnalysisResultView: View {
    let analysis: AnalysisResult
    let images: [UIImage]
    let isEbayAuthenticated: Bool
    let isCreatingListing: Bool
    let listingStatus: String
    let canCreateListing: Bool
    let onAddToInventory: () -> Void
    let onAuthenticateEbay: () -> Void
    let onCreateEbayListing: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            CleanProductCard(analysis: analysis)
            
            if hasMarketData(analysis) {
                CleanMarketCard(analysis: analysis)
            }
            
            CleanPricingCard(analysis: analysis)
            
            EbayIntegrationCard(
                isAuthenticated: isEbayAuthenticated,
                isCreatingListing: isCreatingListing,
                listingStatus: listingStatus,
                canCreateListing: canCreateListing,
                onAuthenticate: onAuthenticateEbay,
                onCreateListing: onCreateEbayListing
            )
            
            HStack(spacing: 12) {
                Button("Add to Inventory", action: onAddToInventory)
                    .buttonStyle(SecondaryButtonStyle())
                
                if isEbayAuthenticated {
                    Button(isCreatingListing ? "Creating..." : "List on eBay", action: onCreateEbayListing)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isCreatingListing || !canCreateListing)
                } else {
                    Button("Connect eBay", action: onAuthenticateEbay)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
    }
    
    private func hasMarketData(_ analysis: AnalysisResult) -> Bool {
        return (analysis.soldListingsCount ?? 0) > 0 || (analysis.competitorCount ?? 0) > 0
    }
}

// MARK: - CLEAN PRODUCT CARD
struct CleanProductCard: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product Identified")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(analysis.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
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

struct CleanMarketCard: View {
    let analysis: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Data")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 16) {
                if let soldCount = analysis.soldListingsCount, soldCount > 0 {
                    MarketStat(
                        title: "Recent Sales",
                        value: "\(soldCount)",
                        color: .blue
                    )
                }
                
                if let activeCount = analysis.competitorCount, activeCount > 0 {
                    MarketStat(
                        title: "Active Listings",
                        value: "\(activeCount)",
                        color: .green
                    )
                }
                
                if let demandLevel = analysis.demandLevel {
                    MarketStat(
                        title: "Demand",
                        value: demandLevel,
                        color: demandLevel == "High" ? .green : demandLevel == "Medium" ? .orange : .red
                    )
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

struct CleanPricingCard: View {
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

struct EbayIntegrationCard: View {
    let isAuthenticated: Bool
    let isCreatingListing: Bool
    let listingStatus: String
    let canCreateListing: Bool
    let onAuthenticate: () -> Void
    let onCreateListing: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("eBay Integration")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(isAuthenticated ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    
                    Text(isAuthenticated ? "Connected" : "Not Connected")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isAuthenticated ? .green : .orange)
                }
            }
            
            if isAuthenticated {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Ready to create listing automatically", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.green)
                    
                    Label("Optimized title, description & pricing", systemImage: "wand.and.rays")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Label("Professional photos & SEO optimization", systemImage: "photo.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    
                    if !canCreateListing {
                        Label("Monthly listing limit reached - upgrade to continue", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
                
                if !listingStatus.isEmpty {
                    Text(listingStatus)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(listingStatus.contains("✅") ? .green : .red)
                        .padding(.top, 4)
                }
                
                if isCreatingListing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                        
                        Text("Creating your eBay listing...")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.top, 8)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Connect eBay to automatically create listings", systemImage: "link")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Label("One-click posting with optimal pricing", systemImage: "bolt.fill")
                        .font(.subheadline)
                        .foregroundColor(.blue)
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

// MARK: - ALL OTHER VIEWS (Dashboard, Inventory, Settings, etc. remain the same)

struct DashboardView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @EnvironmentObject var businessService: BusinessService
    @EnvironmentObject var firebaseService: FirebaseService
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let user = firebaseService.currentUser {
                        UserPlanCard(user: user) { }
                    }
                    
                    EbayStatusCard(isAuthenticated: businessService.isEbayAuthenticated)
                    DashboardStats(inventoryManager: inventoryManager)
                    RecentItemsCard(items: Array(inventoryManager.recentItems.prefix(3)))
                    QuickActionsCard()
                }
                .padding(20)
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct UserPlanCard: View {
    let user: FirebaseUser
    let onUpgrade: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Plan")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(user.currentPlan.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text(user.currentPlan.price)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if user.currentPlan != .pro {
                Button("Upgrade", action: onUpgrade)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct EbayStatusCard: View {
    let isAuthenticated: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("eBay Integration")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(isAuthenticated ? "Connected and ready to list" : "Connect to start auto-listing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(isAuthenticated ? Color.green : Color.orange)
                    .frame(width: 12, height: 12)
                
                Text(isAuthenticated ? "Connected" : "Setup Required")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isAuthenticated ? .green : .orange)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

struct DashboardStats: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Business Overview")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(title: "Total Items", value: "\(inventoryManager.items.count)", color: .blue)
                StatCard(title: "Listed", value: "\(inventoryManager.listedItems)", color: .green)
                StatCard(title: "Sold", value: "\(inventoryManager.soldItems)", color: .purple)
                StatCard(title: "Total Value", value: "$\(Int(inventoryManager.totalEstimatedValue))", color: .orange)
            }
        }
    }
}

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

struct RecentItemsCard: View {
    let items: [InventoryItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Items")
                .font(.headline)
                .fontWeight(.semibold)
            
            if items.isEmpty {
                Text("No items yet - start by analyzing your first item!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(items) { item in
                    RecentItemRow(item: item)
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

struct QuickActionsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                QuickActionButton(title: "Analyze New Item", icon: "viewfinder", color: .blue) { }
                QuickActionButton(title: "View Inventory", icon: "list.bullet", color: .green) { }
                QuickActionButton(title: "Export Data", icon: "square.and.arrow.up", color: .purple) { }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
}

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

// MARK: - INVENTORY VIEW (UNCHANGED)
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
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: selectedStatus == nil) {
                                selectedStatus = nil
                            }
                            
                            ForEach(ItemStatus.allCases, id: \.self) { status in
                                FilterChip(title: status.rawValue, isSelected: selectedStatus == status) {
                                    selectedStatus = status
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
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
            InventoryFiltersView(selectedStatus: $selectedStatus, selectedCategory: $selectedCategory)
        }
    }
}

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

struct InventoryItemRow: View {
    let item: InventoryItem
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.secondary)
                )
            
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

struct StorageOverview: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                StatCard(title: "Total Items", value: "\(inventoryManager.items.count)", color: .blue)
                StatCard(title: "Packaged", value: "\(inventoryManager.getPackagedItems().count)", color: .green)
                StatCard(title: "Ready to Ship", value: "\(inventoryManager.getItemsReadyToList().count)", color: .orange)
                StatCard(title: "Categories", value: "\(inventoryManager.getCategoryBreakdown().count)", color: .purple)
            }
        }
    }
}

struct StorageByCategory: View {
    let inventoryManager: InventoryManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage by Category")
                .font(.headline)
                .fontWeight(.semibold)
            
            let overview = inventoryManager.getInventoryOverview()
            
            if overview.isEmpty {
                Text("No items stored yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 20)
            } else {
                ForEach(overview, id: \.letter) { overview in
                    CategoryStorageCard(overview: overview)
                }
            }
        }
    }
}

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
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var showingExport = false
    @State private var showingAPIConfig = false
    @State private var showingAbout = false
    @State private var showingPlanFeatures = false
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let user = firebaseService.currentUser {
                        HStack {
                            Text("Signed in as")
                            Spacer()
                            Text(user.displayName ?? user.email ?? "User")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Current Plan")
                            Spacer()
                            Text(user.currentPlan.displayName)
                                .foregroundColor(.blue)
                        }
                        
                        Button("View Plans") {
                            showingPlanFeatures = true
                        }
                        .foregroundColor(.blue)
                        
                        if firebaseService.isFaceIDAvailable {
                            HStack {
                                Text("Face ID")
                                Spacer()
                                Toggle("", isOn: .constant(firebaseService.isFaceIDEnabled))
                                    .disabled(true)
                            }
                        }
                        
                        Button("Sign Out") {
                            firebaseService.signOut()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("eBay Integration") {
                    HStack {
                        Label("eBay Status", systemImage: "network")
                        Spacer()
                        Text(businessService.isEbayAuthenticated ? "Connected" : "Not Connected")
                            .foregroundColor(businessService.isEbayAuthenticated ? .green : .orange)
                    }
                    
                    if !businessService.isEbayAuthenticated {
                        Button("Connect eBay Account") {
                            businessService.authenticateEbay { _ in }
                        }
                        .foregroundColor(.blue)
                    } else {
                        if !businessService.ebayService.connectedUserName.isEmpty {
                            HStack {
                                Text("Connected as")
                                Spacer()
                                Text(businessService.ebayService.connectedUserName)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Disconnect eBay") {
                            businessService.ebayService.signOut()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Business") {
                    SettingsRow(title: "Export Data", icon: "square.and.arrow.up", color: .blue) {
                        showingExport = true
                    }
                    
                    SettingsRow(title: "API Configuration", icon: "network", color: .green) {
                        showingAPIConfig = true
                    }
                }
                
                Section("App") {
                    SettingsRow(title: "About ResellAI", icon: "info.circle", color: .gray) {
                        showingAbout = true
                    }
                }
            }
            .navigationTitle("Settings")
        }
        .sheet(isPresented: $showingExport) {
            ExportView().environmentObject(inventoryManager)
        }
        .sheet(isPresented: $showingAPIConfig) {
            APIConfigView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingPlanFeatures) {
            PlanFeaturesView().environmentObject(firebaseService)
        }
    }
}

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

// MARK: - SUPPORTING FORMS AND VIEWS
struct ItemFormView: View {
    let analysisResult: AnalysisResult
    let completion: (InventoryItem) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var purchasePrice = ""
    @State private var source = "Thrift Store"
    @State private var storageLocation = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Item Details") {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(analysisResult.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Suggested Price")
                        Spacer()
                        Text("$\(String(format: "%.2f", analysisResult.suggestedPrice))")
                            .foregroundColor(.green)
                    }
                }
                
                Section("Additional Info") {
                    HStack {
                        Text("Purchase Price")
                        TextField("$0.00", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Source")
                        TextField("Where did you buy this?", text: $source)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Storage Location")
                        TextField("Bin A-1", text: $storageLocation)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Add to Inventory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let item = InventoryItem(
                            itemNumber: 1,
                            name: analysisResult.name,
                            category: analysisResult.category,
                            purchasePrice: Double(purchasePrice) ?? 0,
                            suggestedPrice: analysisResult.suggestedPrice,
                            source: source,
                            condition: analysisResult.condition,
                            title: analysisResult.title,
                            description: analysisResult.description,
                            keywords: analysisResult.keywords,
                            status: .toList,
                            dateAdded: Date(),
                            brand: analysisResult.brand,
                            exactModel: analysisResult.exactModel ?? "",
                            styleCode: analysisResult.styleCode ?? "",
                            size: analysisResult.size ?? "",
                            colorway: analysisResult.colorway ?? "",
                            releaseYear: analysisResult.releaseYear ?? "",
                            subcategory: analysisResult.subcategory ?? "",
                            storageLocation: storageLocation
                        )
                        completion(item)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct InventoryFiltersView: View {
    @Binding var selectedStatus: ItemStatus?
    @Binding var selectedCategory: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Status") {
                    Button("All") {
                        selectedStatus = nil
                        dismiss()
                    }
                    
                    ForEach(ItemStatus.allCases, id: \.self) { status in
                        Button(status.rawValue) {
                            selectedStatus = status
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ExportView: View {
    @EnvironmentObject var inventoryManager: InventoryManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export Options")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Button("Export as CSV") {
                    let csv = inventoryManager.exportToCSV()
                    print("CSV Export: \(csv)")
                }
                .buttonStyle(.borderedProminent)
                
                Text("Export your inventory data for external analysis or backup")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct APIConfigView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("API Configuration")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 12) {
                    ConfigStatusRow(title: "Product Analysis", isConfigured: !Configuration.openAIKey.isEmpty)
                    ConfigStatusRow(title: "Google Sheets", isConfigured: !Configuration.googleScriptURL.isEmpty)
                    ConfigStatusRow(title: "Market Data", isConfigured: !Configuration.rapidAPIKey.isEmpty)
                    ConfigStatusRow(title: "eBay API", isConfigured: Configuration.isEbayConfigured)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                )
                
                Text("Status: \(Configuration.configurationStatus)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("API Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ConfigStatusRow: View {
    let title: String
    let isConfigured: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(isConfigured ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                Text(isConfigured ? "Configured" : "Missing")
                    .font(.caption)
                    .foregroundColor(isConfigured ? .green : .red)
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                    
                    Text("The complete reselling automation tool powered by advanced analysis. Take a photo, get real market comps, and automatically create optimized listings.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Features:")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        FeatureRow(icon: "viewfinder", text: "Advanced product identification")
                        FeatureRow(icon: "chart.bar", text: "Real eBay sold comps analysis")
                        FeatureRow(icon: "dollarsign.circle", text: "Market-driven pricing")
                        FeatureRow(icon: "network", text: "Automatic eBay listing creation")
                        FeatureRow(icon: "list.bullet", text: "Complete inventory management")
                        FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Business analytics & insights")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - FIREBASE AUTH VIEWS (UNCHANGED)
struct FirebaseAuthView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var showingSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingFaceIDSetup = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 64))
                        .foregroundColor(.blue)
                    
                    Text("ResellAI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Reselling Automation Powered by Advanced Analysis")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if firebaseService.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                        
                        Text("Signing you in...")
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 16) {
                        Button(action: {
                            firebaseService.signInWithApple()
                        }) {
                            HStack {
                                Image(systemName: "applelogo")
                                    .font(.title2)
                                Text("Continue with Apple")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.black)
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            firebaseService.signInWithGoogle()
                        }) {
                            HStack {
                                Image(systemName: "globe")
                                    .font(.title2)
                                Text("Continue with Google")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.green],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(12)
                        }
                        
                        HStack {
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                            
                            Text("or")
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.3))
                        }
                        
                        VStack(spacing: 12) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            if showingSignUp {
                                SecureField("Confirm Password", text: $confirmPassword)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                        
                        Button(action: {
                            if showingSignUp {
                                createAccount()
                            } else {
                                signIn()
                            }
                        }) {
                            Text(showingSignUp ? "Create Account" : "Sign In")
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        .disabled(email.isEmpty || password.isEmpty || (showingSignUp && confirmPassword.isEmpty))
                        
                        Button(action: {
                            showingSignUp.toggle()
                            clearFields()
                        }) {
                            Text(showingSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Text("By continuing, you agree to our Terms of Service and Privacy Policy")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(24)
            .navigationBarHidden(true)
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingFaceIDSetup) {
            FaceIDSetupView().environmentObject(firebaseService)
        }
        .onChange(of: firebaseService.authError) { error in
            if let error = error {
                errorMessage = error
                showingError = true
            }
        }
        .onAppear {
            if firebaseService.isAuthenticated && firebaseService.isFaceIDAvailable && !firebaseService.isFaceIDEnabled {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    showingFaceIDSetup = true
                }
            }
        }
    }
    
    private func signIn() {
        firebaseService.signInWithEmail(email, password: password) { success, error in
            if !success {
                errorMessage = error ?? "Sign in failed"
                showingError = true
            }
        }
    }
    
    private func createAccount() {
        guard password == confirmPassword else {
            errorMessage = "Passwords don't match"
            showingError = true
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            showingError = true
            return
        }
        
        firebaseService.createAccount(email: email, password: password) { success, error in
            if !success {
                errorMessage = error ?? "Account creation failed"
                showingError = true
            }
        }
    }
    
    private func clearFields() {
        email = ""
        password = ""
        confirmPassword = ""
    }
}

struct FaceIDSetupView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss
    @State private var isEnabling = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "faceid")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("Enable Face ID")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Use Face ID for quick and secure access to ResellAI")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        BenefitRow(icon: "lock.shield", text: "Secure biometric authentication")
                        BenefitRow(icon: "bolt", text: "Instant app access")
                        BenefitRow(icon: "eye.slash", text: "No need to remember passwords")
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: enableFaceID) {
                        HStack {
                            if isEnabling {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Enabling...")
                            } else {
                                Image(systemName: "faceid")
                                Text("Enable Face ID")
                            }
                        }
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isEnabling)
                    
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func enableFaceID() {
        isEnabling = true
        
        firebaseService.enableFaceID { success, error in
            DispatchQueue.main.async {
                self.isEnabling = false
                
                if success {
                    self.dismiss()
                } else {
                    self.errorMessage = error ?? "Failed to enable Face ID"
                    self.showingError = true
                }
            }
        }
    }
}

struct BenefitRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

struct UsageLimitView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.orange)
                
                if !firebaseService.canAnalyze {
                    Text("Analysis Limit Reached")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("You've used all \(firebaseService.currentUser?.monthlyAnalysisLimit ?? 0) analyses for this month.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else if !firebaseService.canCreateListing {
                    Text("Listing Limit Reached")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("You've used all \(firebaseService.currentUser?.monthlyListingLimit ?? 0) eBay listings for this month.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                } else {
                    Text("Monthly Limits")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("View your current usage and upgrade options.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                
                if let user = firebaseService.currentUser {
                    VStack(spacing: 12) {
                        Text("Current Plan: \(user.currentPlan.displayName)")
                            .font(.headline)
                        
                        Text("Resets in \(firebaseService.daysUntilReset) days")
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Analyses:")
                                Spacer()
                                Text("\(firebaseService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                                    .foregroundColor(firebaseService.canAnalyze ? .green : .red)
                            }
                            
                            HStack {
                                Text("Listings:")
                                Spacer()
                                Text("\(firebaseService.monthlyListingCount)/\(user.monthlyListingLimit)")
                                    .foregroundColor(firebaseService.canCreateListing ? .green : .red)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                VStack(spacing: 16) {
                    Text("Upgrade for More Access")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    ForEach(UserPlan.allCases.filter { $0 != .free }, id: \.self) { plan in
                        Button(action: {
                            upgradeToPlan(plan)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(plan.displayName)
                                        .fontWeight(.semibold)
                                    
                                    Text("\(plan.monthlyLimit) analyses • \(plan.monthlyListingLimit) listings")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(plan.price)
                                    .fontWeight(.bold)
                                    .foregroundColor(.blue)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Button("Continue with Free Plan") {
                    dismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func upgradeToPlan(_ plan: UserPlan) {
        firebaseService.upgradePlan(to: plan) { success in
            if success {
                dismiss()
            }
        }
    }
}

struct PlanFeaturesView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose Your Plan")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.top)
                    
                    ForEach(UserPlan.allCases, id: \.self) { plan in
                        PlanCard(
                            plan: plan,
                            isCurrentPlan: firebaseService.currentUser?.currentPlan == plan,
                            onSelect: {
                                if plan != .free {
                                    upgradeToPlan(plan)
                                }
                            }
                        )
                    }
                    
                    if firebaseService.isFaceIDAvailable {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Security Features")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            HStack {
                                Image(systemName: "faceid")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading) {
                                    Text("Face ID")
                                        .fontWeight(.medium)
                                    
                                    Text(firebaseService.isFaceIDEnabled ? "Enabled" : "Available")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if !firebaseService.isFaceIDEnabled {
                                    Button("Enable") {
                                        enableFaceID()
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func upgradeToPlan(_ plan: UserPlan) {
        firebaseService.upgradePlan(to: plan) { success in
            if success {
                dismiss()
            }
        }
    }
    
    private func enableFaceID() {
        firebaseService.enableFaceID { success, error in
            if let error = error {
                print("❌ Failed to enable Face ID: \(error)")
            }
        }
    }
}

struct PlanCard: View {
    let plan: UserPlan
    let isCurrentPlan: Bool
    let onSelect: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(plan.displayName)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isCurrentPlan {
                    Text("Current")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            
            Text(plan.price)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        
                        Text(feature)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
            
            if !isCurrentPlan && plan != .free {
                Button(action: onSelect) {
                    Text("Select \(plan.displayName)")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isCurrentPlan ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
