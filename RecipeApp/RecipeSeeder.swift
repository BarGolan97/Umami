import Foundation
import SwiftData
import UIKit

@MainActor
class RecipeSeeder {
    
    // MARK: - Built-in Recipe IDs (לא יימחקו גם בלי חיבור לענן)
    static let builtInRecipeIDs: Set<String> = [
        "pizza-margherita-001",
        "smash-burger-004",
        "lava-cake-005",
        "pad-thai-006",
        "guacamole-007",
        "aglio-019",
        "carbonara-021",
        "caprese-020",
        "cheesecake-013",
        "brulee-015",
        "crumble-012",
        "quinoa-salad-003",
        "bolognese-ragu-002",
        "french-onion-soup-008",
        "homemade-pizza-009",
        "mousse-010",
        "piccata-022",
        "risotto-023",
        "tiramisu-027",
        "scramble-046"
    ]
    
    // MARK: - Seed Built-in Recipes (נקרא בעליית האפליקציה)
    /// טוען מתכונים מובנים למכשיר - עובד גם בלי חיבור לאינטרנט
    static func seedBuiltInRecipes(modelContext: ModelContext) {
        print("📦 Checking for built-in recipes...")
        
        // בדיקה אילו מתכונים כבר קיימים
        let existingRecipes = (try? modelContext.fetch(FetchDescriptor<Recipe>())) ?? []
        let existingIDs = Set(existingRecipes.map { $0.id })
        
        // רשימת המתכונים המובנים
        let builtInRecipes: [Recipe] = [
            createMargheritaPizza(),
            createClassicBurger(),
            createChocolateLavaCake(),
            createPadThai(),
            createGuacamole(),
            createAglioEOlio(),
            createCarbonara(),
            createCapreseSalad(),
            createNYCheesecake(),
            createCremeBrulee(),
            createAppleCrumble(),
            createMediterraneanQuinoa(),
            createAuthenticBolognese(),
            createFrenchOnionSoup(),
            createHomemadePizza(),
            createChocolateMousse(),
            createChickenPiccata(),
            createMushroomRisotto(),
            createTiramisu(),
            createScrambledEggs()
        ]
        
        var addedCount = 0
        for recipe in builtInRecipes {
            if !existingIDs.contains(recipe.id) {
                // סימון המתכון כמובנה
                recipe.isBuiltIn = true
                modelContext.insert(recipe)
                addedCount += 1
                print("✅ Added built-in recipe: \(recipe.title)")
            }
        }
        
        if addedCount > 0 {
            try? modelContext.save()
            print("📦 Added \(addedCount) built-in recipes")
        } else {
            print("📦 All built-in recipes already exist")
        }
    }
    
    // MARK: - Migrate defaultServings for existing recipes
    static func migrateDefaultServings(modelContext: ModelContext) {
        let servingsMap: [String: Int] = [
            // RecipeSeeder (20 recipes)
            "pizza-margherita-001": 2,
            "smash-burger-004": 2,
            "lava-cake-005": 4,
            "pad-thai-006": 2,
            "guacamole-007": 4,
            "aglio-019": 4,
            "carbonara-021": 4,
            "caprese-020": 4,
            "cheesecake-013": 8,
            "brulee-015": 4,
            "crumble-012": 6,
            "quinoa-salad-003": 4,
            "bolognese-ragu-002": 6,
            "french-onion-soup-008": 4,
            "homemade-pizza-009": 4,
            "mousse-010": 6,
            "piccata-022": 2,
            "risotto-023": 4,
            "tiramisu-027": 8,
            "scramble-046": 2,
            // RecipeSeeder2 (50 recipes)
            "ramen-101": 6,
            "butterchicken-102": 4,
            "tikkamasala-103": 4,
            "pho-104": 6,
            "sweetandsour-105": 4,
            "greencurry-106": 4,
            "beefteriyaki-107": 4,
            "sushi-108": 3,
            "springrolls-109": 4,
            "bulgogi-110": 4,
            "lasagna-111": 6,
            "gnocchi-112": 4,
            "scampi-113": 4,
            "eggplantparm-114": 6,
            "focaccia-115": 8,
            "ravioli-116": 4,
            "arrabbiata-117": 4,
            "ossobuco-118": 4,
            "calamari-119": 4,
            "minestrone-120": 6,
            "hummus-121": 6,
            "shawarma-122": 4,
            "falafel-123": 4,
            "kofta-124": 4,
            "babaganoush-125": 6,
            "friedchicken-126": 4,
            "pulledpork-127": 8,
            "macandcheese-128": 6,
            "chickentenders-129": 4,
            "potpie-130": 6,
            "turkeyburgers-131": 4,
            "bakedham-132": 8,
            "shortribs-133": 4,
            "salmon-134": 2,
            "clamchowder-135": 4,
            "tilapia-136": 2,
            "fishandchips-137": 4,
            "scallops-138": 2,
            "butternutsquash-139": 6,
            "stuffedpeppers-140": 4,
            "sweetpotatofries-141": 4,
            "chiapudding-142": 2,
            "cauliflowersalad-143": 4,
            "cinnamonrolls-144": 8,
            "bananabread-145": 8,
            "brownies-146": 9,
            "crepes-147": 4,
            "pannacotta-148": 6,
            "lemonpoundcake-149": 8,
            "redvelvet-150": 10,
        ]
        
        guard let recipes = try? modelContext.fetch(FetchDescriptor<Recipe>()) else { return }
        
        var updated = 0
        for recipe in recipes {
            if let correctServings = servingsMap[recipe.id] {
                if recipe.defaultServings != correctServings {
                    recipe.defaultServings = correctServings
                    updated += 1
                }
            } else if recipe.defaultServings == 4 {
                // For unknown recipes (e.g. from cloud), infer from ingredients
                let inferred = inferServings(from: recipe)
                if inferred != 4 {
                    recipe.defaultServings = inferred
                    updated += 1
                }
            }
        }
        
        if updated > 0 {
            try? modelContext.save()
            print("🍽️ Updated servings for \(updated) recipes")
        }
    }
    
