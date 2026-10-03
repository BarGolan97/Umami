//
//  SearchView.swift
//  RecipeApp
//
//  Premium VisionOS Search Screen adapted for SwiftData
//

import SwiftUI
import SwiftData

// MARK: - Navigation Destination for Cooking
struct CookingDestination: Hashable {
    let recipe: Recipe
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(recipe.id)
    }
    
    static func == (lhs: CookingDestination, rhs: CookingDestination) -> Bool {
        lhs.recipe.id == rhs.recipe.id
    }
}

// MARK: - Seeded Random Generator
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    
    init(seed: UInt64) {
        state = seed
    }
    
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - Design System

enum SD {
    static let smallRadius: CGFloat      = 20
    static let mediumRadius: CGFloat     = 24
    static let largeRadius: CGFloat      = 28
    static let extraLargeRadius: CGFloat = 36
    static let sectionSpacing: CGFloat   = 60
    static let hPad: CGFloat             = 80
    static let cardSpacing: CGFloat      = 24

    /// Warm amber accent used throughout Search
    static let accent = Color(red: 1.0, green: 0.75, blue: 0.35)

    static func glass(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(.thickMaterial)
            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 8)
    }

    static func stroke(radius: CGFloat, intensity: CGFloat = 1.0) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.6 * intensity), .white.opacity(0.15 * intensity)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
            )
    }
}



// MARK: - Appear Animation Helper

extension View {
    func appear(_ key: String, delay: Double, set: Binding<Set<String>>) -> some View {
        self
            .opacity(set.wrappedValue.contains(key) ? 1 : 0)
            .offset(y: set.wrappedValue.contains(key) ? 0 : 15)
            .onAppear {
                withAnimation(.snappy(duration: 0.3).delay(delay)) {
                    _ = set.wrappedValue.insert(key)
                }
            }
    }
}

// MARK: - Supporting Types

struct SearchFilter: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let icon: String
    let color: Color
    let criteria: SearchFilterCriteria
    
    init(label: String, icon: String, color: Color, criteria: SearchFilterCriteria = .all) {
        self.label = label
        self.icon = icon
        self.color = color
        self.criteria = criteria
    }
    
    // Hashable conformance - ignore criteria
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SearchFilter, rhs: SearchFilter) -> Bool {
        lhs.id == rhs.id
    }
}

struct SearchFilterCriteria {
    let tags: [String]           // Tags to search for
    let titleKeywords: [String]  // Keywords to search in title
    let difficulties: [String]   // Match recipe.difficulty
    let maxMinutes: Int?         // Match recipe.totalTimeMinutes <= value
    
    init(tags: [String] = [], titleKeywords: [String] = [], difficulties: [String] = [], maxMinutes: Int? = nil) {
        self.tags = tags
        self.titleKeywords = titleKeywords
        self.difficulties = difficulties
        self.maxMinutes = maxMinutes
    }
    
    static let all = SearchFilterCriteria()
}

