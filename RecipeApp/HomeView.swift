//
//  HomeView_VisionPro_Ultimate_Improved.swift
//  RecipeApp
//
//  Created for Apple Vision Pro
//  Professional Design System & Architecture - Enhanced Edition
//

import SwiftUI
import SwiftData
import Combine
import ImageIO
import UIKit

// MARK: - Ultimate Design System
struct SpatialDesign {
    // Radii
    static let smallRadius: CGFloat = 20
    static let mediumRadius: CGFloat = 24
    static let largeRadius: CGFloat = 28
    static let extraLargeRadius: CGFloat = 36
    
    // Spacing
    static let sectionSpacing: CGFloat = 60
    static let horizontalPadding: CGFloat = 80
    static let cardSpacing: CGFloat = 24
    
    // Simplified Glass Effect
    static func spatialGlass(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(.thickMaterial)
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
    }
    
    static func spatialStroke(radius: CGFloat, intensity: CGFloat = 1.0) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.6 * intensity),
                        .white.opacity(0.15 * intensity)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}

// MARK: - Advanced Hover Effect Extension
extension View {
    @ViewBuilder
    func polishedHover(
        scale: CGFloat = 1.04
    ) -> some View {
        #if os(visionOS)
        self
            .hoverEffect(.lift)
            .hoverEffect { effect, isActive, _ in
                effect.scaleEffect(isActive ? scale : 1.0)
            }
        #else
        self.hoverEffect(.lift)
        #endif
    }
}

// MARK: - Spatial Button Style
struct SpatialButtonStyle<S: Shape>: ButtonStyle {
    let shape: S
    
    init(shape: S) {
        self.shape = shape
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .clipShape(shape)
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Navigation Route
private enum Route: Hashable {
    case details(Recipe)
    case cooking(recipe: Recipe)
    case shoppingList
    case seeAll(title: String, recipes: [Recipe])

    private static func recipeIds(_ recipes: [Recipe]) -> [String] {
        recipes.map(\.id)
    }

    static func == (lhs: Route, rhs: Route) -> Bool {
        switch (lhs, rhs) {
        case (.details(let left), .details(let right)):
            return left.id == right.id
        case (.cooking(let left), .cooking(let right)):
            return left.id == right.id
        case (.shoppingList, .shoppingList):
            return true
        case (.seeAll(let leftTitle, let leftRecipes), .seeAll(let rightTitle, let rightRecipes)):
            return leftTitle == rightTitle && recipeIds(leftRecipes) == recipeIds(rightRecipes)
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .details(let recipe):
            hasher.combine("details")
            hasher.combine(recipe.id)
        case .cooking(let recipe):
            hasher.combine("cooking")
            hasher.combine(recipe.id)
        case .shoppingList:
            hasher.combine("shoppingList")
        case .seeAll(let title, let recipes):
            hasher.combine("seeAll")
            hasher.combine(title)
            hasher.combine(Self.recipeIds(recipes))
        }
    }
}

// MARK: - Cuisine Category Data
struct CuisineCategory: Identifiable {
    let id = UUID()
    let name: String
    let tags: [String]  // Multiple tags to search for
    let titleKeywords: [String]  // Keywords to search in recipe title
    let imageName: String
    let color: Color
    
    // Convenience initializer for single tag (backwards compatible)
    init(name: String, tag: String, imageName: String, color: Color) {
        self.name = name
        self.tags = [tag]
        self.titleKeywords = []
        self.imageName = imageName
        self.color = color
    }
    
    // Full initializer with multiple tags and title keywords
    init(name: String, tags: [String], titleKeywords: [String] = [], imageName: String, color: Color) {
        self.name = name
        self.tags = tags
        self.titleKeywords = titleKeywords
        self.imageName = imageName
        self.color = color
    }
}

// MARK: - Magnetic Snap Behavior (Apple-style smooth)
struct ContentSnapScrollTargetBehavior: ScrollTargetBehavior {
    var heroHeight: CGFloat
    var overlap: CGFloat = 80
    
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        let snapToHero = 0.0
        let snapToContentTop = heroHeight - overlap
        
        let currentY = target.rect.minY
        let velocity = context.velocity.dy
        
        // Magnetic snap with velocity consideration for natural feel
        if currentY < snapToContentTop + 100 {
            // If scrolling up fast, snap to hero
            if velocity < -200 || currentY < heroHeight * 0.25 {
                target.rect.origin.y = snapToHero
            }
            // If scrolling down or past threshold, snap to content
            else if velocity > 100 || currentY > heroHeight * 0.25 {
                target.rect.origin.y = snapToContentTop
            }
        }
    }
}

// MARK: - Ultimate Home View
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @Query(sort: \CookingSession.updatedAt, order: .reverse) private var cookingSessions: [CookingSession]
    @Environment(\.dismissWindow) private var dismissWindow
    @AppStorage(RecipePreferenceKeys.preferredDiets) private var preferredDietsRaw: String = ""
    @AppStorage(RecipePreferenceKeys.excludedAllergens) private var excludedAllergensRaw: String = ""
    
    // State
    @State private var query = ""
    @State private var selectedChip: String? = nil
    @State private var path = NavigationPath()
    @State private var currentHeroIndex: Int = 0
    @State private var featuredDayToken: Int = HomeView.dayToken(for: Date())
    @FocusState private var isSearchFocused: Bool
    
    // Animation States
    @State private var contentOpacity: Double = 0
    @State private var isLoading: Bool = true
    
    // Cached Collections
    @State private var cachedVisibleRecipes: [Recipe] = []
    @State private var cachedFeatured: [Recipe] = []
    @State private var cachedPopular: [Recipe] = []
    @State private var cachedSeasonal: [Recipe] = []
    @State private var cachedCompact: [Recipe] = []
    @State private var dessertsCollection: [Recipe] = []
    @State private var quickRecipes: [Recipe] = []
    @State private var cachedChefsChoice: [Recipe] = []
    @State private var cachedWorldFlavors: [Recipe] = []
    @State private var cachedComfortFood: [Recipe] = []
    @State private var cachedPreferencesToken: String = ""
    
