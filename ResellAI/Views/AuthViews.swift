//
//  AuthViews.swift
//  ResellAI
//
//  Authentication Flow Views
//

import SwiftUI

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
            
            // Show error if any
            if let error = firebaseService.authError {
                Text(error)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignSystem.spacing3)
            }
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
