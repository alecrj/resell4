//
//  AnalysisViews.swift
//  ResellAI
//
//  Enhanced Analysis Views with Expert AI Results
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
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.secondary)
                    )
                
                Text("Ready for expert analysis")
                    .font(DesignSystem.headlineFont)
                    .foregroundColor(DesignSystem.primary)
                
                Text("Take a photo for AI-powered market intelligence")
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

// MARK: - PHOTO PREVIEW VIEW (ENHANCED)
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
                
                // Enhanced photo tips
                VStack(spacing: DesignSystem.spacing1) {
                    Text("\(images.count) photo\(images.count == 1 ? "" : "s") selected")
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                    
                    if images.count == 1 {
                        Text("More angles = better expert analysis")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.neonGreen)
                    } else if images.count >= 3 {
                        Text("Perfect! Expert AI will analyze all details")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.neonGreen)
                    }
                }
                
                // AI Analysis preview
                if canAnalyze {
                    ExpertAnalysisPreviewCard()
                        .padding(.horizontal, DesignSystem.spacing3)
                }
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    if canAnalyze {
                        PrimaryButton(title: "Analyze with Expert AI", action: onAnalyze)
                    } else {
                        PrimaryButton(title: "Upgrade for Expert Analysis") {
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

// MARK: - EXPERT ANALYSIS PREVIEW CARD
struct ExpertAnalysisPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(DesignSystem.neonGreen)
                Text("Expert AI Analysis")
                    .font(DesignSystem.headlineFont)
                    .foregroundColor(DesignSystem.primary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                AnalysisFeatureRow(icon: "magnifyingglass", feature: "Precise product identification")
                AnalysisFeatureRow(icon: "chart.line.uptrend.xyaxis", feature: "Market intelligence & trends")
                AnalysisFeatureRow(icon: "diamond", feature: "Rarity & hype assessment")
                AnalysisFeatureRow(icon: "dollarsign.circle", feature: "Expert pricing strategy")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.spacing2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(DesignSystem.neonGreen.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(DesignSystem.neonGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct AnalysisFeatureRow: View {
    let icon: String
    let feature: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.neonGreen)
                .frame(width: 16)
            
            Text(feature)
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.secondary)
        }
    }
}

// MARK: - ENHANCED PROCESSING VIEW
struct ProcessingView: View {
    @EnvironmentObject var businessService: BusinessService
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            // Enhanced loading indicator
            VStack(spacing: DesignSystem.spacing3) {
                ZStack {
                    Circle()
                        .stroke(DesignSystem.tertiary, lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(DesignSystem.neonGreen, lineWidth: 8)
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotationAngle))
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24))
                        .foregroundColor(DesignSystem.neonGreen)
                }
                .onAppear {
                    withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
                
                VStack(spacing: DesignSystem.spacing1) {
                    Text("Expert AI analyzing...")
                        .font(DesignSystem.headlineFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    Text(businessService.analysisProgress)
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.secondary)
                        .animation(.easeInOut, value: businessService.analysisProgress)
                    
                    // Enhanced progress bar
                    ProgressView(value: businessService.progressValue)
                        .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.neonGreen))
                        .frame(maxWidth: 250)
                        .padding(.top, DesignSystem.spacing1)
                }
            }
            
            // Analysis steps
            VStack(alignment: .leading, spacing: 8) {
                ProcessingStep(step: "Identifying exact product", isActive: businessService.progressValue > 0.2)
                ProcessingStep(step: "Assessing rarity & hype", isActive: businessService.progressValue > 0.5)
                ProcessingStep(step: "Calculating optimal pricing", isActive: businessService.progressValue > 0.8)
            }
            .padding(.horizontal, DesignSystem.spacing3)
            
            Spacer()
            
            Text("Expert analysis takes 15-30 seconds")
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ProcessingStep: View {
    let step: String
    let isActive: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isActive ? DesignSystem.neonGreen : DesignSystem.tertiary)
                .frame(width: 8, height: 8)
            
            Text(step)
                .font(DesignSystem.captionFont)
                .foregroundColor(isActive ? DesignSystem.primary : DesignSystem.secondary)
        }
        .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

// MARK: - ENHANCED REVIEW LISTING VIEW
struct ReviewListingView: View {
    let result: AnalysisResult
    let images: [UIImage]
    let onNewPhoto: () -> Void
    let onPostListing: () -> Void
    
    @State private var selectedPrice: Double
    @State private var isPosting = false
    @State private var showingFullDescription = false
    @State private var showingExpertDetails = false
    
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
                // Enhanced item preview with AI insights
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
                        
                        HStack {
                            Text(result.condition)
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.secondary)
                            
                            Spacer()
                            
