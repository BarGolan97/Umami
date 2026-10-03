import SwiftUI
import SwiftData
import UIKit

// MARK: - Measurement System Preference
enum MeasurementSystem: String, CaseIterable {
    case metric = "metric"
    case imperial = "imperial"
    
    var displayName: String {
        switch self {
        case .metric: return "Metric"
        case .imperial: return "Imperial"
        }
    }
    
    var subtitle: String {
        switch self {
        case .metric: return "kg, g, ml, liter"
        case .imperial: return "lb, oz, fl oz, cups"
        }
    }
}

// MARK: - Unit Conversion Helper
struct UnitConverter {
    let system: MeasurementSystem
    
    // Categorize a unit string into a known unit type
    private enum KnownUnit {
        // Metric weight
        case grams, kilograms
        // Imperial weight
        case ounces, pounds
        // Metric volume
        case milliliters, liters
        // Imperial volume
        case cups, fluidOunces, tablespoons, teaspoons
        // Non-convertible
        case passthrough
    }
    
    private func classify(_ unit: String) -> KnownUnit {
        let u = unit.lowercased().trimmingCharacters(in: .whitespaces)
        switch u {
        case "g", "gram", "grams":                return .grams
        case "kg", "kilogram", "kilograms":        return .kilograms
        case "oz", "ounce", "ounces":              return .ounces
        case "lb", "lbs", "pound", "pounds":       return .pounds
        case "ml", "milliliter", "milliliters":    return .milliliters
        case "l", "liter", "liters":               return .liters
        case "cup", "cups":                        return .cups
        case "fl oz", "fluid ounce", "fluid ounces": return .fluidOunces
        case "tbsp", "tablespoon", "tablespoons":  return .tablespoons
        case "tsp", "teaspoon", "teaspoons":       return .teaspoons
        default:                                    return .passthrough
        }
    }
    
    /// Returns converted (quantity, unit) for display based on the user's preferred system.
    /// Handles both metric→imperial and imperial→metric conversions.
    /// Liquids always prefer cups when practical (more intuitive for cooking).
    /// All results are rounded to friendly, clean numbers.
    func convert(quantity: Double, unit: String) -> (Double, String) {
        let kind = classify(unit)
        
        // Pass-through units never convert (tbsp, tsp, slices, units, cloves, etc.)
        if kind == .passthrough || kind == .tablespoons || kind == .teaspoons {
            return (quantity, unit)
        }
        
        switch system {
        case .imperial:
            switch kind {
            // --- Metric weight → Imperial ---
            case .grams:
                if quantity >= 1000 {
                    return (smartRound(quantity / 453.592), "lb")
                }
                return (smartRound(quantity / 28.3495), "oz")
            case .kilograms:
                return (smartRound(quantity * 2.20462), "lb")
            // --- Metric volume → Cups (always prefer cups) ---
            case .milliliters:
                let cups = quantity / 240.0
                if cups >= 0.2 {
                    return (smartRoundCups(cups), "cups")
                }
                // Very small amounts stay as tbsp
                return (smartRound(quantity / 15.0), "tbsp")
            case .liters:
                return (smartRoundCups(quantity * 4.22675), "cups")
            // Already imperial — keep as-is but round
            case .ounces:  return (smartRound(quantity), "oz")
            case .pounds:  return (smartRound(quantity), "lb")
            case .cups:    return (smartRoundCups(quantity), "cups")
            case .fluidOunces:
                // Convert fl oz to cups if large enough
                let cups = quantity / 8.0
                if cups >= 0.25 {
                    return (smartRoundCups(cups), "cups")
                }
                return (smartRound(quantity), "fl oz")
            default:
                return (quantity, unit)
            }
            
        case .metric:
            switch kind {
            // --- Imperial weight → Metric —--
            case .ounces:
                return (smartRoundMetric(quantity * 28.3495), "g")
            case .pounds:
                let grams = quantity * 453.592
                if grams >= 1000 {
                    return (smartRound(grams / 1000.0), "kg")
                }
                return (smartRoundMetric(grams), "g")
            // --- Imperial volume → ml, but prefer cups for readability ---
            case .cups:
                return (smartRoundCups(quantity), "cups")
            case .fluidOunces:
                let cups = quantity / 8.0
                if cups >= 0.25 {
                    return (smartRoundCups(cups), "cups")
                }
                return (smartRoundMetric(quantity * 29.5735), "ml")
            // --- Metric volume → prefer cups when practical ---
            case .milliliters:
                let cups = quantity / 240.0
                if cups >= 0.25 {
                    return (smartRoundCups(cups), "cups")
                }
                return (smartRoundMetric(quantity), "ml")
            case .liters:
                return (smartRoundCups(quantity * 4.22675), "cups")
            // Already metric — round nicely
            case .grams:      return (smartRoundMetric(quantity), "g")
            case .kilograms:  return (smartRound(quantity), "kg")
            default:
                return (quantity, unit)
            }
        }
    }
    