    /// Infer a reasonable serving count from ingredient quantities
    private static func inferServings(from recipe: Recipe) -> Int {
        let ingredients = recipe.ingredients
        guard !ingredients.isEmpty else { return 4 }
        
        // Look at protein quantities for clues
        for ing in ingredients {
            let name = ing.name.lowercased()
            guard let qty = ing.quantity, let unit = ing.unit?.lowercased() else { continue }
            
            // Chicken breasts — typically 1 per person
            if name.contains("chicken breast") && (unit == "units" || unit == "unit") {
                return max(1, Int(qty))
            }
            // Eggs as main ingredient (breakfast dishes)
            if name == "eggs" || name == "egg" {
                let tags = recipe.tagsRaw.lowercased()
                if tags.contains("breakfast") {
                    return max(1, Int(qty / 2))
                }
            }
            // Burger patties / buns
            if (name.contains("bun") || name.contains("patties") || name.contains("patty")) && (unit == "units" || unit == "unit") {
                return max(1, Int(qty))
            }
            // Fish fillets
            if (name.contains("fillet") || name.contains("salmon") || name.contains("tilapia")) && (unit == "units" || unit == "unit") {
                return max(1, Int(qty))
            }
            // Steak
            if name.contains("steak") && (unit == "units" || unit == "unit") {
                return max(1, Int(qty))
            }
        }
        
        // Look at main starch/grain quantities
        for ing in ingredients {
            let name = ing.name.lowercased()
            guard let qty = ing.quantity, let unit = ing.unit?.lowercased() else { continue }
            
            // Pasta/rice quantities
            if (name.contains("pasta") || name.contains("spaghetti") || name.contains("penne") || name.contains("rice")) && unit == "g" {
                // ~100-120g of dry pasta per person
                return max(1, min(8, Int(round(qty / 110.0))))
            }
        }
        
        return 4 // Safe fallback
    }
    
    // MARK: - ================= 20 BUILT-IN RECIPES =================
    
    private static func createFrenchOnionSoup() -> Recipe {
        let ingredients = [
            Ingredient(name: "Yellow Onions", quantity: 4.0, unit: "units"),
            Ingredient(name: "Butter", quantity: 50.0, unit: "g"),
            Ingredient(name: "Beef Broth", quantity: 1.0, unit: "liter"),
            Ingredient(name: "White Wine", quantity: 100.0, unit: "ml"),
            Ingredient(name: "Thyme", quantity: 3.0, unit: "sprigs"),
            Ingredient(name: "Baguette", quantity: 4.0, unit: "slices"),
            Ingredient(name: "Gruyère Cheese", quantity: 100.0, unit: "g")
        ]
        
        let steps = [
            Step(order: 1, text: "Slice onions thinly.", localImageName: "FrenchOnionSoup1"),
            Step(order: 2, text: "Caramelize onions in butter on low heat (40 mins).", durationSec: 2400, localImageName: "FrenchOnionSoup2"),
            Step(order: 3, text: "Deglaze with wine, then add beef broth and thyme.", localImageName: "FrenchOnionSoup3"),
            Step(order: 4, text: "Simmer for 30 minutes.", durationSec: 1800, localImageName: "FrenchOnionSoup4"),
            Step(order: 5, text: "Ladle into oven-safe bowls.", localImageName: "FrenchOnionSoup5"),
            Step(order: 6, text: "Top with baguette slice and grated cheese.", localImageName: "FrenchOnionSoup6"),
            Step(order: 7, text: "Broil until cheese is bubbly and brown.", durationSec: 180, localImageName: "FrenchOnionSoup7")
        ]
        
        return Recipe(
            id: "french-onion-soup-008",
            title: "Classic French Onion Soup",
            localImageName: "FrenchOnionSoupHeader",
            imageURL: nil,
            totalTimeMinutes: 90,
            difficulty: "Medium",
            calories: 400,
            rating: 4.4,
            tags: ["French", "Soup", "Winter"],
            ingredients: ingredients,
            steps: steps
        )
    }

    private static func createMargheritaPizza() -> Recipe {
        let ingredients = [
            Ingredient(name: "Type 00 Pizza Flour", quantity: 500.0, unit: "g"),
            Ingredient(name: "Warm Water", quantity: 325.0, unit: "ml"),
            Ingredient(name: "Fine Sea Salt", quantity: 10.0, unit: "g"),
            Ingredient(name: "Dry Yeast", quantity: 3.0, unit: "g"),
            Ingredient(name: "San Marzano Tomatoes", quantity: 200.0, unit: "g"),
            Ingredient(name: "Fresh Mozzarella", quantity: 125.0, unit: "g"),
            Ingredient(name: "Fresh Basil", quantity: 8.0, unit: "leaves"),
            Ingredient(name: "Extra Virgin Olive Oil", quantity: 1.0, unit: "tbsp")
        ]
        
        let steps = [
            Step(order: 1, text: "Combine flour and yeast in a bowl, then slowly add water.", localImageName: "NeapolitanMargheritaPizza1"),
            Step(order: 2, text: "Knead for 10 minutes until elastic and smooth.", durationSec: 600, localImageName: "NeapolitanMargheritaPizza2"),
            Step(order: 3, text: "Let rise for 2 hours until doubled.", durationSec: 7200, localImageName: "NeapolitanMargheritaPizza3"),
            Step(order: 4, text: "Divide into two balls and proof for 1 hour.", durationSec: 3600, localImageName: "NeapolitanMargheritaPizza4"),
            Step(order: 5, text: "Stretch into a thin circle.", localImageName: "NeapolitanMargheritaPizza5"),
            Step(order: 6, text: "Top with tomatoes, mozzarella, and oil.", localImageName: "NeapolitanMargheritaPizza6"),
            Step(order: 7, text: "Bake at 500°F (260°C) for 7 mins. Garnish with basil.", durationSec: 420, localImageName: "NeapolitanMargheritaPizza7")
        ]
        
        return Recipe(
            id: "pizza-margherita-001",
            title: "Classic Neapolitan Margherita",
            localImageName: "NeapolitanMargheritaPizzaHeader",
            imageURL: nil,
            totalTimeMinutes: 180,
            difficulty: "Hard",
            calories: 820,
            rating: 4.9,
            defaultServings: 2,
            tags: ["Italian", "Pizza", "Vegetarian"],
            ingredients: ingredients,
            steps: steps
        )
    }