    // Optimized Search Results
    @State private var filteredResults: [Recipe] = []
    @State private var searchTask: Task<Void, Never>? = nil
    
    // Search suggestion chips
    private let searchSuggestions = ["Italian", "Asian", "Desserts", "Healthy", "Quick", "Vegetarian", "Mexican"]
    
    // Categories Definition - with multiple tags and title keywords for better matching
    private let cuisineCategories: [CuisineCategory] = [
        CuisineCategory(name: "Italian", tags: ["Italian", "Pasta", "Pizza"], titleKeywords: ["Italian", "Pasta", "Pizza", "Risotto", "Carbonara", "Bolognese", "Tiramisu", "Bruschetta"], imageName: "ItalianCategory", color: Color(red: 0.2, green: 0.6, blue: 0.4)),
        CuisineCategory(name: "Asian", tags: ["Asian", "Wok", "Stir-Fry"], titleKeywords: ["Asian", "Thai", "Chinese", "Japanese", "Korean", "Pad Thai", "Stir-Fry", "Wok"], imageName: "AsianCategory", color: Color(red: 0.8, green: 0.3, blue: 0.3)),
        CuisineCategory(name: "Mexican", tags: ["Mexican"], titleKeywords: ["Mexican", "Taco", "Burrito", "Enchilada", "Quesadilla", "Salsa", "Guacamole", "Tortilla"], imageName: "MexicanCategory", color: Color(red: 0.9, green: 0.5, blue: 0.2)),
        CuisineCategory(name: "Healthy", tags: ["Healthy", "Salad", "Vegetarian", "Vegan"], titleKeywords: ["Healthy", "Salad", "Quinoa", "Vegetable", "Fresh"], imageName: "HealthyCategory", color: Color(red: 0.3, green: 0.7, blue: 0.5)),
        CuisineCategory(name: "Desserts", tags: ["Dessert", "Baking", "Chocolate", "Cake", "Pastry", "Cookie", "Sweet"], titleKeywords: ["Dessert", "Cake", "Chocolate", "Cookie", "Mousse", "Tart", "Cheesecake", "Crumble", "Tiramisu", "Crème", "Macarons"], imageName: "DessertsCategory", color: .pink)
    ]

    private var selectedDiets: Set<DietaryPreference> {
        preferredDietsRaw.rawValueSet(for: DietaryPreference.self)
    }

    private var excludedAllergens: Set<RecipeAllergen> {
        excludedAllergensRaw.rawValueSet(for: RecipeAllergen.self)
    }

    private var visibleRecipes: [Recipe] { cachedVisibleRecipes }
    
