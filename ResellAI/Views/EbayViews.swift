//
//  EbayViews.swift
//  ResellAI
//
//  Premium Dark Theme eBay Integration Views
//

import SwiftUI

// MARK: - EBAY CONNECT VIEW
struct EbayConnectView: View {
    @EnvironmentObject var businessService: BusinessService
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var shouldAutoTransition = false
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing8) {
            Spacer()
            
            // eBay Integration Header
            VStack(spacing: DesignSystem.spacing6) {
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.radiusXLarge)
                        .fill(DesignSystem.surfaceGradient)
                        .frame(width: 120, height: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.radiusXLarge)
                                .stroke(connectionStatusColor.opacity(0.3), lineWidth: 3)
                        )
                    
                    VStack(spacing: 8) {
                        Text("eBay")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        Image(systemName: connectionStatusIcon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(connectionStatusColor)
                    }
                }
                .premiumGlow(color: connectionStatusColor, radius: 25, intensity: 0.6)
                
                VStack(spacing: DesignSystem.spacing3) {
                    Text("Connect to eBay")
                        .font(DesignSystem.titleFont)
                        .foregroundColor(DesignSystem.textPrimary)
                    
                    Text("Link your eBay account to automatically create listings from AI analysis")
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                
                // Connection Status Card
                ConnectionStatusCard(
                    isConnected: businessService.ebayService.isAuthenticated,
                    status: businessService.ebayService.authStatus,
                    connectedUser: businessService.ebayService.connectedUserName
                )
            }
            
            Spacer()
            
            // Action Section
            VStack(spacing: DesignSystem.spacing6) {
                if businessService.ebayService.isAuthenticated {
                    // Success State
                    VStack(spacing: DesignSystem.spacing4) {
                        HStack(spacing: DesignSystem.spacing3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(DesignSystem.success)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connected to eBay!")
                                    .font(DesignSystem.headlineFont)
                                    .foregroundColor(DesignSystem.textPrimary)
                                
                                Text("Ready to create listings")
                                    .font(DesignSystem.bodyFont)
                                    .foregroundColor(DesignSystem.textSecondary)
                            }
                        }
                        
                        VStack(spacing: DesignSystem.spacing2) {
                            Text("Transitioning to main app...")
                                .font(DesignSystem.bodyFont)
                                .foregroundColor(DesignSystem.textSecondary)
                            
                            ProgressRing(progress: 1.0, color: DesignSystem.success, size: 40)
                        }
                    }
                    .padding(DesignSystem.spacing5)
                    .premiumCard()
                } else {
                    // Connection Flow
                    VStack(spacing: DesignSystem.spacing4) {
                        PrimaryButton(
                            title: isConnecting ? "Connecting..." : "Connect eBay Account",
                            action: { connectToEbay() },
                            isEnabled: !isConnecting,
                            isLoading: isConnecting,
                            icon: isConnecting ? nil : "link"
                        )
                        
                        Text("You'll be redirected to eBay to sign in securely")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.textTertiary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.spacing6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") { }
            Button("Try Again") { connectToEbay() }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            print("🔍 EbayConnectView appeared - isAuthenticated: \(businessService.ebayService.isAuthenticated)")
        }
        .onChange(of: businessService.ebayService.isAuthenticated) { isAuthenticated in
            print("🔄 EbayConnectView detected auth change: \(isAuthenticated)")
            if isAuthenticated {
                print("✅ eBay connected - setting auto-transition flag")
                shouldAutoTransition = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    print("🚀 Auto-transitioning to main app")
                }
            }
        }
        .onChange(of: businessService.ebayService.connectedUserName) { userName in
            print("🔄 EbayConnectView detected user name change: \(userName)")
            if !userName.isEmpty && businessService.ebayService.isAuthenticated {
                shouldAutoTransition = true
            }
        }
    }
    
    private var connectionStatusColor: Color {
        businessService.ebayService.isAuthenticated ? DesignSystem.success : DesignSystem.warning
    }
    
    private var connectionStatusIcon: String {
        businessService.ebayService.isAuthenticated ? "checkmark.circle.fill" : "link.circle"
    }
    
    private func connectToEbay() {
        isConnecting = true
        businessService.authenticateEbay { success in
            DispatchQueue.main.async {
                isConnecting = false
                if !success {
                    errorMessage = "Failed to connect to eBay. Please check your internet connection and try again."
                    showingError = true
                }
            }
        }
    }
}

// MARK: - CONNECTION STATUS CARD
struct ConnectionStatusCard: View {
    let isConnected: Bool
    let status: String
    let connectedUser: String
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            HStack(spacing: DesignSystem.spacing3) {
                StatusIndicator(
                    isConnected: isConnected,
                    label: isConnected ? "Connected" : "Not Connected",
                    showPulse: isConnected
                )
                
                Spacer()
                
                if isConnected {
                    Text("ACTIVE")
                        .font(DesignSystem.aiCaptionFont)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(DesignSystem.success.opacity(0.2))
                        )
                }
            }
            
            if isConnected && !connectedUser.isEmpty {
                VStack(spacing: DesignSystem.spacing2) {
                    Text("eBay Account")
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.textTertiary)
                    
                    Text(connectedUser)
                        .font(DesignSystem.bodyFont)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.textPrimary)
                }
            } else if !isConnected {
                Text("Connect your account to start creating automatic listings")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Additional status info
            if !status.isEmpty && status != "Connected" && status != "Not Connected" {
                Text(status)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.spacing5)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                .fill(statusBackgroundColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.radiusLarge)
                        .stroke(statusBackgroundColor.opacity(0.3), lineWidth: 1)
                )
        )
        .premiumGlow(color: statusBackgroundColor, radius: 12, intensity: 0.3)
    }
    
    private var statusBackgroundColor: Color {
        isConnected ? DesignSystem.success : DesignSystem.warning
    }
}

