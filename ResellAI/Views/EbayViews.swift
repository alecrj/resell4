//
//  EbayViews.swift
//  ResellAI
//
//  eBay Integration Views with User Account Display
//

import SwiftUI

// MARK: - EBAY CONNECT VIEW
struct EbayConnectView: View {
    @EnvironmentObject var businessService: BusinessService
    @State private var isConnecting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: DesignSystem.spacing4) {
            Spacer()
            
            // eBay logo and status
            VStack(spacing: DesignSystem.spacing2) {
                RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                    .fill(businessService.isEbayAuthenticated ? Color.blue : Color.gray)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text("eBay")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(spacing: DesignSystem.spacing1) {
                    Text("Connect to eBay")
                        .font(DesignSystem.titleFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    Text("Link your eBay account to automatically create listings")
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Connection status indicator
                ConnectionStatusCard(
                    isConnected: businessService.isEbayAuthenticated,
                    status: businessService.ebayAuthStatus,
                    connectedUser: businessService.ebayService.connectedUserName
                )
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: DesignSystem.spacing2) {
                if businessService.isEbayAuthenticated {
                    PrimaryButton(title: "Continue to App") {
                        // This will trigger the main app view
                    }
                    
                    SecondaryButton(title: "Disconnect eBay") {
                        businessService.ebayService.signOut()
                    }
                } else {
                    PrimaryButton(
                        title: isConnecting ? "Connecting..." : "Connect eBay Account",
                        action: { connectToEbay() },
                        isEnabled: !isConnecting,
                        isLoading: isConnecting
                    )
                    
                    Text("You'll be redirected to eBay to sign in")
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, DesignSystem.spacing3)
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
            // Check authentication status on appear
            print("🔍 eBay connection status: \(businessService.isEbayAuthenticated)")
            print("🔍 eBay user: \(businessService.ebayService.connectedUserName)")
        }
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
        VStack(spacing: DesignSystem.spacing2) {
            HStack {
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                Text(isConnected ? "Connected" : "Not Connected")
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(isConnected ? Color.green : Color.red)
            }
            
            if isConnected && !connectedUser.isEmpty {
                VStack(spacing: 4) {
                    Text("eBay Account")
                        .font(DesignSystem.captionFont)
                        .foregroundColor(DesignSystem.secondary)
                    
                    Text(connectedUser)
                        .font(DesignSystem.bodyFont)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.primary)
                }
            } else if !isConnected {
                Text("Connect your account to start selling")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Additional status info
            if !status.isEmpty && status != "Connected" && status != "Not Connected" {
                Text(status)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(DesignSystem.spacing2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(isConnected ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                        .stroke(isConnected ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
                )
        )
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
            VStack(spacing: DesignSystem.spacing4) {
                // Header
                VStack(spacing: DesignSystem.spacing2) {
                    Image(systemName: "network")
                        .font(.system(size: 40))
                        .foregroundColor(Color.blue)
                    
                    Text("Connect eBay")
                        .font(DesignSystem.titleFont)
                        .foregroundColor(DesignSystem.primary)
                    
                    Text("Link your eBay account to automatically create optimized listings")
                        .font(DesignSystem.bodyFont)
                        .foregroundColor(DesignSystem.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, DesignSystem.spacing4)
                
                // Benefits
                VStack(alignment: .leading, spacing: DesignSystem.spacing2) {
                    BenefitRow(
                        icon: "wand.and.stars",
                        title: "Auto-listing creation",
                        description: "AI generates optimized titles and descriptions"
                    )
                    
                    BenefitRow(
                        icon: "photo.on.rectangle",
                        title: "Image upload",
                        description: "Photos are automatically uploaded to eBay"
                    )
                    
                    BenefitRow(
                        icon: "dollarsign.circle",
                        title: "Smart pricing",
                        description: "Based on recent market data and sold comps"
                    )
                    
                    BenefitRow(
                        icon: "shield.checkered",
                        title: "Secure connection",
                        description: "OAuth 2.0 authentication with eBay"
                    )
                }
                .padding(.horizontal, DesignSystem.spacing3)
                
                Spacer()
                
                // Current connection status
                ConnectionStatusCard(
                    isConnected: businessService.isEbayAuthenticated,
                    status: businessService.ebayAuthStatus,
                    connectedUser: businessService.ebayService.connectedUserName
                )
                .padding(.horizontal, DesignSystem.spacing3)
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    if businessService.isEbayAuthenticated {
                        PrimaryButton(title: "Done") {
                            dismiss()
                        }
                        
                        SecondaryButton(title: "Disconnect Account") {
                            businessService.ebayService.signOut()
                        }
                    } else {
                        PrimaryButton(
                            title: isConnecting ? "Connecting..." : "Connect to eBay",
                            action: { connectToEbay() },
                            isEnabled: !isConnecting,
                            isLoading: isConnecting
                        )
                        
                        if isConnecting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Opening eBay authentication...")
                                    .font(DesignSystem.captionFont)
                                    .foregroundColor(DesignSystem.secondary)
                            }
                            .padding(.top, DesignSystem.spacing1)
                        } else {
                            Text("You'll be redirected to eBay to sign in securely")
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.spacing3)
                .padding(.bottom, DesignSystem.spacing3)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
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
    }
    
    private func connectToEbay() {
        isConnecting = true
        businessService.authenticateEbay { success in
            DispatchQueue.main.async {
                isConnecting = false
                if success {
                    print("✅ eBay connection successful")
                    // Don't auto-dismiss to let user see the connected status
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
    
    var body: some View {
        HStack(spacing: DesignSystem.spacing2) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.neonGreen)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.bodyFont)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.primary)
                
                Text(description)
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - EBAY ACCOUNT STATUS VIEW (for use in other parts of the app)
struct EbayAccountStatus: View {
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        HStack {
            Circle()
                .fill(businessService.isEbayAuthenticated ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            if businessService.isEbayAuthenticated {
                Text("eBay: \(businessService.ebayService.connectedUserName)")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.secondary)
            } else {
                Text("eBay: Not connected")
                    .font(DesignSystem.captionFont)
                    .foregroundColor(DesignSystem.secondary)
            }
        }
    }
}
