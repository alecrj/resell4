//
//  ContentView.swift
//  ResellAI
//
//  Main App Coordinator
//

import SwiftUI

// MARK: - MAIN CONTENT VIEW
struct ContentView: View {
    @StateObject private var firebaseService = FirebaseService()
    @StateObject private var inventoryManager = InventoryManager()
    @StateObject private var businessService = BusinessService()
    
    var body: some View {
        Group {
            if firebaseService.isAuthenticated {
                MainAppView()
                    .environmentObject(firebaseService)
                    .environmentObject(inventoryManager)
                    .environmentObject(businessService)
            } else {
                WelcomeFlow()
                    .environmentObject(firebaseService)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            Configuration.validateConfiguration()
            businessService.initialize(with: firebaseService)
            inventoryManager.initialize(with: firebaseService)
        }
        .onOpenURL { url in
            if url.scheme == "resellai" && url.host == "auth" {
                businessService.handleEbayAuthCallback(url: url)
            }
        }
    }
}

// MARK: - MAIN APP VIEW
struct MainAppView: View {
    @EnvironmentObject var firebaseService: FirebaseService
    @EnvironmentObject var businessService: BusinessService
    @State private var showingEbayConnect = false
    
    var body: some View {
        VStack(spacing: 0) {
            if !businessService.isEbayAuthenticated {
                EbayConnectView()
            } else {
                CameraView()
            }
        }
        .sheet(isPresented: $showingEbayConnect) {
            EbayConnectSheet()
        }
    }
}

#Preview {
    ContentView()
}
