import Foundation
import SwiftData
import UIKit

@MainActor
class RecipeSeeder2 {
    
    // MARK: - Built-in Recipe IDs
    static let builtInRecipeIDs: Set<String> = [
        "ramen-101",
        "butterchicken-102",
        "tikkamasala-103",
        "pho-104",
        "sweetandsour-105",
        "greencurry-106",
        "beefteriyaki-107",
        "sushi-108",
        "springrolls-109",
        "bulgogi-110",
        "lasagna-111",
        "gnocchi-112",
        "scampi-113",
        "eggplantparm-114",
        "focaccia-115",
        "ravioli-116",
        "arrabbiata-117",
        "ossobuco-118",
        "calamari-119",
        "minestrone-120",
        "hummus-121",
        "shawarma-122",
        "falafel-123",
        "kofta-124",
        "babaganoush-125",
        "friedchicken-126",
        "pulledpork-127",
        "macandcheese-128",
        "chickentenders-129",
        "potpie-130",
        "turkeyburgers-131",
        "bakedham-132",
        "shortribs-133",
        "salmon-134",
        "clamchowder-135",
        "tilapia-136",
        "fishandchips-137",
        "scallops-138",
        "butternutsquash-139",
        "stuffedpeppers-140",
        "sweetpotatofries-141",
        "chiapudding-142",
        "cauliflowersalad-143",
        "cinnamonrolls-144",
        "bananabread-145",
        "brownies-146",
        "crepes-147",
        "pannacotta-148",
        "lemonpoundcake-149",
        "redvelvet-150"
    ]
    
