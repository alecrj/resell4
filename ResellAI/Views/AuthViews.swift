//
//  AuthViews.swift
//  ResellAI
//
//  Premium Dark Theme Authentication Views
//

import SwiftUI

// MARK: - WELCOME FLOW
struct WelcomeFlow: View {
    @EnvironmentObject var authService: AuthService
    @State private var currentStep = 0
    @State private var showingAuth = false
    
    var body: some View {
        ZStack {
            DesignSystem.background
                .ignoresSafeArea()
            
            if currentStep == 0 {
                WelcomeScreen(onGetStarted: {
                    withAnimation(.easeInOut(duration: DesignSystem.animationMedium)) {
                        currentStep = 1
                    }
                })
            } else if currentStep == 1 {
                WalkthroughScreen(onContinue: {
                    withAnimation(.easeInOut(duration: DesignSystem.animationMedium)) {
                        currentStep = 2
                    }
                })
            } else {
                AuthScreen()
            }
        }
        .onAppear {
            print("🎯 WelcomeFlow appeared - isAuthenticated: \(authService.isAuthenticated)")
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            print("🔄 WelcomeFlow detected auth change: \(isAuthenticated)")
        }
    }
}

// MARK: - WELCOME SCREEN
struct WelcomeScreen: View {
    let onGetStarted: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing8) {
            Spacer()
            
            // Premium App Icon
            VStack(spacing: DesignSystem.spacing6) {
                ZStack {
                    Circle()
                        .fill(DesignSystem.surfaceGradient)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(DesignSystem.aiPrimary.opacity(0.3), lineWidth: 3)
                        )
                    
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(DesignSystem.aiGradient)
                }
                .premiumGlow(color: DesignSystem.aiPrimary, radius: 30, intensity: 0.6)
                
                VStack(spacing: DesignSystem.spacing4) {
                    HStack(spacing: DesignSystem.spacing2) {
                        Text("ResellAI")
                            .font(DesignSystem.titleFont)
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        // AI Badge
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 16, weight: .medium))
                            
                            Text("AI")
                                .font(DesignSystem.aiCaptionFont)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(DesignSystem.aiPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(DesignSystem.aiPrimary.opacity(0.15))
                        )
                        .premiumGlow(color: DesignSystem.aiPrimary, radius: 8, intensity: 0.4)
                    }
                    
                    Text("Take a photo.\nResellAI does the rest.")
                        .font(DesignSystem.headlineFont)
                        .foregroundColor(DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
            }
            
            Spacer()
            
            // CTA Button
            VStack(spacing: DesignSystem.spacing3) {
                PrimaryButton(
                    title: "Get Started",
                    action: onGetStarted,
                    icon: "arrow.right"
                )
                
                Text("Photo to eBay listing in 30 seconds")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.textTertiary)
            }
            .padding(.horizontal, DesignSystem.spacing6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - WALKTHROUGH SCREEN
struct WalkthroughScreen: View {
    let onContinue: () -> Void
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing8) {
            // Header
            VStack(spacing: DesignSystem.spacing4) {
                Text("How it works")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.textPrimary)
                
                Text("AI-powered reselling in three simple steps")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.textSecondary)
            }
            .padding(.top, DesignSystem.spacing8)
            
            // Steps
            VStack(spacing: DesignSystem.spacing6) {
                WalkthroughStep(
                    number: "1",
                    icon: "camera.fill",
                    title: "Snap a photo",
                    description: "Take a photo of any item you want to sell",
                    color: DesignSystem.aiPrimary
                )
                
                WalkthroughStep(
                    number: "2",
                    icon: "brain.head.profile",
                    title: "AI identifies item",
                    description: "Our AI identifies the product and finds market data",
                    color: DesignSystem.aiSecondary
                )
                
                WalkthroughStep(
                    number: "3",
                    icon: "network",
                    title: "Auto-post to eBay",
                    description: "Optimized listing goes live on your eBay account",
                    color: DesignSystem.aiAccent
                )
            }
            .padding(.horizontal, DesignSystem.spacing6)
            
            Spacer()
            
            // Continue Button
            VStack(spacing: DesignSystem.spacing3) {
                PrimaryButton(
                    title: "Continue",
                    action: onContinue,
                    icon: "arrow.right"
                )
                
                Text("Ready to start selling smarter?")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.textTertiary)
            }
            .padding(.horizontal, DesignSystem.spacing6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WalkthroughStep: View {
    let number: String
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing4) {
            // Step Number with Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 64, height: 64)
                
                Circle()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 64, height: 64)
                
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(color)
                    
                    Text(number)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                }
            }
            .premiumGlow(color: color, radius: 12, intensity: 0.4)
            
            // Content
            VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                Text(title)
                    .font(DesignSystem.headlineFont)
                    .foregroundColor(DesignSystem.textPrimary)
                
                Text(description)
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(DesignSystem.spacing4)
        .premiumCard()
    }
}