                            // Expert AI badge
                            HStack(spacing: 4) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 12))
                                Text("Expert AI")
                                    .font(.caption)
                            }
                            .foregroundColor(DesignSystem.neonGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(DesignSystem.neonGreen.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Expert insights card
                if let demandLevel = result.demandLevel {
                    ExpertInsightsCard(
                        demandLevel: demandLevel,
                        soldListingsCount: result.soldListingsCount,
                        competitorCount: result.competitorCount,
                        confidence: result.aiConfidence
                    )
                    .padding(.horizontal, DesignSystem.spacing3)
                }
                
                // Enhanced pricing options with expert reasoning
                VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
                    HStack {
                        Text("Expert pricing strategy")
                            .font(DesignSystem.headlineFont)
                            .foregroundColor(DesignSystem.primary)
                        
                        Spacer()
                        
                        Button(action: { showingExpertDetails.toggle() }) {
                            Text("Details")
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.neonGreen)
                        }
                    }
                    
                    VStack(spacing: DesignSystem.spacing2) {
                        ExpertPriceOptionView(
                            title: "Quick Sale",
                            price: result.quickPrice,
                            subtitle: "3-7 days • Fast cash",
                            timing: "Fast",
                            isSelected: selectedPrice == result.quickPrice
                        ) {
                            selectedPrice = result.quickPrice
                        }
                        
                        ExpertPriceOptionView(
                            title: "Market Price",
                            price: result.suggestedPrice,
                            subtitle: "2-4 weeks • Best balance",
                            timing: "Balanced",
                            isSelected: selectedPrice == result.suggestedPrice
                        ) {
                            selectedPrice = result.suggestedPrice
                        }
                        
                        ExpertPriceOptionView(
                            title: "Patient Sale",
                            price: result.premiumPrice,
                            subtitle: "1-3 months • Max profit",
                            timing: "Patient",
                            isSelected: selectedPrice == result.premiumPrice
                        ) {
                            selectedPrice = result.premiumPrice
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Expert details sheet
                if showingExpertDetails {
                    ExpertDetailsCard(result: result)
                        .padding(.horizontal, DesignSystem.spacing3)
                }
                
                // Enhanced listing preview
                EnhancedListingPreviewCard(
                    title: result.title,
                    description: result.description,
                    showingFull: $showingFullDescription
                )
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    PrimaryButton(
                        title: isPosting ? "Creating eBay listing..." : "Post to eBay - $\(Int(selectedPrice))",
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

// MARK: - EXPERT INSIGHTS CARD
struct ExpertInsightsCard: View {
    let demandLevel: String
    let soldListingsCount: Int?
    let competitorCount: Int?
    let confidence: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
            Text("Market Intelligence")
                .font(DesignSystem.headlineFont)
                .foregroundColor(DesignSystem.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Demand Level:")
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.secondary)
                    
                    Spacer()
                    
                    Text(demandLevel)
                        .font(DesignSystem.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(demandLevelColor(demandLevel))
                }
                
                if let soldCount = soldListingsCount {
                    HStack {
                        Text("Recent Sales:")
                            .font(DesignSystem.bodyFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        Spacer()
                        
                        Text("\(soldCount) listings")
                            .font(DesignSystem.bodyFont)
                            .foregroundColor(DesignSystem.primary)
                    }
                }
                
                if let competitorCount = competitorCount {
                    HStack {
                        Text("Competition:")
                            .font(DesignSystem.bodyFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        Spacer()
                        
                        Text("\(competitorCount) active")
                            .font(DesignSystem.bodyFont)
                            .foregroundColor(DesignSystem.primary)
                    }
                }
                
                if let confidence = confidence {
                    HStack {
                        Text("AI Confidence:")
                            .font(DesignSystem.bodyFont)
                            .foregroundColor(DesignSystem.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(confidence * 100))%")
                            .font(DesignSystem.bodyFont)
                            .foregroundColor(confidence > 0.8 ? .green : confidence > 0.6 ? .orange : .red)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.spacing2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(DesignSystem.tertiary)
        )
    }
    
    private func demandLevelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "high", "extreme": return .green
        case "medium": return .orange
        case "low": return .red
        default: return DesignSystem.secondary
        }
    }
}

// MARK: - EXPERT PRICE OPTION VIEW
struct ExpertPriceOptionView: View {
    let title: String
    let price: Double
    let subtitle: String
    let timing: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(DesignSystem.bodyFont)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.primary)
                        
                        Spacer()
                        
                        Text(timing)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(timingColor.opacity(0.2))
                            .foregroundColor(timingColor)
                            .cornerRadius(8)
                    }
                    
                    Text(subtitle)
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                }
                
                VStack(alignment: .trailing, spacing: 4) {
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
    
    private var timingColor: Color {
        switch timing.lowercased() {
        case "fast": return .red
        case "balanced": return .blue
        case "patient": return .green
        default: return DesignSystem.secondary
        }
    }
}

// MARK: - EXPERT DETAILS CARD
struct ExpertDetailsCard: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
            Text("Expert Analysis Details")
                .font(DesignSystem.headlineFont)
                .foregroundColor(DesignSystem.primary)
            
            if let sourcingTips = result.sourcingTips, !sourcingTips.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sourcing Tips:")
                        .font(DesignSystem.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.primary)
                    
                    ForEach(sourcingTips, id: \.self) { tip in
                        Text("• \(tip)")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                    }
                }
            }
            
            if let strategy = result.listingStrategy {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Listing Strategy:")
                        .font(DesignSystem.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.primary)
                    
                    Text(strategy)
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.spacing2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(DesignSystem.neonGreen.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(DesignSystem.neonGreen.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - ENHANCED LISTING PREVIEW CARD
struct EnhancedListingPreviewCard: View {
    let title: String
    let description: String
    @Binding var showingFull: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
            Text("eBay Listing Preview")
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
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(DesignSystem.tertiary)
        )
    }
}

// MARK: - CAMERA PICKER (UNCHANGED)
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