private let searchFilters: [SearchFilter] = [
    SearchFilter(label: "Quick",      icon: "bolt.fill",                 color: Color(red:0.95,green:0.75,blue:0.20),
                 criteria: SearchFilterCriteria(tags: ["Quick"], maxMinutes: 30)),
    SearchFilter(label: "Easy",       icon: "hand.thumbsup.fill",        color: Color(red:0.45,green:0.75,blue:0.95),
                 criteria: SearchFilterCriteria(tags: ["Easy", "Beginner"], difficulties: ["Easy", "Beginner"])),
    SearchFilter(label: "Breakfast",  icon: "sun.horizon.fill",          color: Color(red:1.0, green:0.65,blue:0.30),
                 criteria: SearchFilterCriteria(tags: ["Breakfast", "Eggs"], titleKeywords: ["Breakfast", "Eggs", "Pancake", "Waffle", "Omelette"])),
    SearchFilter(label: "Dinner",     icon: "moon.stars.fill",           color: Color(red:0.45,green:0.35,blue:0.75),
                 criteria: SearchFilterCriteria(tags: ["Dinner", "Main", "Meat", "Chicken", "Beef", "Pork"], titleKeywords: ["Dinner"])),
    SearchFilter(label: "Comfort",    icon: "heart.circle.fill",         color: Color(red:0.85,green:0.45,blue:0.45),
                 criteria: SearchFilterCriteria(tags: ["Comfort", "Soup", "Pasta", "Cheese", "Fried", "BBQ"], titleKeywords: ["Mac", "Cheese", "Fried", "Pot Pie", "Lasagna"])),
    SearchFilter(label: "Soup",       icon: "mug.fill",                  color: Color(red:0.70,green:0.50,blue:0.30),
                 criteria: SearchFilterCriteria(tags: ["Soup"], titleKeywords: ["Soup", "Chowder", "Ramen", "Pho"])),
    SearchFilter(label: "Salad",      icon: "leaf.circle.fill",          color: Color(red:0.35,green:0.70,blue:0.40),
                 criteria: SearchFilterCriteria(tags: ["Salad"], titleKeywords: ["Salad"])),
]

struct TrendingTopic: Identifiable {
    let id = UUID()
    let query: String
    let recipeCount: Int
    let accent: Color
}

// Dynamic trending topics - counts will be calculated from actual recipes
struct TrendingQuery {
    let query: String
    let accent: Color
    let icon: String
    let tags: [String]  // Multiple tags to search for
    let titleKeywords: [String]  // Keywords to search in recipe title
    
    init(query: String, accent: Color, icon: String, tags: [String] = [], titleKeywords: [String] = []) {
        self.query = query
        self.accent = accent
        self.icon = icon
        self.tags = tags.isEmpty ? [query] : tags
        self.titleKeywords = titleKeywords.isEmpty ? [query] : titleKeywords
    }
}

// Categories that are shown in HomeView or SearchView filters - should be excluded from trending
private let excludedCategories: Set<String> = [
    // HomeView categories
    "italian", "asian", "mexican", "healthy", "desserts", "dessert",
    // SearchView filter labels
    "quick", "easy", "breakfast", "dinner", "comfort", "soup", "salad"
]