    var body: some View {
        NavigationStack(path: $path) {
            GeometryReader { screenGeometry in
                ZStack(alignment: .top) {
                    // MARK: - Loading State
                    if isLoading {
                        loadingView
                    }
                    
                    // MARK: - Main ScrollView
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            
                            // 1. Search Results Overlay
                            if !query.isEmpty || selectedChip != nil {
                                searchResultsSection
                                    .padding(.top, 160)
                                    .padding(.horizontal, SpatialDesign.horizontalPadding)
                            }
                            // 2. Main Browsing Content
                            else {
                                // IMMERSIVE HERO
                                immersiveHeroSection(screenGeometry: screenGeometry)
                                    .zIndex(0)
                                
                                // SPATIAL SECTIONS CONTAINER
                                LazyVStack(alignment: .leading, spacing: SpatialDesign.sectionSpacing) {
                                    // 0. Continue Cooking (if active session exists)
                                    continueCookingSection
                                    
                                    // A. Categories
                                    modernCategorySection
                                    
                                    // B. Featured (Cinema)
                                    if cachedFeatured.count > 5 {
                                        cinemaFeaturedSection
                                    }
                                    
                                    // C. Popular
                                    if !cachedPopular.isEmpty {
                                        spatialRecipeGrid
                                    }
                                    
                                    // D. Seasonal
                                    if !cachedSeasonal.isEmpty {
                                        seasonalShowcaseSection
                                    }
                                    
                                    // E. Premium Discovery Section
                                    if !cachedCompact.isEmpty {
                                        premiumDiscoverySection
                                    }
                                    
                                    // F. Chef's Choice - Top Rated
                                    if visibleRecipes.count > 8 {
                                        chefsChoiceSection
                                    }
                                    
                                    // G. Quick & Easy Section
                                    if !quickRecipes.isEmpty {
                                        quickAndEasySection
                                    }
                                    
                                    // H. World Flavors Showcase
                                    if visibleRecipes.count > 5 {
                                        worldFlavorsSection
                                    }
                                    
                                    // I. Desserts & Sweets
                                    if !dessertsCollection.isEmpty {
                                        dessertsSection
                                    }
                                    
                                    // J. Comfort Food Section
                                    if visibleRecipes.count > 6 {
                                        comfortFoodSection
                                    }
                                    
                                    // K. New & Trending Section
                                    if visibleRecipes.count > 4 {
                                        newAndTrendingSection
                                    }
                                    
                                    // Bottom spacing
                                    Spacer().frame(height: 40)
                                }
                                .zIndex(1)
                                .padding(.top, -80)
                            }
                        }
                    }
                    .scrollTargetBehavior(ContentSnapScrollTargetBehavior(
                        heroHeight: screenGeometry.size.height
                    ))
                    .scrollBounceBehavior(.basedOnSize)
                    .opacity(contentOpacity)
                    .coordinateSpace(name: "scroll")
                    .ignoresSafeArea()
                }
            }
            // MARK: - Gesture to dismiss search suggestions
            .contentShape(Rectangle())
            .onTapGesture {
                if isSearchFocused {
                    isSearchFocused = false
                }
            }
            // MARK: - Navigation Destinations
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .details(let recipe):
                    RecipeDetailsView(
                        recipe: recipe,
                        onStartCooking: { path.append(Route.cooking(recipe: recipe)) },
                        onAddAllToList: { addIngredientsToShoppingList(recipe: recipe) }
                    )
                case .cooking(let recipe):
                    CookingView(recipe: recipe)
                case .shoppingList:
                    Text("Shopping List")
                case .seeAll(let title, let recipes):
                    ProSeeAllView(title: title, recipes: recipes, path: $path)
                }
            }

            // MARK: - Data Loading
            .task(id: "\(recipes.count)|\(preferredDietsRaw)|\(excludedAllergensRaw)") {
                await updateCollections()
            }
            .task {
                if contentOpacity == 0 {
                    withAnimation(.easeOut(duration: 0.6)) {
                        contentOpacity = 1
                    }
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 3_600_000_000_000) // 1 hour
                    await updateCollections()
                }
            }
            .onChange(of: query) { _, _ in performSearch() }
            .onChange(of: selectedChip) { _, _ in performSearch() }
            .onChange(of: preferredDietsRaw) { _, _ in performSearch() }
            .onChange(of: excludedAllergensRaw) { _, _ in performSearch() }
            .onReceive(NotificationCenter.default.publisher(for: .returnToHome)) { _ in
                // Reset navigation to root when returning from CongratulationsView
                path = NavigationPath()
            }
        }
    }
    
    // MARK: - 1. IMMERSIVE HERO (Enhanced with smooth animations)
    @ViewBuilder
    private func immersiveHeroSection(screenGeometry: GeometryProxy) -> some View {
        let heroHeight = screenGeometry.size.height
        
        GeometryReader { proxy in
            let minY = proxy.frame(in: .named("scroll")).minY
            let progress = minY < 0 ? min(-minY / 400, 1) : 0
            let parallaxOffset = minY < 0 ? -minY / 3 : -minY * 0.15
            let fadeProgress = max(0, min(1, progress * 1.3))
            
            ZStack(alignment: .bottom) {
                if !cachedFeatured.isEmpty {
                    TabView(selection: $currentHeroIndex) {
                        ForEach(Array(cachedFeatured.prefix(5).enumerated()), id: \.offset) { index, recipe in
                            
                            ZStack {
                                RecipeImageView(recipe: recipe, targetHeight: heroHeight)
                                
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .clear,
                                        .black.opacity(0.1),
                                        .black.opacity(0.6),
                                        .black.opacity(0.9)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                
                                VStack {
                                    Spacer()
                                    ImmersiveHeroContent(recipe: recipe) {
                                        path.append(Route.details(recipe))
                                    }
                                    .padding(.bottom, 240)
                                }
                                .opacity(1.0 - (fadeProgress * 1.2))
                            }
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.snappy(duration: 0.4), value: currentHeroIndex)
                    .opacity(1.0 - fadeProgress)
                }
                
                VStack {
                    Spacer()
                    SpatialPageIndicator(numberOfPages: min(5, cachedFeatured.count), currentIndex: $currentHeroIndex)
                        .padding(.bottom, 140)
                        .opacity(1.0 - (fadeProgress * 1.5))
                }
            }
            .frame(width: proxy.size.width, height: heroHeight + (minY > 0 ? minY : 0))
            .offset(y: parallaxOffset)
        }
        .frame(height: heroHeight)
    }
    
    // MARK: - 2. MODERN CATEGORY SECTION (No icons on images)
    private var modernCategorySection: some View {
        VStack(alignment: .leading, spacing: 28) {
            sectionHeader(
                title: "Cuisines of the World",
                subtitle: "Discover flavors from every corner",
                icon: "globe.americas.fill",
                seeAllAction: { path.append(Route.seeAll(title: "All Cuisines", recipes: visibleRecipes)) }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 28) {
                    ForEach(cuisineCategories) { category in
                        ModernCategoryCard(category: category) {
                            var filtered = visibleRecipes.filter { recipe in
                                let tagMatch = recipe.tags.contains { recipeTag in
                                    category.tags.contains { categoryTag in
                                        recipeTag.localizedCaseInsensitiveContains(categoryTag)
                                    }
                                }
                                let titleMatch = category.titleKeywords.contains { keyword in
                                    recipe.title.localizedCaseInsensitiveContains(keyword)
                                }
                                return tagMatch || titleMatch
                            }
                            
                            // Exclude pizzas from non-Italian categories
                            if category.name != "Italian" {
                                filtered = filtered.filter { recipe in
                                    let isPizza = recipe.title.localizedCaseInsensitiveContains("pizza") ||
                                        recipe.tags.contains { $0.localizedCaseInsensitiveContains("pizza") }
                                    return !isPizza
                                }
                            }
                            
                            path.append(Route.seeAll(title: category.name, recipes: filtered))
                        }
                    }
                }
                .padding(.horizontal, SpatialDesign.horizontalPadding)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }
    
    // MARK: - 3. CINEMA FEATURED
    private var cinemaFeaturedSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Featured Recipes",
                subtitle: "Handpicked for you",
                icon: "star.fill",
                seeAllAction: {
                    path.append(Route.seeAll(title: "Featured Recipes", recipes: Array(cachedFeatured.dropFirst(5))))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: SpatialDesign.cardSpacing) {
                    ForEach(Array(cachedFeatured.dropFirst(5).prefix(4)), id: \.id) { recipe in
                        CinemaFeaturedCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 380)
                .padding(.vertical, 24)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 4. POPULAR GRID
    private var spatialRecipeGrid: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Popular Right Now",
                subtitle: "What everyone is cooking",
                icon: "flame.fill",
                seeAllAction: {
                    path.append(Route.seeAll(title: "Popular Right Now", recipes: cachedPopular))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: SpatialDesign.cardSpacing) {
                    ForEach(cachedPopular.prefix(6), id: \.id) { recipe in
                        SpatialRecipeCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 340)
                .padding(.vertical, 24)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 5. SEASONAL
    private var seasonalShowcaseSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Seasonal Favorites",
                subtitle: "Perfect for this time of year",
                icon: "leaf.fill",
                seeAllAction: {
                    path.append(Route.seeAll(title: "Seasonal Favorites", recipes: cachedSeasonal))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: SpatialDesign.cardSpacing) {
                    ForEach(cachedSeasonal.prefix(3), id: \.id) { recipe in
                        SeasonalShowcaseCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 300)
                .padding(.vertical, 24)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 6. PREMIUM DISCOVERY SECTION (Enhanced Apple Vision Pro Style)
    private var premiumDiscoverySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "More to Explore",
                subtitle: "Curated collections just for you",
                icon: "sparkles",
                seeAllAction: {
                    path.append(Route.seeAll(title: "More to Explore", recipes: cachedCompact))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(cachedCompact, id: \.id) { recipe in
                        PremiumDiscoveryCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 420)
                .padding(.vertical, 20)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - CONTINUE COOKING SECTION
    private var activeCookingSession: (session: CookingSession, recipe: Recipe)? {
        // Find the most recent session and its corresponding recipe
        for session in cookingSessions {
            if let recipe = visibleRecipes.first(where: { $0.id == session.recipeId }) {
                // Validate the session is still valid
                let totalSteps = recipe.steps.count
                if totalSteps > 0 && session.stepIndex < totalSteps {
                    return (session, recipe)
                }
            }
        }
        return nil
    }
    
    @ViewBuilder
    private var continueCookingSection: some View {
        if let active = activeCookingSession {
            VStack(alignment: .leading, spacing: 24) {
                // Section header
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.orange.opacity(0.3), .orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.orange)
                            .symbolEffect(.pulse, options: .repeating)
                    }
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.orange.opacity(0.5), .orange.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    )
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Continue Where You Left Off")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text("Pick up right where you stopped")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, SpatialDesign.horizontalPadding)
                
                // Card
                ContinueCookingCard(
                    recipe: active.recipe,
                    session: active.session,
                    onContinue: {
                        path.append(Route.cooking(recipe: active.recipe))
                    },
                    onDismiss: {
                        // Delete the session
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            context.delete(active.session)
                            try? context.save()
                        }
                    }
                )
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .scale(scale: 0.95).combined(with: .opacity)
            ))
        }
    }
    
    // MARK: - 7. CHEF'S CHOICE SECTION
    private var chefsChoiceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Chef's Choice",
                subtitle: "Top rated by our community",
                icon: "crown.fill",
                seeAllAction: {
                    let topRated = visibleRecipes.sorted { $0.rating > $1.rating }
                    path.append(Route.seeAll(title: "Chef's Choice", recipes: topRated))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(cachedChefsChoice.prefix(8), id: \.id) { recipe in
                        ChefsChoiceCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 320)
                .padding(.vertical, 20)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 8. QUICK & EASY SECTION
    private var quickAndEasySection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Quick & Easy",
                subtitle: "Ready in 30 minutes or less",
                icon: "bolt.fill",
                seeAllAction: {
                    path.append(Route.seeAll(title: "Quick & Easy", recipes: quickRecipes))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 18) {
                    ForEach(quickRecipes.prefix(10), id: \.id) { recipe in
                        QuickRecipeCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 240)
                .padding(.vertical, 16)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 9. WORLD FLAVORS SECTION
    private var worldFlavorsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "World Flavors",
                subtitle: "Taste the globe from your kitchen",
                icon: "globe",
                seeAllAction: {
                    path.append(Route.seeAll(title: "World Flavors", recipes: visibleRecipes))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 24) {
                    ForEach(cachedWorldFlavors.prefix(6), id: \.id) { recipe in
                        WorldFlavorCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 360)
                .padding(.vertical, 20)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 10. DESSERTS SECTION
    private var dessertsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Sweet Treats",
                subtitle: "Indulge your sweet tooth",
                icon: "birthday.cake.fill",
                seeAllAction: {
                    path.append(Route.seeAll(title: "Sweet Treats", recipes: dessertsCollection))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(dessertsCollection.prefix(8), id: \.id) { recipe in
                        DessertCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 300)
                .padding(.vertical, 20)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 11. COMFORT FOOD SECTION
    private var comfortFoodSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "Comfort Classics",
                subtitle: "Warm and hearty favorites",
                icon: "heart.fill",
                seeAllAction: {
                    path.append(Route.seeAll(title: "Comfort Classics", recipes: visibleRecipes))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(cachedComfortFood.prefix(8), id: \.id) { recipe in
                        ComfortFoodCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 280)
                .padding(.vertical, 16)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - 12. NEW & TRENDING SECTION
    private var newAndTrendingSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            sectionHeader(
                title: "New & Trending",
                subtitle: "Fresh recipes for you",
                icon: "arrow.up.right.circle.fill",
                seeAllAction: {
                    path.append(Route.seeAll(title: "New & Trending", recipes: visibleRecipes))
                }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 22) {
                    ForEach(visibleRecipes.reversed().prefix(10), id: \.id) { recipe in
                        TrendingCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .frame(height: 320)
                .padding(.vertical, 18)
                .padding(.horizontal, SpatialDesign.horizontalPadding)
            }
        }
    }
    
    // MARK: - Section Header
    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String, icon: String, seeAllAction: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 0) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                    .fill(.white.opacity(0.1))
                    .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            
            Spacer()
            
            Button(action: seeAllAction) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(SpatialButtonStyle(shape: Circle()))
            .polishedHover(scale: 1.08)
        }
        .padding(.horizontal, SpatialDesign.horizontalPadding)
    }
    
    // MARK: - Search Section (with back button)
    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 36) {
            HStack {
                CircularBackButton { query = ""; selectedChip = nil }
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 14) {
                Text(selectedChip.map { "Results for \($0)" } ?? "Results for \"\(query)\"")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text("\(filteredResults.count) delicious recipes found")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
            }
            
            if filteredResults.isEmpty {
                ContentUnavailableView {
                    Label("No Recipes Found", systemImage: "magnifyingglass")
                } description: {
                    Text("Try different keywords or filters")
                }
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 28)],
                    spacing: 28
                ) {
                    ForEach(filteredResults, id: \.id) { recipe in
                        SpatialRecipeCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
            }
        }
    }
    
    
    // MARK: - Helpers
    private func performSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor in
            // Reduced debounce for snappier feel
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            
            let searchQuery = query.lowercased()
            var list = visibleRecipes
            
            if !searchQuery.isEmpty {
                list = list.filter {
                    $0.title.lowercased().contains(searchQuery) ||
                    $0.tags.contains { $0.lowercased().contains(searchQuery) }
                }
            }
            
            if let chip = selectedChip {
                let chipLower = chip.lowercased()
                switch chip {
                case "Quick": list = list.filter { $0.totalTimeMinutes <= 25 }
                case "≤20 min": list = list.filter { $0.totalTimeMinutes <= 20 }
                case "Low Cal": list = list.filter { $0.calories < 400 }
                default: list = list.filter { 
                    $0.tags.contains { $0.lowercased().contains(chipLower) } ||
                    $0.title.lowercased().contains(chipLower)
                }
                }
            }
            
            filteredResults = list.sorted { $0.rating > $1.rating }
        }
    }
    
    @MainActor
    private func updateCollections() async {
        // Rebuild cached visible recipes from source
        cachedVisibleRecipes = RecipePreferenceFilter.filter(recipes, diets: selectedDiets, allergens: excludedAllergens)
        
        let todayToken = Self.dayToken(for: Date())
        let maxFeaturedCount = min(12, cachedVisibleRecipes.count)
        let currentPreferencesToken = "\(preferredDietsRaw)|\(excludedAllergensRaw)"

        // Skip if already populated, count hasn't changed, and preferences are the same
        guard cachedFeatured.isEmpty || cachedFeatured.count != maxFeaturedCount || featuredDayToken != todayToken || cachedPreferencesToken != currentPreferencesToken else {
            if isLoading {
                withAnimation(.easeOut(duration: 0.2)) {
                    isLoading = false
                }
            }
            return
        }
        
        cachedPreferencesToken = currentPreferencesToken
        
        // Sort once and reuse
        let all = cachedVisibleRecipes.sorted { $0.rating > $1.rating }
        
        // Rotate featured recipes daily so the hero changes every 24 hours.
        featuredDayToken = todayToken
        cachedFeatured = Self.dailyRotatedSelection(from: all, count: maxFeaturedCount, dayToken: todayToken)
        currentHeroIndex = min(currentHeroIndex, max(0, cachedFeatured.count - 1))
        cachedPopular = Array(all.dropFirst(12).prefix(20))
        cachedChefsChoice = Array(all.prefix(8))
        
        // Deterministic selection for variety sections (no shuffling!)
        let compactStart = min(all.count, 32)
        cachedCompact = Array(all.suffix(from: compactStart).prefix(12))
        
        // Stride-based selection for variety without expensive shuffling
        if all.count > 5 {
            cachedWorldFlavors = stride(from: 0, to: min(all.count, 30), by: 5).prefix(6).map { all[$0] }
            cachedComfortFood = stride(from: 2, to: min(all.count, 34), by: 4).prefix(8).map { all[$0] }
        }
        
        // Filtering - slightly heavier but still fast
        cachedSeasonal = all.filter { $0.tags.contains { $0.localizedCaseInsensitiveContains("comfort") } }
        quickRecipes = all.filter { $0.totalTimeMinutes <= 30 }
        
        dessertsCollection = all.filter { recipe in
            recipe.tags.contains { tag in
                tag.localizedCaseInsensitiveContains("dessert") ||
                tag.localizedCaseInsensitiveContains("cake") ||
                tag.localizedCaseInsensitiveContains("chocolate") ||
                tag.localizedCaseInsensitiveContains("sweet")
            } ||
            recipe.title.localizedCaseInsensitiveContains("cake") ||
            recipe.title.localizedCaseInsensitiveContains("chocolate") ||
            recipe.title.localizedCaseInsensitiveContains("mousse") ||
            recipe.title.localizedCaseInsensitiveContains("tiramisu")
        }
        
        // Mark loading complete
        if !all.isEmpty && isLoading {
            withAnimation(.easeOut(duration: 0.2)) {
                isLoading = false
            }
        }
    }

    private static func dayToken(for date: Date) -> Int {
        let secondsPerDay: TimeInterval = 86_400
        return Int(date.timeIntervalSinceReferenceDate / secondsPerDay)
    }

    private static func dailyRotatedSelection(from recipes: [Recipe], count: Int, dayToken: Int) -> [Recipe] {
        guard !recipes.isEmpty, count > 0 else { return [] }

        let selectionCount = min(count, recipes.count)
        let startIndex = dayToken % recipes.count

        return (0..<selectionCount).map { offset in
            recipes[(startIndex + offset) % recipes.count]
        }
    }
    
    private func addIngredientsToShoppingList(recipe: Recipe) {
        guard let ctx = recipe.modelContext else { return }
        for ing in recipe.ingredients {
            let qty = [ing.quantity.map { String($0) }, ing.unit].compactMap { $0 }.joined(separator: " ")
            ctx.insert(ShoppingItem(name: ing.name, qty: qty.isEmpty ? nil : qty))
        }
        try? ctx.save()
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        PremiumLoadingView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
    }
}

