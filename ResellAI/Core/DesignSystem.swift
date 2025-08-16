//
//  DesignSystem.swift
//  ResellAI
//
//  Premium Dark Theme Design System
//

import SwiftUI

// MARK: - PREMIUM DESIGN SYSTEM
struct DesignSystem {
    // MARK: - Dark Theme Colors
    static let background = Color(red: 0.05, green: 0.05, blue: 0.05) // #0D0D0D
    static let surfacePrimary = Color(red: 0.08, green: 0.08, blue: 0.08) // #141414
    static let surfaceSecondary = Color(red: 0.11, green: 0.11, blue: 0.11) // #1C1C1C
    static let surfaceTertiary = Color(red: 0.15, green: 0.15, blue: 0.15) // #262626
    
    // AI Brand Colors
    static let aiPrimary = Color(red: 0.0, green: 0.95, blue: 0.8) // #00F2CC - Cyan
    static let aiSecondary = Color(red: 0.4, green: 0.8, blue: 1.0) // #66CCFF - Light Blue
    static let aiAccent = Color(red: 0.8, green: 0.4, blue: 1.0) // #CC66FF - Purple
    
    // RGB Glow Colors for Expert AI
    static let glowRed = Color(red: 1.0, green: 0.2, blue: 0.4) // #FF3366
    static let glowGreen = Color(red: 0.2, green: 1.0, blue: 0.4) // #33FF66
    static let glowBlue = Color(red: 0.2, green: 0.4, blue: 1.0) // #3366FF
    static let glowPurple = Color(red: 0.8, green: 0.2, blue: 1.0) // #CC33FF
    static let glowCyan = Color(red: 0.2, green: 1.0, blue: 1.0) // #33FFFF
    
    // Text Colors
    static let textPrimary = Color(red: 0.98, green: 0.98, blue: 0.98) // #FAFAFA
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.7) // #B3B3B3
    static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.5) // #808080
    static let textDisabled = Color(red: 0.3, green: 0.3, blue: 0.3) // #4D4D4D
    
    // Status Colors
    static let success = Color(red: 0.2, green: 0.9, blue: 0.4) // #33E666
    static let warning = Color(red: 1.0, green: 0.7, blue: 0.0) // #FFB300
    static let error = Color(red: 1.0, green: 0.3, blue: 0.3) // #FF4D4D
    static let info = Color(red: 0.3, green: 0.7, blue: 1.0) // #4DB3FF
    
    // Legacy Support (mapped to new colors)
    static let neonGreen = aiPrimary
    static let primary = textPrimary
    static let secondary = textSecondary
    static let tertiary = surfaceTertiary
    
    // MARK: - Premium Typography
    static let titleFont = Font.custom("SF Pro Display", size: 32).weight(.bold)
    static let largeTitleFont = Font.custom("SF Pro Display", size: 28).weight(.bold)
    static let headlineFont = Font.custom("SF Pro Display", size: 22).weight(.semibold)
    static let subheadlineFont = Font.custom("SF Pro Display", size: 18).weight(.medium)
    static let bodyFont = Font.custom("SF Pro Text", size: 16).weight(.regular)
    static let calloutFont = Font.custom("SF Pro Text", size: 15).weight(.medium)
    static let captionFont = Font.custom("SF Pro Text", size: 13).weight(.medium)
    static let footnoteFont = Font.custom("SF Pro Text", size: 12).weight(.regular)
    
    // AI-specific fonts
    static let aiTitleFont = Font.custom("SF Pro Display", size: 24).weight(.bold)
    static let aiBodyFont = Font.custom("SF Pro Text", size: 15).weight(.medium)
    static let aiCaptionFont = Font.custom("SF Mono", size: 12).weight(.medium) // Monospace for technical data
    
    // MARK: - Spacing System
    static let spacing1: CGFloat = 4
    static let spacing2: CGFloat = 8
    static let spacing3: CGFloat = 12
    static let spacing4: CGFloat = 16
    static let spacing5: CGFloat = 20
    static let spacing6: CGFloat = 24
    static let spacing7: CGFloat = 32
    static let spacing8: CGFloat = 40
    
    // MARK: - Corner Radius
    static let radiusSmall: CGFloat = 6
    static let radiusMedium: CGFloat = 10
    static let radiusLarge: CGFloat = 14
    static let radiusXLarge: CGFloat = 20
    
    // Legacy support
    static let cornerRadius = radiusMedium
    static let buttonRadius = radiusLarge
    
    // MARK: - Shadow System
    static let shadowLight = Color.black.opacity(0.1)
    static let shadowMedium = Color.black.opacity(0.2)
    static let shadowHeavy = Color.black.opacity( 0.4)
    
    // Glow effects
    static let glowRadius: CGFloat = 20
    static let glowIntensity: CGFloat = 0.8
    
    // MARK: - Animation Timing
    static let animationFast = 0.2
    static let animationMedium = 0.3
    static let animationSlow = 0.5
    static let animationGlow = 2.0 // For RGB cycling
    
    // MARK: - Button Styles
    struct ButtonStyle {
        static let height: CGFloat = 56
        static let minWidth: CGFloat = 120
        static let iconSize: CGFloat = 20
    }
    
    // MARK: - Card Styles
    struct Card {
        static let padding: CGFloat = spacing4
        static let radius: CGFloat = radiusLarge
        static let borderWidth: CGFloat = 1
    }
    
    // MARK: - AI Analysis Card Styles
    struct AICard {
        static let padding: CGFloat = spacing5
        static let radius: CGFloat = radiusLarge
        static let glowRadius: CGFloat = 25
        static let borderWidth: CGFloat = 2
    }
}