// Pool of all possible trending queries - will be filtered to show only those with 10+ recipes
private let allTrendingQueries: [TrendingQuery] = [
    // Protein-based
    TrendingQuery(query: "Chicken", accent: Color(red:0.80,green:0.60,blue:0.40), icon: "flame.fill", tags: ["Chicken"], titleKeywords: ["Chicken"]),
    TrendingQuery(query: "Beef", accent: Color(red:0.70,green:0.30,blue:0.30), icon: "flame.fill", tags: ["Beef", "Meat"], titleKeywords: ["Beef", "Steak", "Burger"]),
    TrendingQuery(query: "Seafood", accent: Color(red:0.35,green:0.60,blue:0.80), icon: "drop.fill", tags: ["Seafood", "Fish"], titleKeywords: ["Shrimp", "Salmon", "Fish", "Seafood", "Scallops", "Calamari"]),
    TrendingQuery(query: "Pork", accent: Color(red:0.85,green:0.55,blue:0.45), icon: "fork.knife", tags: ["Pork"], titleKeywords: ["Pork", "Ham", "Bacon"]),
    
    // Cuisine-based (not in HomeView)
    TrendingQuery(query: "Japanese", accent: Color(red:0.90,green:0.40,blue:0.40), icon: "globe.asia.australia.fill", tags: ["Japanese"], titleKeywords: ["Japanese", "Ramen", "Sushi", "Teriyaki"]),
    TrendingQuery(query: "Indian", accent: Color(red:0.95,green:0.60,blue:0.20), icon: "globe.asia.australia.fill", tags: ["Indian"], titleKeywords: ["Indian", "Curry", "Tikka", "Masala"]),
    TrendingQuery(query: "French", accent: Color(red:0.30,green:0.45,blue:0.70), icon: "globe.europe.africa.fill", tags: ["French"], titleKeywords: ["French", "Crepes", "Mousse"]),
    TrendingQuery(query: "Korean", accent: Color(red:0.80,green:0.35,blue:0.45), icon: "globe.asia.australia.fill", tags: ["Korean"], titleKeywords: ["Korean", "Bulgogi", "Kimchi"]),
    TrendingQuery(query: "Thai", accent: Color(red:0.45,green:0.75,blue:0.45), icon: "globe.asia.australia.fill", tags: ["Thai"], titleKeywords: ["Thai", "Curry", "Pad Thai"]),
    TrendingQuery(query: "Vietnamese", accent: Color(red:0.55,green:0.70,blue:0.40), icon: "globe.asia.australia.fill", tags: ["Vietnamese"], titleKeywords: ["Vietnamese", "Pho"]),
    TrendingQuery(query: "Middle Eastern", accent: Color(red:0.85,green:0.65,blue:0.35), icon: "globe.europe.africa.fill", tags: ["Middle Eastern"], titleKeywords: ["Hummus", "Falafel", "Shawarma", "Kofta"]),
    
    // Cooking style
    TrendingQuery(query: "Pasta", accent: Color(red:0.90,green:0.75,blue:0.30), icon: "fork.knife", tags: ["Pasta", "Noodles"], titleKeywords: ["Pasta", "Spaghetti", "Penne", "Lasagna", "Ravioli", "Gnocchi"]),
    TrendingQuery(query: "Baking", accent: Color(red:0.85,green:0.55,blue:0.45), icon: "birthday.cake.fill", tags: ["Baking", "Bread"], titleKeywords: ["Bread", "Cake", "Brownies", "Cookies"]),
    TrendingQuery(query: "Vegetarian", accent: Color(red:0.35,green:0.70,blue:0.40), icon: "leaf.fill", tags: ["Vegetarian", "Vegan"], titleKeywords: ["Vegetarian", "Tofu"]),
    TrendingQuery(query: "Appetizer", accent: Color(red:0.70,green:0.55,blue:0.80), icon: "sparkles", tags: ["Appetizer", "Snack"], titleKeywords: ["Appetizer"]),
]

