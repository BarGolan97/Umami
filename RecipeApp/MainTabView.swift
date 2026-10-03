//
//  MainTabView.swift
//  RecipeApp
//
//  Professional Tab Bar for Apple Vision Pro
//

import SwiftUI
import SwiftData

// MARK: - Tab Definition
enum AppTab: String, CaseIterable, Identifiable {
    case home = "home"
    case search = "search"
    case favorites = "favorites"
    case settings = "settings"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .search: return "Search"
        case .favorites: return "Favorites"
        case .settings: return "Settings"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .search: return "magnifyingglass"
        case .favorites: return "heart.fill"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @State private var selectedTab: AppTab = .home
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    @Environment(\.modelContext) private var context
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                // Home Tab
                HomeView()
                    .tabItem {
                        Label(AppTab.home.title, systemImage: AppTab.home.icon)
                    }
                    .tag(AppTab.home)
                
                // Search Tab
                SearchView()
                    .tabItem {
                        Label(AppTab.search.title, systemImage: AppTab.search.icon)
                    }
                    .tag(AppTab.search)
                
                // Favorites Tab
                FavoritesView()
                    .tabItem {
                        Label(AppTab.favorites.title, systemImage: AppTab.favorites.icon)
                    }
                    .tag(AppTab.favorites)

                SettingsView()
                    .tabItem {
                        Label(AppTab.settings.title, systemImage: AppTab.settings.icon)
                    }
                    .tag(AppTab.settings)
            }
            #if os(visionOS)
            .tabViewStyle(.sidebarAdaptable)
            #endif
            
            // Onboarding overlay
            if showOnboarding {
                OnboardingView(isPresented: $showOnboarding)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showOnboarding)
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: showOnboarding) { _, isShowing in
            if !isShowing && !hasCompletedOnboarding {
                hasCompletedOnboarding = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToHome)) { _ in
            selectedTab = .home
        }
    }
}

#Preview {
    MainTabView()
        .environment(EntitlementManager.shared)
        .environment(AIUsageManager.shared)
}