// MARK: - EBAY CONNECT SHEET
struct EbayConnectSheet: View {
    @EnvironmentObject var businessService: BusinessService
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.spacing6) {
                    // Header
                    VStack(spacing: DesignSystem.spacing4) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.info.opacity(0.2))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "network")
                                .font(.system(size: 40, weight: .medium))
                                .foregroundColor(DesignSystem.info)
                        }
                        .premiumGlow(color: DesignSystem.info, radius: 20, intensity: 0.5)
                        
                        VStack(spacing: DesignSystem.spacing2) {
                            Text("Connect eBay")
                                .font(DesignSystem.titleFont)
                                .foregroundColor(DesignSystem.textPrimary)
                            
                            Text("Link your eBay account to automatically create optimized listings from AI analysis")
                                .font(DesignSystem.bodyFont)
                                .foregroundColor(DesignSystem.textSecondary)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                    }
                    .padding(.top, DesignSystem.spacing6)
                    
                    // Benefits
                    VStack(alignment: .leading, spacing: DesignSystem.spacing4) {
                        Text("What you get:")
                            .font(DesignSystem.headlineFont)
                            .foregroundColor(DesignSystem.textPrimary)
                        
                        VStack(spacing: DesignSystem.spacing3) {
                            BenefitRow(
                                icon: "wand.and.stars",
                                title: "Auto-listing creation",
                                description: "AI generates optimized titles and descriptions",
                                color: DesignSystem.aiPrimary
                            )
                            
                            BenefitRow(
                                icon: "photo.on.rectangle",
                                title: "Image upload",
                                description: "Photos are automatically uploaded to eBay",
                                color: DesignSystem.aiSecondary
                            )
                            
                            BenefitRow(
                                icon: "dollarsign.circle",
                                title: "Smart pricing",
                                description: "Based on real market data and sold comps",
                                color: DesignSystem.success
                            )
                            
                            BenefitRow(
                                icon: "shield.checkered",
                                title: "Secure connection",
                                description: "OAuth 2.0 authentication with eBay",
                                color: DesignSystem.info
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacing6)
                    
                    // Current Status
                    ConnectionStatusCard(
                        isConnected: businessService.ebayService.isAuthenticated,
                        status: businessService.ebayService.authStatus,
                        connectedUser: businessService.ebayService.connectedUserName
                    )
                    .padding(.horizontal, DesignSystem.spacing6)
                    
                    // Actions
                    VStack(spacing: DesignSystem.spacing4) {
                        if businessService.ebayService.isAuthenticated {
                            PrimaryButton(
                                title: "Done",
                                action: { dismiss() },
                                icon: "checkmark"
                            )
                            
                            SecondaryButton(
                                title: "Disconnect Account",
                                action: { businessService.ebayService.signOut() },
                                icon: "link.badge.minus"
                            )
                        } else {
                            PrimaryButton(
                                title: isConnecting ? "Connecting..." : "Connect to eBay",
                                action: { connectToEbay() },
                                isEnabled: !isConnecting,
                                isLoading: isConnecting,
                                icon: isConnecting ? nil : "link"
                            )
                            
                            if isConnecting {
                                HStack(spacing: DesignSystem.spacing2) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.aiPrimary))
                                        .scaleEffect(0.8)
                                    
                                    Text("Opening eBay authentication...")
                                        .font(DesignSystem.captionFont)
                                        .foregroundColor(DesignSystem.textSecondary)
                                }
                                .padding(.top, DesignSystem.spacing2)
                            } else {
                                Text("You'll be redirected to eBay to sign in securely with OAuth 2.0")
                                    .font(DesignSystem.captionFont)
                                    .foregroundColor(DesignSystem.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.spacing6)
                    .padding(.bottom, DesignSystem.spacing6)
                }
            }
            .background(DesignSystem.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.textSecondary)
                }
            }
        }
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") { }
            Button("Try Again") {
                connectToEbay()
            }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: businessService.ebayService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                print("✅ eBay connected in sheet - auto-dismissing after delay")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    dismiss()
                }
            }
        }
    }
    
    private func connectToEbay() {
        isConnecting = true
        businessService.authenticateEbay { success in
            DispatchQueue.main.async {
                isConnecting = false
                if success {
                    print("✅ eBay connection successful")
                } else {
                    errorMessage = "Failed to connect to eBay. Please check your internet connection and try again."
                    showingError = true
                }
            }
        }
    }
}

// MARK: - BENEFIT ROW
struct BenefitRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing4) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.radiusMedium)
                    .fill(color.opacity(0.2))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
            }
            .premiumGlow(color: color, radius: 8, intensity: 0.3)
            
            VStack(alignment: .leading, spacing: DesignSystem.spacing1) {
                Text(title)
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.textPrimary)
                
                Text(description)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
        .padding(DesignSystem.spacing4)
        .premiumCard()
    }
}

// MARK: - EBAY ACCOUNT STATUS VIEW
struct EbayAccountStatus: View {
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing2) {
            StatusIndicator(
                isConnected: businessService.ebayService.isAuthenticated,
                label: businessService.ebayService.isAuthenticated
                    ? "eBay: \(businessService.ebayService.connectedUserName)"
                    : "eBay: Not connected",
                showPulse: businessService.ebayService.isAuthenticated
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(DesignSystem.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            businessService.ebayService.isAuthenticated
                            ? DesignSystem.success.opacity(0.3)
                            : DesignSystem.warning.opacity(0.3),
                            lineWidth: 1
                        )
                )
        )
    }
}