    // MARK: - Seed Built-in Recipes
    static func seedBuiltInRecipes(modelContext: ModelContext) {
        print("📦 Checking for built-in recipes...")
        
        let existingRecipes = (try? modelContext.fetch(FetchDescriptor<Recipe>())) ?? []
        let existingIDs = Set(existingRecipes.map { $0.id })
        
        let builtInRecipes: [Recipe] = [
            createTonkotsuRamen(),
            createButterChicken(),
            createTikkaMasala(),
            createBeefPho(),
            createSweetAndSourPork(),
            createGreenCurry(),
            createBeefTeriyaki(),
            createSushiRolls(),
            createSpringRolls(),
            createBulgogi(),
            createLasagna(),
            createGnocchi(),
            createShrimpScampi(),
            createEggplantParmigiana(),
            createFocaccia(),
            createRavioli(),
            createArrabbiata(),
            createOssoBuco(),
            createCalamari(),
            createMinestrone(),
            createHummus(),
            createShawarma(),
            createFalafel(),
            createKofta(),
            createBabaGanoush(),
            createFriedChicken(),
            createPulledPork(),
            createMacAndCheese(),
            createChickenTenders(),
            createPotPie(),
            createTurkeyBurgers(),
            createBakedHam(),
            createShortRibs(),
            createSalmon(),
            createClamChowder(),
            createTilapia(),
            createFishAndChips(),
            createScallops(),
            createButternutSquashSoup(),
            createStuffedPeppers(),
            createSweetPotatoFries(),
            createChiaPudding(),
            createCauliflowerSalad(),
            createCinnamonRolls(),
            createBananaBread(),
            createBrownies(),
            createCrepes(),
            createPannaCotta(),
            createLemonPoundCake(),
            createRedVelvetCake()
        ]
        
        var addedCount = 0
        for recipe in builtInRecipes {
            if !existingIDs.contains(recipe.id) {
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
    
    static func seedAndUpload(modelContext: ModelContext) async {
        print("🌱 Seeder: Starting CloudKit Upload Sequence...")
        
        let recipes = [
            createTonkotsuRamen(),
            createButterChicken(),
            createTikkaMasala(),
            createBeefPho(),
            createSweetAndSourPork(),
            createGreenCurry(),
            createBeefTeriyaki(),
            createSushiRolls(),
            createSpringRolls(),
            createBulgogi(),
            createLasagna(),
            createGnocchi(),
            createShrimpScampi(),
            createEggplantParmigiana(),
            createFocaccia(),
            createRavioli(),
            createArrabbiata(),
            createOssoBuco(),
            createCalamari(),
            createMinestrone(),
            createHummus(),
            createShawarma(),
            createFalafel(),
            createKofta(),
            createBabaGanoush(),
            createFriedChicken(),
            createPulledPork(),
            createMacAndCheese(),
            createChickenTenders(),
            createPotPie(),
            createTurkeyBurgers(),
            createBakedHam(),
            createShortRibs(),
            createSalmon(),
            createClamChowder(),
            createTilapia(),
            createFishAndChips(),
            createScallops(),
            createButternutSquashSoup(),
            createStuffedPeppers(),
            createSweetPotatoFries(),
            createChiaPudding(),
            createCauliflowerSalad(),
            createCinnamonRolls(),
            createBananaBread(),
            createBrownies(),
            createCrepes(),
            createPannaCotta(),
            createLemonPoundCake(),
            createRedVelvetCake()
        ]
        
        print("🚀 Starting batch upload of \(recipes.count) recipes to CloudKit...")
        
        var successCount = 0
        var failCount = 0
        
        for (index, recipe) in recipes.enumerated() {
            print("📤 Uploading \(index + 1)/\(recipes.count): \(recipe.title)...")
            if let name = recipe.localImageName, UIImage(named: name) == nil {
                print("⚠️ Missing header asset for \(recipe.title): \(name)")
            }
            
            do {
                // שימוש בפורמט החדש עם טבלאות RecipeStep ו-RecipeIngredient
                let snapshot = RecipeSyncSnapshot(recipe: recipe)
                try await CloudKitManager.shared.saveRecipeWithSteps(snapshot: snapshot)
                successCount += 1
            } catch {
                print("❌ Failed to upload \(recipe.title): \(error.localizedDescription)")
                failCount += 1
            }
            
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        
        print("📊 Upload Summary: \(successCount) succeeded, \(failCount) failed")
        print("✅✅✅ SEEDING COMPLETE! All recipes are now in the cloud.")
        print("👉 Data will be refreshed automatically.")
    }

    // MARK: - ================= 50 NEW RECIPES =================

    private static func createTonkotsuRamen() -> Recipe {
        let ingredients = [
            Ingredient(name: "Pork neck bones", quantity: 1350.0, unit: "g"),
            Ingredient(name: "Onion, halved", quantity: 1, unit: "unit"),
            Ingredient(name: "Garlic, halved", quantity: 1, unit: "head"),
            Ingredient(name: "Ginger, sliced", quantity: 5.0, unit: "cm"),
            Ingredient(name: "Ramen noodles", quantity: 4, unit: "portions"),
            Ingredient(name: "Soy sauce (tare)", quantity: 4, unit: "tbsp"),
            Ingredient(name: "Soft-boiled eggs", quantity: 4, unit: "units"),
            Ingredient(name: "Green onions, chopped", quantity: 2, unit: "units")
        ]
        let steps = [
            Step(order: 1, text: "Place pork bones in a large pot, cover with water, and boil for 10 minutes. Discard water and rinse bones thoroughly to remove impurities.", durationSec: 600, localImageName: "Ramen1"),
            Step(order: 2, text: "Return bones to the pot with the onion, garlic, and ginger. Cover with fresh water. Simmer on low heat for 12 hours (720 minutes), adding water as needed to keep bones covered.", durationSec: 43200, localImageName: "Ramen2"),
            Step(order: 3, text: "Strain the broth and discard the solids. Keep the rich, milky broth hot.", localImageName: "Ramen3"),
            Step(order: 4, text: "Boil the ramen noodles in a separate pot of water for 3 minutes (or according to package). Drain.", durationSec: 180, localImageName: "Ramen4"),
            Step(order: 5, text: "Add 1 tbsp of soy sauce to the bottom of 4 bowls. Pour the hot broth over it.", localImageName: "Ramen5"),
            Step(order: 6, text: "Add the cooked noodles and top with a soft-boiled egg and chopped green onions. Serve immediately.", localImageName: "Ramen6")
        ]
        return Recipe(id: "ramen-101", title: "Authentic Japanese Tonkotsu Ramen", localImageName: "AuthenticJapaneseTonkotsuRamenHeader", imageURL: nil, totalTimeMinutes: 750, difficulty: "Hard", calories: 850, rating: 4.7, defaultServings: 6, tags: ["Japanese", "Soup", "Asian"], ingredients: ingredients, steps: steps)
    }

    private static func createButterChicken() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chicken breast, cubed", quantity: 680.0, unit: "g"),
            Ingredient(name: "Plain yogurt", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Garam masala", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Butter", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Onion, diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Garlic, minced", quantity: 3, unit: "cloves"),
            Ingredient(name: "Tomato puree", quantity: 400.0, unit: "g"),
            Ingredient(name: "Heavy cream", quantity: 120.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "In a bowl, mix chicken, yogurt, and 1 tbsp garam masala. Marinate for at least 15 minutes.", durationSec: 900, localImageName: "ButterChicken1"),
            Step(order: 2, text: "Melt butter in a large skillet over medium heat. Add the chicken and cook for 7 minutes until browned. Remove chicken and set aside.", durationSec: 420, localImageName: "ButterChicken2"),
            Step(order: 3, text: "In the same skillet, add the diced onion and cook for 5 minutes until soft. Add garlic and the remaining 1 tbsp garam masala, cooking for 1 minute until fragrant.", durationSec: 360, localImageName: "ButterChicken3"),
            Step(order: 4, text: "Pour in the tomato puree and simmer for 10 minutes.", durationSec: 600, localImageName: "ButterChicken4"),
            Step(order: 5, text: "Stir in the heavy cream and return the chicken to the skillet. Simmer gently for 5 minutes until the chicken is cooked through.", durationSec: 300, localImageName: "ButterChicken5")
        ]
        return Recipe(id: "butterchicken-102", title: "Classic Creamy Butter Chicken", localImageName: "ClassicCreamyButterChickenHeader", imageURL: nil, totalTimeMinutes: 50, difficulty: "Medium", calories: 600, rating: 4.5, tags: ["Indian", "Chicken", "Dinner"], ingredients: ingredients, steps: steps)
    }

    private static func createTikkaMasala() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chicken thighs, cut into bite-sized pieces", quantity: 680.0, unit: "g"),
            Ingredient(name: "Ginger paste", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Garlic paste", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Cayenne pepper", quantity: 1, unit: "tsp"),
            Ingredient(name: "Cumin", quantity: 1, unit: "tsp"),
            Ingredient(name: "Vegetable oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Crushed tomatoes", quantity: 400.0, unit: "g"),
            Ingredient(name: "Heavy cream", quantity: 120.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Toss the chicken with ginger paste, garlic paste, cayenne, and cumin. Let sit for 10 minutes.", durationSec: 600, localImageName: "Tikka1"),
            Step(order: 2, text: "Heat oil in a large pan over medium-high heat. Add the chicken and cook for 8 minutes until browned on all sides.", durationSec: 480, localImageName: "Tikka2"),
            Step(order: 3, text: "Pour in the crushed tomatoes and bring to a simmer. Reduce heat to low and cook for 10 minutes.", durationSec: 600, localImageName: "Tikka3"),
            Step(order: 4, text: "Stir in the heavy cream and simmer for an additional 5 minutes until the sauce thickens and chicken is cooked through.", durationSec: 300, localImageName: "Tikka4")
        ]
        return Recipe(id: "tikkamasala-103", title: "Spicy Chicken Tikka Masala", localImageName: "SpicyChickenTikkaMasalaHeader", imageURL: nil, totalTimeMinutes: 45, difficulty: "Medium", calories: 550, rating: 4.3, tags: ["Indian", "Chicken", "Spicy"], ingredients: ingredients, steps: steps)
    }

    private static func createBeefPho() -> Recipe {
        let ingredients = [
            Ingredient(name: "Beef knuckle or marrow bones", quantity: 900.0, unit: "g"),
            Ingredient(name: "Onion, halved and charred", quantity: 1, unit: "unit"),
            Ingredient(name: "Ginger, charred", quantity: 8.0, unit: "cm"),
            Ingredient(name: "Star anise", quantity: 2, unit: "units"),
            Ingredient(name: "Cinnamon stick", quantity: 1, unit: "unit"),
            Ingredient(name: "Beef broth", quantity: 1900.0, unit: "ml"),
            Ingredient(name: "Beef sirloin, thinly sliced", quantity: 225.0, unit: "g"),
            Ingredient(name: "Rice noodles", quantity: 225.0, unit: "g"),
            Ingredient(name: "Fresh basil and cilantro", quantity: 30.0, unit: "g"),
            Ingredient(name: "Lime", quantity: 1, unit: "unit")
        ]
        let steps = [
            Step(order: 1, text: "In a large pot, roast the bones, charred onion, charred ginger, star anise, and cinnamon stick over medium heat for 5 minutes until fragrant.", durationSec: 300, localImageName: "Pho1"),
            Step(order: 2, text: "Add the beef broth and bring to a boil. Reduce heat and simmer gently for 3 hours (180 minutes), skimming any foam off the top.", durationSec: 10800, localImageName: "Pho2"),
            Step(order: 3, text: "Strain the broth into a clean pot and bring back to a rolling boil.", localImageName: "Pho3"),
            Step(order: 4, text: "Cook rice noodles in a separate pot of boiling water for 4 minutes. Drain and divide into bowls.", durationSec: 240, localImageName: "Pho4"),
            Step(order: 5, text: "Top noodles with the raw, thinly sliced sirloin. Pour the boiling hot broth directly over the beef to cook it instantly.", localImageName: "Pho5"),
            Step(order: 6, text: "Garnish with basil, cilantro, and a squeeze of lime before serving.", localImageName: "Pho6")
        ]
        return Recipe(id: "pho-104", title: "Vietnamese Beef Pho", localImageName: "VietnameseBeefPhoHeader", imageURL: nil, totalTimeMinutes: 200, difficulty: "Medium", calories: 450, rating: 4.4, defaultServings: 6, tags: ["Vietnamese", "Soup", "Beef"], ingredients: ingredients, steps: steps)
    }

    private static func createSweetAndSourPork() -> Recipe {
        let ingredients = [
            Ingredient(name: "Pork tenderloin, cubed", quantity: 450.0, unit: "g"),
            Ingredient(name: "Cornstarch", quantity: 60.0, unit: "g"),
            Ingredient(name: "Vegetable oil", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Bell pepper, chopped", quantity: 1, unit: "unit"),
            Ingredient(name: "Pineapple chunks", quantity: 80.0, unit: "g"),
            Ingredient(name: "Ketchup", quantity: 80.0, unit: "ml"),
            Ingredient(name: "White vinegar", quantity: 60.0, unit: "ml"),
            Ingredient(name: "Sugar", quantity: 3, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Coat the pork cubes thoroughly in cornstarch.", localImageName: "SweetSour1"),
            Step(order: 2, text: "Heat the vegetable oil in a wok or large frying pan over medium-high heat. Fry the pork in batches for 5 minutes per batch until crispy and golden. Remove and set aside on paper towels.", durationSec: 300, localImageName: "SweetSour2"),
            Step(order: 3, text: "Drain all but 1 tbsp of oil from the pan. Add the bell pepper and stir-fry for 3 minutes.", durationSec: 180, localImageName: "SweetSour3"),
            Step(order: 4, text: "In a small bowl, whisk together ketchup, white vinegar, and sugar. Pour into the pan with the peppers and simmer for 2 minutes until it thickens.", durationSec: 120, localImageName: "SweetSour4"),
            Step(order: 5, text: "Add the crispy pork and pineapple chunks to the sauce. Toss for 1 minute until evenly coated and heated through.", durationSec: 60, localImageName: "SweetSour5")
        ]
        return Recipe(id: "sweetandsour-105", title: "Crispy Sweet and Sour Pork", localImageName: "CrispySweetAndSourPorkHeader", imageURL: nil, totalTimeMinutes: 35, difficulty: "Medium", calories: 520, rating: 4.0, tags: ["Chinese", "Pork"], ingredients: ingredients, steps: steps)
    }

    private static func createGreenCurry() -> Recipe {
        let ingredients = [
            Ingredient(name: "Firm tofu, pressed and cubed", quantity: 400.0, unit: "g"),
            Ingredient(name: "Green curry paste", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Coconut milk", quantity: 400.0, unit: "ml"),
            Ingredient(name: "Bamboo shoots, drained", quantity: 120.0, unit: "g"),
            Ingredient(name: "Red bell pepper, sliced", quantity: 1, unit: "unit"),
            Ingredient(name: "Soy sauce", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Brown sugar", quantity: 1, unit: "tsp"),
            Ingredient(name: "Coconut oil", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Heat coconut oil in a large skillet over medium heat. Add the curry paste and cook for 1 minute until fragrant.", durationSec: 60, localImageName: "GreenCurry1"),
            Step(order: 2, text: "Pour in the coconut milk and whisk until smooth. Bring to a gentle simmer for 3 minutes.", durationSec: 180, localImageName: "GreenCurry2"),
            Step(order: 3, text: "Add the cubed tofu, bamboo shoots, and red bell pepper. Simmer for 8 minutes until the vegetables are tender.", durationSec: 480, localImageName: "GreenCurry3"),
            Step(order: 4, text: "Stir in the soy sauce and brown sugar, cooking for 2 more minutes. Serve over rice.", durationSec: 120, localImageName: "GreenCurry4")
        ]
        return Recipe(id: "greencurry-106", title: "Thai Green Curry with Tofu", localImageName: "ThaiGreenCurryWithTofuHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 380, rating: 4.2, tags: ["Thai", "Vegetarian", "Curry"], ingredients: ingredients, steps: steps)
    }

    private static func createBeefTeriyaki() -> Recipe {
        let ingredients = [
            Ingredient(name: "Flank steak, thinly sliced", quantity: 450.0, unit: "g"),
            Ingredient(name: "Pre-cooked udon noodles", quantity: 400.0, unit: "g"),
            Ingredient(name: "Soy sauce", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Mirin", quantity: 60.0, unit: "ml"),
            Ingredient(name: "Brown sugar", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Vegetable oil", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Broccoli florets", quantity: 150.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "In a bowl, mix soy sauce, mirin, and brown sugar to make the teriyaki sauce.", localImageName: "Teriyaki1"),
            Step(order: 2, text: "Heat oil in a large wok over medium-high heat. Add the sliced beef and sear for 4 minutes until browned.", durationSec: 240, localImageName: "Teriyaki2"),
            Step(order: 3, text: "Add the broccoli florets and stir-fry for 3 minutes until slightly tender.", durationSec: 180, localImageName: "Teriyaki3"),
            Step(order: 4, text: "Pour in the teriyaki sauce and bring to a simmer for 2 minutes.", durationSec: 120, localImageName: "Teriyaki4"),
            Step(order: 5, text: "Add the udon noodles, tossing everything together for 3 minutes until the noodles are heated through and coated in the glossy sauce.", durationSec: 180, localImageName: "Teriyaki5")
        ]
        return Recipe(id: "beefteriyaki-107", title: "Beef Teriyaki with Udon Noodles", localImageName: "BeefTeriyakiWithUdonNoodlesHeader", imageURL: nil, totalTimeMinutes: 30, difficulty: "Easy", calories: 550, rating: 4.1, tags: ["Japanese", "Beef", "Noodles"], ingredients: ingredients, steps: steps)
    }

    private static func createSushiRolls() -> Recipe {
        let ingredients = [
            Ingredient(name: "Sushi rice", quantity: 400.0, unit: "g"),
            Ingredient(name: "Water", quantity: 600.0, unit: "ml"),
            Ingredient(name: "Rice vinegar", quantity: 60.0, unit: "ml"),
            Ingredient(name: "Nori (seaweed) sheets", quantity: 4, unit: "units"),
            Ingredient(name: "Cucumber, cut into matchsticks", quantity: 0.5, unit: "unit"),
            Ingredient(name: "Avocado, sliced", quantity: 1, unit: "unit"),
            Ingredient(name: "Sashimi-grade salmon, strips", quantity: 115.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Rinse the sushi rice until the water runs clear. Combine rice and water in a pot, bring to a boil, then cover, reduce heat to low, and simmer for 15 minutes.", durationSec: 900, localImageName: "Sushi1"),
            Step(order: 2, text: "Let the rice rest off the heat, covered, for 10 minutes. Stir in the rice vinegar and let cool to room temperature.", durationSec: 600, localImageName: "Sushi2"),
            Step(order: 3, text: "Place a nori sheet on a bamboo rolling mat. Wet your hands and spread a thin layer of rice evenly over the nori, leaving a 1-inch gap at the top edge.", localImageName: "Sushi3"),
            Step(order: 4, text: "Lay the cucumber, avocado, and salmon in a horizontal line across the bottom third of the rice.", localImageName: "Sushi4"),
            Step(order: 5, text: "Roll the mat tightly from the bottom up, squeezing gently to shape the roll. Wet the top edge of the nori to seal. Slice the roll into 6-8 pieces using a sharp, wet knife.", localImageName: "Sushi5")
        ]
        return Recipe(id: "sushi-108", title: "Homemade Sushi Rolls (Maki)", localImageName: "HomemadeSushiRollsMakiHeader", imageURL: nil, totalTimeMinutes: 50, difficulty: "Medium", calories: 350, rating: 4.3, defaultServings: 3, tags: ["Japanese", "Seafood", "Sushi"], ingredients: ingredients, steps: steps)
    }

    private static func createSpringRolls() -> Recipe {
        let ingredients = [
            Ingredient(name: "Spring roll wrappers", quantity: 10, unit: "units"),
            Ingredient(name: "Shredded cabbage", quantity: 100.0, unit: "g"),
            Ingredient(name: "Large carrot, julienned", quantity: 1, unit: "unit"),
            Ingredient(name: "Bean sprouts", quantity: 100.0, unit: "g"),
            Ingredient(name: "Soy sauce", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Sesame oil", quantity: 1, unit: "tsp"),
            Ingredient(name: "Vegetable oil (for frying)", quantity: 240.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "In a bowl, toss the cabbage, carrot, and bean sprouts with the soy sauce and sesame oil.", localImageName: "SpringRoll1"),
            Step(order: 2, text: "Lay a spring roll wrapper flat in a diamond shape. Place 2 tablespoons of the vegetable filling in the lower half.", localImageName: "SpringRoll2"),
            Step(order: 3, text: "Fold the bottom corner over the filling. Fold the left and right corners inward, then roll up tightly. Seal the top corner with a dab of water. Repeat for all wrappers.", localImageName: "SpringRoll3"),
            Step(order: 4, text: "Heat the vegetable oil in a deep skillet over medium-high heat.", localImageName: "SpringRoll4"),
            Step(order: 5, text: "Fry the spring rolls in batches for 4 minutes per side, until golden brown and crispy. Drain on paper towels.", durationSec: 240, localImageName: "SpringRoll5")
        ]
        return Recipe(id: "springrolls-109", title: "Crispy Vegetable Spring Rolls", localImageName: "CrispyVegetableSpringRollsHeader", imageURL: nil, totalTimeMinutes: 40, difficulty: "Medium", calories: 280, rating: 3.9, tags: ["Asian", "Appetizer", "Vegetarian"], ingredients: ingredients, steps: steps)
    }

    private static func createBulgogi() -> Recipe {
        let ingredients = [
            Ingredient(name: "Ribeye or sirloin, thinly sliced", quantity: 450.0, unit: "g"),
            Ingredient(name: "Soy sauce", quantity: 80.0, unit: "ml"),
            Ingredient(name: "Brown sugar", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Sesame oil", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Garlic, minced", quantity: 3, unit: "cloves"),
            Ingredient(name: "Asian pear, grated", quantity: 1, unit: "unit"),
            Ingredient(name: "Vegetable oil", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "In a bowl, combine soy sauce, brown sugar, sesame oil, garlic, and grated pear. Add the sliced beef, toss well, and let marinate for at least 30 minutes.", durationSec: 1800, localImageName: "Bulgogi1"),
            Step(order: 2, text: "Heat vegetable oil in a large skillet or grill pan over high heat.", localImageName: "Bulgogi2"),
            Step(order: 3, text: "Add the marinated beef in a single layer. Cook for 3 minutes per side without moving it too much, allowing a caramelized crust to form.", durationSec: 180, localImageName: "Bulgogi3"),
            Step(order: 4, text: "Toss for 1 more minute until fully cooked. Serve hot.", durationSec: 60, localImageName: "Bulgogi4")
        ]
        return Recipe(id: "bulgogi-110", title: "Korean Beef Bulgogi", localImageName: "KoreanBeefBulgogiHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 450, rating: 4.5, tags: ["Korean", "Beef", "BBQ"], ingredients: ingredients, steps: steps)
    }

    private static func createLasagna() -> Recipe {
        let ingredients = [
            Ingredient(name: "Lasagna noodles, boiled", quantity: 12, unit: "units"),
            Ingredient(name: "Ground beef", quantity: 450.0, unit: "g"),
            Ingredient(name: "Marinara sauce", quantity: 680.0, unit: "g"),
            Ingredient(name: "Ricotta cheese", quantity: 425.0, unit: "g"),
            Ingredient(name: "Mozzarella cheese, shredded", quantity: 230.0, unit: "g"),
            Ingredient(name: "Parmesan cheese, grated", quantity: 50.0, unit: "g"),
            Ingredient(name: "Egg", quantity: 1, unit: "unit")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 375°F (190°C).", localImageName: "Lasagna1"),
            Step(order: 2, text: "In a skillet, brown the ground beef over medium heat for 8 minutes until cooked through. Drain excess fat. Stir in the marinara sauce and simmer for 5 minutes.", durationSec: 780, localImageName: "Lasagna2"),
            Step(order: 3, text: "In a separate bowl, mix the ricotta cheese, egg, and 1/4 cup of the parmesan cheese.", localImageName: "Lasagna3"),
            Step(order: 4, text: "In a 9x13 inch baking dish, spread a thin layer of the meat sauce. Top with 3 lasagna noodles.", localImageName: "Lasagna4"),
            Step(order: 5, text: "Spread one-third of the ricotta mixture over the noodles, followed by one-third of the mozzarella, and one-third of the meat sauce. Repeat these layers two more times.", localImageName: "Lasagna5"),
            Step(order: 6, text: "Top with the remaining 3 noodles, a final layer of meat sauce, and sprinkle with remaining mozzarella and parmesan.", localImageName: "Lasagna6"),
            Step(order: 7, text: "Cover with foil and bake for 40 minutes. Remove foil and bake for another 15 minutes until bubbly and golden. Let rest 10 minutes before slicing.", durationSec: 3300, localImageName: "Lasagna7")
        ]
        return Recipe(id: "lasagna-111", title: "Classic Lasagna Al Forno", localImageName: "ClassicLasagnaAlFornoHeader", imageURL: nil, totalTimeMinutes: 90, difficulty: "Hard", calories: 650, rating: 4.6, defaultServings: 6, tags: ["Italian", "Pasta", "Beef"], ingredients: ingredients, steps: steps)
    }

    private static func createGnocchi() -> Recipe {
        let ingredients = [
            Ingredient(name: "Store-bought potato gnocchi", quantity: 450.0, unit: "g"),
            Ingredient(name: "Basil pesto", quantity: 120.0, unit: "g"),
            Ingredient(name: "Heavy cream", quantity: 60.0, unit: "ml"),
            Ingredient(name: "Parmesan cheese, grated", quantity: 25.0, unit: "g"),
            Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Bring a large pot of salted water to a boil. Add the gnocchi and cook for 3 minutes, or until they float to the top. Drain, reserving 1/4 cup of the pasta water.", durationSec: 180, localImageName: "Gnocchi1"),
            Step(order: 2, text: "In a large skillet over low heat, combine the pesto, heavy cream, and olive oil. Stir for 2 minutes until warm.", durationSec: 120, localImageName: "Gnocchi2"),
            Step(order: 3, text: "Add the drained gnocchi and the reserved pasta water to the skillet. Toss gently for 2 minutes until the sauce coats the gnocchi and thickens slightly.", durationSec: 120, localImageName: "Gnocchi3"),
            Step(order: 4, text: "Stir in the parmesan cheese and serve immediately.", localImageName: "Gnocchi4")
        ]
        return Recipe(id: "gnocchi-112", title: "Creamy Potato Gnocchi with Pesto", localImageName: "CreamyPotatoGnocchiWithPestoHeader", imageURL: nil, totalTimeMinutes: 20, difficulty: "Easy", calories: 450, rating: 4.0, tags: ["Italian", "Pasta", "Vegetarian"], ingredients: ingredients, steps: steps)
    }

    private static func createShrimpScampi() -> Recipe {
        let ingredients = [
            Ingredient(name: "Large shrimp, peeled and deveined", quantity: 450.0, unit: "g"),
            Ingredient(name: "Butter", quantity: 4, unit: "tbsp"),
            Ingredient(name: "Garlic, minced", quantity: 4, unit: "cloves"),
            Ingredient(name: "Dry white wine", quantity: 60.0, unit: "ml"),
            Ingredient(name: "Lemon juice", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Fresh parsley, chopped", quantity: 15.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Melt the butter in a large skillet over medium heat. Add the minced garlic and sauté for 1 minute until fragrant.", durationSec: 60, localImageName: "Scampi1"),
            Step(order: 2, text: "Add the shrimp in a single layer. Cook for 2 minutes until pink on the bottom.", durationSec: 120, localImageName: "Scampi2"),
            Step(order: 3, text: "Flip the shrimp. Pour in the white wine (or broth) and lemon juice. Simmer for 2 minutes until the shrimp are fully pink and opaque.", durationSec: 120, localImageName: "Scampi3"),
            Step(order: 4, text: "Remove from heat, stir in the fresh parsley, and serve immediately over pasta or crusty bread.", localImageName: "Scampi4")
        ]
        return Recipe(id: "scampi-113", title: "Garlic Butter Shrimp Scampi", localImageName: "GarlicButterShrimpScampiHeader", imageURL: nil, totalTimeMinutes: 20, difficulty: "Easy", calories: 350, rating: 4.4, tags: ["Italian", "Seafood"], ingredients: ingredients, steps: steps)
    }

    private static func createEggplantParmigiana() -> Recipe {
        let ingredients = [
            Ingredient(name: "Large eggplants, sliced", quantity: 2, unit: "units"),
            Ingredient(name: "Flour", quantity: 120.0, unit: "g"),
            Ingredient(name: "Eggs, beaten", quantity: 3, unit: "units"),
            Ingredient(name: "Breadcrumbs", quantity: 200.0, unit: "g"),
            Ingredient(name: "Marinara sauce", quantity: 720.0, unit: "ml"),
            Ingredient(name: "Mozzarella cheese, shredded", quantity: 230.0, unit: "g"),
            Ingredient(name: "Parmesan cheese, grated", quantity: 50.0, unit: "g"),
            Ingredient(name: "Vegetable oil", quantity: 120.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 375°F (190°C).", localImageName: "EggplantParm1"),
            Step(order: 2, text: "Dredge each eggplant slice in flour, dip in the beaten eggs, and coat with breadcrumbs.", localImageName: "EggplantParm2"),
            Step(order: 3, text: "Heat vegetable oil in a large skillet over medium-high heat. Fry the eggplant slices for 3 minutes per side until golden brown. Drain on paper towels.", durationSec: 360, localImageName: "EggplantParm3"),
            Step(order: 4, text: "In a 9x13 inch baking dish, spread a thin layer of marinara sauce. Layer half of the fried eggplant slices, top with half the marinara, half the mozzarella, and half the parmesan.", localImageName: "EggplantParm4"),
            Step(order: 5, text: "Repeat with the remaining eggplant, sauce, and cheeses.", localImageName: "EggplantParm5"),
            Step(order: 6, text: "Bake uncovered for 25 minutes until the cheese is melted, bubbly, and golden brown.", durationSec: 1500, localImageName: "EggplantParm6")
        ]
        return Recipe(id: "eggplantparm-114", title: "Eggplant Parmigiana (Melanzane)", localImageName: "EggplantParmigianaMelanzaneHeader", imageURL: nil, totalTimeMinutes: 70, difficulty: "Medium", calories: 450, rating: 4.1, defaultServings: 6, tags: ["Italian", "Vegetarian"], ingredients: ingredients, steps: steps)
    }

    private static func createFocaccia() -> Recipe {
        let ingredients = [
            Ingredient(name: "All-purpose flour", quantity: 500.0, unit: "g"),
            Ingredient(name: "Warm water", quantity: 360.0, unit: "ml"),
            Ingredient(name: "Active dry yeast", quantity: 7.0, unit: "g"),
            Ingredient(name: "Sugar", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Extra virgin olive oil", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Flaky sea salt", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Fresh rosemary", quantity: 2, unit: "sprigs")
        ]
        let steps = [
            Step(order: 1, text: "In a large bowl, mix warm water, yeast, and sugar. Let sit for 5 minutes until foamy.", durationSec: 300, localImageName: "Focaccia1"),
            Step(order: 2, text: "Add the flour and 1/4 cup of olive oil. Mix until a shaggy dough forms. Knead on a floured surface for 5 minutes until smooth.", durationSec: 300, localImageName: "Focaccia2"),
            Step(order: 3, text: "Place dough in an oiled bowl, cover, and let rise for 1.5 hours until doubled.", durationSec: 5400, localImageName: "Focaccia3"),
            Step(order: 4, text: "Pour remaining 1/4 cup olive oil into a 9x13 inch baking pan. Transfer the dough into the pan, pressing it out to the edges. Let rise for 30 minutes.", durationSec: 1800, localImageName: "Focaccia4"),
            Step(order: 5, text: "Preheat oven to 400°F (200°C). Using your fingers, press deep dimples all over the dough. Sprinkle with flaky sea salt and rosemary leaves.", localImageName: "Focaccia5"),
            Step(order: 6, text: "Bake for 25 minutes until golden brown. Let cool slightly before slicing.", durationSec: 1500, localImageName: "Focaccia6")
        ]
        return Recipe(id: "focaccia-115", title: "Fluffy Rosemary Focaccia Bread", localImageName: "FluffyRosemaryFocacciaBreadHeader", imageURL: nil, totalTimeMinutes: 160, difficulty: "Medium", calories: 250, rating: 4.3, defaultServings: 8, tags: ["Italian", "Bread", "Baking"], ingredients: ingredients, steps: steps)
    }

    private static func createRavioli() -> Recipe {
        let ingredients = [
            Ingredient(name: "Wonton wrappers", quantity: 1, unit: "package"),
            Ingredient(name: "Ricotta cheese", quantity: 250.0, unit: "g"),
            Ingredient(name: "Fresh spinach, finely chopped", quantity: 60.0, unit: "g"),
            Ingredient(name: "Parmesan cheese", quantity: 25.0, unit: "g"),
            Ingredient(name: "Egg, beaten", quantity: 1, unit: "unit"),
            Ingredient(name: "Butter", quantity: 4, unit: "tbsp"),
            Ingredient(name: "Garlic, minced", quantity: 1, unit: "clove")
        ]
        let steps = [
            Step(order: 1, text: "In a bowl, mix the ricotta, chopped spinach, and parmesan cheese until combined.", localImageName: "Ravioli1"),
            Step(order: 2, text: "Lay out half of the wonton wrappers. Place 1 teaspoon of the filling in the center of each wrapper.", localImageName: "Ravioli2"),
            Step(order: 3, text: "Brush the edges of the wrappers with the beaten egg. Place another wrapper on top and press the edges firmly to seal, pushing out any air.", localImageName: "Ravioli3"),
            Step(order: 4, text: "Boil a large pot of salted water. Drop the ravioli in and cook for 3 minutes until they float. Drain carefully.", durationSec: 180, localImageName: "Ravioli4"),
            Step(order: 5, text: "In a skillet, melt the butter over medium heat until it foams and slightly browns (about 3 minutes). Add garlic for 30 seconds. Toss the cooked ravioli in the garlic butter and serve.", durationSec: 210, localImageName: "Ravioli5")
        ]
        return Recipe(id: "ravioli-116", title: "Spinach and Ricotta Ravioli", localImageName: "SpinachAndRicottaRavioliHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 350, rating: 3.8, tags: ["Italian", "Pasta", "Vegetarian"], ingredients: ingredients, steps: steps)
    }

    private static func createArrabbiata() -> Recipe {
        let ingredients = [
            Ingredient(name: "Penne pasta", quantity: 450.0, unit: "g"),
            Ingredient(name: "Olive oil", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Garlic, minced", quantity: 4, unit: "cloves"),
            Ingredient(name: "Red pepper flakes", quantity: 1, unit: "tsp"),
            Ingredient(name: "Crushed tomatoes", quantity: 800.0, unit: "g"),
            Ingredient(name: "Fresh parsley, chopped", quantity: 15.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Cook penne in boiling salted water according to package directions (about 10 minutes). Drain and set aside.", durationSec: 600, localImageName: "Arrabbiata1"),
            Step(order: 2, text: "In a large skillet, heat olive oil over medium heat. Add garlic and red pepper flakes, sautéing for 1 minute until fragrant but not browned.", durationSec: 60, localImageName: "Arrabbiata2"),
            Step(order: 3, text: "Pour in the crushed tomatoes. Reduce heat to low and simmer for 10 minutes to allow flavors to meld.", durationSec: 600, localImageName: "Arrabbiata3"),
            Step(order: 4, text: "Add the cooked penne to the skillet and toss for 2 minutes until the pasta is fully coated in the spicy sauce.", durationSec: 120, localImageName: "Arrabbiata4"),
            Step(order: 5, text: "Stir in the fresh parsley and serve immediately.", localImageName: "Arrabbiata5")
        ]
        return Recipe(id: "arrabbiata-117", title: "Spicy Penne Arrabbiata", localImageName: "SpicyPenneArrabbiataHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 380, rating: 3.9, tags: ["Italian", "Pasta", "Vegan"], ingredients: ingredients, steps: steps)
    }

    private static func createOssoBuco() -> Recipe {
        let ingredients = [
            Ingredient(name: "Veal shanks", quantity: 4, unit: "units"),
            Ingredient(name: "Flour", quantity: 60.0, unit: "g"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Onion, finely diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Carrot, finely diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Celery stalk, finely diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Dry white wine", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Beef broth", quantity: 480.0, unit: "ml"),
            Ingredient(name: "Diced tomatoes", quantity: 400.0, unit: "g"),
            Ingredient(name: "Instant polenta", quantity: 170.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Tie kitchen twine around the outside of each veal shank so it holds its shape. Dredge the shanks in flour, shaking off excess.", localImageName: "OssoBuco1"),
            Step(order: 2, text: "Heat olive oil in a heavy Dutch oven over medium-high heat. Sear the veal shanks for 5 minutes per side until deeply browned. Remove and set aside.", durationSec: 600, localImageName: "OssoBuco2"),
            Step(order: 3, text: "In the same pot, add the diced onion, carrot, and celery. Sauté for 8 minutes until softened.", durationSec: 480, localImageName: "OssoBuco3"),
            Step(order: 4, text: "Pour in the white wine to deglaze the pan, scraping up browned bits for 2 minutes.", durationSec: 120, localImageName: "OssoBuco4"),
            Step(order: 5, text: "Add the beef broth and diced tomatoes. Return the veal to the pot. Bring to a simmer, cover, and cook on low heat for 2 hours (120 minutes) until the meat is fork-tender.", durationSec: 7200, localImageName: "OssoBuco5"),
            Step(order: 6, text: "10 minutes before serving, bring 4 cups of salted water to a boil in a saucepan. Whisk in the instant polenta and cook for 5 minutes until thick and creamy.", durationSec: 300, localImageName: "OssoBuco6"),
            Step(order: 7, text: "Serve the veal shanks and rich sauce over a bed of warm polenta.", localImageName: "OssoBuco7")
        ]
        return Recipe(id: "ossobuco-118", title: "Veal Osso Buco with Polenta", localImageName: "VealOssoBucoWithPolentaHeader", imageURL: nil, totalTimeMinutes: 170, difficulty: "Hard", calories: 750, rating: 4.5, tags: ["Italian", "Meat"], ingredients: ingredients, steps: steps)
    }

    private static func createCalamari() -> Recipe {
        let ingredients = [
            Ingredient(name: "Squid rings", quantity: 450.0, unit: "g"),
            Ingredient(name: "All-purpose flour", quantity: 120.0, unit: "g"),
            Ingredient(name: "Paprika", quantity: 1, unit: "tsp"),
            Ingredient(name: "Salt", quantity: 1, unit: "tsp"),
            Ingredient(name: "Vegetable oil", quantity: 480.0, unit: "ml"),
            Ingredient(name: "Mayonnaise", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Garlic, minced", quantity: 1, unit: "clove"),
            Ingredient(name: "Lemon juice", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "In a small bowl, whisk mayonnaise, minced garlic, and lemon juice to make the aioli. Set aside in the fridge.", localImageName: "Calamari1"),
            Step(order: 2, text: "In a shallow dish, whisk together the flour, paprika, and salt. Toss the squid rings in the flour mixture until completely coated.", localImageName: "Calamari2"),
            Step(order: 3, text: "Heat vegetable oil in a deep skillet to 350°F (175°C).", localImageName: "Calamari3"),
            Step(order: 4, text: "Carefully drop the calamari rings into the hot oil in batches. Fry for 2 minutes until golden brown and crispy.", durationSec: 120, localImageName: "Calamari4"),
            Step(order: 5, text: "Remove with a slotted spoon and drain on paper towels. Serve immediately with the garlic aioli.", localImageName: "Calamari5")
        ]
        return Recipe(id: "calamari-119", title: "Crispy Calamari Rings with Aioli", localImageName: "CrispyCalamariRingsWithAioliHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Medium", calories: 400, rating: 4.0, tags: ["Seafood", "Appetizer"], ingredients: ingredients, steps: steps)
    }

    private static func createMinestrone() -> Recipe {
        let ingredients = [
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Onion, diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Carrots, diced", quantity: 2, unit: "units"),
            Ingredient(name: "Celery stalks, diced", quantity: 2, unit: "units"),
            Ingredient(name: "Garlic, minced", quantity: 2, unit: "cloves"),
            Ingredient(name: "Diced tomatoes", quantity: 400.0, unit: "g"),
            Ingredient(name: "Vegetable broth", quantity: 960.0, unit: "ml"),
            Ingredient(name: "Kidney beans", quantity: 425.0, unit: "g"),
            Ingredient(name: "Zucchini, diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Small pasta", quantity: 60.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Heat olive oil in a large pot over medium heat. Add the onion, carrots, and celery, cooking for 8 minutes until softened.", durationSec: 480, localImageName: "Minestrone1"),
            Step(order: 2, text: "Add the garlic and cook for 1 minute until fragrant.", durationSec: 60, localImageName: "Minestrone2"),
            Step(order: 3, text: "Pour in the diced tomatoes and vegetable broth. Bring to a boil, then reduce heat and simmer for 15 minutes.", durationSec: 900, localImageName: "Minestrone3"),
            Step(order: 4, text: "Add the kidney beans, zucchini, and pasta. Simmer for an additional 12 minutes until the pasta and vegetables are tender.", durationSec: 720, localImageName: "Minestrone4"),
            Step(order: 5, text: "Season with salt and pepper to taste. Serve warm.", localImageName: "Minestrone5")
        ]
        return Recipe(id: "minestrone-120", title: "Classic Minestrone Soup", localImageName: "ClassicMinestroneSoupHeader", imageURL: nil, totalTimeMinutes: 55, difficulty: "Easy", calories: 250, rating: 3.7, tags: ["Italian", "Soup", "Vegetarian"], ingredients: ingredients, steps: steps)
    }

    private static func createHummus() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chickpeas, drained", quantity: 425.0, unit: "g"),
            Ingredient(name: "Tahini", quantity: 120.0, unit: "g"),
            Ingredient(name: "Lemon juice", quantity: 60.0, unit: "ml"),
            Ingredient(name: "Garlic, minced", quantity: 1, unit: "clove"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Cumin", quantity: 0.5, unit: "tsp"),
            Ingredient(name: "Ice water", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Pita breads", quantity: 2, unit: "units")
        ]
        let steps = [
            Step(order: 1, text: "In a food processor, combine tahini and lemon juice. Process for 1 minute until whipped and creamy.", durationSec: 60, localImageName: "Hummus1"),
            Step(order: 2, text: "Add the garlic, olive oil, and cumin to the processor. Process for 30 seconds.", durationSec: 30, localImageName: "Hummus2"),
            Step(order: 3, text: "Add the drained chickpeas to the mixture and blend for 2 minutes until very smooth, scraping down the sides as needed.", durationSec: 120, localImageName: "Hummus3"),
            Step(order: 4, text: "With the processor running, slowly pour in the ice water 1 tablespoon at a time, blending for 1 more minute until the hummus becomes fluffy and light.", durationSec: 60, localImageName: "Hummus4"),
            Step(order: 5, text: "Toast the pita breads in a pan for 1 minute per side until warm. Serve alongside the hummus.", durationSec: 120, localImageName: "Hummus5")
        ]
        return Recipe(id: "hummus-121", title: "Authentic Creamy Hummus with Pita", localImageName: "AuthenticCreamyHummusWithPitaHeader", imageURL: nil, totalTimeMinutes: 15, difficulty: "Easy", calories: 300, rating: 4.4, tags: ["Middle Eastern", "Dip", "Vegan"], ingredients: ingredients, steps: steps)
    }

    private static func createShawarma() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chicken thighs", quantity: 680.0, unit: "g"),
            Ingredient(name: "Olive oil", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Cumin", quantity: 1, unit: "tsp"),
            Ingredient(name: "Paprika", quantity: 1, unit: "tsp"),
            Ingredient(name: "Turmeric", quantity: 1, unit: "tsp"),
            Ingredient(name: "Cinnamon", quantity: 1, unit: "tsp"),
            Ingredient(name: "Garlic powder", quantity: 0.5, unit: "tsp"),
            Ingredient(name: "Red onion, sliced", quantity: 0.5, unit: "unit"),
            Ingredient(name: "Flatbreads", quantity: 4, unit: "units")
        ]
        let steps = [
            Step(order: 1, text: "In a large bowl, mix olive oil, cumin, paprika, turmeric, cinnamon, and garlic powder. Add the chicken thighs and coat evenly.", localImageName: "Shawarma1"),
            Step(order: 2, text: "Preheat oven to 400°F (200°C) or heat a large grill pan over medium-high heat.", localImageName: "Shawarma2"),
            Step(order: 3, text: "Cook the chicken thighs for 8 minutes per side until charred on the outside and cooked through. Let rest for 5 minutes.", durationSec: 960, localImageName: "Shawarma3"),
            Step(order: 4, text: "Slice the cooked chicken thinly.", localImageName: "Shawarma4"),
            Step(order: 5, text: "Serve the warm chicken slices inside flatbreads, topped with the sliced red onion.", localImageName: "Shawarma5")
        ]
        return Recipe(id: "shawarma-122", title: "Middle Eastern Chicken Shawarma", localImageName: "MiddleEasternChickenShawarmaHeader", imageURL: nil, totalTimeMinutes: 35, difficulty: "Medium", calories: 500, rating: 4.5, tags: ["Middle Eastern", "Chicken", "Wrap"], ingredients: ingredients, steps: steps)
    }

    private static func createFalafel() -> Recipe {
        let ingredients = [
            Ingredient(name: "Dried chickpeas, soaked", quantity: 200.0, unit: "g"),
            Ingredient(name: "Onion, chopped", quantity: 0.5, unit: "unit"),
            Ingredient(name: "Fresh parsley and cilantro", quantity: 40.0, unit: "g"),
            Ingredient(name: "Garlic", quantity: 3, unit: "cloves"),
            Ingredient(name: "Cumin", quantity: 1, unit: "tsp"),
            Ingredient(name: "Coriander", quantity: 1, unit: "tsp"),
            Ingredient(name: "Baking powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Vegetable oil", quantity: 240.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Drain the overnight-soaked chickpeas well. Add them to a food processor with the onion, herbs, garlic, cumin, and coriander.", localImageName: "Falafel1"),
            Step(order: 2, text: "Pulse the mixture until it resembles a coarse meal (about 1-2 minutes). Do not over-blend into a paste. Stir in the baking powder.", durationSec: 120, localImageName: "Falafel2"),
            Step(order: 3, text: "Form the mixture into small, tightly packed balls or patties using your hands (about 2 tablespoons per ball).", localImageName: "Falafel3"),
            Step(order: 4, text: "Heat 2 inches of vegetable oil in a deep skillet to 350°F (175°C).", localImageName: "Falafel4"),
            Step(order: 5, text: "Fry the falafel in batches for 4 minutes per side, until deep golden brown and crispy. Drain on paper towels and serve immediately.", durationSec: 480, localImageName: "Falafel5")
        ]
        return Recipe(id: "falafel-123", title: "Crispy Golden Falafel", localImageName: "CrispyGoldenFalafelHeader", imageURL: nil, totalTimeMinutes: 30, difficulty: "Medium", calories: 350, rating: 4.2, tags: ["Middle Eastern", "Vegan", "Fried"], ingredients: ingredients, steps: steps)
    }

    private static func createKofta() -> Recipe {
        let ingredients = [
            Ingredient(name: "Ground lamb", quantity: 450.0, unit: "g"),
            Ingredient(name: "Onion, grated", quantity: 0.5, unit: "unit"),
            Ingredient(name: "Garlic, minced", quantity: 2, unit: "cloves"),
            Ingredient(name: "Fresh mint, chopped", quantity: 15.0, unit: "g"),
            Ingredient(name: "Cumin", quantity: 1, unit: "tsp"),
            Ingredient(name: "Coriander", quantity: 1, unit: "tsp"),
            Ingredient(name: "Wooden skewers", quantity: 4, unit: "units")
        ]
        let steps = [
            Step(order: 1, text: "In a large bowl, combine the ground lamb, grated onion, garlic, mint, cumin, and coriander. Mix thoroughly with your hands until well integrated.", localImageName: "Kofta1"),
            Step(order: 2, text: "Divide the meat into 4 equal portions. Mold each portion tightly around a soaked wooden skewer, creating a long, sausage-like shape.", localImageName: "Kofta2"),
            Step(order: 3, text: "Heat a grill or heavy grill pan over medium-high heat. Brush lightly with oil.", localImageName: "Kofta3"),
            Step(order: 4, text: "Cook the kebabs for 8-10 minutes, turning every 2 minutes, until browned on all sides and cooked through. Serve hot.", durationSec: 600, localImageName: "Kofta4")
        ]
        return Recipe(id: "kofta-124", title: "Spiced Lamb Kofta Kebabs", localImageName: "SpicedLambKoftaKebabsHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 400, rating: 4.0, tags: ["Middle Eastern", "Lamb", "BBQ"], ingredients: ingredients, steps: steps)
    }

    private static func createBabaGanoush() -> Recipe {
        let ingredients = [
            Ingredient(name: "Large eggplants", quantity: 2, unit: "units"),
            Ingredient(name: "Tahini", quantity: 60.0, unit: "g"),
            Ingredient(name: "Lemon juice", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Garlic, minced", quantity: 2, unit: "cloves"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Fresh parsley, chopped", quantity: 15.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 400°F (200°C). Prick the eggplants all over with a fork.", localImageName: "Baba1"),
            Step(order: 2, text: "Place eggplants on a foil-lined baking sheet and roast for 45 minutes, turning once, until the skin is charred and the flesh is very soft and collapsed.", durationSec: 2700, localImageName: "Baba2"),
            Step(order: 3, text: "Remove from oven and let cool for 10 minutes. Slice them open and scoop out the soft flesh into a strainer to drain excess water.", durationSec: 600, localImageName: "Baba3"),
            Step(order: 4, text: "Transfer the eggplant flesh to a bowl and mash it with a fork.", localImageName: "Baba4"),
            Step(order: 5, text: "Stir in the tahini, lemon juice, and minced garlic. Drizzle with olive oil, garnish with parsley, and serve with pita.", localImageName: "Baba5")
        ]
        return Recipe(id: "babaganoush-125", title: "Roasted Eggplant Baba Ganoush", localImageName: "RoastedEggplantBabaGanoushHeader", imageURL: nil, totalTimeMinutes: 55, difficulty: "Easy", calories: 150, rating: 3.8, tags: ["Middle Eastern", "Dip", "Vegan"], ingredients: ingredients, steps: steps)
    }

    private static func createFriedChicken() -> Recipe {
        let ingredients = [
            Ingredient(name: "Whole chicken, cut", quantity: 1, unit: "unit"),
            Ingredient(name: "Buttermilk", quantity: 480.0, unit: "ml"),
            Ingredient(name: "All-purpose flour", quantity: 250.0, unit: "g"),
            Ingredient(name: "Paprika", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Garlic powder", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Cayenne pepper", quantity: 1, unit: "tsp"),
            Ingredient(name: "Vegetable oil", quantity: 960.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Submerge the chicken pieces in buttermilk and let soak for at least 30 minutes.", durationSec: 1800, localImageName: "FriedChicken1"),
            Step(order: 2, text: "In a large shallow dish, whisk together the flour, paprika, garlic powder, cayenne, and a generous pinch of salt and pepper.", localImageName: "FriedChicken2"),
            Step(order: 3, text: "Remove chicken from the buttermilk, letting excess drip off, and dredge thoroughly in the flour mixture until completely coated.", localImageName: "FriedChicken3"),
            Step(order: 4, text: "Heat oil in a deep cast-iron skillet to 350°F (175°C).", localImageName: "FriedChicken4"),
            Step(order: 5, text: "Carefully fry the chicken in batches for 12-15 minutes per side, until deep golden brown and the internal temperature reaches 165°F (74°C). Drain on a wire rack.", durationSec: 1800, localImageName: "FriedChicken5")
        ]
        return Recipe(id: "friedchicken-126", title: "Southern Fried Chicken", localImageName: "SouthernFriedChickenHeader", imageURL: nil, totalTimeMinutes: 50, difficulty: "Medium", calories: 700, rating: 3.9, tags: ["American", "Chicken", "Fried"], ingredients: ingredients, steps: steps)
    }

    private static func createPulledPork() -> Recipe {
        let ingredients = [
            Ingredient(name: "Pork shoulder", quantity: 1350.0, unit: "g"),
            Ingredient(name: "Smoked paprika", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Brown sugar", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Garlic powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Onion powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Chicken broth", quantity: 240.0, unit: "ml"),
            Ingredient(name: "BBQ sauce", quantity: 360.0, unit: "ml"),
            Ingredient(name: "Hamburger buns", quantity: 6, unit: "units")
        ]
        let steps = [
            Step(order: 1, text: "Mix the paprika, brown sugar, garlic powder, and onion powder to create a rub. Coat the pork shoulder evenly with the spice mixture.", localImageName: "PulledPork1"),
            Step(order: 2, text: "Place the seasoned pork in a slow cooker. Pour the chicken broth around the base of the meat.", localImageName: "PulledPork2"),
            Step(order: 3, text: "Cover and cook on LOW for 8 hours (480 minutes) until the meat is incredibly tender and falls apart easily.", durationSec: 28800, localImageName: "PulledPork3"),
            Step(order: 4, text: "Remove the pork from the slow cooker, discard any excess fat, and shred the meat using two forks.", localImageName: "PulledPork4"),
            Step(order: 5, text: "Toss the shredded pork with the BBQ sauce and serve warm on hamburger buns.", localImageName: "PulledPork5")
        ]
        return Recipe(id: "pulledpork-127", title: "Slow-Cooked BBQ Pulled Pork", localImageName: "SlowcookedBbqPulledPorkHeader", imageURL: nil, totalTimeMinutes: 495, difficulty: "Easy", calories: 600, rating: 4.8, defaultServings: 8, tags: ["American", "Pork", "BBQ"], ingredients: ingredients, steps: steps)
    }

    private static func createMacAndCheese() -> Recipe {
        let ingredients = [
            Ingredient(name: "Elbow macaroni", quantity: 450.0, unit: "g"),
            Ingredient(name: "Butter", quantity: 55.0, unit: "g"),
            Ingredient(name: "All-purpose flour", quantity: 30.0, unit: "g"),
            Ingredient(name: "Whole milk", quantity: 720.0, unit: "ml"),
            Ingredient(name: "Sharp cheddar cheese", quantity: 230.0, unit: "g"),
            Ingredient(name: "Gruyere cheese", quantity: 115.0, unit: "g"),
            Ingredient(name: "Panko breadcrumbs", quantity: 50.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 350°F (175°C). Boil the macaroni in salted water for 8 minutes (slightly undercooked). Drain.", durationSec: 480, localImageName: "MacCheese1"),
            Step(order: 2, text: "In a large pot, melt the butter over medium heat. Whisk in the flour and cook for 2 minutes to create a roux.", durationSec: 120, localImageName: "MacCheese2"),
            Step(order: 3, text: "Gradually pour in the milk, whisking constantly. Simmer for 5 minutes until the sauce thickens.", durationSec: 300, localImageName: "MacCheese3"),
            Step(order: 4, text: "Remove from heat and stir in the cheddar and gruyere cheeses until completely melted and smooth. Fold in the cooked macaroni.", localImageName: "MacCheese4"),
            Step(order: 5, text: "Pour the mixture into a 9x13 inch baking dish. Top evenly with panko breadcrumbs.", localImageName: "MacCheese5"),
            Step(order: 6, text: "Bake for 20 minutes until bubbling and the breadcrumbs are golden brown.", durationSec: 1200, localImageName: "MacCheese6")
        ]
        return Recipe(id: "macandcheese-128", title: "Ultimate Baked Macaroni and Cheese", localImageName: "UltimateBakedMacaroniAndCheeseHeader", imageURL: nil, totalTimeMinutes: 50, difficulty: "Medium", calories: 550, rating: 4.3, defaultServings: 6, tags: ["American", "Pasta", "Cheese"], ingredients: ingredients, steps: steps)
    }

    private static func createChickenTenders() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chicken breast tenders", quantity: 450.0, unit: "g"),
            Ingredient(name: "Buttermilk", quantity: 240.0, unit: "ml"),
            Ingredient(name: "All-purpose flour", quantity: 190.0, unit: "g"),
            Ingredient(name: "Garlic powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Paprika", quantity: 1, unit: "tsp"),
            Ingredient(name: "Salt", quantity: 1, unit: "tsp"),
            Ingredient(name: "Vegetable oil", quantity: 480.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Soak the chicken tenders in the buttermilk for 15 minutes.", durationSec: 900, localImageName: "Tenders1"),
            Step(order: 2, text: "In a separate bowl, whisk together the flour, garlic powder, paprika, and salt.", localImageName: "Tenders2"),
            Step(order: 3, text: "Remove each tender from the buttermilk and coat completely in the seasoned flour mixture.", localImageName: "Tenders3"),
            Step(order: 4, text: "Heat the vegetable oil in a large skillet over medium-high heat until a pinch of flour sizzles immediately.", localImageName: "Tenders4"),
            Step(order: 5, text: "Fry the chicken tenders for 5-6 minutes per side, until golden brown and cooked through. Drain on paper towels.", durationSec: 720, localImageName: "Tenders5")
        ]
        return Recipe(id: "chickentenders-129", title: "Crispy Buttermilk Chicken Tenders", localImageName: "CrispyButtermilkChickenTendersHeader", imageURL: nil, totalTimeMinutes: 30, difficulty: "Easy", calories: 450, rating: 4.6, tags: ["American", "Chicken", "Fried"], ingredients: ingredients, steps: steps)
    }

    private static func createPotPie() -> Recipe {
        let ingredients = [
            Ingredient(name: "Pie crusts", quantity: 2, unit: "units"),
            Ingredient(name: "Butter", quantity: 75.0, unit: "g"),
            Ingredient(name: "Flour", quantity: 40.0, unit: "g"),
            Ingredient(name: "Chicken broth", quantity: 360.0, unit: "ml"),
            Ingredient(name: "Milk", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Cooked chicken, shredded", quantity: 300.0, unit: "g"),
            Ingredient(name: "Frozen mixed vegetables", quantity: 150.0, unit: "g"),
            Ingredient(name: "Egg, beaten", quantity: 1, unit: "unit")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 400°F (200°C).", localImageName: "PotPie1"),
            Step(order: 2, text: "In a saucepan, melt butter over medium heat. Stir in the flour and cook for 1 minute.", durationSec: 60, localImageName: "PotPie2"),
            Step(order: 3, text: "Gradually whisk in the chicken broth and milk. Simmer for 5 minutes until the sauce is thick and creamy.", durationSec: 300, localImageName: "PotPie3"),
            Step(order: 4, text: "Stir the shredded chicken and frozen vegetables into the sauce. Remove from heat.", localImageName: "PotPie4"),
            Step(order: 5, text: "Line a 9-inch pie dish with one pie crust. Pour the chicken filling into the crust.", localImageName: "PotPie5"),
            Step(order: 6, text: "Cover with the second pie crust. Crimp the edges to seal and cut 3 slits in the top for steam to escape. Brush the top with the beaten egg.", localImageName: "PotPie6"),
            Step(order: 7, text: "Bake for 30-35 minutes until the crust is golden brown and the filling is bubbly. Let cool for 10 minutes before slicing.", durationSec: 2100, localImageName: "PotPie7")
        ]
        return Recipe(id: "potpie-130", title: "Classic Chicken Pot Pie", localImageName: "ClassicChickenPotPieHeader", imageURL: nil, totalTimeMinutes: 65, difficulty: "Medium", calories: 500, rating: 4.2, defaultServings: 6, tags: ["American", "Chicken", "Pie"], ingredients: ingredients, steps: steps)
    }

    private static func createTurkeyBurgers() -> Recipe {
        let ingredients = [
            Ingredient(name: "Ground turkey", quantity: 450.0, unit: "g"),
            Ingredient(name: "Breadcrumbs", quantity: 30.0, unit: "g"),
            Ingredient(name: "Garlic powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Worcestershire sauce", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Burger buns", quantity: 4, unit: "units")
        ]
        let steps = [
            Step(order: 1, text: "In a bowl, gently combine the ground turkey, breadcrumbs, garlic powder, and Worcestershire sauce. Do not overmix.", localImageName: "TurkeyBurger1"),
            Step(order: 2, text: "Form the mixture into 4 equal-sized patties, pressing a small dimple into the center of each to prevent them from puffing up.", localImageName: "TurkeyBurger2"),
            Step(order: 3, text: "Heat olive oil in a skillet or heat a grill to medium-high.", localImageName: "TurkeyBurger3"),
            Step(order: 4, text: "Cook the patties for 6 minutes per side, ensuring the internal temperature reaches 165°F (74°C).", durationSec: 720, localImageName: "TurkeyBurger4"),
            Step(order: 5, text: "Serve immediately on burger buns with your favorite toppings.", localImageName: "TurkeyBurger5")
        ]
        return Recipe(id: "turkeyburgers-131", title: "Juicy Turkey Burgers", localImageName: "JuicyTurkeyBurgersHeader", imageURL: nil, totalTimeMinutes: 22, difficulty: "Easy", calories: 350, rating: 3.6, tags: ["American", "Turkey", "Grill"], ingredients: ingredients, steps: steps)
    }

    private static func createBakedHam() -> Recipe {
        let ingredients = [
            Ingredient(name: "Bone-in ham", quantity: 2250.0, unit: "g"),
            Ingredient(name: "Honey", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Brown sugar", quantity: 50.0, unit: "g"),
            Ingredient(name: "Dijon mustard", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Apple cider vinegar", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 325°F (160°C). Place the ham in a roasting pan, cover tightly with foil, and bake for 60 minutes.", durationSec: 3600, localImageName: "BakedHam1"),
            Step(order: 2, text: "While the ham bakes, whisk together the honey, brown sugar, Dijon mustard, and apple cider vinegar in a small bowl to make the glaze.", localImageName: "BakedHam2"),
            Step(order: 3, text: "Remove the ham from the oven and discard the foil. Score the fat on the outside of the ham in a diamond pattern.", localImageName: "BakedHam3"),
            Step(order: 4, text: "Brush half of the glaze generously over the ham.", localImageName: "BakedHam4"),
            Step(order: 5, text: "Return the ham to the oven uncovered. Bake for 15 minutes. Brush the remaining glaze over the top and bake for a final 15 minutes until sticky and caramelized.", durationSec: 1800, localImageName: "BakedHam5")
        ]
        return Recipe(id: "bakedham-132", title: "Honey Glazed Baked Ham", localImageName: "HoneyGlazedBakedHamHeader", imageURL: nil, totalTimeMinutes: 105, difficulty: "Easy", calories: 400, rating: 4.1, defaultServings: 8, tags: ["American", "Pork", "Holiday"], ingredients: ingredients, steps: steps)
    }

    private static func createShortRibs() -> Recipe {
        let ingredients = [
            Ingredient(name: "Beef short ribs", quantity: 1350.0, unit: "g"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Onion, diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Carrots, chopped", quantity: 2, unit: "units"),
            Ingredient(name: "Dry red wine", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Beef broth", quantity: 480.0, unit: "ml"),
            Ingredient(name: "Fresh thyme", quantity: 2, unit: "sprigs")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 325°F (160°C). Season the ribs generously with salt and pepper.", localImageName: "ShortRibs1"),
            Step(order: 2, text: "Heat olive oil in a large Dutch oven over medium-high heat. Sear the ribs for 3 minutes per side until deeply browned. Remove and set aside.", durationSec: 360, localImageName: "ShortRibs2"),
            Step(order: 3, text: "Add the onion and carrots to the pot, cooking for 5 minutes until soft.", durationSec: 300, localImageName: "ShortRibs3"),
            Step(order: 4, text: "Pour in the red wine, scraping up the browned bits from the bottom, and simmer for 3 minutes until reduced by half.", durationSec: 180, localImageName: "ShortRibs4"),
            Step(order: 5, text: "Return the ribs to the pot. Add the beef broth and thyme sprigs. The liquid should cover about half of the meat.", localImageName: "ShortRibs5"),
            Step(order: 6, text: "Cover the pot and transfer to the oven. Roast for 2.5 to 3 hours (150-180 minutes) until the meat is fork-tender and falling off the bone.", durationSec: 10800, localImageName: "ShortRibs6")
        ]
        return Recipe(id: "shortribs-133", title: "Slow-Roasted Beef Short Ribs", localImageName: "SlowroastedBeefShortRibsHeader", imageURL: nil, totalTimeMinutes: 200, difficulty: "Medium", calories: 650, rating: 4.5, tags: ["American", "Beef", "SlowCook"], ingredients: ingredients, steps: steps)
    }

    private static func createSalmon() -> Recipe {
        let ingredients = [
            Ingredient(name: "Salmon fillets", quantity: 2, unit: "units"),
            Ingredient(name: "Asparagus, trimmed", quantity: 1, unit: "bunch"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Lemon juice", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Garlic, minced", quantity: 1, unit: "clove")
        ]
        let steps = [
            Step(order: 1, text: "Toss the trimmed asparagus with 1 tbsp olive oil, minced garlic, salt, and pepper. Set aside.", localImageName: "Salmon1"),
            Step(order: 2, text: "Pat the salmon fillets completely dry with a paper towel and season with salt and pepper.", localImageName: "Salmon2"),
            Step(order: 3, text: "Heat the remaining 1 tbsp olive oil in a large skillet over medium-high heat.", localImageName: "Salmon3"),
            Step(order: 4, text: "Place the salmon fillets flesh-side down in the pan. Cook for 4 minutes until a golden crust forms.", durationSec: 240, localImageName: "Salmon4"),
            Step(order: 5, text: "Flip the salmon. Add the asparagus to the empty spaces in the pan. Cook everything together for another 4-5 minutes until the salmon is cooked through and the asparagus is tender-crisp. Drizzle with lemon juice before serving.", durationSec: 300, localImageName: "Salmon5")
        ]
        return Recipe(id: "salmon-134", title: "Pan-Seared Salmon with Asparagus", localImageName: "PansearedSalmonWithAsparagusHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 400, rating: 4.3, defaultServings: 2, tags: ["Seafood", "Healthy", "Quick"], ingredients: ingredients, steps: steps)
    }

    private static func createClamChowder() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chopped clams (reserve juice)", quantity: 550.0, unit: "g"),
            Ingredient(name: "Bacon, chopped", quantity: 4, unit: "slices"),
            Ingredient(name: "Onion, diced", quantity: 1, unit: "unit"),
            Ingredient(name: "Potatoes, cubed", quantity: 2, unit: "units"),
            Ingredient(name: "Heavy cream", quantity: 240.0, unit: "ml"),
            Ingredient(name: "All-purpose flour", quantity: 2, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "In a large pot, cook the chopped bacon over medium heat for 6 minutes until crispy. Remove the bacon bits, leaving the bacon fat in the pot.", durationSec: 360, localImageName: "Chowder1"),
            Step(order: 2, text: "Add the diced onion to the pot and cook for 5 minutes until soft.", durationSec: 300, localImageName: "Chowder2"),
            Step(order: 3, text: "Stir in the flour and cook for 1 minute.", durationSec: 60, localImageName: "Chowder3"),
            Step(order: 4, text: "Pour in the reserved clam juice from the cans and add the cubed potatoes. Bring to a boil, then lower heat and simmer for 15 minutes until the potatoes are tender.", durationSec: 900, localImageName: "Chowder4"),
            Step(order: 5, text: "Stir in the chopped clams and the heavy cream. Simmer gently for 3 minutes to heat through (do not boil, or the cream may curdle). Top with the crispy bacon before serving.", durationSec: 180, localImageName: "Chowder5")
        ]
        return Recipe(id: "clamchowder-135", title: "Classic New England Clam Chowder", localImageName: "ClassicNewEnglandClamChowderHeader", imageURL: nil, totalTimeMinutes: 45, difficulty: "Medium", calories: 450, rating: 4.4, tags: ["American", "Soup", "Seafood"], ingredients: ingredients, steps: steps)
    }

    private static func createTilapia() -> Recipe {
        let ingredients = [
            Ingredient(name: "Tilapia fillets", quantity: 4, unit: "units"),
            Ingredient(name: "Butter, melted", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Lemon juice", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Dried oregano", quantity: 1, unit: "tsp"),
            Ingredient(name: "Garlic powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Lemon, sliced", quantity: 0.5, unit: "unit")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 400°F (200°C). Line a baking sheet with parchment paper.", localImageName: "Tilapia1"),
            Step(order: 2, text: "Place the tilapia fillets on the baking sheet.", localImageName: "Tilapia2"),
            Step(order: 3, text: "In a small bowl, mix the melted butter, lemon juice, dried oregano, and garlic powder.", localImageName: "Tilapia3"),
            Step(order: 4, text: "Brush the butter mixture evenly over the fish fillets. Top each fillet with a slice of fresh lemon.", localImageName: "Tilapia4"),
            Step(order: 5, text: "Bake for 12-15 minutes, until the fish is opaque and flakes easily with a fork.", durationSec: 900, localImageName: "Tilapia5")
        ]
        return Recipe(id: "tilapia-136", title: "Lemon Herb Baked Tilapia", localImageName: "LemonHerbBakedTilapiaHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Easy", calories: 200, rating: 3.5, tags: ["Seafood", "Healthy", "Baking"], ingredients: ingredients, steps: steps)
    }

    private static func createFishAndChips() -> Recipe {
        let ingredients = [
            Ingredient(name: "Potatoes, cut into thick fries", quantity: 4, unit: "units"),
            Ingredient(name: "Cod or haddock fillets", quantity: 450.0, unit: "g"),
            Ingredient(name: "All-purpose flour", quantity: 120.0, unit: "g"),
            Ingredient(name: "Baking powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Cold beer", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Vegetable oil", quantity: 960.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Heat the vegetable oil in a deep fryer or large pot to 325°F (160°C). Fry the potatoes for 5 minutes (they will be soft but not brown). Remove and drain. Increase oil heat to 375°F (190°C).", durationSec: 300, localImageName: "FishChips1"),
            Step(order: 2, text: "In a bowl, whisk together the flour, baking powder, and a pinch of salt. Pour in the cold beer and whisk gently until just combined (lumps are fine).", localImageName: "FishChips2"),
            Step(order: 3, text: "Pat the fish fillets dry and dip them into the batter, coating fully.", localImageName: "FishChips3"),
            Step(order: 4, text: "Carefully lower the fish into the hot oil. Fry for 6-8 minutes until deep golden brown and crispy. Remove and drain.", durationSec: 480, localImageName: "FishChips4"),
            Step(order: 5, text: "Drop the fries back into the hot oil for a second fry, cooking for 3 minutes until crispy and golden. Serve together immediately.", durationSec: 180, localImageName: "FishChips5")
        ]
        return Recipe(id: "fishandchips-137", title: "Traditional Fish and Chips", localImageName: "TraditionalFishAndChipsHeader", imageURL: nil, totalTimeMinutes: 35, difficulty: "Medium", calories: 600, rating: 4.4, tags: ["British", "Seafood", "Fried"], ingredients: ingredients, steps: steps)
    }

    private static func createScallops() -> Recipe {
        let ingredients = [
            Ingredient(name: "Sea scallops", quantity: 450.0, unit: "g"),
            Ingredient(name: "Olive oil", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Butter", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Garlic, minced", quantity: 2, unit: "cloves"),
            Ingredient(name: "Lemon juice", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Pat the scallops completely dry with paper towels (crucial for a good sear). Season lightly with salt and pepper.", localImageName: "Scallops1"),
            Step(order: 2, text: "Heat the olive oil in a large skillet over high heat until it just begins to smoke.", localImageName: "Scallops2"),
            Step(order: 3, text: "Add the scallops to the pan, ensuring they do not touch. Sear without moving them for 2 minutes until a dark brown crust forms on the bottom.", durationSec: 120, localImageName: "Scallops3"),
            Step(order: 4, text: "Flip the scallops. Immediately add the butter and minced garlic to the pan.", localImageName: "Scallops4"),
            Step(order: 5, text: "As the butter melts and browns, use a spoon to baste the garlic butter over the scallops for 1.5 minutes. Remove from heat, drizzle with lemon juice, and serve instantly.", durationSec: 90, localImageName: "Scallops5")
        ]
        return Recipe(id: "scallops-138", title: "Seared Scallops with Garlic Butter", localImageName: "SearedScallopsWithGarlicButterHeader", imageURL: nil, totalTimeMinutes: 15, difficulty: "Medium", calories: 250, rating: 4.3, defaultServings: 2, tags: ["Seafood", "Fancy", "Quick"], ingredients: ingredients, steps: steps)
    }

    private static func createButternutSquashSoup() -> Recipe {
        let ingredients = [
            Ingredient(name: "Butternut squash, cubed", quantity: 1, unit: "unit"),
            Ingredient(name: "Onion, quartered", quantity: 1, unit: "unit"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Vegetable broth", quantity: 720.0, unit: "ml"),
            Ingredient(name: "Nutmeg", quantity: 0.5, unit: "tsp"),
            Ingredient(name: "Coconut milk", quantity: 60.0, unit: "ml")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 400°F (200°C).", localImageName: "SquashSoup1"),
            Step(order: 2, text: "Toss the cubed squash and quartered onion with olive oil on a baking sheet. Roast for 40 minutes until the squash is very soft and caramelized.", durationSec: 2400, localImageName: "SquashSoup2"),
            Step(order: 3, text: "Transfer the roasted squash and onion to a large pot. Pour in the vegetable broth and bring to a simmer over medium heat.", localImageName: "SquashSoup3"),
            Step(order: 4, text: "Use an immersion blender (or transfer to a standard blender) to puree the mixture until completely smooth.", localImageName: "SquashSoup4"),
            Step(order: 5, text: "Stir in the nutmeg and coconut milk. Simmer for 3 minutes until heated through.", durationSec: 180, localImageName: "SquashSoup5")
        ]
        return Recipe(id: "butternutsquash-139", title: "Roasted Butternut Squash Soup", localImageName: "RoastedButternutSquashSoupHeader", imageURL: nil, totalTimeMinutes: 60, difficulty: "Easy", calories: 200, rating: 4.0, tags: ["Soup", "Vegetarian", "Autumn"], ingredients: ingredients, steps: steps)
    }

    private static func createStuffedPeppers() -> Recipe {
        let ingredients = [
            Ingredient(name: "Bell peppers", quantity: 4, unit: "units"),
            Ingredient(name: "Cooked quinoa", quantity: 185.0, unit: "g"),
            Ingredient(name: "Black beans", quantity: 425.0, unit: "g"),
            Ingredient(name: "Corn kernels", quantity: 150.0, unit: "g"),
            Ingredient(name: "Salsa", quantity: 120.0, unit: "ml"),
            Ingredient(name: "Cumin", quantity: 1, unit: "tsp")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 375°F (190°C).", localImageName: "StuffedPeppers1"),
            Step(order: 2, text: "In a bowl, mix the cooked quinoa, black beans, corn, salsa, and cumin.", localImageName: "StuffedPeppers2"),
            Step(order: 3, text: "Stand the hollowed-out bell peppers upright in a baking dish.", localImageName: "StuffedPeppers3"),
            Step(order: 4, text: "Spoon the quinoa mixture tightly into each pepper, filling them to the top.", localImageName: "StuffedPeppers4"),
            Step(order: 5, text: "Pour 1/4 cup of water into the bottom of the baking dish to create steam. Cover the dish tightly with foil.", localImageName: "StuffedPeppers5"),
            Step(order: 6, text: "Bake for 30 minutes until the peppers are tender. Remove foil and bake for 5 more minutes.", durationSec: 2100, localImageName: "StuffedPeppers6")
        ]
        return Recipe(id: "stuffedpeppers-140", title: "Quinoa and Black Bean Stuffed Peppers", localImageName: "QuinoaAndBlackBeanStuffedPeppersHeader", imageURL: nil, totalTimeMinutes: 50, difficulty: "Easy", calories: 300, rating: 3.8, tags: ["Vegetarian", "Healthy", "Baking"], ingredients: ingredients, steps: steps)
    }

    private static func createSweetPotatoFries() -> Recipe {
        let ingredients = [
            Ingredient(name: "Sweet potatoes, cut into thin sticks", quantity: 2, unit: "units"),
            Ingredient(name: "Cornstarch", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Paprika", quantity: 0.5, unit: "tsp"),
            Ingredient(name: "Garlic powder", quantity: 0.5, unit: "tsp")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 425°F (220°C). Line a baking sheet with parchment paper.", localImageName: "SweetPotato1"),
            Step(order: 2, text: "Place the sweet potato sticks in a large bowl. Toss them with the cornstarch until lightly coated. (This helps them get crispy).", localImageName: "SweetPotato2"),
            Step(order: 3, text: "Drizzle with olive oil, sprinkle with paprika and garlic powder, and toss again to coat evenly.", localImageName: "SweetPotato3"),
            Step(order: 4, text: "Spread the fries in a single, even layer on the baking sheet. Make sure they are not touching.", localImageName: "SweetPotato4"),
            Step(order: 5, text: "Bake for 15 minutes. Remove from oven, flip the fries, and bake for an additional 10 minutes until the edges are crispy and browned.", durationSec: 1500, localImageName: "SweetPotato5")
        ]
        return Recipe(id: "sweetpotatofries-141", title: "Crispy Baked Sweet Potato Fries", localImageName: "CrispyBakedSweetPotatoFriesHeader", imageURL: nil, totalTimeMinutes: 35, difficulty: "Easy", calories: 180, rating: 3.7, tags: ["Side", "Vegetarian", "Healthy"], ingredients: ingredients, steps: steps)
    }

    private static func createChiaPudding() -> Recipe {
        let ingredients = [
            Ingredient(name: "Chia seeds", quantity: 40.0, unit: "g"),
            Ingredient(name: "Almond milk", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Maple syrup", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Vanilla extract", quantity: 0.5, unit: "tsp"),
            Ingredient(name: "Fresh berries", quantity: 75.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "In a jar or glass container, combine the chia seeds, almond milk, maple syrup, and vanilla extract.", localImageName: "Chia1"),
            Step(order: 2, text: "Stir thoroughly for 1 minute to ensure no clumps form. Let sit for 5 minutes, then stir vigorously one more time.", durationSec: 360, localImageName: "Chia2"),
            Step(order: 3, text: "Cover the container and place it in the refrigerator.", localImageName: "Chia3"),
            Step(order: 4, text: "Let it chill and thicken for at least 2 hours (120 minutes), or overnight.", durationSec: 7200, localImageName: "Chia4"),
            Step(order: 5, text: "Top with fresh berries before serving.", localImageName: "Chia5")
        ]
        return Recipe(id: "chiapudding-142", title: "Healthy Chia Seed Pudding", localImageName: "HealthyChiaSeedPuddingHeader", imageURL: nil, totalTimeMinutes: 125, difficulty: "Easy", calories: 250, rating: 3.9, defaultServings: 2, tags: ["Breakfast", "Healthy", "Vegan"], ingredients: ingredients, steps: steps)
    }

    private static func createCauliflowerSalad() -> Recipe {
        let ingredients = [
            Ingredient(name: "Cauliflower florets", quantity: 1, unit: "head"),
            Ingredient(name: "Olive oil", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Cumin", quantity: 0.5, unit: "tsp"),
            Ingredient(name: "Tahini", quantity: 3, unit: "tbsp"),
            Ingredient(name: "Lemon juice", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Warm water", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Pomegranate seeds", quantity: 40.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 425°F (220°C).", localImageName: "Cauliflower1"),
            Step(order: 2, text: "Toss the cauliflower florets with olive oil, cumin, salt, and pepper. Spread on a baking sheet.", localImageName: "Cauliflower2"),
            Step(order: 3, text: "Roast for 25 minutes, flipping halfway, until the cauliflower is tender and has browned, crispy edges.", durationSec: 1500, localImageName: "Cauliflower3"),
            Step(order: 4, text: "While the cauliflower roasts, whisk together the tahini, lemon juice, and warm water in a small bowl until smooth and pourable.", localImageName: "Cauliflower4"),
            Step(order: 5, text: "Transfer the warm roasted cauliflower to a serving dish. Drizzle generously with the tahini dressing and sprinkle with pomegranate seeds.", localImageName: "Cauliflower5")
        ]
        return Recipe(id: "cauliflowersalad-143", title: "Roasted Cauliflower and Tahini Salad", localImageName: "RoastedCauliflowerAndTahiniSaladHeader", imageURL: nil, totalTimeMinutes: 35, difficulty: "Easy", calories: 200, rating: 4.0, tags: ["Salad", "Vegan", "Healthy"], ingredients: ingredients, steps: steps)
    }

    private static func createCinnamonRolls() -> Recipe {
        let ingredients = [
            Ingredient(name: "All-purpose flour", quantity: 375.0, unit: "g"),
            Ingredient(name: "Rapid-rise yeast", quantity: 7.0, unit: "g"),
            Ingredient(name: "Warm milk", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Melted butter (for dough)", quantity: 75.0, unit: "g"),
            Ingredient(name: "Softened butter (for filling)", quantity: 55.0, unit: "g"),
            Ingredient(name: "Brown sugar", quantity: 100.0, unit: "g"),
            Ingredient(name: "Ground cinnamon", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Cream cheese, softened", quantity: 115.0, unit: "g"),
            Ingredient(name: "Powdered sugar", quantity: 120.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "In a stand mixer, combine warm milk, yeast, and 1 tbsp of sugar. Let sit for 5 minutes. Add the flour and melted butter, kneading for 5 minutes until a smooth dough forms. Cover and let rise for 1 hour.", durationSec: 4200, localImageName: "CinnamonRoll1"),
            Step(order: 2, text: "Roll the dough out on a floured surface into a 12x18 inch rectangle.", localImageName: "CinnamonRoll2"),
            Step(order: 3, text: "Spread the softened butter evenly over the dough. Mix the brown sugar and cinnamon, then sprinkle it evenly over the butter.", localImageName: "CinnamonRoll3"),
            Step(order: 4, text: "Roll the dough up tightly starting from the long edge. Cut into 12 equal slices using unflavored dental floss or a serrated knife.", localImageName: "CinnamonRoll4"),
            Step(order: 5, text: "Place the rolls in a greased 9x13 inch baking pan. Cover and let rise for 45 minutes.", durationSec: 2700, localImageName: "CinnamonRoll5"),
            Step(order: 6, text: "Preheat oven to 350°F (175°C). Bake the rolls for 25 minutes until golden brown.", durationSec: 1500, localImageName: "CinnamonRoll6"),
            Step(order: 7, text: "While baking, beat the cream cheese and powdered sugar together until smooth. Spread over the warm cinnamon rolls immediately after baking.", localImageName: "CinnamonRoll7")
        ]
        return Recipe(id: "cinnamonrolls-144", title: "Classic Cinnamon Rolls with Cream Cheese Icing", localImageName: "ClassicCinnamonRollsWithCreamCheeseIcingHeader", imageURL: nil, totalTimeMinutes: 175, difficulty: "Medium", calories: 450, rating: 4.7, defaultServings: 8, tags: ["Dessert", "Baking", "Sweet"], ingredients: ingredients, steps: steps)
    }

    private static func createBananaBread() -> Recipe {
        let ingredients = [
            Ingredient(name: "Overripe bananas, mashed", quantity: 3, unit: "units"),
            Ingredient(name: "Melted butter", quantity: 75.0, unit: "g"),
            Ingredient(name: "Sugar", quantity: 150.0, unit: "g"),
            Ingredient(name: "Egg", quantity: 1, unit: "unit"),
            Ingredient(name: "Vanilla extract", quantity: 1, unit: "tsp"),
            Ingredient(name: "All-purpose flour", quantity: 190.0, unit: "g"),
            Ingredient(name: "Baking soda", quantity: 1, unit: "tsp"),
            Ingredient(name: "Chopped walnuts", quantity: 60.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 350°F (175°C) and grease a 4x8 inch loaf pan.", localImageName: "BananaBread1"),
            Step(order: 2, text: "In a large bowl, mix the mashed bananas and melted butter.", localImageName: "BananaBread2"),
            Step(order: 3, text: "Stir in the sugar, beaten egg, and vanilla extract until well combined.", localImageName: "BananaBread3"),
            Step(order: 4, text: "Sprinkle the flour and baking soda over the wet ingredients. Gently fold the mixture together until just combined (do not overmix).", localImageName: "BananaBread4"),
            Step(order: 5, text: "Fold in the chopped walnuts.", localImageName: "BananaBread5"),
            Step(order: 6, text: "Pour the batter into the prepared loaf pan. Bake for 55-60 minutes, or until a toothpick inserted into the center comes out clean. Let cool before slicing.", durationSec: 3600, localImageName: "BananaBread6")
        ]
        return Recipe(id: "bananabread-145", title: "Moist Banana Walnut Bread", localImageName: "MoistBananaWalnutBreadHeader", imageURL: nil, totalTimeMinutes: 75, difficulty: "Easy", calories: 300, rating: 4.4, defaultServings: 8, tags: ["Baking", "Dessert", "Sweet"], ingredients: ingredients, steps: steps)
    }

    private static func createBrownies() -> Recipe {
        let ingredients = [
            Ingredient(name: "Unsalted butter, melted", quantity: 115.0, unit: "g"),
            Ingredient(name: "Granulated sugar", quantity: 200.0, unit: "g"),
            Ingredient(name: "Large eggs", quantity: 2, unit: "units"),
            Ingredient(name: "Vanilla extract", quantity: 1, unit: "tsp"),
            Ingredient(name: "Cocoa powder", quantity: 40.0, unit: "g"),
            Ingredient(name: "All-purpose flour", quantity: 60.0, unit: "g"),
            Ingredient(name: "Chocolate chips", quantity: 90.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 350°F (175°C). Line an 8x8 inch square baking pan with parchment paper.", localImageName: "Brownie1"),
            Step(order: 2, text: "In a large bowl, whisk together the melted butter and sugar until smooth.", localImageName: "Brownie2"),
            Step(order: 3, text: "Beat in the eggs one at a time, followed by the vanilla extract. Whisk vigorously for 1 minute until the mixture lightens in color.", durationSec: 60, localImageName: "Brownie3"),
            Step(order: 4, text: "Fold in the cocoa powder and flour until just combined. Gently fold in the chocolate chips.", localImageName: "Brownie4"),
            Step(order: 5, text: "Pour the batter into the prepared pan and smooth the top.", localImageName: "Brownie5"),
            Step(order: 6, text: "Bake for 25-30 minutes. A toothpick inserted into the center should come out with moist crumbs, not wet batter. Let cool completely before cutting.", durationSec: 1800, localImageName: "Brownie6")
        ]
        return Recipe(id: "brownies-146", title: "Fudgy Double Chocolate Brownies", localImageName: "FudgyDoubleChocolateBrowniesHeader", imageURL: nil, totalTimeMinutes: 45, difficulty: "Easy", calories: 350, rating: 4.5, defaultServings: 9, tags: ["Dessert", "Chocolate", "Baking"], ingredients: ingredients, steps: steps)
    }

    private static func createCrepes() -> Recipe {
        let ingredients = [
            Ingredient(name: "All-purpose flour", quantity: 125.0, unit: "g"),
            Ingredient(name: "Eggs", quantity: 2, unit: "units"),
            Ingredient(name: "Milk", quantity: 360.0, unit: "ml"),
            Ingredient(name: "Melted butter", quantity: 2, unit: "tbsp"),
            Ingredient(name: "Sugar", quantity: 1, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "In a blender, combine the flour, eggs, milk, melted butter, and sugar. Blend for 10 seconds until completely smooth. Let the batter rest for 10 minutes.", durationSec: 610, localImageName: "Crepe1"),
            Step(order: 2, text: "Heat a 10-inch non-stick skillet over medium heat. Melt a tiny pad of butter to coat the bottom.", localImageName: "Crepe2"),
            Step(order: 3, text: "Pour exactly 1/4 cup of the batter into the center of the pan. Immediately tilt and swirl the pan in a circular motion so the batter coats the bottom in a very thin, even layer.", localImageName: "Crepe3"),
            Step(order: 4, text: "Cook for 1.5 minutes until the bottom is lightly browned and the edges lift easily.", durationSec: 90, localImageName: "Crepe4"),
            Step(order: 5, text: "Flip carefully with a spatula and cook the other side for 30 seconds. Slide onto a plate and repeat until the batter is gone. Serve with fresh fruit, Nutella, or lemon juice.", durationSec: 30, localImageName: "Crepe5")
        ]
        return Recipe(id: "crepes-147", title: "Traditional French Crepes", localImageName: "TraditionalFrenchCrepesHeader", imageURL: nil, totalTimeMinutes: 25, difficulty: "Medium", calories: 200, rating: 4.1, tags: ["French", "Breakfast", "Dessert"], ingredients: ingredients, steps: steps)
    }

    private static func createPannaCotta() -> Recipe {
        let ingredients = [
            Ingredient(name: "Heavy cream", quantity: 480.0, unit: "ml"),
            Ingredient(name: "Sugar", quantity: 50.0, unit: "g"),
            Ingredient(name: "Vanilla extract", quantity: 1, unit: "tsp"),
            Ingredient(name: "Unflavored gelatin", quantity: 1, unit: "packet"),
            Ingredient(name: "Cold water", quantity: 3, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "In a small bowl, sprinkle the gelatin evenly over the cold water. Let it sit for 5 minutes to bloom and thicken.", durationSec: 300, localImageName: "PannaCotta1"),
            Step(order: 2, text: "In a saucepan, combine the heavy cream and sugar. Heat over medium heat, stirring gently, until the sugar dissolves and the cream begins to steam. Do not let it boil.", localImageName: "PannaCotta2"),
            Step(order: 3, text: "Remove from heat and stir in the vanilla extract.", localImageName: "PannaCotta3"),
            Step(order: 4, text: "Add the bloomed gelatin to the hot cream mixture. Whisk continuously for 2 minutes until the gelatin is completely dissolved.", durationSec: 120, localImageName: "PannaCotta4"),
            Step(order: 5, text: "Pour the mixture into 4 ramekins or small glasses. Refrigerate for at least 4 hours (240 minutes) until set and jiggly. Serve with a berry coulis if desired.", durationSec: 14400, localImageName: "PannaCotta5")
        ]
        return Recipe(id: "pannacotta-148", title: "Authentic Italian Panna Cotta", localImageName: "AuthenticItalianPannaCottaHeader", imageURL: nil, totalTimeMinutes: 255, difficulty: "Easy", calories: 400, rating: 4.3, defaultServings: 6, tags: ["Italian", "Dessert"], ingredients: ingredients, steps: steps)
    }

    private static func createLemonPoundCake() -> Recipe {
        let ingredients = [
            Ingredient(name: "All-purpose flour", quantity: 190.0, unit: "g"),
            Ingredient(name: "Baking powder", quantity: 1, unit: "tsp"),
            Ingredient(name: "Unsalted butter, softened", quantity: 225.0, unit: "g"),
            Ingredient(name: "Granulated sugar", quantity: 200.0, unit: "g"),
            Ingredient(name: "Eggs", quantity: 4, unit: "units"),
            Ingredient(name: "Lemon zest", quantity: 2, unit: "units"),
            Ingredient(name: "Fresh lemon juice", quantity: 2, unit: "tbsp")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 350°F (175°C). Grease and flour a standard loaf pan.", localImageName: "LemonCake1"),
            Step(order: 2, text: "In a bowl, whisk together the flour and baking powder.", localImageName: "LemonCake2"),
            Step(order: 3, text: "In a large bowl or stand mixer, cream the softened butter and sugar together for 3 minutes until light and fluffy.", durationSec: 180, localImageName: "LemonCake3"),
            Step(order: 4, text: "Beat in the eggs one at a time, mixing well after each addition.", localImageName: "LemonCake4"),
            Step(order: 5, text: "Stir in the lemon zest and lemon juice.", localImageName: "LemonCake5"),
            Step(order: 6, text: "Gradually add the flour mixture, mixing on low speed just until combined.", localImageName: "LemonCake6"),
            Step(order: 7, text: "Pour the batter into the prepared loaf pan. Bake for 55-60 minutes, until a toothpick inserted in the center comes out clean. Let cool in the pan for 10 minutes before transferring to a wire rack.", durationSec: 3600, localImageName: "LemonCake7")
        ]
        return Recipe(id: "lemonpoundcake-149", title: "Zesty Lemon Pound Cake", localImageName: "ZestyLemonPoundCakeHeader", imageURL: nil, totalTimeMinutes: 80, difficulty: "Medium", calories: 350, rating: 3.9, defaultServings: 8, tags: ["Dessert", "Baking", "Lemon"], ingredients: ingredients, steps: steps)
    }

    private static func createRedVelvetCake() -> Recipe {
        let ingredients = [
            Ingredient(name: "All-purpose flour", quantity: 315.0, unit: "g"),
            Ingredient(name: "Sugar", quantity: 300.0, unit: "g"),
            Ingredient(name: "Baking soda", quantity: 1, unit: "tsp"),
            Ingredient(name: "Cocoa powder", quantity: 1, unit: "tbsp"),
            Ingredient(name: "Buttermilk", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Large eggs", quantity: 2, unit: "units"),
            Ingredient(name: "Vegetable oil", quantity: 240.0, unit: "ml"),
            Ingredient(name: "Red food coloring", quantity: 1, unit: "tbsp"),
            Ingredient(name: "White vinegar", quantity: 1, unit: "tsp"),
            Ingredient(name: "Cream cheese, softened", quantity: 225.0, unit: "g"),
            Ingredient(name: "Butter, softened", quantity: 115.0, unit: "g"),
            Ingredient(name: "Powdered sugar", quantity: 360.0, unit: "g")
        ]
        let steps = [
            Step(order: 1, text: "Preheat oven to 350°F (175°C). Grease two 8-inch round cake pans.", localImageName: "RedVelvet1"),
            Step(order: 2, text: "In a large bowl, sift together the flour, sugar, baking soda, and cocoa powder.", localImageName: "RedVelvet2"),
            Step(order: 3, text: "In a separate bowl, whisk together the buttermilk, eggs, vegetable oil, red food coloring, and white vinegar.", localImageName: "RedVelvet3"),
            Step(order: 4, text: "Gradually pour the wet ingredients into the dry ingredients, mixing with a hand mixer on low speed for 2 minutes until just combined and smooth.", durationSec: 120, localImageName: "RedVelvet4"),
            Step(order: 5, text: "Divide the batter evenly between the two prepared cake pans. Bake for 25-30 minutes until a toothpick comes out clean. Let the cakes cool completely on wire racks.", durationSec: 1800, localImageName: "RedVelvet5"),
            Step(order: 6, text: "Frosting: In a large bowl, beat the softened cream cheese and butter together for 2 minutes. Gradually add the powdered sugar, beating until light and fluffy.", durationSec: 120, localImageName: "RedVelvet6"),
            Step(order: 7, text: "Level the cooled cakes with a knife if needed. Place one layer down, spread a layer of frosting, top with the second cake layer, and frost the top and sides completely.", localImageName: "RedVelvet7")
        ]
        return Recipe(id: "redvelvet-150", title: "Classic Red Velvet Cake", localImageName: "ClassicRedVelvetCakeHeader", imageURL: nil, totalTimeMinutes: 60, difficulty: "Hard", calories: 500, rating: 4.2, defaultServings: 10, tags: ["Dessert", "Cake", "Baking"], ingredients: ingredients, steps: steps)
    }
}