// MARK: - Unified Circular Back Button
struct CircularBackButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(SpatialButtonStyle(shape: Circle()))
        .polishedHover(scale: 1.08)
        .accessibilityLabel("Back")
    }
}

// MARK: - CARD COMPONENTS

// 1. Modern Category Card (Clean - no count)
struct ModernCategoryCard: View {
    let category: CuisineCategory
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Image(category.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 260, height: 260)
                    .clipped()
                
                LinearGradient(
                    colors: [.black.opacity(0.8), .black.opacity(0.4), .clear],
                    startPoint: .bottom,
                    endPoint: .center
                )
                
                Text(category.name)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(28)
            }
            .frame(width: 260, height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(SpatialDesign.spatialStroke(radius: 34, intensity: 0.9))
        }
        .buttonStyle(SpatialButtonStyle(shape: RoundedRectangle(cornerRadius: 34)))
        .polishedHover(scale: 1.06)
    }
}

// 2. Cinema Featured Card
struct CinemaFeaturedCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: SpatialDesign.extraLargeRadius)
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RecipeImageView(recipe: recipe, targetHeight: 360)
                    .frame(width: 580, height: 360)
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                
                HStack(alignment: .bottom, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(recipe.title)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                        
                        HStack(spacing: 16) {
                            Label(recipe.formattedTotalTime, systemImage: "clock.fill")
                            Label("\(recipe.calories) kcal", systemImage: "flame.fill")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 10)
                }
                .padding(36)
            }
            .frame(width: 580, height: 360)
            .overlay(SpatialDesign.spatialStroke(radius: SpatialDesign.extraLargeRadius))
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.04)
    }
}