    // MARK: - Smart Rounding
    
    /// Round to the nearest friendly number for general values.
    /// Examples: 1.1 → 1, 2.48 → 2.5, 3.7 → 3.5 or 4
    private func smartRound(_ value: Double) -> Double {
        if value >= 10 { return (value).rounded() }           // 17.6 → 18
        if value >= 1 { return (value * 2).rounded() / 2 }    // 2.3 → 2.5, 1.1 → 1
        if value >= 0.25 { return (value * 4).rounded() / 4 } // 0.3 → 0.25, 0.7 → 0.75
        return (value * 10).rounded() / 10                     // small: 1 decimal
    }
    
    /// Round cups to the nearest cooking-friendly fraction (¼, ⅓, ½, ¾, 1, 1.5, 2…)
    private func smartRoundCups(_ value: Double) -> Double {
        if value >= 4 { return (value).rounded() }            // 4.2 cups → 4
        if value >= 1 { return (value * 2).rounded() / 2 }    // 1.3 → 1.5
        // For fractions of a cup, snap to nearest ¼
        return (value * 4).rounded() / 4                       // 0.3 → 0.25, 0.6 → 0.5
    }
    
    /// Round metric grams/ml to the nearest clean step (5, 10, 25, 50…)
    private func smartRoundMetric(_ value: Double) -> Double {
        if value >= 500 { return (value / 50).rounded() * 50 }  // 567 → 550
        if value >= 100 { return (value / 25).rounded() * 25 }  // 113 → 100
        if value >= 10  { return (value / 5).rounded() * 5 }    // 28 → 30
        return (value * 2).rounded() / 2                         // small: round to 0.5
    }
    
    /// Format a quantity for display — clean, no unnecessary decimals.
    static func formatQuantity(_ value: Double) -> String {
        // Exact whole number
        if value == floor(value) && value < 10000 {
            return String(format: "%.0f", value)
        }
        // Common fractions for cups-like values
        let fraction = value - floor(value)
        let whole = Int(floor(value))
        if let fracStr = friendlyFraction(fraction) {
            if whole == 0 {
                return fracStr
            }
            return "\(whole) \(fracStr)"
        }
        // Otherwise 1 decimal, but drop .0
        let rounded = (value * 10).rounded() / 10
        if rounded == floor(rounded) {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }
    
    /// Map common decimal fractions to readable strings.
    private static func friendlyFraction(_ value: Double) -> String? {
        let tolerance = 0.06
        if abs(value - 0.25) < tolerance { return "¼" }
        if abs(value - 0.33) < tolerance { return "⅓" }
        if abs(value - 0.5)  < tolerance { return "½" }
        if abs(value - 0.66) < tolerance { return "⅔" }
        if abs(value - 0.75) < tolerance { return "¾" }
        return nil
    }
}

struct RecipeDetailsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var recipe: Recipe
    var onStartCooking: () -> Void
    var onAddAllToList: () -> Void
    
    // MARK: - State for Animations & Performance
    @State private var scrollOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var selectedServings: Int = 0
    
    private var servingsMultiplier: Double {
        guard recipe.defaultServings > 0, selectedServings > 0 else { return 1.0 }
        return Double(selectedServings) / Double(recipe.defaultServings)
    }
    
