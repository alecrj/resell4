//
//  Components.swift
//  ResellAI
//
//  Premium Dark Theme UI Components
//

import SwiftUI

// MARK: - PREMIUM BUTTONS

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var icon: String? = nil
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing2) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.background))
                        .scaleEffect(0.8)
                }
                
                if let icon = icon, !isLoading {
                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.ButtonStyle.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.semibold)
            }
            .foregroundColor(isEnabled ? DesignSystem.background : DesignSystem.textDisabled)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.ButtonStyle.height)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.buttonRadius)
                    .fill(
                        isEnabled
                        ? DesignSystem.buttonGradient
                        : LinearGradient(colors: [DesignSystem.surfaceTertiary], startPoint: .leading, endPoint: .trailing)
                    )
            )
            .premiumGlow(
                color: isEnabled ? DesignSystem.aiPrimary : Color.clear,
                radius: 12,
                intensity: isEnabled ? 0.4 : 0
            )
        }
        .disabled(!isEnabled || isLoading)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.easeInOut(duration: DesignSystem.animationMedium), value: isEnabled)
        .animation(.easeInOut(duration: DesignSystem.animationMedium), value: isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var icon: String? = nil
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: DesignSystem.ButtonStyle.iconSize, weight: .medium))
                }
                
                Text(title)
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.medium)
            }
            .foregroundColor(isEnabled ? DesignSystem.textPrimary : DesignSystem.textDisabled)
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.ButtonStyle.height)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.buttonRadius)
                    .fill(DesignSystem.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.buttonRadius)
                            .stroke(DesignSystem.surfaceTertiary, lineWidth: 1)
                    )
            )
        }
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.95)
        .animation(.easeInOut(duration: DesignSystem.animationMedium), value: isEnabled)
    }
}

struct TertiaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var color: Color = DesignSystem.textSecondary
    var icon: String? = nil
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.spacing2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(DesignSystem.calloutFont)
                    .fontWeight(.medium)
            }
            .foregroundColor(isEnabled ? color : DesignSystem.textDisabled)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: DesignSystem.animationFast), value: isEnabled)
    }
}

// MARK: - PREMIUM OVERLAYS

struct LoadingOverlay: View {
    var message: String = "Loading..."
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .blur(radius: 1)
            
            VStack(spacing: DesignSystem.spacing4) {
                ZStack {
                    Circle()
                        .stroke(DesignSystem.surfaceTertiary, lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(DesignSystem.aiPrimary, lineWidth: 4)
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1.5).repeatForever(autoreverses: false), value: true)
                }
                .premiumGlow(color: DesignSystem.aiPrimary, radius: 15, intensity: 0.6)
                
                Text(message)
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .padding(DesignSystem.spacing6)
            .premiumCard()
        }
    }
}

struct SuccessOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .blur(radius: 1)
            
            VStack(spacing: DesignSystem.spacing4) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.success.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(DesignSystem.success)
                }
                .premiumGlow(color: DesignSystem.success, radius: 20, intensity: 0.8)
                
                Text(message)
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.textPrimary)
                    .multilineTextAlignment(.center)
                
                PrimaryButton(title: "Continue", action: onDismiss)
                    .frame(maxWidth: 200)
            }
            .padding(DesignSystem.spacing6)
            .premiumCard()
        }
    }
}

struct ErrorView: View {
    let error: String
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            ZStack {
                Circle()
                    .fill(DesignSystem.error.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(DesignSystem.error)
            }
            .premiumGlow(color: DesignSystem.error, radius: 20, intensity: 0.6)
            
            Text("Error")
                .font(DesignSystem.headlineFont)
                .foregroundColor(DesignSystem.textPrimary)
            
            Text(error)
                .font(DesignSystem.bodyFont)
                .foregroundColor(DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: DesignSystem.spacing3) {
                if let onRetry = onRetry {
                    PrimaryButton(title: "Try Again", action: onRetry, icon: "arrow.clockwise")
                }
                
                SecondaryButton(title: "OK", action: onDismiss)
            }
        }
        .padding(DesignSystem.spacing6)
        .premiumCard()
    }
}

// MARK: - STATUS INDICATORS

struct StatusIndicator: View {
    let isConnected: Bool
    let label: String
    var showPulse: Bool = false
    
    @State private var isPulsing = false
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing2) {
            ZStack {
                Circle()
                    .fill(isConnected ? DesignSystem.success : DesignSystem.error)
                    .frame(width: 12, height: 12)
                
                if showPulse && isConnected {
                    Circle()
                        .fill(DesignSystem.success.opacity(0.3))
                        .frame(width: isPulsing ? 20 : 12, height: isPulsing ? 20 : 12)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
                }
            }
            .onAppear {
                if showPulse && isConnected {
                    isPulsing = true
                }
            }
            
            Text(label)
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.textSecondary)
        }
    }
}

struct UsageMeter: View {
    let current: Int
    let limit: Int
    let label: String
    
    private var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(Double(current) / Double(limit), 1.0)
    }
    
    private var isNearLimit: Bool {
        percentage >= 0.8
    }
    
    private var meterColor: Color {
        if percentage >= 0.9 { return DesignSystem.error }
        if percentage >= 0.7 { return DesignSystem.warning }
        return DesignSystem.aiPrimary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
            HStack {
                Text(label)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.textSecondary)
                
                Spacer()
                
                Text("\(current)/\(limit)")
                    .font(DesignSystem.captionFont)
                    .fontWeight(.medium)
                    .foregroundColor(isNearLimit ? DesignSystem.error : DesignSystem.textPrimary)
            }
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.surfaceTertiary)
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(meterColor)
                    .frame(width: max(8, CGFloat(percentage) * 200), height: 8)
                    .animation(.easeInOut(duration: DesignSystem.animationMedium), value: percentage)
                
                if isNearLimit {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(meterColor.opacity(0.3))
                        .frame(width: max(8, CGFloat(percentage) * 200), height: 8)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isNearLimit)
                }
            }
        }
        .padding(DesignSystem.spacing4)
        .premiumCard()
    }
}

// MARK: - PROGRESS INDICATORS

struct ProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat
    
    init(progress: Double, color: Color = DesignSystem.aiPrimary, lineWidth: CGFloat = 6, size: CGFloat = 60) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(DesignSystem.surfaceTertiary, lineWidth: lineWidth)
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: DesignSystem.animationMedium), value: progress)
        }
        .premiumGlow(color: color, radius: 8, intensity: 0.4)
    }
}

// MARK: - CARDS AND CONTAINERS

struct InfoCard: View {
    let title: String
    let subtitle: String?
    let value: String
    let icon: String
    let color: Color
    
    init(title: String, subtitle: String? = nil, value: String, icon: String, color: Color = DesignSystem.aiPrimary) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.icon = icon
        self.color = color
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing4) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                Text(title)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.textSecondary)
                
                Text(value)
                    .font(DesignSystem.headlineFont)
                    .foregroundColor(DesignSystem.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(DesignSystem.footnoteFont)
                        .foregroundColor(DesignSystem.textTertiary)
                }
            }
            
            Spacer()
        }
        .premiumCard()
    }
}

// MARK: - FLOATING ACTION BUTTON

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var isEnabled: Bool = true
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(DesignSystem.buttonGradient)
                    .frame(width: 64, height: 64)
                
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(DesignSystem.background)
            }
        }
        .disabled(!isEnabled)
        .scaleEffect(isEnabled ? 1.0 : 0.8)
        .premiumGlow(color: DesignSystem.aiPrimary, radius: 16, intensity: 0.6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEnabled)
    }
}
