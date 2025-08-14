//
//  Components.swift
//  ResellAI
//
//  Reusable UI Components - FIXED VERSION
//

import SwiftUI

// MARK: - REUSABLE COMPONENTS

struct PrimaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var isLoading: Bool = false
    
    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.black))
                        .scaleEffect(0.8)
                }
                
                Text(title)
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(isEnabled ? Color.black : Color.gray)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? DesignSystem.neonGreen : DesignSystem.tertiary)
            .cornerRadius(DesignSystem.buttonRadius)
        }
        .disabled(!isEnabled || isLoading)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
}

struct SecondaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var color: Color = DesignSystem.primary
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.bodyFont)
                .fontWeight(.medium)
                .foregroundColor(isEnabled ? color : Color.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DesignSystem.tertiary)
                .cornerRadius(DesignSystem.buttonRadius)
        }
        .disabled(!isEnabled)
        .animation(.easeInOut(duration: 0.2), value: isEnabled)
    }
}

struct TertiaryButton: View {
    let title: String
    let action: () -> Void
    var isEnabled: Bool = true
    var color: Color = DesignSystem.secondary
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(DesignSystem.bodyFont)
                .fontWeight(.medium)
                .foregroundColor(isEnabled ? color : Color.gray)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .disabled(!isEnabled)
    }
}

struct LoadingOverlay: View {
    var message: String = "Loading..."
    
    var body: some View {
        Color.black.opacity(0.3)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                VStack(spacing: DesignSystem.spacing2) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.neonGreen))
                        .scaleEffect(1.2)
                    
                    Text(message)
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(Color.white)
                }
                .padding(DesignSystem.spacing3)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .fill(Color.black.opacity(0.8))
                )
            )
    }
}

struct SuccessOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        Color.black.opacity(0.3)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                VStack(spacing: DesignSystem.spacing2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(DesignSystem.neonGreen)
                    
                    Text(message)
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(Color.white)
                        .multilineTextAlignment(.center)
                    
                    PrimaryButton(title: "Continue", action: onDismiss)
                        .frame(maxWidth: 200)
                }
                .padding(DesignSystem.spacing3)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .fill(Color.black.opacity(0.8))
                )
            )
    }
}

struct ErrorView: View {
    let error: String
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color.red)
            
            Text("Error")
                .font(DesignSystem.headlineFont)
                .foregroundColor(DesignSystem.primary)
            
            Text(error)
                .font(DesignSystem.bodyFont)
                .foregroundColor(DesignSystem.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: DesignSystem.spacing2) {
                if let onRetry = onRetry {
                    PrimaryButton(title: "Try Again", action: onRetry)
                }
                
                SecondaryButton(title: "OK", action: onDismiss)
            }
        }
        .padding(DesignSystem.spacing3)
        .background(DesignSystem.background)
        .cornerRadius(DesignSystem.cornerRadius)
    }
}

struct StatusIndicator: View {
    let isConnected: Bool
    let label: String
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing1) {
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.secondary)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
            HStack {
                Text(label)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.secondary)
                
                Spacer()
                
                Text("\(current)/\(limit)")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(isNearLimit ? Color.red : DesignSystem.secondary)
            }
            
            ProgressView(value: percentage)
                .progressViewStyle(LinearProgressViewStyle(tint: isNearLimit ? Color.red : DesignSystem.neonGreen))
                .frame(height: 4)
        }
        .padding(DesignSystem.spacing2)
        .background(DesignSystem.tertiary)
        .cornerRadius(DesignSystem.cornerRadius)
    }
}
