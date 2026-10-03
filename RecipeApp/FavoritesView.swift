//
//  FavoritesView.swift
//  RecipeApp
//
//  Minimalist Favorites Screen for Apple Vision Pro
//

import SwiftUI
import SwiftData

// MARK: - Navigation Destination for Cooking (if not already defined)
struct FavoritesCookingDestination: Hashable {
    let recipe: Recipe
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(recipe.id)
    }
    
    static func == (lhs: FavoritesCookingDestination, rhs: FavoritesCookingDestination) -> Bool {
        lhs.recipe.id == rhs.recipe.id
    }
}

struct FavoritesView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Recipe> { $0.isFavorite }, sort: \Recipe.title)
    private var favoriteRecipes: [Recipe]
    @AppStorage(RecipePreferenceKeys.preferredDiets) private var preferredDietsRaw: String = ""
    @AppStorage(RecipePreferenceKeys.excludedAllergens) private var excludedAllergensRaw: String = ""
    
    @State private var appeared: Set<String> = []
    @State private var favoritesPath = NavigationPath()

    private var selectedDiets: Set<DietaryPreference> {
        preferredDietsRaw.rawValueSet(for: DietaryPreference.self)
    }

    private var excludedAllergens: Set<RecipeAllergen> {
        excludedAllergensRaw.rawValueSet(for: RecipeAllergen.self)
    }

    private var visibleFavoriteRecipes: [Recipe] {
        RecipePreferenceFilter.filter(favoriteRecipes, diets: selectedDiets, allergens: excludedAllergens)
    }
    
    var body: some View {
        NavigationStack(path: $favoritesPath) {
            ZStack {
                // Background
                Color.clear
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea()
                
                if visibleFavoriteRecipes.isEmpty {
                    emptyStateView
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 40) {
                            // Header
                            headerSection
                                .opacity(appeared.contains("header") ? 1 : 0)
                                .offset(y: appeared.contains("header") ? 0 : 15)
                                .onAppear {
                                    withAnimation(.snappy(duration: 0.3)) {
                                        _ = appeared.insert("header")
                                    }
                                }
                            
                            // Favorites Grid
                            favoritesGrid
                                .opacity(appeared.contains("grid") ? 1 : 0)
                                .offset(y: appeared.contains("grid") ? 0 : 15)
                                .onAppear {
                                    withAnimation(.snappy(duration: 0.3).delay(0.08)) {
                                        _ = appeared.insert("grid")
                                    }
                                }
                        }
                        .padding(.top, 50)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("\(visibleFavoriteRecipes.count) \(visibleFavoriteRecipes.count == 1 ? "recipe" : "recipes")")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 60)
    }
    
    // MARK: - Favorites Grid
    private var favoritesGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 280, maximum: 340), spacing: 24)],
            spacing: 24
        ) {
            ForEach(visibleFavoriteRecipes, id: \.id) { recipe in
                NavigationLink(value: recipe) {
                    MinimalFavoriteCard(recipe: recipe) {
                        toggleFavorite(recipe)
                    }
                }
                .buttonStyle(FavCardButtonStyle())
            }
        }
        .padding(.horizontal, 60)
        .navigationDestination(for: Recipe.self) { recipe in
            RecipeDetailsView(
                recipe: recipe,
                onStartCooking: {
                    favoritesPath.append(FavoritesCookingDestination(recipe: recipe))
                },
                onAddAllToList: {}
            )
        }
        .navigationDestination(for: FavoritesCookingDestination.self) { destination in
            CookingView(recipe: destination.recipe)
        }
        .onReceive(NotificationCenter.default.publisher(for: .returnToHome)) { _ in
            favoritesPath = NavigationPath()
        }
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 28) {
            Image(systemName: "heart")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.white.opacity(0.3))
            
            VStack(spacing: 10) {
                Text(favoriteRecipes.isEmpty ? "No Favorites Yet" : "Favorites Hidden by Filters")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                Text(favoriteRecipes.isEmpty ? "Tap the heart on any recipe to save it here" : "Change dietary or allergy settings to show more favorites")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Functions
    private func toggleFavorite(_ recipe: Recipe) {
        withAnimation(.spring(response: 0.3)) {
            recipe.isFavorite.toggle()
            try? context.save()
        }
    }
}

// MARK: - Minimal Favorite Card
struct MinimalFavoriteCard: View {
    let recipe: Recipe
    let onRemove: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // Image
                ZStack(alignment: .bottomLeading) {
                    RecipeImageView(recipe: recipe, targetHeight: 200)
                        .frame(height: 200)
                        .clipped()
                    
                    // Subtle gradient
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.4)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    // Rating
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", recipe.rating))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(14)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 10) {
                    Text(recipe.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    
                    HStack(spacing: 16) {
                        Label(recipe.formattedTotalTime, systemImage: "clock")
                        Label("\(recipe.calories) cal", systemImage: "flame")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
            }
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
            
            // Heart button
            Button(action: onRemove) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.pink)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .padding(12)
        }
    }
}

// MARK: - Button Style for Favorites Cards
struct FavCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .hoverEffect(.lift)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    FavoritesView()
}