    private static func createAuthenticBolognese() -> Recipe {
        let ingredients = [
            Ingredient(name: "Ground Beef", quantity: 500.0, unit: "g"),
            Ingredient(name: "Diced Pancetta", quantity: 100.0, unit: "g"),
            Ingredient(name: "Onion, Carrot, Celery (finely diced)", quantity: 150.0, unit: "g"),
            Ingredient(name: "Dry Red Wine", quantity: 150.0, unit: "ml"),
            Ingredient(name: "Tomato Paste", quantity: 2.0, unit: "tbsp"),
            Ingredient(name: "Whole Milk", quantity: 100.0, unit: "ml"),
            Ingredient(name: "Beef Stock", quantity: 250.0, unit: "ml"),
            Ingredient(name: "Olive Oil", quantity: 2.0, unit: "tbsp")
        ]
        
        let steps = [
            Step(order: 1, text: "Sauté vegetables and pancetta in olive oil.", localImageName: "AuthenticBologneseRagu1"),
            Step(order: 2, text: "Brown the beef thoroughly.", localImageName: "AuthenticBologneseRagu2"),
            Step(order: 3, text: "Stir in tomato paste and cook for 3 mins.", durationSec: 180, localImageName: "AuthenticBologneseRagu3"),
            Step(order: 4, text: "Deglaze the pot with red wine.", localImageName: "AuthenticBologneseRagu4"),
            Step(order: 5, text: "Simmer with stock for 2.5 hours on low heat.", durationSec: 9000, localImageName: "AuthenticBologneseRagu5"),
            Step(order: 6, text: "Add milk and simmer for 15 more minutes.", durationSec: 900, localImageName: "AuthenticBologneseRagu6"),
            Step(order: 7, text: "Serve with Parmesan over tagliatelle.", localImageName: "AuthenticBologneseRagu7")
        ]
        
        return Recipe(
            id: "bolognese-ragu-002",
            title: "Authentic Bolognese Ragu",
            localImageName: "AuthenticBologneseRaguHeader",
            imageURL: nil,
            totalTimeMinutes: 180,
            difficulty: "Medium",
            calories: 680,
            rating: 4.8,
            defaultServings: 6,
            tags: ["Italian", "Meat", "Dinner"],
            ingredients: ingredients,
            steps: steps
        )
    }

    private static func createMediterraneanQuinoa() -> Recipe {
        let ingredients = [
            Ingredient(name: "Dry Quinoa", quantity: 170.0, unit: "g"),
            Ingredient(name: "Cucumber", quantity: 2.0, unit: "units"),
            Ingredient(name: "Cherry Tomatoes", quantity: 150.0, unit: "g"),
            Ingredient(name: "Fresh Parsley (chopped)", quantity: 30.0, unit: "g"),
            Ingredient(name: "Red Onion (finely diced)", quantity: 40.0, unit: "g"),
            Ingredient(name: "Olive Oil", quantity: 4.0, unit: "tbsp"),
            Ingredient(name: "Lemon Juice", quantity: 3.0, unit: "tbsp"),
            Ingredient(name: "Feta Cheese", quantity: 50.0, unit: "g")
        ]
        
        let steps = [
            Step(order: 1, text: "Rinse quinoa to remove bitterness.", localImageName: "MediterraneanQuinoaSalad1"),
            Step(order: 2, text: "Boil with water, then simmer for 15 mins.", durationSec: 900, localImageName: "MediterraneanQuinoaSalad2"),
            Step(order: 3, text: "Fluff and cool to room temperature.", localImageName: "MediterraneanQuinoaSalad3"),
            Step(order: 4, text: "Chop vegetables and herbs into small cubes.", localImageName: "MediterraneanQuinoaSalad4"),
            Step(order: 5, text: "Whisk lemon juice and olive oil for the dressing.", localImageName: "MediterraneanQuinoaSalad5"),
            Step(order: 6, text: "Mix everything and top with feta.", localImageName: "MediterraneanQuinoaSalad6")
        ]
        
        return Recipe(
            id: "quinoa-salad-003",
            title: "Mediterranean Quinoa Salad",
            localImageName: "MediterraneanQuinoaHeader",
            imageURL: nil,
            totalTimeMinutes: 30,
            difficulty: "Easy",
            calories: 340,
            rating: 4.3,
            tags: ["Healthy", "Vegetarian", "Salad"],
            ingredients: ingredients,
            steps: steps
        )
    }
    
    private static func createClassicBurger() -> Recipe {
        let ingredients = [
            Ingredient(name: "Ground beef (80% lean / 20% fat)", quantity: 450.0, unit: "g"),
            Ingredient(name: "Salt", quantity: 1.0, unit: "tsp"),
            Ingredient(name: "Black pepper", quantity: 0.5, unit: "tsp"),
            Ingredient(name: "Hamburger buns", quantity: 4.0, unit: "units"),
            Ingredient(name: "American or Cheddar cheese (slices)", quantity: 4.0, unit: "slices"),
            Ingredient(name: "Butter (for toasting buns)", quantity: 1.0, unit: "tbsp")
        ]
        
        let steps = [
            Step(order: 1, text: "Divide the ground beef into 4 equal portions and loosely form them into balls. Do not pack them tight.", localImageName: "ClassicSmashBurger1"),
            Step(order: 2, text: "Heat a cast-iron skillet or heavy pan over medium-high heat for 3 minutes until very hot.", durationSec: 180, localImageName: "ClassicSmashBurger2"),
            Step(order: 3, text: "Butter the cut side of the buns and toast them in the pan for 1 minute until golden. Remove and set aside.", durationSec: 60, localImageName: "ClassicSmashBurger3"),
            Step(order: 4, text: "Place the beef balls into the hot pan. Immediately smash them flat with a spatula. Season generously with salt and pepper.", localImageName: "ClassicSmashBurger4"),
            Step(order: 5, text: "Cook undisturbed for 3 minutes until a deep brown crust forms.", durationSec: 180, localImageName: "ClassicSmashBurger5"),
            Step(order: 6, text: "Flip the patties and cook for 1 minute.", durationSec: 60, localImageName: "ClassicSmashBurger6"),
            Step(order: 7, text: "Place a slice of cheese on each patty, cover the pan with a lid (or foil), and cook for 1 minute to melt the cheese.", durationSec: 60, localImageName: "ClassicSmashBurger7"),
            Step(order: 8, text: "Assemble the burgers on the toasted buns immediately.", localImageName: "ClassicSmashBurger7")
        ]
        
        return Recipe(
            id: "smash-burger-004",
            title: "Classic Smash Burger",
            localImageName: "ClassicSmashBurgerHeader",
            imageURL: nil,
            totalTimeMinutes: 25,
            difficulty: "Easy",
            calories: 950,
            rating: 4.9,
            defaultServings: 2,
            tags: ["American", "Meat", "Fast Food"],
            ingredients: ingredients,
            steps: steps
        )
    }
    
