//
//  AnalysisViews.swift
//  ResellAI
//
//  Camera and Analysis Flow Views - iOS 16 Compatible
//

import SwiftUI
import UIKit
import PhotosUI
import AVFoundation

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
                    .multilineTextAlignment(.center)
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
                            
                            // Image counter
                            Text("\(index + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
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
                
                // Photo count and tips
                VStack(spacing: DesignSystem.spacing1) {
                    Text("\(images.count) photo\(images.count == 1 ? "" : "s") selected")
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                    
                    if images.count == 1 {
                        Text("Add more angles for better results")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.neonGreen)
                    }
                }
                
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
                    
                    // Progress bar
                    ProgressView(value: businessService.progressValue)
                        .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.neonGreen))
                        .frame(maxWidth: 200)
                        .padding(.top, DesignSystem.spacing1)
                }
            }
            
            Spacer()
            
            Text("This usually takes 10-15 seconds")
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.secondary)
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
                    MarketDataCard(
                        soldListingsCount: soldListingsCount,
                        competitorCount: result.competitorCount,
                        demandLevel: result.demandLevel
                    )
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
                ListingPreviewCard(
                    title: result.title,
                    description: result.description,
                    showingFull: $showingFullDescription
                )
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    PrimaryButton(
                        title: isPosting ? "Posting to eBay..." : "Post to eBay",
                        action: {
                            isPosting = true
                            onPostListing()
                        },
                        isEnabled: !isPosting,
                        isLoading: isPosting
                    )
                    
                    SecondaryButton(title: "Take New Photo", action: onNewPhoto)
                }
                .padding(.horizontal, DesignSystem.spacing3)
            }
            .padding(.vertical, DesignSystem.spacing3)
        }
    }
}

// MARK: - MARKET DATA CARD
struct MarketDataCard: View {
    let soldListingsCount: Int
    let competitorCount: Int?
    let demandLevel: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
            Text("Market Data")
                .font(DesignSystem.headlineFont)
                .foregroundColor(DesignSystem.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Based on \(soldListingsCount) recent sales")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.secondary)
                
                if let competitorCount = competitorCount {
                    Text("\(competitorCount) active listings")
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                }
                
                if let demandLevel = demandLevel {
                    Text("Demand: \(demandLevel)")
                        .font(DesignSystem.captionFont)
                        .foregroundColor(demandLevel == "High" ? DesignSystem.neonGreen : DesignSystem.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.spacing2)
        .background(DesignSystem.tertiary)
        .cornerRadius(DesignSystem.cornerRadius)
    }
}

// MARK: - LISTING PREVIEW CARD
struct ListingPreviewCard: View {
    let title: String
    let description: String
    @Binding var showingFull: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
            Text("Listing Preview")
                .font(DesignSystem.headlineFont)
                .foregroundColor(DesignSystem.primary)
            
            VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                Text(title)
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.primary)
                
                Text(showingFull ? description : String(description.prefix(150)) + (description.count > 150 ? "..." : ""))
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if description.count > 150 {
                    Button(showingFull ? "Show Less" : "Show More") {
                        showingFull.toggle()
                    }
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.neonGreen)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.spacing2)
        .background(DesignSystem.tertiary)
        .cornerRadius(DesignSystem.cornerRadius)
    }
}

// MARK: - PRICE OPTION VIEW
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

// MARK: - SETTINGS VIEW
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let user = firebaseService.currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName ?? "User")
                                .font(DesignSystem.bodyFont)
                                .fontWeight(.semibold)
                            
                            Text(user.email ?? "")
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.secondary)
                        }
                    }
                    
                    Button("Sign Out") {
                        firebaseService.signOut()
                    }
                    .foregroundColor(.red)
                }
                
                Section("eBay Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(businessService.isEbayAuthenticated ? "Connected" : "Not Connected")
                            .foregroundColor(businessService.isEbayAuthenticated ? .green : .red)
                    }
                    
                    if businessService.isEbayAuthenticated {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(businessService.ebayService.connectedUserName)
                                .foregroundColor(DesignSystem.secondary)
                        }
                        
                        Button("Disconnect eBay") {
                            businessService.ebayService.signOut()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Usage") {
                    if let user = firebaseService.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Analyses")
                                Spacer()
                                Text("\(firebaseService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                                    .foregroundColor(DesignSystem.secondary)
                            }
                            
                            ProgressView(value: Double(firebaseService.monthlyAnalysisCount) / Double(user.monthlyAnalysisLimit))
                                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.neonGreen))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Listings")
                                Spacer()
                                Text("\(firebaseService.monthlyListingCount)/\(user.monthlyListingLimit)")
                                    .foregroundColor(DesignSystem.secondary)
                            }
                            
                            ProgressView(value: Double(firebaseService.monthlyListingCount) / Double(user.monthlyListingLimit))
                                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.neonGreen))
                        }
                    }
                }
                
                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Configuration.version)
                            .foregroundColor(DesignSystem.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
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
