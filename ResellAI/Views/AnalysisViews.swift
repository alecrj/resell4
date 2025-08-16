//
//  AnalysisViews.swift
//  ResellAI
//
//  Premium Analysis Views with RGB Glow Effects
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
        VStack(spacing: DesignSystem.spacing8) {
            Spacer()
            
            VStack(spacing: DesignSystem.spacing6) {
                // Premium AI Icon
                ZStack {
                    Circle()
                        .fill(DesignSystem.surfaceGradient)
                        .frame(width: 140, height: 140)
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.aiPrimary.opacity(0.3), lineWidth: 2)
                        )
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(DesignSystem.aiGradient)
                }
                .premiumGlow(color: DesignSystem.aiPrimary, radius: 25, intensity: 0.4)
                
                VStack(spacing: DesignSystem.spacing3) {
                    Text("Ready for AI Analysis")
                        .font(DesignSystem.largeTitleFont)
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Text("Take a photo for instant product identification and market intelligence")
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            VStack(spacing: DesignSystem.spacing4) {
                PrimaryButton(
                    title: "Take Photo",
                    action: onCamera,
                    icon: "camera.fill"
                )
                
                SecondaryButton(
                    title: "Choose from Library",
                    action: onLibrary,
                    icon: "photo.on.rectangle"
                )
            }
            .padding(.horizontal, DesignSystem.spacing6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
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
            VStack(spacing: DesignSystem.spacing6) {
                // Photos Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.spacing3), count: 2), spacing: DesignSystem.spacing3) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                                .background(DesignSystem.surfaceSecondary)
                                .cornerRadius(DesignSystem.radiusLarge)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                        .stroke(DesignSystem.surfaceTertiary, lineWidth: 1)
                                )
                            
                            // Premium Image Counter
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.background.opacity(0.9))
                                    .frame(width: 32, height: 32)
                                
                                Text("\(index + 1)")
                                    .font(DesignSystem.captionFont)
                                    .fontWeight(.bold)
                                    .foregroundColor(DesignSystem.aiPrimary)
                            }
                            .padding(DesignSystem.spacing2)
                        }
                    }
                    
                    // Add More Button
                    if images.count < 8 {
                        Button(action: onAddMore) {
                            RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                .fill(DesignSystem.surfaceSecondary)
                                .frame(height: 180)
                                .overlay(
                                    VStack(spacing: DesignSystem.spacing2) {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 32, weight: .medium))
                                            .foregroundColor(DesignSystem.aiPrimary)
                                        
                                        Text("Add More")
                                            .font(DesignSystem.captionFont)
                                            .foregroundColor(DesignSystem.textSecondary)
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                        .stroke(DesignSystem.aiPrimary.opacity(0.3), lineWidth: 2)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                                )
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing6)
                
                // Photo Stats
                VStack(spacing: DesignSystem.spacing2) {
                    Text("\(images.count) photo\(images.count == 1 ? "" : "s") selected")
                        .font(DesignSystem.calloutFont)
                        .foregroundColor(DesignSystem.textSecondary)
                    
                    if images.count == 1 {
                        Text("More angles = better AI analysis")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.aiPrimary)
                    } else if images.count >= 3 {
                        Text("Perfect! AI will analyze all details")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.success)
                    }
                }
                
                // AI Analysis Preview with RGB Glow
                if canAnalyze {
                    AIAnalysisPreviewCard()
                        .padding(.horizontal, DesignSystem.spacing6)
                }
                
                // Action Buttons
                VStack(spacing: DesignSystem.spacing4) {
                    if canAnalyze {
                        PrimaryButton(
                            title: "Analyze with AI",
                            action: onAnalyze,
                            icon: "brain.head.profile"
                        )
                    } else {
                        PrimaryButton(
                            title: "Upgrade for AI Analysis",
                            action: { /* Show upgrade flow */ },
                            icon: "crown.fill"
                        )
                    }
                    
                    TertiaryButton(
                        title: "Start Over",
                        action: onReset,
                        icon: "arrow.counterclockwise"
                    )
                }
                .padding(.horizontal, DesignSystem.spacing6)
            }
            .padding(.vertical, DesignSystem.spacing6)
        }
        .background(DesignSystem.background)
    }
}

