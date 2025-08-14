//
//  ContentView.swift
//  ResellAI
//
//  Clean, Minimal Reselling App Interface
//

import SwiftUI
import UIKit
import AVFoundation
import PhotosUI
import MessageUI
import LocalAuthentication

// MARK: - DESIGN SYSTEM
struct DesignSystem {
    // Colors
    static let neonGreen = Color(red: 0.22, green: 1.0, blue: 0.08) // #39FF14
    static let background = Color.white
    static let primary = Color.black
    static let secondary = Color.gray
    static let tertiary = Color(white: 0.9)
    
    // Typography
    static let titleFont = Font.system(size: 28, weight: .bold, design: .default)
    static let headlineFont = Font.system(size: 20, weight: .semibold, design: .default)
    static let bodyFont = Font.system(size: 16, weight: .regular, design: .default)
    static let captionFont = Font.system(size: 14, weight: .medium, design: .default)
    
    // Spacing
    static let spacing1: CGFloat = 8
    static let spacing2: CGFloat = 16
    static let spacing3: CGFloat = 24
    static let spacing4: CGFloat = 32
    
    // Corner Radius
    static let cornerRadius: CGFloat = 12
    static let buttonRadius: CGFloat = 16
}

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var businessService = BusinessService()
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                MainAppView()
                    .environmentObject(firebaseService)
                    .environmentObject(inventoryManager)
                    .environmentObject(businessService)
            } else {
                WelcomeFlow()
                    .environmentObject(firebaseService)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            Configuration.validateConfiguration()
            businessService.initialize(with: firebaseService)
            inventoryManager.initialize(with: firebaseService)
        }
        .onOpenURL { url in
            if url.scheme == "resellai" && url.host == "auth" {
                businessService.handleEbayAuthCallback(url: url)
            }
        }
    }
}

// MARK: - WELCOME FLOW
struct WelcomeFlow: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @State private var currentStep = 0
    @State private var showingAuth = false
    
    var body: some View {
        VStack(spacing: 0) {
            if currentStep == 0 {
                WelcomeScreen(onGetStarted: { currentStep = 1 })
            } else if currentStep == 1 {
                WalkthroughScreen(onContinue: { currentStep = 2 })
            } else {
                AuthScreen()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: currentStep)
    }
}

// MARK: - WELCOME SCREEN
struct WelcomeScreen: View {
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            // Logo/Icon
            Circle()
                .fill(DesignSystem.neonGreen)
                .frame(width: 80, height: 80)
                .overlay(
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.black)
                )
            
            VStack(spacing: DesignSystem.spacing2) {
                Text("ResellAI")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.primary)
                
                Text("Take a photo.\nResellAI does the rest.")
                    .font(DesignSystem.headlineFont)
                    .foregroundColor(DesignSystem.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            
            Spacer()
            
            // CTA Button
            PrimaryButton(title: "Get Started", action: onGetStarted)
                .padding(.horizontal, DesignSystem.spacing3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
    }
}

// MARK: - WALKTHROUGH SCREEN
struct WalkthroughScreen: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Text("How it works")
                .font(DesignSystem.titleFont)
                .foregroundColor(DesignSystem.primary)
                .padding(.top, DesignSystem.spacing4)
            
            VStack(spacing: DesignSystem.spacing3) {
                WalkthroughStep(
                    number: "1",
                    icon: "camera.fill",
                    title: "Snap a photo",
                    description: "Take a photo of any item you want to sell"
                )
                
                WalkthroughStep(
                    number: "2",
                    icon: "brain.head.profile",
                    title: "AI identifies item",
                    description: "Our AI identifies the product and finds market comps"
                )
                
                WalkthroughStep(
                    number: "3",
                    icon: "network",
                    title: "Auto-post to eBay",
                    description: "Optimized listing goes live on your eBay account"
                )
            }
            .padding(.horizontal, DesignSystem.spacing3)
            
            Spacer()
            
            PrimaryButton(title: "Continue", action: onContinue)
                .padding(.horizontal, DesignSystem.spacing3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
    }
}

struct WalkthroughStep: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing2) {
            // Step number
            Circle()
                .fill(DesignSystem.neonGreen)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(number)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(DesignSystem.primary)
                    Text(title)
                        .font(DesignSystem.headlineFont)
                        .foregroundColor(DesignSystem.primary)
                }
                
                Text(description)
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - AUTH SCREEN
struct AuthScreen: View {
    @EnvironmentObject var firebaseService: FirebaseService
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            VStack(spacing: DesignSystem.spacing2) {
                Text("Sign in to continue")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.primary)
                