// MARK: - Continue Cooking Card (Premium Design)
struct ContinueCookingCard: View {
    let recipe: Recipe
    let session: CookingSession
    let onContinue: () -> Void
    let onDismiss: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
    
    private var steps: [Step] { recipe.steps.sorted { $0.order < $1.order } }
    private var totalSteps: Int { steps.count }
    private var currentStep: Int { min(session.stepIndex + 1, totalSteps) }
    private var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(session.stepIndex) / Double(totalSteps)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main tappable card
            Button(action: onContinue) {
                HStack(spacing: 0) {
                    // Left: Recipe Image with Progress Overlay
                    ZStack {
                        RecipeImageView(recipe: recipe, targetHeight: 220)
                            .frame(width: 200, height: 220)
                            .clipped()
                            .id("continue-cooking-\(recipe.id)-\(recipe.localImageName ?? "")")
                        
                        // Dark overlay for better text visibility
                        LinearGradient(
                            colors: [
                                .black.opacity(0.1),
                                .black.opacity(0.5)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        
                        // Circular Progress Ring
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ZStack {
                                    // Background ring
                                    Circle()
                                        .stroke(.white.opacity(0.3), lineWidth: 4)
                                        .frame(width: 52, height: 52)
                                    
                                    // Progress ring
                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.orange, .orange.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                        )
                                        .frame(width: 52, height: 52)
                                        .rotationEffect(.degrees(-90))
                                    
                                    // Step counter
                                    Text("\(currentStep)")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                                .padding(12)
                            }
                        }
                    }
                    .frame(width: 200)
                    
                    // Right: Content
                    VStack(alignment: .leading, spacing: 16) {
                        // Header - badge only (dismiss button moved to overlay)
                        HStack {
                            // Continue badge
                            HStack(spacing: 6) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Continue Cooking")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.orange.opacity(0.2))
                            .clipShape(Capsule())
                            
                            Spacer()
                        }
                        
                        // Recipe Title
                        Text(recipe.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Progress Info
                        VStack(alignment: .leading, spacing: 8) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    // Background
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(.tertiary.opacity(0.3))
                                        .frame(height: 6)
                                    
                                    // Progress
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.orange, .orange.opacity(0.7)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * progress, height: 6)
                                }
                            }
                            .frame(height: 6)
                            
                            // Step indicator text
                            HStack {
                                Text("Step \(currentStep) of \(totalSteps)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)
                                
                                Spacer()
                                
                                Text("\(Int(progress * 100))%")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        Spacer()
                        
                        // Continue button
                        HStack {
                            Spacer()
                            HStack(spacing: 8) {
                                Text("Resume")
                                    .font(.system(size: 16, weight: .semibold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.85)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: .orange.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
                .background(.regularMaterial)
                .clipShape(shape)
                .overlay(
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [.orange.opacity(0.5), .white.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                )
                .shadow(color: .orange.opacity(0.15), radius: 20, x: 0, y: 10)
            }
            .buttonStyle(SpatialButtonStyle(shape: shape))
            .polishedHover(scale: 1.02)
            
            // Dismiss button - OUTSIDE the main button so it can receive taps
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .hoverEffect(.lift)
            .padding(16)
        }
    }
}

// MARK: - Premium Loading View
struct PremiumLoadingView: View {
    @State private var rotation: Double = 0
    @State private var arcProgress: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    
    // Elegant warm amber - single cohesive color
    private let accentColor = Color(red: 0.92, green: 0.55, blue: 0.22)
    
    var body: some View {
        VStack(spacing: 36) {
            ZStack {
                // Subtle outer glow
                Circle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                    .scaleEffect(pulseScale)
                
                // Track ring (subtle background)
                Circle()
                    .stroke(
                        Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                
                // Animated progress arc
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor.opacity(0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotation - 90))
                
                // Center container
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                
                // Logo
                Image("UmamiLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .opacity(logoOpacity)
                    .scaleEffect(logoOpacity)
            }
            
            // Text section
            VStack(spacing: 8) {
                Text("Umami")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .opacity(textOpacity)
                
                Text("Loading recipes")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.white.opacity(0.5))
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Smooth continuous rotation
        withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Subtle pulse
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.15
        }
        
        // Logo fade in
        withAnimation(.easeOut(duration: 0.6).delay(0.2)) {
            logoOpacity = 1.0
        }
        
        // Text fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            textOpacity = 1.0
        }
    }
}

#Preview {
    PremiumLoadingView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.1))
}

// 3. Spatial Recipe Card
struct SpatialRecipeCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: SpatialDesign.mediumRadius)
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                RecipeImageView(recipe: recipe, targetHeight: 200)
                    .frame(width: 280, height: 200)
                    .clipped()
                
                VStack(spacing: 12) {
                    Text(recipe.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack {
                        Label(recipe.formattedTotalTime, systemImage: "clock")
                        Spacer()
                        Label("\(recipe.calories)", systemImage: "flame")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .frame(width: 280, height: 120, alignment: .top)
                .background(.regularMaterial)
            }
            .overlay(SpatialDesign.spatialStroke(radius: SpatialDesign.mediumRadius))
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.05)
    }
}