// MARK: - AI ANALYSIS PREVIEW CARD WITH RGB GLOW
struct AIAnalysisPreviewCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
            // Header with AI branding
            HStack(spacing: DesignSystem.spacing3) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.aiPrimary.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignSystem.aiPrimary)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Analysis")
                        .font(DesignSystem.aiTitleFont)
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Text("GPT-5 powered identification")
                        .font(DesignSystem.aiCaptionFont)
                        .foregroundColor(DesignSystem.aiPrimary)
                }
                
                Spacer()
                
                // AI Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(DesignSystem.success)
                        .frame(width: 8, height: 8)
                    
                    Text("READY")
                        .font(DesignSystem.aiCaptionFont)
                        .foregroundColor(DesignSystem.success)
                }
            }
            
            // Features List
            VStack(alignment: .leading, spacing: DesignSystem.spacing3) {
                AIFeatureRow(
                    icon: "viewfinder.circle",
                    feature: "Precise product identification",
                    description: "Brand, model, and condition"
                )
                
                AIFeatureRow(
                    icon: "chart.line.uptrend.xyaxis",
                    feature: "Real-time market data",
                    description: "eBay sold listings and trends"
                )
                
                AIFeatureRow(
                    icon: "target",
                    feature: "Smart pricing strategy",
                    description: "Quick, market, and premium tiers"
                )
                
                AIFeatureRow(
                    icon: "wand.and.stars",
                    feature: "Auto eBay listing",
                    description: "Title, description, and photos"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.AICard.padding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.AICard.radius)
                .fill(DesignSystem.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.AICard.radius)
                        .stroke(DesignSystem.aiPrimary.opacity(0.4), lineWidth: DesignSystem.AICard.borderWidth)
                )
        )
        .rgbGlow(isAnimating: true) // RGB Glow Effect!
    }
}

struct AIFeatureRow: View {
    let icon: String
    let feature: String
    let description: String
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing3) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(DesignSystem.aiPrimary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(feature)
                    .font(DesignSystem.aiBodyFont)
                    .foregroundColor(DesignSystem.textPrimary)
                
                Text(description)
                    .font(DesignSystem.aiCaptionFont)
                    .foregroundColor(DesignSystem.textSecondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - PROCESSING VIEW WITH PREMIUM ANIMATIONS
struct ProcessingView: View {
    @EnvironmentObject var businessService: BusinessService
    @State private var currentStep = 0
    @State private var rotationAngle: Double = 0
    
    private let steps = [
        "Analyzing with AI...",
        "Identifying product details...",
        "Fetching market data...",
        "Calculating optimal pricing...",
        "Generating listing content..."
    ]
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing8) {
            Spacer()
            
            // Premium Loading Animation
            VStack(spacing: DesignSystem.spacing6) {
                ZStack {
                    // Outer Ring
                    Circle()
                        .stroke(DesignSystem.surfaceTertiary, lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    // Progress Ring
                    Circle()
                        .trim(from: 0, to: businessService.progressValue * 0.8 + 0.2)
                        .stroke(DesignSystem.aiPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: businessService.progressValue)
                    
                    // Inner AI Icon
                    ZStack {
                        Circle()
                            .fill(DesignSystem.surfaceSecondary)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(DesignSystem.aiPrimary)
                            .rotationEffect(.degrees(rotationAngle))
                    }
                }
                .rgbGlow(isAnimating: true)
                .onAppear {
                    withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                        rotationAngle = 360
                    }
                }
                
                VStack(spacing: DesignSystem.spacing3) {
                    Text("AI Processing")
                        .font(DesignSystem.largeTitleFont)
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Text(businessService.analysisProgress)
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut, value: businessService.analysisProgress)
                    
                    // Progress Percentage
                    Text("\(Int(businessService.progressValue * 100))%")
                        .font(DesignSystem.aiTitleFont)
                        .foregroundColor(DesignSystem.aiPrimary)
                        .fontWeight(.bold)
                }
            }
            
            // Processing Steps
            VStack(alignment: .leading, spacing: DesignSystem.spacing3) {
                ProcessingStep(
                    step: "Identifying product",
                    isActive: businessService.progressValue > 0.2,
                    isCompleted: businessService.progressValue > 0.4
                )
                
                ProcessingStep(
                    step: "Fetching market data",
                    isActive: businessService.progressValue > 0.4,
                    isCompleted: businessService.progressValue > 0.6
                )
                
                ProcessingStep(
                    step: "Calculating pricing",
                    isActive: businessService.progressValue > 0.6,
                    isCompleted: businessService.progressValue > 0.8
                )
                
                ProcessingStep(
                    step: "Generating listing",
                    isActive: businessService.progressValue > 0.8,
                    isCompleted: businessService.progressValue >= 1.0
                )
            }
            .padding(.horizontal, DesignSystem.spacing6)
            
            Spacer()
            
            Text("AI analysis typically takes 15-30 seconds")
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
    }
}