    private static func createChocolateLavaCake() -> Recipe {
        let ingredients = [
            Ingredient(name: "Dark Chocolate (70%)", quantity: 120.0, unit: "g"),
            Ingredient(name: "Unsalted Butter", quantity: 115.0, unit: "g"),
            Ingredient(name: "Eggs", quantity: 2.0, unit: "units"),
            Ingredient(name: "Egg Yolks", quantity: 2.0, unit: "units"),
            Ingredient(name: "Sugar", quantity: 50.0, unit: "g"),
            Ingredient(name: "All-Purpose Flour", quantity: 30.0, unit: "g"),
            Ingredient(name: "Powdered Sugar", quantity: 1.0, unit: "tbsp")
        ]
        
        let steps = [
            Step(order: 1, text: "Preheat oven to 425°F (220°C). Grease ramekins.", localImageName: "MoltenChocolateLavaCake1"),
            Step(order: 2, text: "Melt butter and chocolate together.", localImageName: "MoltenChocolateLavaCake2"),
            Step(order: 3, text: "Whisk eggs, yolks, and sugar until thick.", localImageName: "MoltenChocolateLavaCake3"),
            Step(order: 4, text: "Fold chocolate into eggs, then flour.", localImageName: "MoltenChocolateLavaCake4"),
            Step(order: 5, text: "Pour into ramekins. Bake for exactly 12 minutes.", durationSec: 720, localImageName: "MoltenChocolateLavaCake5"),
            Step(order: 6, text: "Invert onto plate, dust with sugar.", localImageName: "MoltenChocolateLavaCake6"),
            Step(order: 7, text: "Serve immediately.", localImageName: "MoltenChocolateLavaCake7")
        ]
        
        return Recipe(
            id: "lava-cake-005",
            title: "Molten Chocolate Lava Cake",
            localImageName: "MoltenLavaCakesHeader",
            imageURL: nil,
            totalTimeMinutes: 25,
            difficulty: "Hard",
            calories: 450,
            rating: 4.9,
            tags: ["Dessert", "Chocolate", "Baking"],
            ingredients: ingredients,
            steps: steps
        )
    }
    
    private static func createPadThai() -> Recipe {
        let ingredients = [
            Ingredient(name: "Rice Noodles", quantity: 200.0, unit: "g"),
            Ingredient(name: "Shrimp", quantity: 150.0, unit: "g"),
            Ingredient(name: "Eggs", quantity: 2.0, unit: "units"),
            Ingredient(name: "Bean Sprouts", quantity: 100.0, unit: "g"),
            Ingredient(name: "Peanuts (Crushed)", quantity: 2.0, unit: "tbsp"),
            Ingredient(name: "Tamarind Paste", quantity: 2.0, unit: "tbsp"),
            Ingredient(name: "Fish Sauce", quantity: 2.0, unit: "tbsp"),
            Ingredient(name: "Palm sugar", quantity: 2.0, unit: "tbsp"),
            Ingredient(name: "Lime", quantity: 1.0, unit: "unit")
        ]
        
        let steps = [
            Step(order: 1, text: "Soak rice noodles in warm water for 30 minutes.", durationSec: 1800, localImageName: "ShrimpPadThai1"),
            Step(order: 2, text: "Mix tamarind, fish sauce, and sugar.", localImageName: "ShrimpPadThai2"),
            Step(order: 3, text: "Stir-fry shrimp until pink, remove.", localImageName: "ShrimpPadThai3"),
            Step(order: 4, text: "Scramble eggs in the wok.", localImageName: "ShrimpPadThai4"),
            Step(order: 5, text: "Add noodles and sauce. Toss until soft.", localImageName: "ShrimpPadThai5"),
            Step(order: 6, text: "Add sprouts and shrimp. Toss for 1 min.", durationSec: 60, localImageName: "ShrimpPadThai6"),
            Step(order: 7, text: "Serve with peanuts and lime.", localImageName: "ShrimpPadThai7")
        ]
        
        return Recipe(
            id: "pad-thai-006",
            title: "Traditional Shrimp Pad Thai",
            localImageName: "ShrimpPadThaiHeader",
            imageURL: nil,
            totalTimeMinutes: 40,
            difficulty: "Medium",
            calories: 520,
            rating: 4.4,
            defaultServings: 2,
            tags: ["Asian", "Seafood", "Wok"],
            ingredients: ingredients,
            steps: steps
        )
    }

    private static func createGuacamole() -> Recipe {
        let ingredients = [
            Ingredient(name: "Ripe avocados", quantity: 3.0, unit: "units"),
            Ingredient(name: "Small onion, finely diced", quantity: 0.5, unit: "unit"),
            Ingredient(name: "Roma tomatoes, diced", quantity: 2.0, unit: "units"),
            Ingredient(name: "Fresh cilantro, chopped", quantity: 20.0, unit: "g"),
            Ingredient(name: "Jalapeño pepper, minced (seeds removed)", quantity: 1.0, unit: "unit"),
            Ingredient(name: "Lime juice (freshly squeezed)", quantity: 2.0, unit: "tbsp"),
            Ingredient(name: "Salt", quantity: 0.5, unit: "tsp")
        ]
        
        let steps = [
            Step(order: 1, text: "Cut the avocados in half, remove the pit, and scoop the flesh into a large bowl.", localImageName: "ClassicGuacamole&Chips2"),
            Step(order: 2, text: "Mash the avocados with a fork for 1 to 2 minutes until smooth but still slightly chunky.", durationSec: 120, localImageName: "ClassicGuacamole&Chips3"),
            Step(order: 3, text: "Add the diced onion, tomatoes, cilantro, jalapeño, lime juice, and salt.", localImageName: "ClassicGuacamole&Chips4"),
            Step(order: 4, text: "Stir gently to combine. Taste and add more salt if needed.", localImageName: "ClassicGuacamole&Chips5"),
            Step(order: 5, text: "Serve immediately with tortilla chips.", localImageName: "ClassicGuacamoleHeader")
        ]
        
        return Recipe(
            id: "guacamole-007",
            title: "Classic Guacamole",
            localImageName: "ClassicGuacamoleHeader",
            imageURL: nil,
            totalTimeMinutes: 10,
            difficulty: "Easy",
            calories: 320,
            rating: 4.2,
            tags: ["Mexican", "Snack", "Vegan"],
            ingredients: ingredients,
            steps: steps
        )
    }