// 4. Seasonal Showcase Card
struct SeasonalShowcaseCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: SpatialDesign.largeRadius)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                RecipeImageView(recipe: recipe, targetHeight: 280)
                    .frame(width: 240, height: 280)
                
                VStack(alignment: .leading, spacing: 14) {
                    Text("SEASONAL")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.green.opacity(0.2))
                        .clipShape(Capsule())
                    
                    Text(recipe.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                    
                    Spacer()
                    
                    HStack {
                        Text("Cook Now")
                            .font(.system(size: 16, weight: .bold))
                        Image(systemName: "arrow.right")
                    }
                    .foregroundStyle(.white)
                }
                .padding(24)
                .frame(width: 260, height: 280, alignment: .leading)
                .background(.regularMaterial)
            }
            .overlay(SpatialDesign.spatialStroke(radius: SpatialDesign.largeRadius))
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.04)
    }
}

// 5. PREMIUM DISCOVERY CARD (Apple Vision Pro Cinematic Design)
struct PremiumDiscoveryCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 36, style: .continuous)
    private let cardWidth: CGFloat = 260
    private let cardHeight: CGFloat = 380
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Full-bleed cinematic image
                RecipeImageView(recipe: recipe, targetHeight: cardHeight)
                    .frame(width: cardWidth, height: cardHeight)
                    .clipped()
                
                // Subtle vignette gradient
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.0),
                        .init(color: .clear, location: 0.5),
                        .init(color: .black.opacity(0.6), location: 0.8),
                        .init(color: .black.opacity(0.9), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content overlay
                VStack {
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Title
                        Text(recipe.title)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Minimal metadata
                        HStack(spacing: 16) {
                            HStack(spacing: 5) {
                                Image(systemName: "clock")
                                    .font(.system(size: 13, weight: .medium))
                                Text(recipe.formattedTotalTime)
                                    .font(.system(size: 14, weight: .medium))
                            }
                            
                            HStack(spacing: 5) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", recipe.rating))
                                    .font(.system(size: 14, weight: .medium))
                            }
                        }
                        .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .clipShape(shape)
            .overlay(
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.05)
    }
}

