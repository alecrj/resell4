//
//  SettingsView.swift
//  ResellAI
//
//  Created by Alec on 8/15/25.
//


//
//  SettingsView.swift
//  ResellAI
//
//  Settings View - Updated to Use AuthService
//

import SwiftUI

// MARK: - SETTINGS VIEW (UPDATED)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var businessService: BusinessService
    
    var body: some View {
        NavigationView {
            List {
                Section("Account") {
                    if let user = authService.currentUser {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName ?? "User")
                                .font(DesignSystem.bodyFont)
                                .fontWeight(.semibold)
                            
                            Text(user.email ?? "")
                                .font(DesignSystem.captionFont)
                                .foregroundColor(DesignSystem.secondary)
                        }
                    }
                    
                    Button("Sign Out") {
                        authService.signOut()
                    }
                    .foregroundColor(.red)
                }
                
                Section("eBay Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(businessService.isEbayAuthenticated ? "Connected" : "Not Connected")
                            .foregroundColor(businessService.isEbayAuthenticated ? .green : .red)
                    }
                    
                    if businessService.isEbayAuthenticated {
                        HStack {
                            Text("Account")
                            Spacer()
                            Text(businessService.ebayService.connectedUserName)
                                .foregroundColor(DesignSystem.secondary)
                        }
                        
                        Button("Disconnect eBay") {
                            businessService.ebayService.signOut()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                Section("Usage") {
                    if let user = authService.currentUser {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Analyses")
                                Spacer()
                                Text("\(authService.monthlyAnalysisCount)/\(user.monthlyAnalysisLimit)")
                                    .foregroundColor(DesignSystem.secondary)
                            }
                            
                            ProgressView(value: Double(authService.monthlyAnalysisCount) / Double(user.monthlyAnalysisLimit))
                                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.neonGreen))
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Listings")
                                Spacer()
                                Text("\(authService.monthlyListingCount)/\(user.monthlyListingLimit)")
                                    .foregroundColor(DesignSystem.secondary)
                            }
                            
                            ProgressView(value: Double(authService.monthlyListingCount) / Double(user.monthlyListingLimit))
                                .progressViewStyle(LinearProgressViewStyle(tint: DesignSystem.neonGreen))
                        }
                    }
                }
                
                Section("Security") {
                    if authService.isFaceIDAvailable {
                        HStack {
                            Text("Face ID")
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { authService.isFaceIDEnabled },
                                set: { enabled in
                                    if enabled {
                                        authService.enableFaceID { success, error in
                                            if !success {
                                                print("Failed to enable Face ID: \(error ?? "Unknown error")")
                                            }
                                        }
                                    } else {
                                        authService.disableFaceID()
                                    }
                                }
                            ))
                        }
                    }
                }
                
                Section("App") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Configuration.version)
                            .foregroundColor(DesignSystem.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}