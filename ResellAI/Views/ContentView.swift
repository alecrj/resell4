//
//  ContentView.swift
//  ResellAI
//
//  Main App Coordinator with AuthService Integration
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - MAIN CONTENT VIEW (UPDATED FOR AUTH SERVICE)
struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var businessService = BusinessService()
    
    // Extract authService from firebaseService for direct access
    private var authService: AuthService {
        firebaseService.authService
    }
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainAppView()
                    .environmentObject(authService)
                    .environmentObject(firebaseService)
                    .environmentObject(inventoryManager)
                    .environmentObject(businessService)
            } else {
                WelcomeFlow()
                    .environmentObject(authService)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            initializeServices()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
    }
    
    private func initializeServices() {
        print("🚀 Initializing ResellAI services...")
        Configuration.validateConfiguration()
        businessService.initialize(with: firebaseService)
        inventoryManager.initialize(with: firebaseService)
        
        print("✅ Services initialized")
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 Incoming URL: \(url)")
        print("📋 URL scheme: \(url.scheme ?? "nil")")
        print("📋 URL host: \(url.host ?? "nil")")
        print("📋 URL path: \(url.path)")
        print("📋 URL query: \(url.query ?? "nil")")
        
        // Handle eBay OAuth callback
        if url.scheme == "resellai" && url.host == "auth" {
            if url.path.contains("ebay") || url.absoluteString.contains("ebay") {
                print("🔗 Handling eBay Auth callback")
                businessService.handleEbayAuthCallback(url: url)
            } else {
                print("⚠️ Unknown auth callback: \(url)")
            }
        } else {
            print("⚠️ Unhandled URL scheme: \(url)")
        }
    }
}

// MARK: - MAIN APP VIEW (UPDATED)
struct MainAppView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var businessService: BusinessService
    @State private var showingEbayConnect = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Check eBay authentication status from businessService
            if !businessService.ebayService.isAuthenticated {
                EbayConnectView()
                    .environmentObject(businessService)
            } else {
                MainCameraView()
            }
        }
        .sheet(isPresented: $showingEbayConnect) {
            EbayConnectSheet()
        }
        .onAppear {
            print("🎯 MainAppView appeared")
            print("• Auth authenticated: \(authService.isAuthenticated)")
            print("• eBay authenticated: \(businessService.ebayService.isAuthenticated)")
            if businessService.ebayService.isAuthenticated {
                print("• Connected user: \(businessService.ebayService.connectedUserName)")
            }
        }
        // Force UI refresh when eBay auth state changes
        .onChange(of: businessService.ebayService.isAuthenticated) { isAuthenticated in
            print("🔄 eBay auth state changed: \(isAuthenticated)")
            if isAuthenticated {
                print("✅ eBay connected - transitioning to main camera view")
            }
        }
    }
}

// MARK: - MAIN CAMERA VIEW (UPDATED)
struct MainCameraView: View {
    @EnvironmentObject var businessService: BusinessService
    @EnvironmentObject var authService: AuthService
    
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingProcessing = false
    @State private var analysisResult: AnalysisResult?
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showingSettings = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingEbayStatus = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with eBay status
            HStack {
                Text("ResellAI")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.primary)
                
                Spacer()
                
                // eBay status indicator
                Button(action: { showingEbayStatus = true }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(businessService.ebayService.isAuthenticated ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        if businessService.ebayService.isAuthenticated {
                            Text(businessService.ebayService.connectedUserName.isEmpty ? "eBay" : businessService.ebayService.connectedUserName)
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.secondary)
                        } else {
                            Text("Not connected")
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.secondary)
                        }
                    }
                }
                
                // Usage indicator
                if let user = authService.currentUser {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(authService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        if !authService.canAnalyze {
                            Text("Limit reached")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.secondary)
                }
            }
            .padding(.horizontal, DesignSystem.spacing3)
            .padding(.vertical, DesignSystem.spacing2)
            
            if capturedImages.isEmpty && !showingProcessing && analysisResult == nil {
                // Initial camera state
                InitialCameraState(
                    onCamera: {
                        checkCameraPermission { granted in
                            if granted {
                                showingCamera = true
                            } else {
                                errorMessage = "Camera access required to take photos"
                                showingError = true
                            }
                        }
                    },
                    onLibrary: { showingPhotoLibrary = true }
                )
            } else if showingProcessing {
                // Processing state
                ProcessingView()
            } else if let result = analysisResult {
                // Results state
                ReviewListingView(
                    result: result,
                    images: capturedImages,
                    onNewPhoto: resetToCamera,
                    onPostListing: postToEbay
                )
            } else {
                // Photo preview state
                PhotoPreviewView(
                    images: capturedImages,
                    onAnalyze: analyzePhotos,
                    onAddMore: { showingPhotoLibrary = true },
                    onReset: resetToCamera,
                    canAnalyze: authService.canAnalyze
                )
            }
        }
        .background(DesignSystem.background)
        .sheet(isPresented: $showingCamera) {
            CameraPickerView { images in
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
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingEbayStatus) {
            EbayConnectSheet()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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
    
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    private func analyzePhotos() {
        guard authService.canAnalyze else {
            errorMessage = "Monthly analysis limit reached. Please upgrade your plan."
            showingError = true
            return
        }
        
        showingProcessing = true
        businessService.analyzeItem(capturedImages) { result in
            DispatchQueue.main.async {
                showingProcessing = false
                if let result = result {
                    analysisResult = result
                } else {
                    errorMessage = "Failed to analyze item. Please try again."
                    showingError = true
                }
            }
        }
    }
    
    private func resetToCamera() {
        capturedImages = []
        analysisResult = nil
        showingProcessing = false
    }
    
    private func postToEbay() {
        guard let result = analysisResult else { return }
        guard authService.canCreateListing else {
            errorMessage = "Monthly listing limit reached. Please upgrade your plan."
            showingError = true
            return
        }
        
        businessService.createEbayListing(from: result, images: capturedImages) { success, error in
            DispatchQueue.main.async {
                if success {
                    resetToCamera()
                } else {
                    errorMessage = error ?? "Failed to create listing"
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