// MARK: - Hero Content (with hover on Start Cooking button)
struct ImmersiveHeroContent: View {
    let recipe: Recipe
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("TRENDING NOW")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.9))
            
            Text(recipe.title)
                .font(.system(size: 60, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                .lineLimit(2)
                .frame(maxWidth: 700, alignment: .leading)
            
            Button(action: action) {
                Text("Start Cooking")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
            .buttonStyle(SpatialButtonStyle(shape: Capsule()))
            .polishedHover(scale: 1.08)
        }
        .padding(.leading, SpatialDesign.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Page Indicator
struct SpatialPageIndicator: View {
    let numberOfPages: Int
    @Binding var currentIndex: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { index in
                Circle()
                    .fill(currentIndex == index ? .white : .white.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeOut(duration: 0.2), value: currentIndex)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - PRO SEE ALL VIEW (Single back button)
struct ProSeeAllView: View {
    let title: String
    let recipes: [Recipe]
    @Binding var path: NavigationPath
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 32) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("\(recipes.count) \(recipes.count == 1 ? "recipe" : "recipes")")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 60)
                .padding(.top, 20)
                
                // Grid
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 260, maximum: 320), spacing: 20)],
                    spacing: 20
                ) {
                    ForEach(recipes, id: \.id) { recipe in
                        SpatialRecipeCard(recipe: recipe) {
                            path.append(Route.details(recipe))
                        }
                    }
                }
                .padding(.horizontal, 60)
            }
            .padding(.bottom, 60)
        }
        .background(.ultraThinMaterial)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CircularBackButton { dismiss() }
            }
        }
    }
}

// MARK: - Image Loader
final class DiskImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var name: String?
    private let targetPixelSize: CGSize?
    private static let cache = NSCache<NSString, UIImage>()
    
    init(name: String?, targetPixelSize: CGSize? = nil) {
        self.name = name
        self.targetPixelSize = targetPixelSize
        Self.cache.totalCostLimit = 200 * 1024 * 1024
        load()
    }

    func updateImage(name: String?) {
        guard self.name != name else { return }
        self.name = name
        self.image = nil
        load()
    }
    
    private func load() {
        guard let name else { return }
        let key = NSString(string: "\(name)_\(Int(targetPixelSize?.width ?? 0))")
        
        if let cached = Self.cache.object(forKey: key) {
            self.image = cached
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var loadedImage: UIImage?
            
            // 1. נסה לטעון מ-Documents (תמונות שהורדו מהענן)
            let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            if let dirPath = urls.first {
                let imageURL = dirPath.appendingPathComponent("\(name).jpg")
                if FileManager.default.fileExists(atPath: imageURL.path) {
                    if let target = self.targetPixelSize {
                        loadedImage = self.downsample(imageAt: imageURL, to: target, scale: 2.0)
                    } else {
                        loadedImage = UIImage(contentsOfFile: imageURL.path)
                    }
                }
            }
            
            // 2. Fallback: Load from Assets (built-in images)
            if loadedImage == nil {
                // UIImage(named:) is thread-safe for reading from asset catalogs
                loadedImage = UIImage(named: name)
            }
            
            if let img = loadedImage {
                Self.cache.setObject(img, forKey: key)
                DispatchQueue.main.async {
                    // Direct assignment without animation for smoother scrolling
                    self.image = img
                }
            }
        }
    }
    
    private func downsample(imageAt url: URL, to pointSize: CGSize, scale: CGFloat) -> UIImage? {
        let maxDimension = max(pointSize.width, pointSize.height) * scale
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]
        
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