// MARK: - View Extensions for Glow Effects
extension View {
    func premiumGlow(color: Color = DesignSystem.aiPrimary, radius: CGFloat = DesignSystem.glowRadius, intensity: CGFloat = DesignSystem.glowIntensity) -> some View {
        self
            .shadow(color: color.opacity(intensity), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(intensity * 0.7), radius: radius * 0.7, x: 0, y: 0)
            .shadow(color: color.opacity(intensity * 0.4), radius: radius * 0.4, x: 0, y: 0)
    }
    
    func rgbGlow(isAnimating: Bool = true) -> some View {
        self.modifier(RGBGlowModifier(isAnimating: isAnimating))
    }
    
    func aiCardStyle() -> some View {
        self
            .padding(DesignSystem.AICard.padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.AICard.radius)
                    .fill(DesignSystem.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.AICard.radius)
                            .stroke(DesignSystem.aiPrimary.opacity(0.3), lineWidth: DesignSystem.AICard.borderWidth)
                    )
            )
            .premiumGlow(color: DesignSystem.aiPrimary, radius: DesignSystem.AICard.glowRadius, intensity: 0.6)
    }
    
    func premiumCard() -> some View {
        self
            .padding(DesignSystem.Card.padding)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Card.radius)
                    .fill(DesignSystem.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Card.radius)
                            .stroke(DesignSystem.surfaceTertiary, lineWidth: DesignSystem.Card.borderWidth)
                    )
            )
            .shadow(color: DesignSystem.shadowMedium, radius: 8, x: 0, y: 4)
    }
}

// MARK: - RGB Glow Animation Modifier
struct RGBGlowModifier: ViewModifier {
    let isAnimating: Bool
    @State private var animationPhase: Double = 0
    
    private let colors: [Color] = [
        DesignSystem.glowRed,
        DesignSystem.glowGreen,
        DesignSystem.glowBlue,
        DesignSystem.glowPurple,
        DesignSystem.glowCyan
    ]
    
    private var currentColor: Color {
        let index = Int(animationPhase * Double(colors.count)) % colors.count
        return colors[index]
    }
    
    private var nextColor: Color {
        let nextIndex = (Int(animationPhase * Double(colors.count)) + 1) % colors.count
        return colors[nextIndex]
    }
    
    private var blendFactor: Double {
        let phase = animationPhase * Double(colors.count)
        return phase - floor(phase)
    }
    
    func body(content: Content) -> some View {
        content
            .shadow(color: currentColor.opacity(0.6), radius: 25, x: 0, y: 0)
            .shadow(color: nextColor.opacity(0.3 * blendFactor), radius: 20, x: 0, y: 0)
            .shadow(color: currentColor.opacity(0.8), radius: 15, x: 0, y: 0)
            .shadow(color: currentColor.opacity(0.4), radius: 35, x: 0, y: 0)
            .onAppear {
                if isAnimating {
                    withAnimation(.linear(duration: DesignSystem.animationGlow).repeatForever(autoreverses: false)) {
                        animationPhase = 1.0
                    }
                }
            }
    }
}

// MARK: - Status Indicator Colors
extension DesignSystem {
    static func statusColor(for status: String) -> Color {
        switch status.lowercased() {
        case "connected", "success", "complete", "active":
            return success
        case "pending", "processing", "loading":
            return warning
        case "error", "failed", "disconnected":
            return error
        case "info", "analyzing":
            return info
        default:
            return textSecondary
        }
    }
}

// MARK: - Gradient Definitions
extension DesignSystem {
    static let aiGradient = LinearGradient(
        colors: [aiPrimary, aiSecondary],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let surfaceGradient = LinearGradient(
        colors: [surfacePrimary, surfaceSecondary],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let buttonGradient = LinearGradient(
        colors: [aiPrimary, aiAccent],
        startPoint: .leading,
        endPoint: .trailing
    )
}