                Text("Connect your account to start selling")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.secondary)
            }
            
            VStack(spacing: DesignSystem.spacing2) {
                // Apple Sign In
                Button(action: { firebaseService.signInWithApple() }) {
                    HStack {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continue with Apple")
                            .font(DesignSystem.bodyFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(DesignSystem.buttonRadius)
                }
                
                // Google Sign In
                Button(action: { firebaseService.signInWithGoogle() }) {
                    HStack {
                        Image(systemName: "globe")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continue with Google")
                            .font(DesignSystem.bodyFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DesignSystem.tertiary)
                    .cornerRadius(DesignSystem.buttonRadius)
                }
            }
            .padding(.horizontal, DesignSystem.spacing3)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
        .overlay(
            Group {
                if firebaseService.isLoading {
                    LoadingOverlay()
                }
            }
        )
    }
}

// MARK: - MAIN APP VIEW
struct MainAppView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var businessService: BusinessService
    @State private var showingEbayConnect = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !businessService.isEbayAuthenticated {
                EbayConnectView()
            } else {
                CameraView()
            }
        }
        .sheet(isPresented: $showingEbayConnect) {
            EbayConnectSheet()
        }
    }
}

// MARK: - EBAY CONNECT VIEW
struct EbayConnectView: View {
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            // eBay logo placeholder
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(Color.blue)
                .frame(width: 80, height: 80)
                .overlay(
                    Text("eBay")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: DesignSystem.spacing2) {
                Text("Connect to eBay")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.primary)
                
                Text("Link your eBay account to automatically create listings")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            PrimaryButton(title: "Connect eBay Account") {
                businessService.authenticateEbay { _ in }
            }
            .padding(.horizontal, DesignSystem.spacing3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
    }
}

// MARK: - CAMERA VIEW
struct CameraView: View {
    @EnvironmentObject var businessService: BusinessService
    @EnvironmentObject var firebaseService: FirebaseService
    
    @State private var capturedImages: [UIImage] = []
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingProcessing = false
    @State private var analysisResult: AnalysisResult?
    @State private var selectedItems: [PhotosPickerItem] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ResellAI")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.primary)
                
                Spacer()
                
                Button(action: { /* Show settings */ }) {
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
                    onCamera: { showingCamera = true },
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
                    onReset: resetToCamera
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
    
    private func analyzePhotos() {
        guard firebaseService.canAnalyze else { return }
        
        showingProcessing = true
        businessService.analyzeItem(capturedImages) { result in
            DispatchQueue.main.async {
                showingProcessing = false
                analysisResult = result
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
        guard firebaseService.canCreateListing else { return }
        
        businessService.createEbayListing(from: result, images: capturedImages) { success, error in
            DispatchQueue.main.async {
                if success {
                    resetToCamera()
                }
            }
        }
    }
}

// MARK: - INITIAL CAMERA STATE
struct InitialCameraState: View {
    let onCamera: () -> Void
    let onLibrary: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            VStack(spacing: DesignSystem.spacing2) {
                Circle()
                    .stroke(DesignSystem.tertiary, lineWidth: 2)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.secondary)
                    )
                
                Text("Ready to analyze")
                    .font(DesignSystem.headlineFont)
                    .foregroundColor(DesignSystem.primary)
                
                Text("Take a photo or select from library")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.secondary)
            }
            
            Spacer()
            
            VStack(spacing: DesignSystem.spacing2) {
                PrimaryButton(title: "Take Photo", action: onCamera)
                
                SecondaryButton(title: "Choose from Library", action: onLibrary)
            }
            .padding(.horizontal, DesignSystem.spacing3)
        }
    }
}

// MARK: - PHOTO PREVIEW VIEW
struct PhotoPreviewView: View {
    let images: [UIImage]
    let onAnalyze: () -> Void
    let onAddMore: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.spacing3) {
                // Photos grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.spacing2) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 160)
                            .clipped()
                            .cornerRadius(DesignSystem.cornerRadius)
                    }
                    
                    if images.count < 8 {
                        Button(action: onAddMore) {
                            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                                .fill(DesignSystem.tertiary)
                                .frame(height: 160)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 24))
                                        Text("Add More")
                                            .font(DesignSystem.captionFont)
                                    }
                                    .foregroundColor(DesignSystem.secondary)
                                )
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    PrimaryButton(title: "Analyze Item", action: onAnalyze)
                    
                    Button("Start Over", action: onReset)
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.secondary)
                }
                .padding(.horizontal, DesignSystem.spacing3)
            }
            .padding(.vertical, DesignSystem.spacing3)
        }
    }
}