    private func refreshRatingFromStore() {
        let currentId = recipe.id
        if let updated = try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == currentId })).first {
            if updated.rating != recipe.rating {
                recipe.rating = updated.rating
            }
            if let notes = updated.notes, notes != recipe.notes {
                recipe.notes = notes
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()
            
            // MARK: - Parallax Background Image
            GeometryReader { proxy in
                let size = proxy.size
                let scrollY = scrollOffset
                
                RecipeImageView(recipe: recipe, targetHeight: 520)
                    .frame(width: size.width, height: size.height + max(0, -scrollY * 0.3))
                    // Only allow upward parallax. A positive scrollY (pull-down / overscroll)
                    // must never push the image down, or it exposes a blank gap at the top.
                    .offset(y: min(0, scrollY) * 0.45)
                    .scaleEffect(scrollY < 0 ? 1 + (-scrollY / 1200) : 1.0, anchor: .top)
                    .clipped()
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.75), .clear, .black.opacity(0.65)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .frame(height: 520)
            .ignoresSafeArea()
            
            // MARK: - Optimized Scrollable Content
            ScrollViewReader { scrollProxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0, pinnedViews: []) {
                        // Spacer for image
                        Color.clear
                            .frame(height: 380)
                            .id("top")
                        
                        // Main content card
                        contentCard
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: geo.frame(in: .named("scroll")).minY
                                    )
                                }
                            )
                    }
                }
                .coordinateSpace(name: "scroll")
                .scrollTargetBehavior(.viewAligned)
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
            .ignoresSafeArea()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    withAnimation(.spring(response: 0.3)) {
                        dismiss()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                RecipeFavoriteButton(recipe: recipe)
            }
            
            ToolbarItem(placement: .bottomOrnament) {
                StartCookingButton(action: onStartCooking)
                    .id("startCooking-\(recipe.id)")
            }
        }
        .id("recipeDetails-\(recipe.id)")
        .onAppear {
            if selectedServings == 0 {
                selectedServings = recipe.defaultServings
            }
        }
        .task {
            await MainActor.run {
                refreshRatingFromStore()
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isVisible = true
                }
            }
        }
    }
    
    // MARK: - Content Card
    private var contentCard: some View {
        VStack(spacing: 0) {
            // Header Section
            headerSection
                .padding(.top, 48)
                .padding(.bottom, 32)
            
            // Stats Bar
            StatsBarView(recipe: recipe)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            
            // Main Content
            LazyVStack(alignment: .leading, spacing: 40) {
                // Notes (multiple, deletable individually)
                if let notesText = recipe.notes {
                    let list = notesText
                        .components(separatedBy: "\n\n")
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    if !list.isEmpty {
                        RecipeNotesListView(notes: list) { index in
                            // remove note at index and save
                            var current = (recipe.notes ?? "")
                                .components(separatedBy: "\n\n")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            if index < current.count {
                                current.remove(at: index)
                                let joined = current.joined(separator: "\n\n")
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                    recipe.notes = joined.isEmpty ? nil : joined
                                }
                                try? context.save()
                            }
                        }
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                    }
                }
                
                // Ingredients with servings adjuster
                IngredientsSectionView(
                    ingredients: recipe.ingredients,
                    defaultServings: recipe.defaultServings,
                    currentServings: $selectedServings,
                    servingsMultiplier: servingsMultiplier
                )
                .padding(.horizontal, 24)
                
                // Elegant Divider
                HStack {
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.1), .white.opacity(0.3), .white.opacity(0.1)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                    
                    Circle()
                        .fill(.white.opacity(0.3))
                        .frame(width: 4, height: 4)
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                
                // Instructions
                InstructionsSectionView(steps: recipe.steps)
                    .padding(.horizontal, 24)
            }
            .padding(.bottom, 140)
        }
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color(white: 0.08),
                        Color(white: 0.05)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Noise texture overlay
                Rectangle()
                    .fill(.white.opacity(0.02))
            }
            .clipShape(CustomCorner(radius: 44, corners: [.topLeft, .topRight]))
            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: -10)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 20)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title with animated gradient
            Text(recipe.title)
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white, .white.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
                .lineSpacing(4)
            
            // Rating & Difficulty
            HStack(spacing: 16) {
                RatingView(rating: recipe.rating)
                
                DifficultyBadge(difficulty: recipe.difficulty)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Recipe Notes (Formerly Chef's Notes)
private struct RecipeNotesView: View {
    let notes: String
    var onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Label {
                    Text("Notes") // Changed from "Chef's Notes"
                        .font(.title2)
                        .fontWeight(.bold)
                } icon: {
                    Image(systemName: "note.text")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash.fill")
                        .font(.callout)
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(.red.opacity(isHovered ? 0.2 : 0.1))
                        )
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3)) {
                        isHovered = hovering
                    }
                }
            }
            
            Text(notes)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.white.opacity(0.85))
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
                )
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Notes List with per-item delete
private struct RecipeNotesListView: View {
    let notes: [String]
    var onDelete: (Int) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Label {
                    Text("Notes")
                        .font(.title2)
                        .fontWeight(.bold)
                } icon: {
                    Image(systemName: "note.text")
                        .font(.title3)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.orange)
                }
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                    RecipeNoteCard(note: note) {
                        onDelete(index)
                    }
                }
            }
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }
}