// MARK: - ════════════════════════════════════════════
//         SEARCH VIEW  — Premium Edition (Integrated)
// ════════════════════════════════════════════════════

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @AppStorage(RecipePreferenceKeys.preferredDiets) private var preferredDietsRaw: String = ""
    @AppStorage(RecipePreferenceKeys.excludedAllergens) private var excludedAllergensRaw: String = ""

    @State private var query: String = ""
    @State private var activeFilter: SearchFilter? = nil
    @State private var showAllRecipes: Bool = false
    @State private var activeTrendingQuery: TrendingQuery? = nil  // Track active trending topic
    @State private var recentSearches: [String] = []
    @State private var appeared: Set<String> = []
    @FocusState private var searchFocused: Bool
    @State private var searchPath = NavigationPath()
    @State private var featuredRandomSeed: Int = Int.random(in: 0...1000)
    @State private var inspirationRandomSeed: Int = Int.random(in: 0...1000)
    
    // Cached collections to avoid recomputing on every render
    @State private var cachedVisibleRecipes: [Recipe] = []
    @State private var cachedTrendingQueries: [(query: TrendingQuery, count: Int)] = []
    @State private var cachedFeaturedRecipes: [Recipe] = []
    @State private var cachedInspirationRecipes: [Recipe] = []
    @State private var lastVisibleRecipesCount: Int = 0

    private var selectedDiets: Set<DietaryPreference> {
        preferredDietsRaw.rawValueSet(for: DietaryPreference.self)
    }

    private var excludedAllergens: Set<RecipeAllergen> {
        excludedAllergensRaw.rawValueSet(for: RecipeAllergen.self)
    }

    private var visibleRecipes: [Recipe] { cachedVisibleRecipes }

    // Check if a recipe matches filter criteria
    private func recipeMatchesCriteria(_ recipe: Recipe, criteria: SearchFilterCriteria) -> Bool {
        // Check tags
        let tagMatch = !criteria.tags.isEmpty && recipe.tags.contains { recipeTag in
            criteria.tags.contains { criteriaTag in
                recipeTag.localizedCaseInsensitiveContains(criteriaTag)
            }
        }
        
        // Check title keywords
        let titleMatch = !criteria.titleKeywords.isEmpty && criteria.titleKeywords.contains { keyword in
            recipe.title.localizedCaseInsensitiveContains(keyword)
        }
        
        // Check difficulty
        let difficultyMatch = !criteria.difficulties.isEmpty && criteria.difficulties.contains { diff in
            recipe.difficulty.localizedCaseInsensitiveContains(diff)
        }
        
        // Check max minutes
        let timeMatch = criteria.maxMinutes.map { recipe.totalTimeMinutes <= $0 } ?? false
        
        // If no criteria specified (All filter), match everything
        if criteria.tags.isEmpty && criteria.titleKeywords.isEmpty && criteria.difficulties.isEmpty && criteria.maxMinutes == nil {
            return true
        }
        
        return tagMatch || titleMatch || difficultyMatch || timeMatch
    }
    
    // Check if recipe matches a trending query (same logic as counting)
    private func recipeMatchesTrendingQuery(_ recipe: Recipe, trendingQuery: TrendingQuery) -> Bool {
        let tagMatch = recipe.tags.contains { recipeTag in
            trendingQuery.tags.contains { queryTag in
                recipeTag.localizedCaseInsensitiveContains(queryTag)
            }
        }
        let titleMatch = trendingQuery.titleKeywords.contains { keyword in
            recipe.title.localizedCaseInsensitiveContains(keyword)
        }
        return tagMatch || titleMatch
    }

    private var filteredRecipes: [Recipe] {
        // First apply the filter pill criteria
        let base: [Recipe]
        if let filter = activeFilter {
            base = visibleRecipes.filter { recipeMatchesCriteria($0, criteria: filter.criteria) }
        } else {
            base = Array(visibleRecipes)
        }
        
        // If there's an active trending query, use it
        if let trendingQuery = activeTrendingQuery {
            return base.filter { recipeMatchesTrendingQuery($0, trendingQuery: trendingQuery) }
        }
        
        // Otherwise apply text search
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.tags.contains { tag in tag.localizedCaseInsensitiveContains(query) }
        }
    }

    private var isSearching: Bool { !query.isEmpty || activeFilter != nil || showAllRecipes || activeTrendingQuery != nil }
    
    private func addToRecentSearches(_ term: String) {
        let trimmed = term.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Remove if exists, then add to front
        recentSearches.removeAll { $0.lowercased() == trimmed.lowercased() }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 5 { recentSearches.removeLast() }
    }
    
    private func rebuildCaches() {
        cachedVisibleRecipes = RecipePreferenceFilter.filter(recipes, diets: selectedDiets, allergens: excludedAllergens)
        let visible = cachedVisibleRecipes
        lastVisibleRecipesCount = visible.count
        
        // Cache trending queries with counts
        cachedTrendingQueries = allTrendingQueries.compactMap { tq in
            let count = visible.filter { recipe in
                let tagMatch = recipe.tags.contains { recipeTag in
                    tq.tags.contains { queryTag in
                        recipeTag.localizedCaseInsensitiveContains(queryTag)
                    }
                }
                let titleMatch = tq.titleKeywords.contains { keyword in
                    recipe.title.localizedCaseInsensitiveContains(keyword)
                }
                return tagMatch || titleMatch
            }.count
            return count >= 10 ? (query: tq, count: count) : nil
        }
        
        // Cache shuffled collections
        var featRng = SeededRandomNumberGenerator(seed: UInt64(featuredRandomSeed))
        cachedFeaturedRecipes = visible.shuffled(using: &featRng)
        
        var inspRng = SeededRandomNumberGenerator(seed: UInt64(inspirationRandomSeed))
        cachedInspirationRecipes = visible.shuffled(using: &inspRng)
    }

    var body: some View {
        NavigationStack(path: $searchPath) {
            ZStack {
                // Background
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // ── Hero header with search bar ────────
                        searchHeader
                            .appear("sh", delay: 0.05, set: $appeared)

                        // ── Filter pill strip ──────────────────
                        filterStrip
                            .padding(.top, 28)
                            .appear("sf", delay: 0.12, set: $appeared)

                        // ── Adaptive content ───────────────────
                        Group {
                            if isSearching {
                                liveResultsSection
                                    .padding(.top, 40)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .bottom).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            } else {
                                VStack(alignment: .leading, spacing: 52) {
                                    if !recentSearches.isEmpty {
                                        recentSection.appear("rec", delay: 0.18, set: $appeared)
                                    }
                                    trendingSection.appear("tr", delay: 0.26, set: $appeared)
                                    
                                    if !visibleRecipes.isEmpty {
                                        featuredPicksSection.appear("feat", delay: 0.34, set: $appeared)
                                        inspirationSection.appear("ins", delay: 0.42, set: $appeared)
                                    }
                                }
                                .padding(.top, 44)
                            }
                        }
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isSearching)

                        Spacer().frame(height: 120)
                    }
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailsView(
                    recipe: recipe,
                    onStartCooking: {
                        searchPath.append(CookingDestination(recipe: recipe))
                    },
                    onAddAllToList: {}
                )
            }
            .navigationDestination(for: CookingDestination.self) { destination in
                CookingView(recipe: destination.recipe)
            }
            .onReceive(NotificationCenter.default.publisher(for: .returnToHome)) { _ in
                searchPath = NavigationPath()
            }
            .task(id: "\(recipes.count)|\(preferredDietsRaw)|\(excludedAllergensRaw)") {
                rebuildCaches()
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: Search Header
    // ─────────────────────────────────────────
    private var searchHeader: some View {
        VStack(alignment: .leading, spacing: 28) {

            // Greeting block
            VStack(alignment: .leading, spacing: 6) {
                Text("What are you")
                    .font(.system(size: 50, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                Text("looking for?")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Search bar
            HStack(spacing: 0) {

                // Leading icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(searchFocused ? SD.accent : .white.opacity(0.40))
                    .animation(.easeOut(duration: 0.22), value: searchFocused)
                    .padding(.leading, 24)
                    .padding(.trailing, 14)

                // Text field or Trending Query Display
                if let trendingQuery = activeTrendingQuery {
                    // Show active trending query as a styled tag
                    HStack(spacing: 8) {
                        Text(trendingQuery.query)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(trendingQuery.accent)
                    }
                    .frame(height: 60, alignment: .leading)
                } else {
                    TextField("Pasta, risotto, tacos…", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .tint(SD.accent)
                        .focused($searchFocused)
                        .submitLabel(.search)
                        .frame(height: 60)
                        .contentShape(.interaction, Rectangle())
                        .onSubmit {
                            addToRecentSearches(query)
                        }
                }

                Spacer()

                // Clear - show when there's text query or active trending query
                if !query.isEmpty || activeTrendingQuery != nil {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            query = ""
                            activeTrendingQuery = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.40))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

            }
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.regularMaterial)
                    .hoverEffectDisabled()
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(
                                searchFocused
                                    ? SD.accent.opacity(0.55)
                                    : Color.white.opacity(0.10),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(
                        color: searchFocused ? SD.accent.opacity(0.22) : .black.opacity(0.10),
                        radius: searchFocused ? 20 : 8, x: 0, y: 4
                    )
                    .animation(.easeOut(duration: 0.25), value: searchFocused)
            }
        }
        .padding(.horizontal, SD.hPad)
        .padding(.top, 52)
    }

    // ─────────────────────────────────────────
    // MARK: Filter Strip
    // ─────────────────────────────────────────
    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All Recipes" pill
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        if showAllRecipes && activeFilter == nil {
                            showAllRecipes = false
                        } else {
                            showAllRecipes = true
                            activeFilter = nil
                        }
                        activeTrendingQuery = nil
                    }
                } label: {
                    let isActive = showAllRecipes && activeFilter == nil && activeTrendingQuery == nil
                    HStack(spacing: 9) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isActive ? .black : Color(red: 0.6, green: 0.6, blue: 0.7))

                        Text("All Recipes")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(isActive ? .black : .white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background {
                        if isActive {
                            Capsule()
                                .fill(SD.accent)
                                .shadow(color: SD.accent.opacity(0.45), radius: 10, x: 0, y: 4)
                        } else {
                            Capsule()
                                .fill(.regularMaterial)
                                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                        }
                    }
                    .contentShape(Capsule())
                    .contentShape(.hoverEffect, Capsule())
                    .hoverEffect(.highlight)
                }
                .buttonStyle(SpatialButtonStyle(shape: Capsule()))
                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: showAllRecipes)

                ForEach(searchFilters) { filter in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            if activeFilter == filter {
                                activeFilter = nil
                            } else {
                                activeFilter = filter
                            }
                            showAllRecipes = false
                            activeTrendingQuery = nil
                        }
                    } label: {
                        let isActive = activeFilter == filter
                        HStack(spacing: 9) {
                            Image(systemName: filter.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isActive ? .black : filter.color)

                            Text(filter.label)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(isActive ? .black : .white)
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background {
                            if isActive {
                                Capsule()
                                    .fill(SD.accent)
                                    .shadow(color: SD.accent.opacity(0.45), radius: 10, x: 0, y: 4)
                            } else {
                                Capsule()
                                    .fill(.regularMaterial)
                                    .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                            }
                        }
                        .contentShape(Capsule())
                        .contentShape(.hoverEffect, Capsule())
                        .hoverEffect(.highlight)
                    }
                    .buttonStyle(SpatialButtonStyle(shape: Capsule()))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: activeFilter)
                }
            }
            .padding(.horizontal, SD.hPad)
        }
    }

    // ─────────────────────────────────────────
    // MARK: Live Results Section
    // ─────────────────────────────────────────
    private var liveResultsSection: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Count
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(filteredRecipes.count)")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(SD.accent)
                Text(filteredRecipes.count == 1 ? "recipe found" : "recipes found")
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.50))
                    .padding(.bottom, 2)
            }
            .padding(.horizontal, SD.hPad)

            if filteredRecipes.isEmpty {
                emptyState
            } else if showAllRecipes && activeFilter == nil {
                // Vertical grid for "All Recipes"
                let columns = [
                    GridItem(.adaptive(minimum: 270, maximum: 360), spacing: 20)
                ]
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(filteredRecipes, id: \.id) { recipe in
                        Button { searchPath.append(recipe) } label: {
                            SearchResultCard(recipe: recipe, isLarge: false)
                        }
                        .buttonStyle(SpatialButtonStyle(
                            shape: RoundedRectangle(cornerRadius: SD.largeRadius, style: .continuous)
                        ))
                        .polishedHover(scale: 1.04)
                    }
                }
                .padding(.horizontal, SD.hPad)
                .padding(.vertical, 20)
            } else {
                // Horizontal cinematic scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .center, spacing: 20) {
                        ForEach(Array(filteredRecipes.enumerated()), id: \.element.id) { idx, recipe in
                            Button { searchPath.append(recipe) } label: {
                                SearchResultCard(recipe: recipe, isLarge: idx % 5 == 0)
                            }
                            .buttonStyle(SpatialButtonStyle(
                                shape: RoundedRectangle(cornerRadius: SD.largeRadius, style: .continuous)
                            ))
                            .polishedHover(scale: 1.04)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, SD.hPad)
                    .padding(.vertical, 20)
                }
                .scrollTargetBehavior(.viewAligned)
                .frame(height: 420)
            }
        }
    }

    // ── Empty state ───────────────────────────
    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.06))
                    .frame(width: 110, height: 110)
                    .overlay(Circle().stroke(.white.opacity(0.08), lineWidth: 1))
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 42, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(0.25))
            }
            VStack(spacing: 8) {
                Text("No recipes found")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Try a different keyword or adjust the filters above")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 70)
    }

    // ─────────────────────────────────────────
    // MARK: Recent Searches
    // ─────────────────────────────────────────
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SearchSectionLabel(title: "Recent Searches", icon: "clock.arrow.circlepath")
                .padding(.horizontal, SD.hPad)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentSearches, id: \.self) { term in
                        Button {
                            withAnimation(.spring(response: 0.3)) { query = term }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.40))
                                Text(term)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 18).padding(.vertical, 13)
                            .background(.regularMaterial)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                            .contentShape(.hoverEffect, Capsule())
                        }
                        .buttonStyle(SpatialButtonStyle(shape: Capsule()))
                        .polishedHover(scale: 1.05)
                    }

                    // Clear all
                    Button {
                        withAnimation(.spring(response: 0.4)) { recentSearches.removeAll() }
                    } label: {
                        Text("Clear")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.35))
                            .padding(.horizontal, 16).padding(.vertical, 13)
                            .background(.white.opacity(0.06)).clipShape(Capsule())
                            .contentShape(.hoverEffect, Capsule())
                    }
                    .buttonStyle(SpatialButtonStyle(shape: Capsule()))
                    .hoverEffect(.highlight)
                }
                .padding(.horizontal, SD.hPad)
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: Trending
    // ─────────────────────────────────────────
    
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SearchSectionLabel(title: "Trending Now", icon: "chart.line.uptrend.xyaxis")
                .padding(.horizontal, SD.hPad)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(cachedTrendingQueries, id: \.query.query) { item in
                        let tq = item.query
                        let count = item.count
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                query = ""  // Clear text query
                                activeTrendingQuery = tq  // Set trending query for filtering
                            }
                        } label: {
                            DynamicTrendingCard(query: tq.query, count: count, accent: tq.accent, icon: tq.icon)
                        }
                        .buttonStyle(
                            SpatialButtonStyle(
                                shape: RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                        )
                        .polishedHover(scale: 1.05)
                    }
                }
                .padding(.horizontal, SD.hPad).scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 130)
        }
    }

    // ─────────────────────────────────────────
    // MARK: Inspiration Grid
    // ─────────────────────────────────────────
    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SearchSectionLabel(title: "Browse Inspiration", icon: "sparkles")
                .padding(.horizontal, SD.hPad)

            // Staggered-height horizontal scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 20) {
                    ForEach(cachedInspirationRecipes.prefix(min(15, visibleRecipes.count)), id: \.id) { recipe in
                        Button { searchPath.append(recipe) } label: {
                            InspirationCard(recipe: recipe)
                        }
                        .buttonStyle(SpatialButtonStyle(
                            shape: RoundedRectangle(cornerRadius: SD.mediumRadius, style: .continuous)
                        ))
                        .polishedHover(scale: 1.04)
                    }
                }
                .padding(.horizontal, SD.hPad).scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 390)
        }
    }
    
    // ─────────────────────────────────────────
    // MARK: Featured Picks Section
    // ─────────────────────────────────────────
    private var featuredPicksSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            SearchSectionLabel(title: "Featured Picks", icon: "star.fill")
                .padding(.horizontal, SD.hPad)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(cachedFeaturedRecipes.prefix(6), id: \.id) { recipe in
                        Button { 
                            addToRecentSearches(recipe.title)
                            searchPath.append(recipe) 
                        } label: {
                            FeaturedPickCard(recipe: recipe)
                        }
                        .buttonStyle(SpatialButtonStyle(
                            shape: RoundedRectangle(cornerRadius: 28, style: .continuous)
                        ))
                        .polishedHover(scale: 1.04)
                    }
                }
                .padding(.horizontal, SD.hPad).scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .frame(height: 320)
        }
    }
    
}