// MARK: - PROCESSING VIEW
struct ProcessingView: View {
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            // Animated loading indicator
            VStack(spacing: DesignSystem.spacing3) {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(DesignSystem.neonGreen, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: true)
                
                VStack(spacing: DesignSystem.spacing1) {
                    Text("Analyzing item...")
                        .font(DesignSystem.headlineFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    Text(businessService.analysisProgress)
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.secondary)
                        .animation(.easeInOut, value: businessService.analysisProgress)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - REVIEW LISTING VIEW
struct ReviewListingView: View {
    let result: AnalysisResult
    let images: [UIImage]
    let onNewPhoto: () -> Void
    let onPostListing: () -> Void
    
    @State private var selectedPrice: Double
    @State private var isPosting = false
    
    init(result: AnalysisResult, images: [UIImage], onNewPhoto: @escaping () -> Void, onPostListing: @escaping () -> Void) {
        self.result = result
        self.images = images
        self.onNewPhoto = onNewPhoto
        self.onPostListing = onPostListing
        self._selectedPrice = State(initialValue: result.suggestedPrice)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.spacing3) {
                // Item preview
                VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
                    if let firstImage = images.first {
                        Image(uiImage: firstImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(DesignSystem.cornerRadius)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                        Text(result.name)
                            .font(DesignSystem.headlineFont)
                            .foregroundColor(DesignSystem.primary)
                        
                        if !result.brand.isEmpty {
                            Text(result.brand)
                                .font(DesignSystem.bodyFont)
                                .foregroundColor(DesignSystem.secondary)
                        }
                        
                        Text(result.condition)
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                    }
                }
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Pricing options
                VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
                    Text("Choose price")
                        .font(DesignSystem.headlineFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    VStack(spacing: DesignSystem.spacing2) {
                        PriceOptionView(
                            title: "Quick Sale",
                            price: result.quickPrice,
                            subtitle: "Sells fast",
                            isSelected: selectedPrice == result.quickPrice
                        ) {
                            selectedPrice = result.quickPrice
                        }
                        
                        PriceOptionView(
                            title: "Market Price",
                            price: result.suggestedPrice,
                            subtitle: "Best value",
                            isSelected: selectedPrice == result.suggestedPrice
                        ) {
                            selectedPrice = result.suggestedPrice
                        }
                        
                        PriceOptionView(
                            title: "Premium",
                            price: result.premiumPrice,
                            subtitle: "Max profit",
                            isSelected: selectedPrice == result.premiumPrice
                        ) {
                            selectedPrice = result.premiumPrice
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    PrimaryButton(
                        title: isPosting ? "Posting..." : "Post to eBay",
                        action: onPostListing
                    )
                    .disabled(isPosting)
                    
                    SecondaryButton(title: "Take New Photo", action: onNewPhoto)
                }
                .padding(.horizontal, DesignSystem.spacing3)
            }
            .padding(.vertical, DesignSystem.spacing3)
        }
    }
}

struct PriceOptionView: View {
    let title: String
    let price: Double
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DesignSystem.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.primary)
                    
                    Text(subtitle)
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                }
                
                Spacer()
                
                Text("$\(Int(price))")
                    .font(DesignSystem.headlineFont)
                    .foregroundColor(isSelected ? DesignSystem.neonGreen : DesignSystem.primary)
                
                Circle()
                    .fill(isSelected ? DesignSystem.neonGreen : DesignSystem.tertiary)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: isSelected ? 8 : 0, height: isSelected ? 8 : 0)
                    )
            }
            .padding(DesignSystem.spacing2)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .fill(isSelected ? DesignSystem.neonGreen.opacity(0.1) : DesignSystem.tertiary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                            .stroke(isSelected ? DesignSystem.neonGreen : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - REUSABLE COMPONENTS

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DesignSystem.neonGreen)
                .cornerRadius(DesignSystem.buttonRadius)
        }
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.bodyFont)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DesignSystem.tertiary)
                .cornerRadius(DesignSystem.buttonRadius)
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        Color.black.opacity(0.3)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                VStack(spacing: DesignSystem.spacing2) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.neonGreen))
                        .scaleEffect(1.2)
                    
                    Text("Signing in...")
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(.white)
                }
                .padding(DesignSystem.spacing3)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .fill(Color.black.opacity(0.8))
                )
            )
    }
}

// MARK: - CAMERA PICKER
struct CameraPickerView: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion, dismiss: dismiss)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: ([UIImage]) -> Void
        let dismiss: DismissAction
        
        init(completion: @escaping ([UIImage]) -> Void, dismiss: DismissAction) {
            self.completion = completion
            self.dismiss = dismiss
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                completion([image])
            }
            dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

// MARK: - EBAY CONNECT SHEET
struct EbayConnectSheet: View {
    @EnvironmentObject var businessService: BusinessService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.spacing4) {
                VStack(spacing: DesignSystem.spacing2) {
                    Text("Connect eBay")
                        .font(DesignSystem.titleFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    Text("Link your eBay account to automatically create optimized listings")
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                PrimaryButton(title: "Connect to eBay") {
                    businessService.authenticateEbay { success in
                        if success {
                            dismiss()
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing3)
            }
            .padding(DesignSystem.spacing3)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