private struct RecipeNoteCard: View {
    let note: String
    var onDelete: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Text(note)
                .font(.body)
                .lineSpacing(6)
                .foregroundStyle(.white.opacity(0.85))
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                        
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [.orange.opacity(0.3), .orange.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                    }
                    .shadow(color: .orange.opacity(0.1), radius: 10, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(isHovered ? 0.25 : 0.1), lineWidth: isHovered ? 2 : 1)
                )
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.3)) { isHovered = hovering }
                }
            
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.callout)
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.red.opacity(isHovered ? 0.2 : 0.1))
                    )
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .padding(10)
        }
    }
}

// MARK: - Premium Ingredients Section
private struct IngredientsSectionView: View {
    let ingredients: [Ingredient]
    let defaultServings: Int
    @Binding var currentServings: Int
    var servingsMultiplier: Double = 1.0
    @AppStorage("measurementSystem") private var measurementSystemRaw: String = MeasurementSystem.metric.rawValue
    private let stepperButtonShape = Circle()
    
    private var converter: UnitConverter {
        UnitConverter(system: MeasurementSystem(rawValue: measurementSystemRaw) ?? .metric)
    }
    
    private var minServings: Int { max(1, defaultServings / 2) }
    private var maxServings: Int {
        if defaultServings <= 2 { return 6 }
        if defaultServings <= 4 { return defaultServings * 2 }
        return min(defaultServings * 2, 20)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header with integrated servings stepper
            HStack {
                Image(systemName: "basket.fill")
                    .font(.title3)
                    .foregroundStyle(.green.gradient)
                
                Text("Ingredients")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Spacer()
                
                // Compact servings stepper
                HStack(spacing: 0) {
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            if currentServings > minServings {
                                currentServings -= 1
                            }
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(currentServings > minServings ? .white : .white.opacity(0.25))
                            .frame(width: 34, height: 40)
                            .background(
                                stepperButtonShape
                                    .fill(.white.opacity(0.001))
                            )
                            .clipShape(stepperButtonShape)
                    }
                    .buttonStyle(SpatialButtonStyle(shape: stepperButtonShape))
                    .polishedHover(scale: 1.08)
                    .disabled(currentServings <= minServings)
                    
                    // Servings display
                    VStack(spacing: 0) {
                        Text("\(currentServings)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                        
                        Text("servings")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                            .textCase(.uppercase)
                            .tracking(0.3)
                    }
                    .frame(width: 52, height: 40)
                    
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            if currentServings < maxServings {
                                currentServings += 1
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(currentServings < maxServings ? .white : .white.opacity(0.25))
                            .frame(width: 34, height: 40)
                            .background(
                                stepperButtonShape
                                    .fill(.white.opacity(0.001))
                            )
                            .clipShape(stepperButtonShape)
                    }
                    .buttonStyle(SpatialButtonStyle(shape: stepperButtonShape))
                    .polishedHover(scale: 1.08)
                    .disabled(currentServings >= maxServings)
                }
                .background(
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            
            if ingredients.isEmpty {
                EmptyIngredientsView()
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(Array(ingredients.enumerated()), id: \.element.id) { index, ingredient in
                        IngredientCard(ingredient: ingredient, index: index, converter: converter, servingsMultiplier: servingsMultiplier)
                    }
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Premium Instructions Section
private struct InstructionsSectionView: View {
    let steps: [Step]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack {
                Image(systemName: "list.number")
                    .font(.title3)
                    .foregroundStyle(.blue.gradient)
                
                Text("Instructions")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            
            LazyVStack(spacing: 16) {
                let sortedSteps = steps.sorted { $0.order < $1.order }
                ForEach(Array(sortedSteps.enumerated()), id: \.element.id) { index, step in
                    StepRow(step: step, index: index)
                }
            }
        }
        .frame(maxWidth: 760, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Premium Ingredient Card
private struct IngredientCard: View {
    let ingredient: Ingredient
    let index: Int
    var converter: UnitConverter
    var servingsMultiplier: Double = 1.0
    let cachedIcon: IngredientIconDescriptor
    
    @State private var isPressed = false
    @State private var isHovered = false
    @State private var isExpanded = false
    
    init(ingredient: Ingredient, index: Int, converter: UnitConverter, servingsMultiplier: Double = 1.0) {
        self.ingredient = ingredient
        self.index = index
        self.converter = converter
        self.servingsMultiplier = servingsMultiplier
        self.cachedIcon = resolveIngredientIcon(for: ingredient.name)
    }
    
    var quantityNumber: String {
        guard let q = ingredient.quantity else { return "" }
        let scaledQ = q * servingsMultiplier
        let unit = ingredient.unit ?? ""
        let (convertedQty, _) = converter.convert(quantity: scaledQ, unit: unit)
        return UnitConverter.formatQuantity(convertedQty)
    }
    
    var quantityUnit: String {
        guard ingredient.quantity != nil else { return "" }
        let unit = ingredient.unit ?? ""
        let scaledQ = (ingredient.quantity ?? 0) * servingsMultiplier
        let (_, convertedUnit) = converter.convert(quantity: scaledQ, unit: unit)
        return convertedUnit
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isHovered ?
                                [.green.opacity(0.4), .blue.opacity(0.4)] :
                                [.green.opacity(0.2), .blue.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                if let customAssetName = cachedIcon.customAssetName {
                    Image(customAssetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(Circle())
                        .foregroundStyle(.white.opacity(isHovered ? 1.0 : 0.9))
                        .shadow(color: .black.opacity(0.18), radius: 0.8, x: 0, y: 0.4)
                } else {
                    Image(systemName: cachedIcon.fallbackSystemName)
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(.white.opacity(isHovered ? 1.0 : 0.9))
                        .symbolRenderingMode(.monochrome)
                        .opacity(0.98)
                        .shadow(color: .black.opacity(0.18), radius: 0.8, x: 0, y: 0.4)
                }
            }
            .frame(width: 52, height: 52)
            .scaleEffect(isHovered ? 1.1 : 1.0)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(ingredient.name.capitalized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isHovered ? .white : .white.opacity(0.95))
                    .lineLimit(isExpanded ? nil : 2)
                    .minimumScaleFactor(0.85)
                
                if !quantityNumber.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(quantityNumber)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        Text(quantityUnit)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(isHovered ? 0.7 : 0.5))
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(minHeight: 80)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isHovered ? .white.opacity(0.15) : .white.opacity(0.05))
                
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(isHovered ? 0.4 : 0.1), lineWidth: isHovered ? 2 : 1)
            }
            .shadow(color: isHovered ? .white.opacity(0.2) : .clear, radius: 10, x: 0, y: 5)
        )
        .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.03 : 1.0))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
        .onLongPressGesture(minimumDuration: 0.1, maximumDistance: 10) {
            // Long press action
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

// MARK: - Premium Step Row
private struct StepRow: View {
    let step: Step
    let index: Int
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number with shimmer effect
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isHovered ?
                                [.purple.opacity(0.5), .blue.opacity(0.5)] :
                                [.purple.opacity(0.3), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text(String(format: "%02d", step.order))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)
            .overlay(
                Circle()
                    .stroke(.white.opacity(isHovered ? 0.4 : 0.2), lineWidth: isHovered ? 2 : 1.5)
            )
            .shadow(color: isHovered ? .purple.opacity(0.4) : .purple.opacity(0.2), radius: 8, x: 0, y: 4)
            .scaleEffect(isHovered ? 1.05 : 1.0)
            
            VStack(alignment: .leading, spacing: 14) {
                Text(step.text)
                    .font(.system(size: 16, weight: .regular))
                    .lineSpacing(6)
                    .foregroundStyle(isHovered ? .white : .white.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                
                if let duration = step.durationSec {
                    HStack(spacing: 8) {
                        Image(systemName: "timer")
                            .font(.callout)
                        Text(formatDuration(seconds: duration))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(.orange.opacity(isHovered ? 0.25 : 0.15))
                            .overlay(
                                Capsule()
                                    .stroke(.orange.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(isHovered ? .white.opacity(0.12) : .white.opacity(0.04))
                    
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(isHovered ? 0.3 : 0.08), lineWidth: isHovered ? 2 : 1)
                }
                .shadow(color: isHovered ? .white.opacity(0.1) : .clear, radius: 10, x: 0, y: 5)
            )
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .scaleEffect(isHovered ? 1.01 : 1.0)
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    func formatDuration(seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s"
        } else if seconds < 3600 {
            return "\(seconds/60)m"
        } else {
            let hours = seconds / 3600
            let mins = (seconds % 3600) / 60
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
    }
}

// MARK: - Premium Stats Bar
private struct StatsBarView: View {
    let recipe: Recipe
    
    // Logic for Time Format
    var formattedTime: String {
        let mins = recipe.totalTimeMinutes
        if mins > 60 {
            let h = mins / 60
            let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(mins)"
    }
    
    var timeUnit: String {
        recipe.totalTimeMinutes > 60 ? "" : "min"
    }
    
    var body: some View {
        HStack(spacing: 0) {
            StatItem(
                icon: "clock.fill",
                value: formattedTime,
                unit: timeUnit,
                gradient: [.blue, .cyan]
            )
            
            Divider()
                .frame(height: 40)
                .overlay(.white.opacity(0.15))
                .padding(.horizontal, 20)
            
            StatItem(
                icon: "flame.fill",
                value: "\(recipe.calories)",
                unit: "kcal",
                gradient: [.orange, .red]
            )
            
            Divider()
                .frame(height: 40)
                .overlay(.white.opacity(0.15))
                .padding(.horizontal, 20)
            
            StatItem(
                icon: "chart.bar.fill",
                value: recipe.difficulty,
                unit: "",
                gradient: [.green, .mint]
            )
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 32)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.2), .white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
        )
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }
}

private struct StatItem: View {
    let icon: String
    let value: String
    let unit: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolRenderingMode(.hierarchical)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.6))
                        .textCase(.uppercase)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Premium Rating View
private struct RatingView: View {
    let rating: Double
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "star.fill")
                .font(.title3)
                .foregroundStyle(.yellow.gradient)
                .symbolEffect(.bounce, value: rating)
            
            Text(String(format: "%.1f", rating))
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .yellow.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .overlay(
            Capsule()
                .stroke(.yellow.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Difficulty Badge
private struct DifficultyBadge: View {
    let difficulty: String
    
    var difficultyColor: Color {
        switch difficulty.lowercased() {
        case "easy": return .green
        case "medium": return .orange
        case "hard": return .red
        default: return .blue
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(difficultyColor.gradient)
                .frame(width: 8, height: 8)
            
            Text(difficulty.capitalized)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule()
                .stroke(difficultyColor.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Premium Favorite Button
private struct RecipeFavoriteButton: View {
    @Bindable var recipe: Recipe
    @Environment(\.modelContext) private var context
    @State private var isPulsing = false
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                recipe.isFavorite.toggle()
                isPulsing = true
            }
            context.saveAndSync(recipe)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isPulsing = false
            }
        } label: {
            Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(recipe.isFavorite ? AnyShapeStyle(.red.gradient) : AnyShapeStyle(.white.gradient))
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .symbolEffect(.bounce, value: recipe.isFavorite)
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

// MARK: - Premium Start Cooking Button
private struct StartCookingButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                
                Text("Start Cooking")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 48)
            .padding(.vertical, 18)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.orange,
                                Color.orange.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: .orange.opacity(0.4), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(SpatialButtonStyle(shape: Capsule()))
        .polishedHover(scale: 1.06)
    }
}

// MARK: - Empty State
private struct EmptyIngredientsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "basket")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No ingredients listed")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.03))
        )
    }
}

// MARK: - Helpers
struct CustomCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Ingredient Icon Logic
struct IngredientIconDescriptor {
    let customAssetName: String?
    let fallbackSystemName: String
}

func resolveIngredientIcon(for ingredientName: String) -> IngredientIconDescriptor {
    let fallbackSystemName = getIconName(for: ingredientName)
    let normalizedName = ingredientName.lowercased()

    let customRules: [([String], String)] = [
        // Specific matches first (longer/more specific keywords before shorter ones)
        (["apple cider vinegar"], "Apple_cider_vinegar"),
        (["balsamic glaze"], "Balsamic_glaze"),
        (["bamboo shoot"], "Bamboo_shoots_drained"),
        (["basil pesto", "pesto"], "Basil_pesto"),
        (["bean sprout", "sprout"], "Bean_sprouts"),
        (["beef broth", "beef stock"], "Beef_broth"),
        (["beef knuckle", "marrow bone"], "Beef_knuckle_or_marrow_bones"),
        (["beef sirloin", "sirloin", "ribeye", "flank steak", "beef short rib"], "Beef_sirloin_thinly_sliced"),
        (["bbq sauce"], "BBQ_sauce"),
        (["black pepper"], "Black_pepper_freshly_cracked"),
        (["bone-in ham", "ham"], "Bone_in_ham"),
        (["cherry tomato"], "Cherry_Tomatoes"),
        (["chicken breast", "chicken tender"], "Chicken_breast_cubed"),
        (["chicken thigh", "chicken"], "Whole_chicken_cut"),
        (["chocolate chip"], "Chocolate_chips"),
        (["chocolate", "cocoa"], "Dark_Chocolate_70"),
        (["cold beer", "beer"], "Cold_beer"),
        (["egg yolk"], "Egg_yolks"),
        (["soft-boiled egg", "soft boiled egg"], "Soft_boiled_eggs"),
        (["green onion", "scallion"], "Green_onions_chopped"),
        (["ground beef", "ground lamb", "ground turkey", "ground meat"], "Ground_beef"),
        (["gruyere", "gruyère"], "Gruyere_cheese"),
        (["cheddar", "american cheese", "cheese slice", "sharp cheddar"], "American_or_Cheddar_cheese_slices"),
        (["maple syrup"], "Maple_syrup"),
        (["olive oil", "extra virgin"], "Extra_virgin_olive_oil"),
        (["pizza dough"], "Pre_made_pizza_dough_room_temp"),
        (["pie crust"], "Pie_crusts"),
        (["pomegranate"], "Pomegranate_seeds"),
        (["spring roll", "wonton wrapper"], "Spring_roll_wrappers"),
        (["star anise"], "Star_anise"),
        (["sweet potato"], "Sweet_potatoes_cut_into_thin_sticks"),
        (["whole chicken"], "Whole_chicken_cut"),
        (["ladyfinger", "savoiardi"], "Ladyfinger_cookies_Savoiardi_biscuits"),
        (["wooden skewer", "skewer"], "Wooden_skewers"),

        // General matches
        (["flour"], "All_Purpose_Flour"),
        (["milk", "almond milk", "buttermilk"], "Almond_milk"),
        (["rice", "arborio", "sushi rice", "quinoa"], "Arborio_rice"),
        (["asparagus"], "Asparagus_trimmed"),
        (["avocado"], "Avocado_sliced"),
        (["bacon", "pancetta"], "Bacon_chopped"),
        (["baguette", "bread", "flatbread"], "Baguette"),
        (["bell pepper", "red bell pepper"], "Bell_peppers"),
        (["black bean", "kidney bean", "beans"], "Black_beans"),
        (["breadcrumb", "panko"], "Breadcrumbs"),
        (["broccoli"], "Broccoli_florets"),
        (["bun", "hamburger bun"], "Burger_buns"),
        (["butter"], "Butter"),
        (["caper"], "Capers_drained"),
        (["carrot"], "Carrots_chopped"),
        (["cauliflower"], "Cauliflower_florets"),
        (["celery"], "Celery_stalks_diced"),
        (["chia"], "Chia_seeds"),
        (["chickpea"], "Chickpeas_drained"),
        (["cinnamon"], "Cinnamon_stick"),
        (["cod", "haddock", "tilapia", "fish"], "Cod_or_haddock_fillets"),
        (["cucumber"], "Cucumber"),
        (["cumin"], "Cumin_powder"),
        (["mustard", "dijon"], "Dijon_mustard"),
        (["egg"], "Egg"),
        (["macaroni", "elbow"], "Elbow_macaroni"),
        (["tofu"], "Firm_tofu_pressed_and_cubed"),
        (["basil", "cilantro", "parsley", "herb", "thyme", "mint", "chive"], "Fresh_Basil"),
        (["rosemary"], "Fresh_rosemary"),
        (["spinach", "kale", "arugula", "lettuce", "cabbage"], "Fresh_spinach_leaves"),
        (["garlic"], "Garlic"),
        (["ginger"], "Ginger_sliced"),
        (["apple"], "Granny_Smith_apples_cubed"),
        (["sugar", "powdered sugar", "brown sugar"], "Granulated_sugar"),
        (["cream", "sour cream", "cream cheese", "mascarpone", "ricotta"], "Heavy_cream"),
        (["honey"], "Honey"),
        (["jalapeño", "jalapeno"], "Jalapeno_pepper_minced_seeds_removed"),
        (["eggplant"], "Large_eggplants"),
        (["lasagna"], "Lasagna_noodles_boiled"),
        (["lemon", "lime", "citrus"], "Lemon_sliced"),
        (["mayonnaise"], "Mayonnaise"),
        (["mushroom"], "Mushrooms_sliced"),
        (["seaweed", "nori"], "Nori_seaweed_sheets"),
        (["onion"], "Onion_chopped"),
        (["banana"], "Overripe_bananas_mashed"),
        (["parmesan", "pecorino", "feta", "mozzarella", "cheese"], "Parmesan_cheese_grated"),
        (["peanut"], "Peanuts_Crushed"),
        (["penne", "pasta", "noodle", "udon"], "Penne_pasta"),
        (["pineapple"], "Pineapple_chunks"),
        (["pita"], "Pita_breads"),
        (["potato", "gnocchi"], "Potatoes_cubed"),
        (["ramen"], "Ramen_noodles"),
        (["salt", "sea salt"], "Salt"),
        (["scallop"], "Sea_scallops"),
        (["shrimp", "prawn"], "Shrimp"),
        (["soy sauce", "fish sauce", "mirin", "rice vinegar", "vinegar", "worcestershire"], "Soy_sauce"),
        (["spaghetti"], "Spaghetti"),
        (["squid", "calamari"], "Squid_rings"),
        (["strawberry", "berries", "berry"], "Strawberries"),
        (["coffee", "espresso"], "Strong_brewed_espresso_or_coffee_cooled"),
        (["tahini"], "Tahini"),
        (["tomato", "marinara", "pizza sauce", "salsa", "tomato paste", "tomato puree"], "Tomatoes_ripe"),
        (["vanilla"], "Vanilla_bean"),
        (["walnut", "oat", "rolled oat"], "Walnuts_Chopped_walnuts"),
        (["water", "broth", "stock", "ice water"], "Water"),
        (["wine", "white wine", "red wine"], "White_wine"),
        (["zucchini"], "Zucchini_sliced"),
        (["oil", "vegetable oil", "coconut oil", "sesame oil"], "Extra_virgin_olive_oil"),
        (["pepper", "paprika", "cayenne", "red pepper flake", "chili"], "Bell_peppers"),
        (["corn", "polenta", "cornmeal", "cornstarch"], "Peanuts_Crushed"),
        (["salmon"], "Cod_or_haddock_fillets"),
        (["pork", "veal"], "Beef_sirloin_thinly_sliced"),
        (["yogurt"], "Heavy_cream"),
        (["gelatin", "baking powder", "baking soda", "yeast"], "Salt"),
        (["ketchup", "hot sauce", "curry paste", "tamarind"], "Soy_sauce"),
        (["coconut milk", "coconut"], "Almond_milk"),
        (["food coloring", "nutmeg", "turmeric", "coriander", "garam masala", "oregano", "thyme", "smoked paprika"], "Cumin_powder")
    ]

    if let assetName = customRules.first(where: { keywords, _ in
        keywords.contains(where: { normalizedName.contains($0) })
    })?.1 {
        return IngredientIconDescriptor(customAssetName: assetName, fallbackSystemName: fallbackSystemName)
    }

    return IngredientIconDescriptor(customAssetName: nil, fallbackSystemName: fallbackSystemName)
}

func getIconName(for ingredientName: String) -> String {
    let name = ingredientName.lowercased()
    
    // 1. Fish icon - only for fish
    if name.contains("fish") || name.contains("salmon") || name.contains("tuna") || 
       name.contains("cod") || name.contains("trout") {
        return "fish.fill"
    }
    
    // 2. Carrot icon - only for carrots
    if name.contains("carrot") {
        return "carrot.fill"
    }
    
    // 3. Leaf icon - only for leafy greens
    if name.contains("lettuce") || name.contains("spinach") || name.contains("kale") ||
       name.contains("arugula") || name.contains("chard") {
        return "leaf.fill"
    }
    
    // 4. Drop icon - only for liquids/oils
    if name.contains("oil") || name.contains("water") || name.contains("vinegar") ||
       name.contains("wine") || name.contains("juice") || name.contains("broth") ||
       name.contains("stock") || name.contains("milk") {
        return "drop.fill"
    }
    
    // 5. Egg icon - only for eggs
    if name.contains("egg") {
        return "oval.portrait.fill"
    }
    
    // Generic fallback for everything else
    return "fork.knife.circle.fill"
}