struct ProcessingStep: View {
    let step: String
    let isActive: Bool
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing3) {
            ZStack {
                Circle()
                    .fill(stepColor.opacity(0.2))
                    .frame(width: 24, height: 24)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(DesignSystem.success)
                } else if isActive {
                    Circle()
                        .fill(DesignSystem.aiPrimary)
                        .frame(width: 8, height: 8)
                } else {
                    Circle()
                        .fill(DesignSystem.surfaceTertiary)
                        .frame(width: 8, height: 8)
                }
            }
            
            Text(step)
                .font(DesignSystem.bodyFont)
                .foregroundColor(stepTextColor)
            
            Spacer()
            
            if isActive && !isCompleted {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.aiPrimary))
                    .scaleEffect(0.7)
            }
        }
        .animation(.easeInOut(duration: DesignSystem.animationMedium), value: isActive)
        .animation(.easeInOut(duration: DesignSystem.animationMedium), value: isCompleted)
    }
    
    private var stepColor: Color {
        if isCompleted { return DesignSystem.success }
        if isActive { return DesignSystem.aiPrimary }
        return DesignSystem.surfaceTertiary
    }
    
    private var stepTextColor: Color {
        if isCompleted { return DesignSystem.success }
        if isActive { return DesignSystem.textPrimary }
        return DesignSystem.textSecondary
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
    @State private var showingAIDetails = false
    
    init(result: AnalysisResult, images: [UIImage], onNewPhoto: @escaping () -> Void, onPostListing: @escaping () -> Void) {
        self.result = result
        self.images = images
        self.onNewPhoto = onNewPhoto
        self.onPostListing = onPostListing
        self._selectedPrice = State(initialValue: result.suggestedPrice)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.spacing6) {
                // Item Preview
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    if let firstImage = images.first {
                        Image(uiImage: firstImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 240)
                            .clipped()
                            .background(DesignSystem.surfaceSecondary)
                            .cornerRadius(DesignSystem.radiusLarge)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                                    .stroke(DesignSystem.surfaceTertiary, lineWidth: 1)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
                        Text(result.name)
                            .font(DesignSystem.largeTitleFont)
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        if !result.brand.isEmpty {
                            Text(result.brand)
                                .font(DesignSystem.bodyFont)
                                .foregroundColor(DesignSystem.textSecondary)
                        }
                        
                        HStack {
                            Text(result.condition)
                                .font(DesignSystem.calloutFont)
                                .foregroundColor(DesignSystem.textSecondary)
                            
                            Spacer()
                            
                            // AI Analysis Badge with glow
                            HStack(spacing: 6) {
                                Image(systemName: "brain.head.profile")
                                    .font(.system(size: 14, weight: .medium))
                                
                                Text("AI ANALYZED")
                                    .font(DesignSystem.aiCaptionFont)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(DesignSystem.aiPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(DesignSystem.aiPrimary.opacity(0.15))
                            )
                            .premiumGlow(color: DesignSystem.aiPrimary, radius: 8, intensity: 0.3)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing6)
                
                // AI Insights Card with RGB Glow
                if let demandLevel = result.demandLevel {
                    AIInsightsCard(
                        demandLevel: demandLevel,
                        soldListingsCount: result.soldListingsCount,
                        competitorCount: result.competitorCount,
                        confidence: result.aiConfidence
                    )
                    .padding(.horizontal, DesignSystem.spacing6)
                }
                
                // Pricing Strategy
                VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                    HStack {
                        Text("AI Pricing Strategy")
                            .font(DesignSystem.headlineFont)
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        Spacer()
                        
                        Button(action: { showingAIDetails.toggle() }) {
                            Text("Details")
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.aiPrimary)
                        }
                    }
                    
                    VStack(spacing: DesignSystem.spacing3) {
                        PriceOptionView(
                            title: "Quick Sale",
                            price: result.quickPrice,
                            subtitle: "3-7 days • Fast cash",
                            timing: "Fast",
                            isSelected: selectedPrice == result.quickPrice,
                            color: DesignSystem.warning
                        ) {
                            selectedPrice = result.quickPrice
                        }
                        
                        PriceOptionView(
                            title: "Market Price",
                            price: result.suggestedPrice,
                            subtitle: "2-4 weeks • AI recommended",
                            timing: "Optimal",
                            isSelected: selectedPrice == result.suggestedPrice,
                            color: DesignSystem.aiPrimary
                        ) {
                            selectedPrice = result.suggestedPrice
                        }
                        
                        PriceOptionView(
                            title: "Premium Price",
                            price: result.premiumPrice,
                            subtitle: "1-3 months • Max profit",
                            timing: "Patient",
                            isSelected: selectedPrice == result.premiumPrice,
                            color: DesignSystem.success
                        ) {
                            selectedPrice = result.premiumPrice
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing6)
                
                // Listing Preview
                ListingPreviewCard(
                    title: result.title,
                    description: result.description,
                    showingFull: $showingFullDescription
                )
                .padding(.horizontal, DesignSystem.spacing6)
                
                // Action Buttons
                VStack(spacing: DesignSystem.spacing4) {
                    PrimaryButton(
                        title: isPosting ? "Creating eBay listing..." : "Post to eBay - $\(Int(selectedPrice))",
                        action: {
                            isPosting = true
                            onPostListing()
                        },
                        isEnabled: !isPosting,
                        isLoading: isPosting,
                        icon: isPosting ? nil : "network"
                    )
                    
                    SecondaryButton(
                        title: "Take New Photo",
                        action: onNewPhoto,
                        icon: "camera"
                    )
                }
                .padding(.horizontal, DesignSystem.spacing6)
            }
            .padding(.vertical, DesignSystem.spacing6)
        }
        .background(DesignSystem.background)
    }
}

