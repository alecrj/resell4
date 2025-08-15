//
//  ContentView.swift
//  ResellAI
//
//  Enhanced Main App with Expert AI Integration
//

import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - ENHANCED MAIN CONTENT VIEW
struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var businessService = BusinessService()
    
    // Directly observe the authService to ensure proper state updates
    @ObservedObject private var authService: AuthService
    
    init() {
        let firebase = FirebaseService()
        self._firebaseService = StateObject(wrappedValue: firebase)
        self.authService = firebase.authService
        self._inventoryManager = StateObject(wrappedValue: InventoryManager())
        self._businessService = StateObject(wrappedValue: BusinessService())
    }
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if businessService.ebayService.isAuthenticated {
                    // ✅ SHOW ENHANCED CAMERA APP WITH EXPERT AI
                    EnhancedMainCameraView()
                        .environmentObject(authService)
                        .environmentObject(firebaseService)
                        .environmentObject(inventoryManager)
                        .environmentObject(businessService)
                } else {
                    // Show eBay connection flow
                    EbayConnectView()
                        .environmentObject(authService)
                        .environmentObject(firebaseService)
                        .environmentObject(inventoryManager)
                        .environmentObject(businessService)
                }
            } else {
                WelcomeFlow()
                    .environmentObject(authService)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            initializeEnhancedServices()
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            print("🔄 Auth state changed in ContentView: \(isAuthenticated)")
        }
        .onChange(of: businessService.ebayService.isAuthenticated) { isAuthenticated in
            print("🔄 eBay auth state changed in ContentView: \(isAuthenticated)")
            if isAuthenticated {
                print("✅ eBay connected - showing enhanced camera view")
                businessService.objectWillChange.send()
            }
        }
    }
    
    private func initializeEnhancedServices() {
        print("🚀 Initializing Enhanced ResellAI services...")
        Configuration.validateConfiguration()
        businessService.initialize(with: firebaseService)
        inventoryManager.initialize(with: firebaseService)
        print("✅ Enhanced services initialized")
    }
    
    private func handleIncomingURL(_ url: URL) {
        print("📱 Incoming URL: \(url)")
        
        // Handle eBay OAuth callback
        if url.scheme == "resellai" && url.host == "auth" {
            if url.path.contains("ebay") || url.absoluteString.contains("ebay") {
                print("🔗 Handling eBay Auth callback")
                businessService.handleEbayAuthCallback(url: url)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Forcing UI state refresh after eBay callback")
                    self.businessService.objectWillChange.send()
                }
            }
        }
    }
}

// MARK: - ENHANCED MAIN CAMERA VIEW WITH EXPERT AI
struct EnhancedMainCameraView: View {
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
            // Enhanced header with expert AI branding
            enhancedHeader
            
            // Main content area
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
                // Enhanced processing state
                ProcessingView()
            } else if let result = analysisResult {
                // Enhanced results state
                ReviewListingView(
                    result: result,
                    images: capturedImages,
                    onNewPhoto: resetToCamera,
                    onPostListing: postToEbay
                )
            } else {
                // Enhanced photo preview state
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
    
    // MARK: - Enhanced Header
    private var enhancedHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("ResellAI")
                        .font(DesignSystem.titleFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    // Expert AI badge
                    HStack(spacing: 4) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                        Text("Expert AI")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(DesignSystem.neonGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignSystem.neonGreen.opacity(0.1))
                    .cornerRadius(12)
                }
                
                Text("Photo to eBay listing in 30 seconds")
                    .font(.caption)
                    .foregroundColor(DesignSystem.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 16) {
                // eBay status indicator
                Button(action: { showingEbayStatus = true }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(businessService.ebayService.isAuthenticated ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(businessService.ebayService.isAuthenticated ? "eBay ✓" : "eBay")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                    }
                }
                
                // Enhanced usage indicator
                if let user = authService.currentUser {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(authService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        if !authService.canAnalyze {
                            Text("Upgrade")
                                .font(.caption2)
                                .foregroundColor(.red)
                        } else {
                            Text("analyses")
                                .font(.caption2)
                                .foregroundColor(DesignSystem.secondary)
                        }
                    }
                }
                
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.secondary)
                }
            }
        }
        .padding(.horizontal, DesignSystem.spacing3)
        .padding(.vertical, DesignSystem.spacing2)
    }
    
    // MARK: - Helper Methods
    
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
            errorMessage = "Monthly analysis limit reached. Upgrade for unlimited expert analysis."
            showingError = true
            return
        }
        
        showingProcessing = true
        
        // Track that we're using expert AI
        print("🧠 Starting Expert AI Analysis with \(capturedImages.count) images")
        
        businessService.analyzeItem(capturedImages) { result in
            DispatchQueue.main.async {
                showingProcessing = false
                if let result = result {
                    analysisResult = result
                    print("✅ Expert AI analysis complete: \(result.name)")
                } else {
                    errorMessage = "Expert AI analysis failed. Please try again with clearer photos."
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
            errorMessage = "Monthly listing limit reached. Upgrade for unlimited listings."
            showingError = true
            return
        }
        
        print("📤 Creating eBay listing from Expert AI analysis")
        
        businessService.createEbayListing(from: result, images: capturedImages) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("🎉 Expert AI to eBay listing success!")
                    resetToCamera()
                } else {
                    errorMessage = error ?? "Failed to create eBay listing"
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
