//
//  AnalysisViews.swift
//  ResellAI
//
//  Camera and Analysis Flow Views
//

import SwiftUI
import UIKit
import PhotosUI

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
    @State private var showingSettings = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ResellAI")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.primary)
                
                Spacer()
                
                // Usage indicator
                if let user = firebaseService.currentUser {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(firebaseService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        if !firebaseService.canAnalyze {
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
                    canAnalyze: firebaseService.canAnalyze
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
        guard firebaseService.canAnalyze else {
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
        guard firebaseService.canCreateListing else {
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
    let canAnalyze: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.spacing3) {
                // Photos grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.spacing2) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 160)
                                .clipped()
                                .cornerRadius(DesignSystem.cornerRadius)
                            
                            // Remove button
                            Button(action: { /* Remove image */ }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
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
                    if canAnalyze {
                        PrimaryButton(title: "Analyze Item", action: onAnalyze)
                    } else {
                        PrimaryButton(title: "Upgrade to Analyze") {
                            // Show upgrade flow
                        }
                    }
                    
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
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            // Animated loading indicator
            VStack(spacing: DesignSystem.spacing3) {
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(DesignSystem.neonGreen, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(rotationAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            rotationAngle = 360
                        }
                    }
                
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
    @State private var showingFullDescription = false
    
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
                
                // Market data summary
                if let soldListingsCount = result.soldListingsCount {
                    VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                        Text("Market Data")
                            .font(DesignSystem.headlineFont)
                            .foregroundColor(DesignSystem.primary)
                        
                        Text("Based on \(soldListingsCount) recent sales")
                            .font(DesignSystem.bodyFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        if let demandLevel = result.demandLevel {
                            Text("Demand: \(demandLevel)")
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.spacing3)
                }
                
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
                
                // Listing preview
                VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
                    Text("Listing Preview")
                        .font(DesignSystem.headlineFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                        Text(result.title)
                            .font(DesignSystem.bodyFont)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.primary)
                        
                        Text(showingFullDescription ? result.description : String(result.description.prefix(100)) + "...")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        Button(showingFullDescription ? "Show Less" : "Show More") {
                            showingFullDescription.toggle()
                        }
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.neonGreen)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    PrimaryButton(
                        title: isPosting ? "Posting..." : "Post to eBay",
                        action: {
                            isPosting = true
                            onPostListing()
                        }
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
                            .animation(.easeInOut(duration: 0.2), value: isSelected)
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

// MARK: - CAMERA PICKER
struct CameraPickerView: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
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

// MARK: - SETTINGS VIEW (Placeholder)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Settings")
                    .font(DesignSystem.titleFont)
                Spacer()
            }
            .padding()
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
