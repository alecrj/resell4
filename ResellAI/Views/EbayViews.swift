//
//  EbayViews.swift
//  ResellAI
//
//  eBay Integration Views - CLEAN VERSION
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
            
            // eBay logo placeholder
            RoundedRectangle(cornerRadius: DesignSystem.cornerRadius)
                .fill(Color.blue)
                .frame(width: 80, height: 80)
                .overlay(
                    Text("eBay")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: DesignSystem.spacing2) {
                Text("Connect to eBay")
                    .font(DesignSystem.titleFont)
                    .foregroundColor(DesignSystem.primary)
                
                Text("Link your eBay account to automatically create listings")
                    .font(DesignSystem.bodyFont)
                    .foregroundColor(DesignSystem.secondary)
                    .multilineTextAlignment(.center)
                
                // Connection status
                VStack(spacing: DesignSystem.spacing1) {
                    HStack {
                        Circle()
                            .fill(businessService.isEbayAuthenticated ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        
                        Text(businessService.ebayAuthStatus)
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                    }
                    
                    if businessService.isEbayAuthenticated {
                        Text("Connected to eBay")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.neonGreen)
                    }
                }
            }
            
            Spacer()
            
            VStack(spacing: DesignSystem.spacing2) {
                if businessService.isEbayAuthenticated {
                    PrimaryButton(title: "Continue to App") {
                        // This will trigger the main app view
                    }
                    
                    SecondaryButton(title: "Disconnect eBay") {
                        businessService.ebayService.signOut()
                    }
                } else {
                    PrimaryButton(title: isConnecting ? "Connecting..." : "Connect eBay Account") {
                        connectToEbay()
                    }
                    .disabled(isConnecting)
                }
            }
            .padding(.horizontal, DesignSystem.spacing3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.background)
        .alert("Connection Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            // Check authentication status
            if businessService.isEbayAuthenticated {
                print("✅ eBay already connected")
            }
        }
    }
    
    private func connectToEbay() {
        isConnecting = true
        businessService.authenticateEbay { success in
            DispatchQueue.main.async {
                isConnecting = false
                if !success {
                    errorMessage = "Failed to connect to eBay. Please try again."
                    showingError = true
                }
            }
        }
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
                
                // Connection status
                if businessService.isEbayAuthenticated {
                    VStack(spacing: DesignSystem.spacing1) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color.green)
                            Text("Connected to eBay")
                                .font(DesignSystem.bodyFont)
                                .foregroundColor(Color.green)
                        }
                        
                        Text("Ready to create listings")
                            .font(DesignSystem.captionFont)
                            .foregroundColor(DesignSystem.secondary)
                    }
                    .padding(DesignSystem.spacing2)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(DesignSystem.cornerRadius)
                    .padding(.horizontal, DesignSystem.spacing3)
                }
                
                // Actions
                VStack(spacing: DesignSystem.spacing2) {
                    if businessService.isEbayAuthenticated {
                        PrimaryButton(title: "Done") {
                            dismiss()
                        }
                        
                        SecondaryButton(title: "Disconnect") {
                            businessService.ebayService.signOut()
                        }
                    } else {
                        PrimaryButton(title: isConnecting ? "Connecting..." : "Connect to eBay") {
                            connectToEbay()
                        }
                        .disabled(isConnecting)
                        
                        if isConnecting {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Opening eBay authentication...")
                                    .font(DesignSystem.captionFont)
                                    .foregroundColor(DesignSystem.secondary)
                            }
                            .padding(.top, DesignSystem.spacing1)
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