// MARK: - AI INSIGHTS CARD WITH RGB GLOW
struct AIInsightsCard: View {
    let demandLevel: String
    let soldListingsCount: Int?
    let competitorCount: Int?
    let confidence: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
            HStack(spacing: DesignSystem.spacing3) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                        .fill(DesignSystem.info.opacity(0.2))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignSystem.info)
                }
                
                Text("Market Intelligence")
                    .font(DesignSystem.aiTitleFont)
                    .foregroundColor(DesignSystem.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.spacing3) {
                InsightRow(
                    label: "Demand Level",
                    value: demandLevel,
                    color: demandLevelColor(demandLevel)
                )
                
                if let soldCount = soldListingsCount {
                    InsightRow(
                        label: "Recent Sales",
                        value: "\(soldCount) listings",
                        color: DesignSystem.textPrimary
                    )
                }
                
                if let competitorCount = competitorCount {
                    InsightRow(
                        label: "Competition",
                        value: "\(competitorCount) active",
                        color: DesignSystem.textPrimary
                    )
                }
                
                if let confidence = confidence {
                    InsightRow(
                        label: "AI Confidence",
                        value: "\(Int(confidence * 100))%",
                        color: confidence > 0.8 ? DesignSystem.success : confidence > 0.6 ? DesignSystem.warning : DesignSystem.error
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.AICard.padding)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.AICard.radius)
                .fill(DesignSystem.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.AICard.radius)
                        .stroke(DesignSystem.info.opacity(0.4), lineWidth: DesignSystem.AICard.borderWidth)
                )
        )
        .rgbGlow(isAnimating: true)
    }
    
    private func demandLevelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "high", "extreme": return DesignSystem.success
        case "medium": return DesignSystem.warning
        case "low": return DesignSystem.error
        default: return DesignSystem.textSecondary
        }
    }
}

struct InsightRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .font(DesignSystem.bodyFont)
                .foregroundColor(DesignSystem.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.bodyFont)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

// MARK: - PRICE OPTION VIEW
struct PriceOptionView: View {
    let title: String
    let price: Double
    let subtitle: String
    let timing: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing4) {
                VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                    HStack {
                        Text(title)
                            .font(DesignSystem.bodyFont)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        Spacer()
                        
                        Text(timing)
                            .font(DesignSystem.captionFont)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.2))
                            .foregroundColor(color)
                            .cornerRadius(8)
                    }
                    
                    Text(subtitle)
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.textSecondary)
                }
                
                VStack(alignment: .trailing, spacing: DesignSystem.spacing1) {
                    Text("$\(Int(price))")
                        .font(DesignSystem.headlineFont)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? color : DesignSystem.textPrimary)
                    
                    ZStack {
                        Circle()
                            .fill(isSelected ? color : DesignSystem.surfaceTertiary)
                            .frame(width: 24, height: 24)
                        
                        if isSelected {
                            Circle()
                                .fill(DesignSystem.background)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .padding(DesignSystem.spacing4)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                    .fill(isSelected ? color.opacity(0.1) : DesignSystem.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                            .stroke(isSelected ? color : DesignSystem.surfaceTertiary, lineWidth: isSelected ? 2 : 1)
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: DesignSystem.animationFast), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - LISTING PREVIEW CARD
struct ListingPreviewCard: View {
    let title: String
    let description: String
    @Binding var showingFull: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
            Text("eBay Listing Preview")
                .font(DesignSystem.headlineFont)
                .foregroundColor(DesignSystem.textPrimary)
            
            VStack(alignment: .leading, spacing: DesignSystem.spacing3) {
                Text(title)
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.textPrimary)
                
                Text(showingFull ? description : String(description.prefix(150)) + (description.count > 150 ? "..." : ""))
                    .font(DesignSystem.calloutFont)
                    .foregroundColor(DesignSystem.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                if description.count > 150 {
                    Button(showingFull ? "Show Less" : "Show More") {
                        withAnimation(.easeInOut(duration: DesignSystem.animationMedium)) {
                            showingFull.toggle()
                        }
                    }
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.aiPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .premiumCard()
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