// ─────────────────────────────────────────
// MARK: Search Sub-components
// ─────────────────────────────────────────

struct SearchSectionLabel: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(SD.accent)
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

struct SearchResultCard: View {
    let recipe: Recipe
    let isLarge: Bool

    private var cardWidth: CGFloat  { isLarge ? 360 : 270 }
    private var cardHeight: CGFloat { 380 }
    private let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Actual App Image
            RecipeImageView(recipe: recipe, targetHeight: cardHeight)
                .frame(width: cardWidth, height: cardHeight)
                .clipped()

            // Gradient scrim
            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.0),
                    .init(color: .clear,               location: 0.35),
                    .init(color: .black.opacity(0.50), location: 0.62),
                    .init(color: .black.opacity(0.88), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Content
            VStack(alignment: .leading, spacing: 10) {

                // Star badge
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(red:1.0,green:0.82,blue:0.28))
                    Text(String(format: "%.1f", recipe.rating))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.black.opacity(0.40)).clipShape(Capsule())

                // Title
                Text(recipe.title)
                    .font(.system(size: isLarge ? 26 : 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).lineLimit(2)

                // Meta row
                HStack(spacing: 14) {
                    HStack(spacing: 5) {
                        Image(systemName: "clock.fill").font(.system(size: 12))
                        Text(recipe.formattedTotalTime).font(.system(size: 13, weight: .semibold))
                    }
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill").font(.system(size: 12))
                        Text("\(recipe.calories) kcal").font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundStyle(.white.opacity(0.70))

                // Tag pills
                HStack(spacing: 6) {
                    ForEach(recipe.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(0.90))
                            .padding(.horizontal, 9).padding(.vertical, 4)
                            .background(.white.opacity(0.14)).clipShape(Capsule())
                    }
                }
            }
            .padding(22)
        }
        .frame(width: cardWidth, height: cardHeight)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.28), .white.opacity(0.05)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
    }
}

