import Foundation

struct RecipePreferenceKeys {
    static let preferredDiets = "preferredDiets"
    static let excludedAllergens = "excludedAllergens"
}

enum DietaryPreference: String, CaseIterable, Identifiable {
    case vegan
    case vegetarian
    case pescatarian
    case glutenFree
    case dairyFree

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vegan: return "Vegan"
        case .vegetarian: return "Vegetarian"
        case .pescatarian: return "Pescatarian"
        case .glutenFree: return "Gluten-Free"
        case .dairyFree: return "Dairy-Free"
        }
    }

    var subtitle: String {
        switch self {
        case .vegan: return "No animal products"
        case .vegetarian: return "No meat or seafood"
        case .pescatarian: return "Seafood allowed, no meat"
        case .glutenFree: return "Exclude gluten ingredients"
        case .dairyFree: return "Exclude milk-based ingredients"
        }
    }
}

enum RecipeAllergen: String, CaseIterable, Identifiable {
    case gluten
    case dairy
    case eggs
    case peanuts
    case treeNuts
    case soy
    case sesame
    case fish
    case shellfish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gluten: return "Gluten"
        case .dairy: return "Dairy"
        case .eggs: return "Eggs"
        case .peanuts: return "Peanuts"
        case .treeNuts: return "Tree Nuts"
        case .soy: return "Soy"
        case .sesame: return "Sesame"
        case .fish: return "Fish"
        case .shellfish: return "Shellfish"
        }
    }
}

extension String {
    func rawValueSet<T: RawRepresentable>(for type: T.Type) -> Set<T> where T.RawValue == String {
        Set(
            split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .compactMap(T.init(rawValue:))
        )
    }
}

extension Set where Element: RawRepresentable, Element.RawValue == String {
    var rawString: String {
        map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }
}

enum RecipePreferenceFilter {
    static func filter(
        _ recipes: [Recipe],
        diets: Set<DietaryPreference>,
        allergens: Set<RecipeAllergen>
    ) -> [Recipe] {
        recipes.filter { matches($0, diets: diets, allergens: allergens) }
    }

    static func matches(
        _ recipe: Recipe,
        diets: Set<DietaryPreference>,
        allergens: Set<RecipeAllergen>
    ) -> Bool {
        let analyzer = RecipeContentAnalyzer(recipe: recipe)

        // Allergy exclusions
        if allergens.contains(.gluten), analyzer.hasGluten { return false }
        if allergens.contains(.dairy), analyzer.hasDairy { return false }
        if allergens.contains(.eggs), analyzer.hasEggs { return false }
        if allergens.contains(.peanuts), analyzer.hasPeanuts { return false }
        if allergens.contains(.treeNuts), analyzer.hasTreeNuts { return false }
        if allergens.contains(.soy), analyzer.hasSoy { return false }
        if allergens.contains(.sesame), analyzer.hasSesame { return false }
        if allergens.contains(.fish), analyzer.hasFish { return false }
        if allergens.contains(.shellfish), analyzer.hasShellfish { return false }

        // Dietary preferences (all selected preferences must be satisfied)
        if diets.contains(.vegan), !analyzer.isVegan { return false }
        if diets.contains(.vegetarian), !analyzer.isVegetarian { return false }
        if diets.contains(.pescatarian), !analyzer.isPescatarian { return false }
        if diets.contains(.glutenFree), analyzer.hasGluten { return false }
        if diets.contains(.dairyFree), analyzer.hasDairy { return false }

        return true
    }
}

private struct RecipeContentAnalyzer {
    private let haystack: String
    private let tags: [String]

    init(recipe: Recipe) {
        self.tags = recipe.tags.map { $0.lowercased() }
        let title = recipe.title.lowercased()
        let ingredients = recipe.ingredients.map { $0.name.lowercased() }.joined(separator: " ")
        let tagText = tags.joined(separator: " ")
        self.haystack = [title, ingredients, tagText].joined(separator: " ")
    }

    private func containsAny(_ keywords: [String]) -> Bool {
        keywords.contains { haystack.contains($0) }
    }

    private func hasTag(_ keyword: String) -> Bool {
        tags.contains { $0.contains(keyword) }
    }

    private var hasMeat: Bool {
        // Strip "graham" first so its "ham" substring doesn't cause a false positive.
        let cleaned = haystack.replacingOccurrences(of: "graham", with: "")
        return [
            "beef", "pork", "chicken", "turkey", "ham", "bacon", "sausage", "lamb", "veal", "pepperoni", "prosciutto"
        ].contains { cleaned.contains($0) }
    }

    var hasFish: Bool {
        containsAny([
            "fish", "salmon", "tuna", "tilapia", "cod", "anchovy", "sardine", "trout"
        ])
    }

    var hasShellfish: Bool {
        containsAny([
            "shrimp", "prawn", "crab", "lobster", "clam", "mussel", "oyster", "scallop", "calamari", "squid"
        ])
    }

    var hasDairy: Bool {
        if hasTag("dairy-free") { return false }
        return containsAny([
            "milk", "cheese", "butter", "cream", "yogurt", "ricotta", "mozzarella", "parmesan", "cheddar", "ghee"
        ])
    }

    var hasEggs: Bool {
        // Strip "eggplant" first so its "egg" substring doesn't cause a false positive.
        let cleaned = haystack.replacingOccurrences(of: "eggplant", with: "")
        return ["egg", "mayonnaise", "mayo"].contains { cleaned.contains($0) }
    }

    var hasGluten: Bool {
        if hasTag("gluten-free") { return false }
        return containsAny([
            "wheat", "flour", "bread", "pasta", "noodle", "barley", "rye", "seitan", "breadcrumbs", "pita", "soy sauce"
        ])
    }

    var hasSoy: Bool {
        containsAny(["soy", "tofu", "tempeh", "miso", "edamame"])
    }

    var hasSesame: Bool {
        containsAny(["sesame", "tahini"])
    }

    var hasPeanuts: Bool {
        containsAny(["peanut"])
    }

    var hasTreeNuts: Bool {
        containsAny(["almond", "walnut", "cashew", "pistachio", "hazelnut", "pecan", "nutella"])
    }

    var isVegetarian: Bool {
        if hasTag("vegetarian") || hasTag("vegan") { return true }
        return !hasMeat && !hasFish && !hasShellfish
    }

    var isVegan: Bool {
        if hasTag("vegan") { return true }
        return isVegetarian && !hasDairy && !hasEggs && !containsAny(["honey"])
    }

    var isPescatarian: Bool {
        if hasTag("pescatarian") { return true }
        return !hasMeat
    }
}