    private static func createHomemadePizza() -> Recipe {
        let ingredients = [
            Ingredient(name: "Pre-made pizza dough (room temp)", quantity: 1, unit: "ball"),
            Ingredient(name: "Pizza sauce", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Mozzarella (shredded)", quantity: 170.0, unit: "g"),
            Ingredient(name: "Toppings of choice", quantity: 1, unit: "assortment"),
            Ingredient(name: "Cornmeal or flour (for dusting)", quantity: 2, unit: "tbsp")
        ]
        
        let steps = [
            Step(order: 1, text: "Preheat oven to 450°F (230°C). If using a pizza stone, heat it now.", localImageName: "ClassicHomemadePizza5"),
            Step(order: 2, text: "Let the dough sit at room temperature for 15 minutes to make it easier to stretch.", durationSec: 900, localImageName: "ClassicHomemadePizza4"),
            Step(order: 3, text: "Dust a baking sheet or peel with cornmeal. Stretch or roll the dough into a 12-inch circle (3–5 minutes).", durationSec: 300, localImageName: "ClassicHomemadePizza6"),
            Step(order: 4, text: "Spread the sauce evenly, leaving a rim. Top with cheese and desired toppings.", localImageName: "ClassicHomemadePizza6"),
            Step(order: 5, text: "Bake for 12–15 minutes until the crust is golden and cheese melted.", durationSec: 900, localImageName: "ClassicHomemadePizza7"),
            Step(order: 6, text: "Let cool for 2 minutes before slicing.", durationSec: 120, localImageName: "ClassicHomemadePizza8")
        ]
        
        return Recipe(
            id: "homemade-pizza-009",
            title: "Homemade Pizza (Quick Dough)",
            localImageName: "HomemadePizzaQuickDoughHeader",
            imageURL: nil,
            totalTimeMinutes: 35,
            difficulty: "Medium",
            calories: 750,
            rating: 4.3,
            tags: ["Italian", "Baking", "Dinner"],
            ingredients: ingredients,
            steps: steps
        )
    }

    // MARK: - DESSERTS

    private static func createChocolateMousse() -> Recipe {
        let ingredients = [
            Ingredient(name: "Dark chocolate (70% cocoa), chopped", quantity: 200, unit: "g"),
            Ingredient(name: "Unsalted butter, cubed", quantity: 30, unit: "g"),
            Ingredient(name: "Large eggs, separated", quantity: 4, unit: "units"),
            Ingredient(name: "Granulated sugar", quantity: 40, unit: "g"),
            Ingredient(name: "Fine sea salt", quantity: 1, unit: "pinch")
        ]
        let steps = [
            Step(order: 1, text: "Fill a saucepan with 3cm of water and bring to a simmer.", localImageName: "ChocolateMousse1"),
            Step(order: 2, text: "Place chocolate and butter in a heatproof bowl over the simmering water and stir until melted (about 5 minutes).", durationSec: 300, localImageName: "ChocolateMousse2"),
            Step(order: 3, text: "Remove bowl from heat and let it cool for 5 minutes.", durationSec: 300, localImageName: "ChocolateMousse2"),
            Step(order: 4, text: "Whisk the egg yolks into the chocolate mixture one by one until glossy.", localImageName: "ChocolateMousse3"),
            Step(order: 5, text: "In a separate clean bowl, whisk egg whites and salt until soft peaks form.", localImageName: "ChocolateMousse4"),
            Step(order: 6, text: "Add sugar gradually to the whites and whisk until stiff peaks form.", localImageName: "ChocolateMousse5"),
            Step(order: 7, text: "Fold the egg whites gently into the chocolate mixture in two batches using a spatula.", localImageName: "ChocolateMousse6"),
            Step(order: 8, text: "Divide into glasses and refrigerate for at least 4 hours before serving.", durationSec: 14400, localImageName: "ChocolateMousse7")
        ]
        return Recipe(id: "mousse-010", title: "Classic French Chocolate Mousse", localImageName: "ClassicFrenchChocolateMousseHeader", imageURL: nil, totalTimeMinutes: 265, difficulty: "Beginner", calories: 350, rating: 4.4, defaultServings: 6, tags: ["Dessert", "French", "Chocolate"], ingredients: ingredients, steps: steps)
    }

    private static func createAppleCrumble() -> Recipe {
        let ingredients = [
            Ingredient(name: "Granny Smith apples, cubed", quantity: 3, unit: "units"),
            Ingredient(name: "Frozen mixed berries", quantity: 200, unit: "g"),
            Ingredient(name: "Brown sugar (divided: 50g for fruit, 80g for topping)", quantity: 130, unit: "g"),
            Ingredient(name: "Cinnamon", quantity: 1, unit: "tsp"),
            Ingredient(name: "Flour (for fruit)", quantity: 1, unit: "tbsp"),
            Ingredient(name: "All-purpose flour (for topping)", quantity: 150, unit: "g"),
            Ingredient(name: "Rolled oats", quantity: 100, unit: "g"),
            Ingredient(name: "Cold butter, cubed", quantity: 100, unit: "g"),
            Ingredient(name: "Heavy cream (for whipping)", quantity: 250, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 180°C (350°F).", localImageName: "AppleCrumble1"),
            Step(order: 2, text: "Toss apples, berries, 50g sugar, cinnamon, and 1 tbsp flour in a bowl.", localImageName: "AppleCrumble1"),
            Step(order: 3, text: "Spread fruit mixture into a baking dish.", localImageName: "AppleCrumble2"),
            Step(order: 4, text: "Rub 150g flour, oats, 80g sugar, and cold butter together with fingertips until crumbly.", localImageName: "AppleCrumble3"),
            Step(order: 5, text: "Scatter the crumble topping over the fruit.", localImageName: "AppleCrumble4"),
            Step(order: 6, text: "Bake for 35–40 minutes until golden and bubbling.", durationSec: 2400, localImageName: "AppleCrumble5"),
            Step(order: 7, text: "Let rest for 10 minutes, then serve with whipped cream.", durationSec: 600, localImageName: "AppleCrumble5")
        ]
        return Recipe(id: "crumble-012", title: "Apple & Berry Crumble", localImageName: "AppleBerryCrumbleHeader", imageURL: nil, totalTimeMinutes: 60, difficulty: "Beginner", calories: 380, rating: 4.3, defaultServings: 6, tags: ["Dessert", "Fruit", "Baking"], ingredients: ingredients, steps: steps)
    }

    private static func createNYCheesecake() -> Recipe {
        let ingredients = [
            Ingredient(name: "Digestive biscuits, crushed", quantity: 200, unit: "g"),
            Ingredient(name: "Unsalted butter, melted", quantity: 100, unit: "g"),
            Ingredient(name: "Cream cheese, room temp", quantity: 900, unit: "g"),
            Ingredient(name: "Granulated sugar (divided: 200g for filling, 50g for sauce)", quantity: 250, unit: "g"),
            Ingredient(name: "Sour cream", quantity: 200, unit: "ml"),
            Ingredient(name: "All-purpose flour", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Eggs", quantity: 3, unit: "units"),
            Ingredient(name: "Lemon zest", quantity: 1, unit: "tsp"),
            Ingredient(name: "Strawberries", quantity: 250, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 160°C (320°F). Mix crushed biscuits and melted butter, press into a springform pan, and bake for 10 minutes.", durationSec: 600, localImageName: "Cheesecake1"),
            Step(order: 2, text: "Increase oven to 200°C (400°F). Beat cream cheese and 200g sugar, then mix in flour, sour cream, lemon zest, and eggs.", localImageName: "Cheesecake2"),
            Step(order: 3, text: "Pour over crust and place pan in a water bath (roasting pan with boiling water). Bake at 200°C for 10 minutes, then reduce to 110°C (230°F) and bake for 60 minutes.", durationSec: 3600, localImageName: "Cheesecake3"),
            Step(order: 4, text: "Turn oven off and let cool inside for 1 hour, then refrigerate for 6 hours.", durationSec: 25200, localImageName: "Cheesecake4"),
            Step(order: 5, text: "Simmer strawberries and 50g sugar for 10 minutes to make a sauce, then serve over cake.", durationSec: 600, localImageName: "Cheesecake4")
        ]
        return Recipe(id: "cheesecake-013", title: "New York Cheesecake", localImageName: "NewYorkCheesecakeHeader", imageURL: nil, totalTimeMinutes: 465, difficulty: "Intermediate", calories: 550, rating: 4.9, defaultServings: 8, tags: ["Dessert", "Cake", "American"], ingredients: ingredients, steps: steps)
    }

    private static func createCremeBrulee() -> Recipe {
        let ingredients = [
            Ingredient(name: "Heavy cream", quantity: 500, unit: "ml"),
            Ingredient(name: "Vanilla bean", quantity: 1, unit: "unit"),
            Ingredient(name: "Egg yolks", quantity: 6, unit: "units"),
            Ingredient(name: "Sugar (for custard)", quantity: 75, unit: "g"),
            Ingredient(name: "Sugar (for topping)", quantity: 4, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 150°C (300°F). Heat cream with vanilla bean until simmering, then let steep off heat for 15 minutes.", durationSec: 900, localImageName: "CremeBrulee1"),
            Step(order: 2, text: "Whisk egg yolks and 75g sugar, then slowly pour in the warm cream while whisking.", localImageName: "CremeBrulee2"),
            Step(order: 3, text: "Strain mixture and pour into ramekins placed in a roasting pan. Fill pan with water halfway up the ramekins.", localImageName: "CremeBrulee3"),
            Step(order: 4, text: "Bake for 30–40 minutes until set but wobbly.", durationSec: 2400, localImageName: "CremeBrulee4"),
            Step(order: 5, text: "Chill for 4 hours.", durationSec: 14400, localImageName: "CremeBrulee5"),
            Step(order: 6, text: "Sprinkle top with sugar and caramelize with a blow torch for 1 minute before serving.", durationSec: 60, localImageName: "CremeBrulee5")
        ]
        return Recipe(id: "brulee-015", title: "Vanilla Bean Crème Brûlée", localImageName: "VanillaBeanCrmeBrieHeader", imageURL: nil, totalTimeMinutes: 300, difficulty: "Intermediate", calories: 350, rating: 4.8, tags: ["Dessert", "French"], ingredients: ingredients, steps: steps)
    }

    // MARK: - ITALIAN

    private static func createAglioEOlio() -> Recipe {
        let ingredients = [
            Ingredient(name: "Spaghetti", quantity: 450, unit: "g"),
            Ingredient(name: "Garlic (thinly sliced)", quantity: 6, unit: "cloves"),
            Ingredient(name: "Extra virgin olive oil", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Red pepper flakes", quantity: 1, unit: "tsp"),
            Ingredient(name: "Fresh parsley (chopped)", quantity: 25.0, unit: "g"),
            Ingredient(name: "Parmesan cheese (grated)", quantity: 50.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Bring a large pot of salted water to a boil and cook the spaghetti for 8–10 minutes until al dente. Reserve 1 cup of pasta water before draining.", durationSec: 600, localImageName: "Aglio1"),
            Step(order: 2, text: "While the pasta cooks, heat the olive oil in a large skillet over medium heat for 1 minute.", durationSec: 60, localImageName: "Aglio2"),
            Step(order: 3, text: "Add the sliced garlic and sauté for 2–3 minutes until golden brown (do not burn).", durationSec: 180, localImageName: "Aglio2"),
            Step(order: 4, text: "Add the red pepper flakes and cook for 30 seconds.", durationSec: 30, localImageName: "Aglio3"),
            Step(order: 5, text: "Add the cooked pasta and 1/2 cup of the reserved pasta water to the skillet. Toss vigorously for 2 minutes over medium heat to emulsify the sauce.", durationSec: 120, localImageName: "Aglio3"),
            Step(order: 6, text: "Remove from heat, stir in the parsley and parmesan cheese, and serve immediately.", localImageName: "Aglio3")
        ]
        return Recipe(id: "aglio-019", title: "Spaghetti Aglio e Olio", localImageName: "ClassicSpaghettiAglioEOlioHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 400, rating: 4.5, tags: ["Italian", "Pasta", "Vegetarian"], ingredients: ingredients, steps: steps)
    }
    
    private static func createCapreseSalad() -> Recipe {
        let ingredients = [
            Ingredient(name: "Large tomatoes (ripe)", quantity: 3, unit: "units"),
            Ingredient(name: "Fresh Mozzarella cheese", quantity: 225, unit: "g"),
            Ingredient(name: "Fresh basil leaves", quantity: 15.0, unit: "g"),
            Ingredient(name: "Extra virgin olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Balsamic glaze (optional)", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Salt & black pepper", quantity: 1, unit: "to taste")
        ]
        let steps = [
            Step(order: 1, text: "Slice the tomatoes and mozzarella cheese into 1/4-inch thick rounds.", localImageName: "Caprese1"),
            Step(order: 2, text: "Arrange them on a platter, alternating slices: Tomato, Mozzarella, Basil leaf. Repeat.", localImageName: "Caprese2"),
            Step(order: 3, text: "Drizzle the olive oil (and balsamic glaze if using) over the top.", localImageName: "Caprese3"),
            Step(order: 4, text: "Sprinkle with salt and freshly cracked black pepper just before serving.", localImageName: "Caprese3")
        ]
        return Recipe(id: "caprese-020", title: "Caprese Salad", localImageName: "CapreseSaladHeader", imageURL: nil, totalTimeMinutes: 10, difficulty: "Easy", calories: 300, rating: 4.8, tags: ["Italian", "Salad", "Vegetarian"], ingredients: ingredients, steps: steps)
    }

    private static func createCarbonara() -> Recipe {
        let ingredients = [
            Ingredient(name: "Spaghetti", quantity: 450, unit: "g"),
            Ingredient(name: "Eggs", quantity: 4, unit: "units"),
            Ingredient(name: "Pecorino Romano (grated)", quantity: 100.0, unit: "g"),
            Ingredient(name: "Bacon or Pancetta (diced)", quantity: 150.0, unit: "g"),
            Ingredient(name: "Black pepper (freshly cracked)", quantity: 1, unit: "tsp")
        ]
        let steps = [
            Step(order: 1, text: "Bring a pot of salted water to a boil. Cook pasta for 9–11 minutes until al dente. Reserve 1 cup of pasta water.", durationSec: 660, localImageName: "Carbonara1"),
            Step(order: 2, text: "While water boils, whisk eggs, pecorino, and pepper for 2 minutes until smooth.", durationSec: 120, localImageName: "Carbonara3"),
            Step(order: 3, text: "In a large skillet, fry the diced bacon over medium heat for 6–8 minutes until crisp. Remove the pan from heat but keep the fat.", durationSec: 480, localImageName: "Carbonara2"),
            Step(order: 4, text: "Add the hot, drained pasta to the skillet with the bacon. Toss for 1 minute to coat in the fat.", durationSec: 60, localImageName: "Carbonara4"),
            Step(order: 5, text: "Off the heat, pour the egg mixture over the pasta while tossing quickly and continuously for 2 minutes. Add splashes of reserved pasta water as needed to thin the sauce.", durationSec: 120, localImageName: "Carbonara4")
        ]
        return Recipe(id: "carbonara-021", title: "Creamy Spaghetti Carbonara", localImageName: "CreamySpaghettiCarbonaraHeader", imageURL: nil, totalTimeMinutes: 30, difficulty: "Medium", calories: 650, rating: 4.8, tags: ["Italian", "Pasta", "Meat"], ingredients: ingredients, steps: steps)
    }

    private static func createChickenPiccata() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chicken breasts (butterflied)", quantity: 2, unit: "units"),
            Ingredient(name: "All-purpose flour", quantity: 60.0, unit: "g"),
            Ingredient(name: "Butter (divided)", quantity: 4, unit: "tbsp"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Lemon juice", quantity: 80.0, unit: "ml"),
            Ingredient(name: "Chicken stock", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Capers (drained)", quantity: 2, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Dredge the chicken pieces in the flour, shaking off excess.", localImageName: "Piccata1"),
            Step(order: 2, text: "Heat olive oil and 2 tbsp of butter in a large skillet over medium-high heat for 2 minutes.", durationSec: 120, localImageName: "Piccata1"),
            Step(order: 3, text: "Cook the chicken for 3–4 minutes per side until golden brown and cooked through. Remove and set aside.", durationSec: 480, localImageName: "Piccata2"),
            Step(order: 4, text: "In the same pan, pour in the chicken stock and lemon juice. Scrape the bottom and simmer for 3 minutes to reduce slightly.", durationSec: 180, localImageName: "Piccata2"),
            Step(order: 5, text: "Stir in the capers and the remaining 2 tbsp of butter. Whisk for 1 minute until glossy.", durationSec: 60, localImageName: "Piccata2"),
            Step(order: 6, text: "Return chicken to the pan and warm for 1 minute before serving.", durationSec: 60, localImageName: "Piccata3")
        ]
        return Recipe(id: "piccata-022", title: "Chicken Piccata", localImageName: "ChickenPiccataHeader", imageURL: nil, totalTimeMinutes: 30, difficulty: "Medium", calories: 450, rating: 4.4, defaultServings: 2, tags: ["Italian", "Chicken", "Dinner"], ingredients: ingredients, steps: steps)
    }

    private static func createMushroomRisotto() -> Recipe {
        let ingredients = [
            Ingredient(name: "Arborio rice", quantity: 300.0, unit: "g"),
            Ingredient(name: "Chicken or Vegetable broth (kept warm)", quantity: 1200.0, unit: "ml"),
            Ingredient(name: "Onion (finely chopped)", quantity: 1, unit: "unit"),
            Ingredient(name: "Mushrooms (sliced)", quantity: 225, unit: "g"),
            Ingredient(name: "White wine (optional)", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Parmesan cheese", quantity: 50.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "In a separate pot, heat the broth and keep it simmering.", localImageName: "Risotto1"),
            Step(order: 2, text: "In a large pot, sauté the onion and mushrooms in a little oil over medium heat for 5 minutes until softened.", durationSec: 300, localImageName: "Risotto1"),
            Step(order: 3, text: "Add the Arborio rice and toast it, stirring constantly, for 2 minutes.", durationSec: 120, localImageName: "Risotto2"),
            Step(order: 4, text: "Add the white wine (if using) and stir for 2 minutes until fully absorbed.", durationSec: 120, localImageName: "Risotto2"),
            Step(order: 5, text: "Add the warm broth one ladle at a time, stirring frequently and waiting for absorption before adding the next, for 20–25 minutes until rice is tender and creamy.", durationSec: 1500, localImageName: "Risotto3"),
            Step(order: 6, text: "Remove from heat. Stir in the parmesan cheese for 1 minute and serve.", durationSec: 60, localImageName: "Risotto4")
        ]
        return Recipe(id: "risotto-023", title: "Easy Mushroom Risotto", localImageName: "EasyMushroomRisottoHeader", imageURL: nil, totalTimeMinutes: 45, difficulty: "Medium", calories: 400, rating: 4.3, tags: ["Italian", "Rice", "Vegetarian"], ingredients: ingredients, steps: steps)
    }

    private static func createTiramisu() -> Recipe {
        let ingredients = [
            Ingredient(name: "Mascarpone cheese (room temperature)", quantity: 500, unit: "g"),
            Ingredient(name: "Heavy cream (whipping cream)", quantity: 300, unit: "ml"),
            Ingredient(name: "Egg yolks (large eggs)", quantity: 6, unit: "units"),
            Ingredient(name: "Granulated sugar", quantity: 150, unit: "g"),
            Ingredient(name: "Ladyfinger cookies (Savoiardi biscuits)", quantity: 300, unit: "g"),
            Ingredient(name: "Strong brewed espresso or coffee (cooled)", quantity: 480.0, unit: "ml"),
            Ingredient(name: "Coffee liqueur (Kahlúa or Marsala wine, optional)", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Cocoa powder (for dusting)", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Dark chocolate shavings (optional)", quantity: 1, unit: "optional")
        ]
        
        let steps = [
            Step(order: 1, text: "Prepare coffee: Brew 2 cups of strong espresso or very strong filter coffee. Add liqueur if using. Let coffee cool completely to room temperature. This is crucial - hot coffee will melt the cheese! If you don't have an espresso machine, use strong instant coffee (4 tbsp instant coffee in 2 cups boiling water).", localImageName: "Tiramisu1"),
            
            Step(order: 2, text: "Whip the cream: In a clean bowl, whip the heavy cream using a mixer on medium-high speed for 3-4 minutes until stiff peaks form. Be careful not to over-whip into butter! Transfer to a separate bowl and refrigerate.", durationSec: 240, localImageName: "Tiramisu2"),
            
            Step(order: 3, text: "Make egg mixture: Using a mixer, beat the egg yolks with sugar on high speed for 4-5 minutes until the mixture lightens in color, thickens, and doubles in volume. The mixture should be pale yellow and creamy.", durationSec: 300, localImageName: "Tiramisu3"),
            
            Step(order: 4, text: "Add mascarpone: Add the mascarpone cheese (at room temperature!) to the egg yolk mixture. Mix on low speed for 1 minute until smooth and uniform. Don't overmix!", durationSec: 60, localImageName: "Tiramisu4"),
            
            Step(order: 5, text: "Fold in cream: Using a large spoon or silicone spatula, gently fold the whipped cream into the mascarpone mixture. Use gentle bottom-to-top motions for 1-2 minutes until everything is combined but still airy. This keeps the texture light!", durationSec: 120, localImageName: "Tiramisu5"),
            
            Step(order: 6, text: "First layer assembly: Quickly dip each ladyfinger cookie in the cold coffee - one second per side! No more, or the cookies will fall apart. Arrange a tight layer of dipped ladyfingers in the bottom of a 9x13 inch (20x30 cm) dish.", localImageName: "Tiramisu6"),
            
            Step(order: 7, text: "First cream layer: Spread half of the mascarpone mixture over the ladyfingers. Smooth with a spatula into an even layer.", localImageName: "Tiramisu7"),
            
            Step(order: 8, text: "Second layer: Repeat the process - a layer of ladyfingers quickly dipped in coffee, then the remaining cream mixture. Smooth the top layer nicely.", localImageName: "Tiramisu8"),
            
            Step(order: 9, text: "Chill: Cover the dish with parchment paper or plastic wrap and transfer to the refrigerator. Chill for a minimum of 6 hours, preferably overnight. This is essential for the tiramisu to set!", durationSec: 21600, localImageName: "Tiramisu9"),
            
            Step(order: 10, text: "Serve: Just before serving, use a sieve to dust a thick layer of cocoa powder over the entire surface of the tiramisu. You can also add chocolate shavings. Cut into squares and serve cold.", localImageName: "Tiramisu10")
        ]
        
        return Recipe(
            id: "tiramisu-027",
            title: "Classic Italian Tiramisu",
            localImageName: "AuthenticTiramisuHeader",
            imageURL: nil,
            totalTimeMinutes: 390, // 6.5 hours with chilling
            difficulty: "Medium",
            calories: 450,
            rating: 4.9,
            defaultServings: 8,
            tags: ["Dessert", "Italian", "Classic"],
            ingredients: ingredients,
            steps: steps
        )
    }

    // MARK: - BREAKFAST

    private static func createScrambledEggs() -> Recipe {
        let ingredients = [
            Ingredient(name: "Large eggs", quantity: 4, unit: "units"),
            Ingredient(name: "Unsalted butter", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Heavy cream (or milk)", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Salt", quantity: 1, unit: "pinch"),
            Ingredient(name: "Black pepper", quantity: 1, unit: "pinch"),
            Ingredient(name: "Fresh chives (optional)", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Crack eggs into a bowl. Add cream, salt, and pepper. Whisk for 1 minute until uniform.", durationSec: 60, localImageName: "Scramble1"),
            Step(order: 2, text: "Heat a non-stick pan over low heat. Add butter and let it melt completely.", localImageName: "Scramble2"),
            Step(order: 3, text: "Pour in the egg mixture. Let it sit undisturbed for 30 seconds.", durationSec: 30, localImageName: "Scramble3"),
            Step(order: 4, text: "Use a spatula to gently push the eggs from the edges to the center. Let sit for 20 seconds and repeat.", durationSec: 20, localImageName: "Scramble3"),
            Step(order: 5, text: "Continue folding gently for 3-4 minutes until eggs are just set but still creamy. Remove from heat while still slightly wet – they will continue cooking.", durationSec: 240, localImageName: "Scramble4"),
            Step(order: 6, text: "Serve immediately, topped with fresh chives if desired.", localImageName: "Scramble4")
        ]
        return Recipe(id: "scramble-046", title: "Creamy Scrambled Eggs", localImageName: "CreamyScrambledEggsHeader", imageURL: nil, totalTimeMinutes: 10, difficulty: "Easy", calories: 280, rating: 4.6, defaultServings: 2, tags: ["Breakfast", "Eggs", "Quick"], ingredients: ingredients, steps: steps)
    }
}