// MARK: - AUTH SCREEN
struct AuthScreen: View {
    @EnvironmentObject var authService: AuthService
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing8) {
            Spacer()
            
            // Header
            VStack(spacing: DesignSystem.spacing4) {
                Text("Sign in to continue")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.textPrimary)
                
                Text("Connect your account to start selling with AI")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Auth Buttons
            VStack(spacing: DesignSystem.spacing4) {
                // Apple Sign In
                Button(action: {
                    print("🍎 Apple Sign In button tapped")
                    authService.signInWithApple()
                }) {
                    HStack(spacing: DesignSystem.spacing3) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Continue with Apple")
                            .font(DesignSystem.bodyFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(DesignSystem.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignSystem.ButtonStyle.height)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.buttonRadius)
                            .fill(DesignSystem.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.buttonRadius)
                                    .stroke(DesignSystem.textPrimary.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
                
                // Google Sign In
                Button(action: {
                    print("🔍 Google Sign In button tapped")
                    authService.signInWithGoogle()
                }) {
                    HStack(spacing: DesignSystem.spacing3) {
                        Image(systemName: "globe")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Continue with Google")
                            .font(DesignSystem.bodyFont)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(DesignSystem.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: DesignSystem.ButtonStyle.height)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.buttonRadius)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color(white: 0.95)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
                }
            }
            .padding(.horizontal, DesignSystem.spacing6)
            
            Spacer()
            
            // Debug Info (only in debug builds)
            #if DEBUG
            debugInfo
            #endif
            
            // Error Display
            if let error = authService.authError {
                Text(error)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.spacing6)
                    .padding(.bottom, DesignSystem.spacing4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            Group {
                if authService.isLoading {
                    LoadingOverlay(message: "Signing in...")
                }
            }
        )
        .onAppear {
            print("🎯 AuthScreen appeared")
            print("• isAuthenticated: \(authService.isAuthenticated)")
            print("• isLoading: \(authService.isLoading)")
        }
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            print("🔄 AuthScreen detected auth change: \(isAuthenticated)")
        }
    }
    
    #if DEBUG
    private var debugInfo: some View {
        VStack(spacing: DesignSystem.spacing2) {
            Text("Debug Info:")
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.textTertiary)
            
            Text("isAuthenticated: \(authService.isAuthenticated ? "YES" : "NO")")
                .font(DesignSystem.captionFont)
                .foregroundColor(authService.isAuthenticated ? DesignSystem.success : DesignSystem.error)
            
            Text("isLoading: \(authService.isLoading ? "YES" : "NO")")
                .font(DesignSystem.captionFont)
                .foregroundColor(DesignSystem.textTertiary)
            
            if let user = authService.currentUser {
                Text("User: \(user.displayName ?? "Unknown")")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.success)
            } else {
                Text("User: None")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.error)
            }
            
            if let error = authService.authError {
                Text("Error: \(error)")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.error)
            }
            
            // Test button
            Button("🔄 Test Auth State") {
                print("📊 Current Auth State:")
                print("• isAuthenticated: \(authService.isAuthenticated)")
                print("• isLoading: \(authService.isLoading)")
                print("• currentUser: \(authService.currentUser?.displayName ?? "nil")")
                print("• authError: \(authService.authError ?? "nil")")
            }
            .font(DesignSystem.captionFont)
            .foregroundColor(DesignSystem.info)
        }
        .padding(DesignSystem.spacing4)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                .fill(DesignSystem.surfaceSecondary.opacity(0.5))
        )
        .padding(.horizontal, DesignSystem.spacing6)
    }
    #endif
}