struct RecipeImageView: View {
    let recipe: Recipe
    let targetHeight: CGFloat?
    
    init(recipe: Recipe, targetHeight: CGFloat? = nil) {
        self.recipe = recipe
        self.targetHeight = targetHeight
    }
    
    var body: some View {
        RecipeImageViewInternal(
            imageName: recipe.localImageName,
            recipeId: recipe.id,
            targetHeight: targetHeight
        )
    }
}

// Internal view that properly handles StateObject lifecycle
private struct RecipeImageViewInternal: View {
    let imageName: String?
    let recipeId: String
    let targetHeight: CGFloat?
    @StateObject private var loader: DiskImageLoader
    
    init(imageName: String?, recipeId: String, targetHeight: CGFloat?) {
        self.imageName = imageName
        self.recipeId = recipeId
        self.targetHeight = targetHeight
        let size = targetHeight.map { CGSize(width: $0, height: $0) }
        _loader = StateObject(wrappedValue: DiskImageLoader(name: imageName, targetPixelSize: size))
    }
    
    var body: some View {
        Group {
            if let img = loader.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .onChange(of: imageName) { _, newName in
            loader.updateImage(name: newName)
        }
    }
}

// MARK: - Chef's Choice Card
struct ChefsChoiceCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RecipeImageView(recipe: recipe, targetHeight: 300)
                    .frame(width: 240, height: 300)
                    .clipped()
                
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 10) {
                    // Rating badge
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", recipe.rating))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    Text(recipe.title)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label(recipe.formattedTotalTime, systemImage: "clock")
                        Label("\(recipe.calories)", systemImage: "flame")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(20)
            }
            .frame(width: 240, height: 300)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.05)
    }
}
// MARK: - Quick Recipe Card
struct QuickRecipeCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                RecipeImageView(recipe: recipe, targetHeight: 180)
                    .frame(width: 140, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                VStack(alignment: .leading, spacing: 12) {
                    // Time badge
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.yellow)
                        Text(recipe.formattedTotalTime)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.yellow.opacity(0.2))
                    .clipShape(Capsule())
                    
                    Text(recipe.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", recipe.rating))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding(.vertical, 16)
                .padding(.trailing, 16)
            }
            .frame(width: 320, height: 200)
            .background(.regularMaterial)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.04)
    }
}

// MARK: - World Flavor Card
struct WorldFlavorCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RecipeImageView(recipe: recipe, targetHeight: 340)
                    .frame(width: 300, height: 340)
                    .clipped()
                
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.4),
                        .init(color: .black.opacity(0.9), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(spacing: 14) {
                    // Tags
                    if let firstTag = recipe.tags.first {
                        Text(firstTag.uppercased())
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.2))
                            .clipShape(Capsule())
                    }
                    
                    Text(recipe.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    HStack(spacing: 20) {
                        HStack(spacing: 5) {
                            Image(systemName: "clock")
                            Text(recipe.formattedTotalTime)
                        }
                        HStack(spacing: 5) {
                            Image(systemName: "flame")
                            Text("\(recipe.calories) kcal")
                        }
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .padding(28)
            }
            .frame(width: 300, height: 340)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.4), .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.05)
    }
}

// MARK: - Dessert Card
struct DessertCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RecipeImageView(recipe: recipe, targetHeight: 260)
                    .frame(width: 220, height: 260)
                    .clipped()
                
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    // Sweet badge
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text("Sweet")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.pink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.pink.opacity(0.25))
                    .clipShape(Capsule())
                    
                    Text(recipe.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 10) {
                        Label(recipe.formattedTotalTime, systemImage: "clock")
                        Label("\(recipe.calories)", systemImage: "flame")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
            }
            .frame(width: 220, height: 260)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.pink.opacity(0.5), .white.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.05)
    }
}

// MARK: - Comfort Food Card
struct ComfortFoodCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RecipeImageView(recipe: recipe, targetHeight: 240)
                    .frame(width: 260, height: 240)
                    .clipped()
                
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: .black.opacity(0.8), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(recipe.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label(recipe.formattedTotalTime, systemImage: "clock")
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text(String(format: "%.1f", recipe.rating))
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
            }
            .frame(width: 260, height: 240)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.04)
    }
}

// MARK: - Trending Card
struct TrendingCard: View {
    let recipe: Recipe
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                RecipeImageView(recipe: recipe, targetHeight: 300)
                    .frame(width: 240, height: 300)
                    .clipped()
                
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.35),
                        .init(color: .black.opacity(0.85), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                VStack(alignment: .leading, spacing: 10) {
                    // Trending badge
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("Trending")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.green.opacity(0.2))
                    .clipShape(Capsule())
                    
                    Text(recipe.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        Label(recipe.formattedTotalTime, systemImage: "clock")
                        Label("\(recipe.calories)", systemImage: "flame")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
                }
                .padding(18)
            }
            .frame(width: 240, height: 300)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.04)
    }
}