// Dynamic Trending Card with real counts
struct DynamicTrendingCard: View {
    let query: String
    let count: Int
    let accent: Color
    let icon: String

    var body: some View {
        HStack(spacing: 14) {
            // Icon block with gradient
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.35), accent.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(query)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(count == 1 ? "1 recipe" : "\(count) recipes")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(count > 0 ? accent.opacity(0.9) : .white.opacity(0.45))
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 18)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(accent.opacity(0.25), lineWidth: 1)
        )
    }
}

struct InspirationCard: View {
    let recipe: Recipe

    private let cardHeight: CGFloat = 360
    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Actual App Image
            RecipeImageView(recipe: recipe, targetHeight: cardHeight)
                .frame(width: 220, height: cardHeight)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear,               location: 0.38),
                    .init(color: .black.opacity(0.82), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(recipe.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white).lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: "clock").font(.system(size: 12, weight: .medium))
                    Text(recipe.formattedTotalTime).font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.65))
            }
            .padding(18)
        }
        .frame(width: 220, height: cardHeight)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.22), .white.opacity(0.04)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
    }
}

// MARK: - Featured Pick Card
struct FeaturedPickCard: View {
    let recipe: Recipe
    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RecipeImageView(recipe: recipe, targetHeight: 300)
                .frame(width: 280, height: 300)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.3),
                    .init(color: .black.opacity(0.85), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 12) {
                // Rating badge
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", recipe.rating))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                
                Text(recipe.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                HStack(spacing: 14) {
                    Label(recipe.formattedTotalTime, systemImage: "clock")
                    Label("\(recipe.calories) kcal", systemImage: "flame")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            }
            .padding(22)
        }
        .frame(width: 280, height: 300)
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.35), .white.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
    }
}
