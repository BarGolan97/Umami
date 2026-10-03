import Foundation
import CloudKit
import SwiftData
import UIKit

@Observable
class CloudKitManager {
    static let shared = CloudKitManager()
    
    // וודא שהמזהה הזה תואם לקונטיינר שלך
    let container = CKContainer(identifier: "iCloud.com.yonatan.recipeapp")
    var database: CKDatabase { container.publicCloudDatabase }
    
    private init() {}
    
    // MARK: - 1. Fetch (קריאה וסנכרון)
    
    func fetchAllRecipes(modelContext: ModelContext) async {
        print("☁️ Starting smart sync...")
        
        do {
            // 1. הורדת הנתונים מהענן
            async let recipesTask = fetchAllRecords(recordType: "Recipe")
            async let stepsTask = fetchAllRecords(recordType: "RecipeStep")
            async let ingredientsTask = fetchAllRecords(recordType: "RecipeIngredient")
            
            let (recipes, steps, ingredients) = try await (recipesTask, stepsTask, ingredientsTask)
            
            print("📦 Fetched \(recipes.count) recipes, \(steps.count) steps, \(ingredients.count) ingredients.")
            
            // 2. שמירה ועדכון ב-SwiftData
            let stepsByRecipeID = organizeRecordsByRecipe(records: steps)
            let ingredientsByRecipeID = organizeRecordsByRecipe(records: ingredients)
            
            await saveToSwiftData(
                recipes: recipes,
                stepsMap: stepsByRecipeID,
                ingredientsMap: ingredientsByRecipeID,
                context: modelContext
            )
            
            // 3. ניקוי כפילויות
            await removeDuplicates(context: modelContext)
            
            await pruneLocalRecipesNotInCloud(
                fetchedRecipeIDs: Set(recipes.map { $0.recordID.recordName }),
                context: modelContext
            )
            
            await pruneOrphanCookingSessions(context: modelContext)
            
            await sweepUnusedImages(context: modelContext)
            
            print("✅ Smart sync complete.")

        } catch {
            print("❌ Sync Error: \(error)")
        }
    }

    // MARK: - Deduplication Logic
    
    @MainActor
    private func removeDuplicates(context: ModelContext) {
        do {
            let allRecipes = try context.fetch(FetchDescriptor<Recipe>())
            let grouped = Dictionary(grouping: allRecipes, by: { $0.id })
            
            var deletedCount = 0
            for (_, duplicates) in grouped {
                if duplicates.count > 1 {
                    let _ = duplicates.first
                    let toDelete = duplicates.dropFirst()
                    for duplicate in toDelete {
                        context.delete(duplicate)
                        deletedCount += 1
                    }
                }
            }
            if deletedCount > 0 { try context.save() }
        } catch {
            print("❌ Failed to remove duplicates: \(error)")
        }
    }
    
    // MARK: - 2. Upload (העלאה בפורמט הישן - תואם ל-59 המתכונים הקיימים)
    
    /// Saves a recipe in the OLD schema format (all data embedded in Recipe record).
    /// This matches the format of the existing 59 recipes in CloudKit.
    /// - Parameter recipe: The recipe to save
    /// - Throws: CloudKit errors if the save operation fails
    func saveRecipeOldFormat(recipe: Recipe) async throws {
        // בדיקת סטטוס iCloud לפני העלאה
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            print("❌ iCloud account not available! Status: \(accountStatus.rawValue)")
            print("⚠️ Please sign in to iCloud in Simulator: Settings > Sign in to your iPhone")
            throw NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud account not available"])
        }
        
        let recipeRecordID = CKRecord.ID(recordName: recipe.id)
        
        print("🚀 Starting OLD FORMAT Upload for: \(recipe.title)")
        
        // 1. Fetch existing or create new Recipe record
        let recipeRecord = await fetchOrNew(recordID: recipeRecordID, recordType: "Recipe")
        
        // 2. Set basic fields
        recipeRecord["title"] = recipe.title
        recipeRecord["timeMinutes"] = recipe.totalTimeMinutes
        recipeRecord["difficulty"] = recipe.difficulty
        recipeRecord["calories"] = recipe.calories
        recipeRecord["rating"] = recipe.rating
        recipeRecord["tags"] = recipe.tags
        recipeRecord["isFavorite"] = 0
        
        // 3. Set ingredients as arrays (OLD FORMAT)
        // Note: Using _ingredients directly because @Transient may not work without ModelContext
        let allIngredients = recipe._ingredients ?? recipe.ingredients
        let ingredientNames = allIngredients.map { $0.name }
        let ingredientAmounts = allIngredients.map { ingredient -> String in
            if let qty = ingredient.quantity, let unit = ingredient.unit {
                return "\(qty) \(unit)"
            } else if let qty = ingredient.quantity {
                return "\(qty)"
            } else if let unit = ingredient.unit {
                return unit
            }
            return ""
        }
        recipeRecord["ingredientsNames"] = ingredientNames
        recipeRecord["ingredientsAmounts"] = ingredientAmounts
        print("🥕 Ingredients count: \(ingredientNames.count)")
        
        // 4. Set steps as arrays (OLD FORMAT)
        // Note: Using _steps directly because @Transient may not work without ModelContext
        let allSteps = recipe._steps ?? recipe.steps
        let sortedSteps = allSteps.sorted(by: { $0.order < $1.order })
        let stepsInstructions = sortedSteps.map { $0.text }
        recipeRecord["stepsInstructions"] = stepsInstructions
        print("📝 Steps count: \(sortedSteps.count), Instructions: \(stepsInstructions.prefix(2))...")
        
        // 5. Handle images
        var tempFiles: [URL] = []
        
        // Main image
        if let localName = recipe.localImageName {
            if let image = UIImage(named: localName),
               let (asset, url) = try? makeAsset(from: image) {
                recipeRecord["mainImage"] = asset
                tempFiles.append(url)
            }
        }
        
        // Step images as array of assets (OLD FORMAT)
        var stepImageAssets: [CKAsset] = []
        for step in sortedSteps {
            if let stepImgName = step.localImageName,
               let stepImage = UIImage(named: stepImgName),
               let (asset, url) = try? makeAsset(from: stepImage) {
                stepImageAssets.append(asset)
                tempFiles.append(url)
            }
        }
        if !stepImageAssets.isEmpty {
            recipeRecord["stepsImages"] = stepImageAssets
        }
        
        // 6. Save to CloudKit
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: [recipeRecord], recordIDsToDelete: nil)
            operation.savePolicy = .allKeys
            operation.qualityOfService = .userInitiated
            
            operation.modifyRecordsResultBlock = { result in
                // Clean up temp files
                for url in tempFiles { try? FileManager.default.removeItem(at: url) }
                
                switch result {
                case .success:
                    print("✅ UPLOADED (OLD FORMAT): \(recipe.title)")
                    continuation.resume()
                case .failure(let error):
                    print("❌ Upload failed for \(recipe.title): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    // MARK: - 2b. Upload (פורמט חדש עם טבלאות נפרדות)
    
    /// Saves a recipe with all its steps and ingredients to CloudKit (NEW FORMAT).
    /// This function properly waits for the CloudKit operation to complete.
    /// - Parameter recipe: The recipe to save
    /// - Throws: CloudKit errors if the save operation fails
    func saveRecipeWithSteps(snapshot: RecipeSyncSnapshot) async throws {
        // בדיקת סטטוס iCloud לפני העלאה
        let accountStatus = try await container.accountStatus()
        guard accountStatus == .available else {
            print("❌ iCloud account not available! Status: \(accountStatus.rawValue)")
            throw NSError(domain: "CloudKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "iCloud account not available"])
        }

        let recipeRecordID = CKRecord.ID(recordName: snapshot.id)

        print("🚀 Starting NEW FORMAT Upload for: \(snapshot.title)")

        // 1. הכנת רשומת האב (Recipe) - אם קיים, מושכים ומעדכנים. אם לא, יוצרים חדש.
        let recipeRecord = await fetchOrNew(recordID: recipeRecordID, recordType: "Recipe")

        recipeRecord["title"] = snapshot.title
        recipeRecord["timeMinutes"] = snapshot.totalTimeMinutes
        recipeRecord["difficulty"] = snapshot.difficulty
        recipeRecord["calories"] = snapshot.calories
        recipeRecord["rating"] = snapshot.rating
        recipeRecord["tags"] = snapshot.tags

        var tempFiles: [URL] = []

        if let localName = snapshot.localImageName {
            // Load from disk-or-asset: cloud-sourced recipes store a disk path, not an asset name.
            if let image = RecipeImageLoader.loadImage(named: localName),
               let (asset, url) = try? makeAsset(from: image) {
                recipeRecord["mainImage"] = asset
                tempFiles.append(url)
            }
        }
        
        // 2. הכנת השלבים (Steps)
        let allSteps = snapshot.steps
        print("📝 Steps count: \(allSteps.count)")

        var stepRecords: [CKRecord] = []
        for step in allSteps {
            let stepID = CKRecord.ID(recordName: "\(snapshot.id)_step_\(step.order)")
            let stepRecord = await fetchOrNew(recordID: stepID, recordType: "RecipeStep")
            
            stepRecord["text"] = step.text
            stepRecord["order"] = step.order
            stepRecord["owningRecipe"] = CKRecord.Reference(recordID: recipeRecordID, action: .deleteSelf)
            if let d = step.durationSec { stepRecord["durationSec"] = NSNumber(value: d) }
            
            if let stepImgName = step.localImageName {
                if let stepImage = RecipeImageLoader.loadImage(named: stepImgName),
                   let (asset, url) = try? makeAsset(from: stepImage) {
                    stepRecord["image"] = asset
                    tempFiles.append(url)
                }
            }
            stepRecords.append(stepRecord)
        }
        
        // 3. הכנת המצרכים (Ingredients)
        let allIngredients = snapshot.ingredients
        print("🥕 Ingredients count: \(allIngredients.count)")

        var ingredientRecords: [CKRecord] = []
        for (index, ingredient) in allIngredients.enumerated() {
            let ingredientID = CKRecord.ID(recordName: "\(snapshot.id)_ing_\(index)")
            let ingRecord = await fetchOrNew(recordID: ingredientID, recordType: "RecipeIngredient")
            
            ingRecord["name"] = ingredient.name
            ingRecord["quantity"] = ingredient.quantity
            ingRecord["unit"] = ingredient.unit
            ingRecord["owningRecipe"] = CKRecord.Reference(recordID: recipeRecordID, action: .deleteSelf)
            
            ingredientRecords.append(ingRecord)
        }
        
        // 3.5 ניקוי רשומות ישנות בענן (Steps & Ingredients) לפני שמירה
        let existingStepRecords = await fetchStepRecords(for: recipeRecordID)
        let existingIngredientRecords = await fetchIngredientRecords(for: recipeRecordID)
        
        let desiredStepIDs = Set(stepRecords.map { $0.recordID })
        let desiredIngredientIDs = Set(ingredientRecords.map { $0.recordID })
        
        let stepsToDelete = existingStepRecords.map { $0.recordID }.filter { !desiredStepIDs.contains($0) }
        let ingredientsToDelete = existingIngredientRecords.map { $0.recordID }.filter { !desiredIngredientIDs.contains($0) }
        let toDelete = stepsToDelete + ingredientsToDelete
        
        // 4. שליחה לענן (כולל מחיקת ישנים שאינם רצויים יותר)
        let allRecords = [recipeRecord] + stepRecords + ingredientRecords
        
        // Use withCheckedThrowingContinuation to properly await the result
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKModifyRecordsOperation(recordsToSave: allRecords, recordIDsToDelete: toDelete)
            
            // חשוב: savePolicy .allKeys דורס את מה שיש בשרת עם מה שיש אצלנו
            operation.savePolicy = .allKeys
            
            // Add QoS for better performance
            operation.qualityOfService = .userInitiated
            
            operation.modifyRecordsResultBlock = { result in
                // Clean up temp files regardless of result
                for url in tempFiles { try? FileManager.default.removeItem(at: url) }
                
                switch result {
                case .success:
                    print("✅ UPDATED/UPLOADED: \(snapshot.title) (Steps: \(stepRecords.count), Ingredients: \(ingredientRecords.count), Deleted: \(toDelete.count))")
                    continuation.resume()
                case .failure(let error):
                    print("❌ Upload failed for \(snapshot.title): \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
            
            database.add(operation)
        }
    }
    
    // פונקציית עזר קריטית ל-Force Update: מביאה את הקיים כדי לעדכן אותו, או יוצרת חדש
    private func fetchOrNew(recordID: CKRecord.ID, recordType: String) async -> CKRecord {
        do {
            return try await database.record(for: recordID)
        } catch {
            // אם לא קיים, יוצרים חדש
            return CKRecord(recordType: recordType, recordID: recordID)
        }
    }
    
    // MARK: - Helpers

    /// Fetch existing step records for a given recipe using CloudKit Reference query.
    /// This is efficient and scales properly for production use.
    private func fetchStepRecords(for recipeID: CKRecord.ID) async -> [CKRecord] {
        var records: [CKRecord] = []
        
        do {
            // Use CKRecord.Reference to query efficiently by owningRecipe
            let reference = CKRecord.Reference(recordID: recipeID, action: .none)
            let predicate = NSPredicate(format: "owningRecipe == %@", reference)
            let query = CKQuery(recordType: "RecipeStep", predicate: predicate)
            
            let (results, cursor) = try await database.records(matching: query)
            
            for (_, result) in results {
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            
            // Handle pagination if there are many steps
            var currentCursor = cursor
            while let c = currentCursor {
                let page = try await database.records(continuingMatchFrom: c)
                for (_, result) in page.matchResults {
                    if case .success(let record) = result {
                        records.append(record)
                    }
                }
                currentCursor = page.queryCursor
            }
        } catch {
            print("⚠️ fetchStepRecords failed: \(error)")
        }
        
        return records
    }
    
    /// Fetch existing ingredient records for a given recipe using CloudKit Reference query.
    /// This is efficient and scales properly for production use.
    private func fetchIngredientRecords(for recipeID: CKRecord.ID) async -> [CKRecord] {
        var records: [CKRecord] = []
        
        do {
            // Use CKRecord.Reference to query efficiently by owningRecipe
            let reference = CKRecord.Reference(recordID: recipeID, action: .none)
            let predicate = NSPredicate(format: "owningRecipe == %@", reference)
            let query = CKQuery(recordType: "RecipeIngredient", predicate: predicate)
            
            let (results, cursor) = try await database.records(matching: query)
            
            for (_, result) in results {
                if case .success(let record) = result {
                    records.append(record)
                }
            }
            
            // Handle pagination if there are many ingredients
            var currentCursor = cursor
            while let c = currentCursor {
                let page = try await database.records(continuingMatchFrom: c)
                for (_, result) in page.matchResults {
                    if case .success(let record) = result {
                        records.append(record)
                    }
                }
                currentCursor = page.queryCursor
            }
        } catch {
            print("⚠️ fetchIngredientRecords failed: \(error)")
        }
        
        return records
    }
    
    private func fetchAllRecords(recordType: String) async throws -> [CKRecord] {
        var allRecords: [CKRecord] = []
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        
        let (matchResults, cursor) = try await database.records(matching: query)
        for (_, result) in matchResults {
            if case .success(let record) = result { allRecords.append(record) }
        }
        
        var currentCursor = cursor
        while let c = currentCursor {
            let page = try await database.records(continuingMatchFrom: c)
            for (_, result) in page.matchResults {
                if case .success(let record) = result { allRecords.append(record) }
            }
            currentCursor = page.queryCursor
        }
        return allRecords
    }
    
    private func organizeRecordsByRecipe(records: [CKRecord]) -> [String: [CKRecord]] {
        var map: [String: [CKRecord]] = [:]
        for record in records {
            if let ref = record["owningRecipe"] as? CKRecord.Reference {
                map[ref.recordID.recordName, default: []].append(record)
            }
        }
        return map
    }
    
    @MainActor
    private func saveToSwiftData(recipes: [CKRecord],
                                 stepsMap: [String: [CKRecord]],
                                 ingredientsMap: [String: [CKRecord]],
                                 context: ModelContext) {
        
        // Fetch existing recipes and create a lookup dictionary by ID
        let existingRecipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        var existingRecipesByID: [String: Recipe] = [:]
        for recipe in existingRecipes {
            existingRecipesByID[recipe.id] = recipe
        }
        let existingIDSet = Set(existingRecipesByID.keys)
        
        for record in recipes {
            let id = record.recordID.recordName
            let title = record["title"] as? String ?? "Unknown"
            let time = record["timeMinutes"] as? Int ?? 0
            let diff = record["difficulty"] as? String ?? "Medium"
            let cals = record["calories"] as? Int ?? 0
            let rating = record["rating"] as? Double ?? 0.0
            let rawTags = record["tags"] as? [String]
            let inferredTags = inferTags(from: title)
            let tags = (rawTags?.isEmpty == false) ? (rawTags ?? inferredTags) : inferredTags
            
            var localImagePath: String? = nil
            if let asset = record["mainImage"] as? CKAsset, let url = asset.fileURL {
                localImagePath = saveImageToDisk(from: url, name: "\(id)_main")
            }
            
            let stepRecords = stepsMap[id] ?? []
            let ingredientRecords = ingredientsMap[id] ?? []
            
            // Process steps: prefer new-format (separate records), fall back to old-format (embedded arrays)
            var processedSteps = processSteps(stepRecords, recipeID: id)
            if processedSteps.isEmpty {
                processedSteps = processOldFormatSteps(record, recipeID: id)
            }
            
            // Process ingredients: prefer new-format (separate records), fall back to old-format (embedded arrays)
            var processedIngredients = processIngredients(ingredientRecords)
            if processedIngredients.isEmpty {
                processedIngredients = processOldFormatIngredients(record)
            }
            
            if existingIDSet.contains(id), let existingRecipe = existingRecipesByID[id] {
                // Update existing recipe - no need for another fetch
                existingRecipe.title = title
                existingRecipe.totalTimeMinutes = time
                existingRecipe.difficulty = diff
                existingRecipe.calories = cals
                existingRecipe.rating = rating
                if let path = localImagePath { existingRecipe.localImageName = path }
                // Only overwrite steps/ingredients if we got data from CloudKit
                if !processedSteps.isEmpty {
                    existingRecipe.steps = processedSteps
                }
                if !processedIngredients.isEmpty {
                    existingRecipe.ingredients = processedIngredients
                }
                if let existingTags = existingRecipe.tags as [String]?, !existingTags.isEmpty, tags.isEmpty {
                    existingRecipe.tags = existingTags
                } else {
                    existingRecipe.tags = tags
                }
            } else if !existingIDSet.contains(id) {
                // Only insert if recipe doesn't exist
                let newRecipe = Recipe(
                    id: id, title: title, localImageName: localImagePath, imageURL: nil,
                    totalTimeMinutes: time, difficulty: diff, calories: cals, rating: rating,
                    tags: tags, ingredients: processedIngredients, steps: processedSteps
                )
                context.insert(newRecipe)
            }
        }
        try? context.save()
    }
    
    private func processSteps(_ records: [CKRecord], recipeID: String) -> [Step] {
        var steps: [Step] = []
        let sortedRecords = records.sorted { ($0["order"] as? Int ?? 0) < ($1["order"] as? Int ?? 0) }
        
        for record in sortedRecords {
            let text = record["text"] as? String ?? ""
            let order = record["order"] as? Int ?? 0
            var imagePath: String? = nil
            if let asset = record["image"] as? CKAsset, let url = asset.fileURL {
                imagePath = saveImageToDisk(from: url, name: "\(recipeID)_step_\(order)")
            }
            let duration = (record["durationSec"] as? Int) ?? (record["durationSec"] as? NSNumber)?.intValue
            steps.append(Step(order: order, text: text, durationSec: duration, localImageName: imagePath))
        }
        return steps
    }
    
    private func processIngredients(_ records: [CKRecord]) -> [Ingredient] {
        var ingredients: [Ingredient] = []
        for record in records {
            let name = record["name"] as? String ?? "Unknown"
            let quantity = record["quantity"] as? Double
            let unit = record["unit"] as? String
            ingredients.append(Ingredient(name: name, quantity: quantity, unit: unit))
        }
        return ingredients
    }
    
    // MARK: - Old Format Fallbacks
    
    /// Parse ingredients from old-format recipe records where ingredientsNames and
    /// ingredientsAmounts are stored as string arrays directly on the Recipe record.
    private func processOldFormatIngredients(_ record: CKRecord) -> [Ingredient] {
        guard let names = record["ingredientsNames"] as? [String] else { return [] }
        let amounts = record["ingredientsAmounts"] as? [String] ?? []
        
        var ingredients: [Ingredient] = []
        for (index, name) in names.enumerated() {
            let amountStr = index < amounts.count ? amounts[index] : ""
            let (qty, unit) = parseAmountString(amountStr)
            ingredients.append(Ingredient(name: name, quantity: qty, unit: unit))
        }
        return ingredients
    }
    
    /// Parse steps from old-format recipe records where stepsInstructions is stored
    /// as a string array directly on the Recipe record.
    private func processOldFormatSteps(_ record: CKRecord, recipeID: String) -> [Step] {
        guard let instructions = record["stepsInstructions"] as? [String] else { return [] }
        
        var steps: [Step] = []
        // Try to get step images from old format
        let stepImageAssets = record["stepsImages"] as? [CKAsset] ?? []
        
        for (index, text) in instructions.enumerated() {
            var imagePath: String? = nil
            if index < stepImageAssets.count, let url = stepImageAssets[index].fileURL {
                imagePath = saveImageToDisk(from: url, name: "\(recipeID)_step_\(index + 1)")
            }
            steps.append(Step(order: index + 1, text: text, durationSec: nil, localImageName: imagePath))
        }
        return steps
    }
    
    /// Parse an amount string like "500.0 g" or "2 tbsp" into (quantity, unit).
    private func parseAmountString(_ amount: String) -> (Double?, String?) {
        let trimmed = amount.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return (nil, nil) }
        
        // Try to extract a leading number and trailing unit
        let scanner = Scanner(string: trimmed)
        scanner.charactersToBeSkipped = .whitespaces
        
        if let number = scanner.scanDouble() {
            let remaining = String(trimmed[scanner.currentIndex...]).trimmingCharacters(in: .whitespaces)
            let unit = remaining.isEmpty ? nil : remaining
            return (number, unit)
        }
        
        // No number found — treat entire string as unit (e.g. "to taste")
        return (nil, trimmed)
    }
    
    private func saveImageToDisk(from sourceURL: URL, name: String) -> String? {
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destination = documents.appendingPathComponent("\(name).jpg")
            if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
            return name
        } catch { return nil }
    }

    private func inferTags(from title: String) -> [String] {
        let lowercased = title.lowercased()
        var tags: Set<String> = []

        if lowercased.contains("pizza") || lowercased.contains("pasta") || lowercased.contains("risotto") || lowercased.contains("carbonara") || lowercased.contains("bolognese") || lowercased.contains("bruschetta") || lowercased.contains("caprese") || lowercased.contains("tiramisu") {
            tags.insert("Italian")
        }
        if lowercased.contains("pad thai") || lowercased.contains("ramen") || lowercased.contains("sushi") || lowercased.contains("stir fry") || lowercased.contains("noodle") || lowercased.contains("teriyaki") || lowercased.contains("dumpling") {
            tags.insert("Asian")
        }
        if lowercased.contains("taco") || lowercased.contains("burrito") || lowercased.contains("quesadilla") || lowercased.contains("enchilada") || lowercased.contains("guacamole") || lowercased.contains("salsa") || lowercased.contains("carne asada") || lowercased.contains("mole") || lowercased.contains("tortilla") {
            tags.insert("Mexican")
        }
        if lowercased.contains("salad") || lowercased.contains("quinoa") || lowercased.contains("bowl") || lowercased.contains("avocado") || lowercased.contains("vegan") || lowercased.contains("smoothie") {
            tags.insert("Healthy")
        }
        if lowercased.contains("burger") || lowercased.contains("smash") {
            tags.insert("Burger")
        }
        if lowercased.contains("cake") || lowercased.contains("cookie") || lowercased.contains("brownie") || lowercased.contains("mousse") || lowercased.contains("tart") || lowercased.contains("cheesecake") || lowercased.contains("tiramisu") || lowercased.contains("creme brulee") || lowercased.contains("brulee") || lowercased.contains("pudding") || lowercased.contains("ice cream") || lowercased.contains("lava") || lowercased.contains("chocolate") || lowercased.contains("macaron") || lowercased.contains("posset") || lowercased.contains("crumble") || lowercased.contains("profiterole") {
            tags.insert("Dessert")
        }

        return Array(tags)
    }
    
    private func makeAsset(from image: UIImage) throws -> (CKAsset, URL) {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
        if let data = image.jpegData(compressionQuality: 0.8) {
            try data.write(to: fileURL)
            return (CKAsset(fileURL: fileURL), fileURL)
        }
        throw NSError(domain: "ImageError", code: -1, userInfo: nil)
    }
    
    // MARK: - Delete All Recipes from CloudKit
    
    /// מוחק את כל המתכונים, השלבים והמצרכים מ-CloudKit
    /// השתמש בפונקציה הזו פעם אחת לניקוי הענן לפני העלאה מחדש
    func deleteAllRecipesFromCloud() async {
        print("🗑️ Starting to delete ALL recipes from CloudKit...")
        
        do {
            // 1. מביאים את כל הרשומות
            async let recipesTask = fetchAllRecords(recordType: "Recipe")
            async let stepsTask = fetchAllRecords(recordType: "RecipeStep")
            async let ingredientsTask = fetchAllRecords(recordType: "RecipeIngredient")
            
            let (recipes, steps, ingredients) = try await (recipesTask, stepsTask, ingredientsTask)
            
            let allRecordIDs = recipes.map { $0.recordID } + steps.map { $0.recordID } + ingredients.map { $0.recordID }
            
            print("📦 Found \(recipes.count) recipes, \(steps.count) steps, \(ingredients.count) ingredients to delete.")
            
            if allRecordIDs.isEmpty {
                print("✅ CloudKit is already empty!")
                return
            }
            
            // 2. מוחקים בקבוצות של 400 (מגבלת CloudKit)
            let batchSize = 400
            for batchStart in stride(from: 0, to: allRecordIDs.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, allRecordIDs.count)
                let batch = Array(allRecordIDs[batchStart..<batchEnd])
                
                let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: batch)
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        print("✅ Deleted batch \(batchStart/batchSize + 1): \(batch.count) records")
                    case .failure(let error):
                        print("❌ Failed to delete batch: \(error.localizedDescription)")
                    }
                }
                
                database.add(operation)
                
                // המתנה קצרה בין קבוצות
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            print("🎉 Delete operation completed! CloudKit should now be empty.")
            
        } catch {
            print("❌ Error deleting recipes: \(error)")
        }
    }
    
    @MainActor
    private func pruneLocalRecipesNotInCloud(fetchedRecipeIDs: Set<String>, context: ModelContext) {
        do {
            // Fetch all local recipes
            let localRecipes = try context.fetch(FetchDescriptor<Recipe>())

            // Identify local recipes that are not present in CloudKit fetch results
            // אבל לא מוחקים מתכונים מובנים!
            let toDelete = localRecipes.filter { 
                !fetchedRecipeIDs.contains($0.id) && 
                !$0.isBuiltIn && 
                !RecipeSeeder.builtInRecipeIDs.contains($0.id) &&
                !RecipeSeeder2.builtInRecipeIDs.contains($0.id)
            }

            // Delete associated images and cooking sessions, then the recipe itself
            for recipe in toDelete {
                var imageNamesToDelete: [String] = []
                if let name = recipe.localImageName { imageNamesToDelete.append(name) }
                imageNamesToDelete.append(contentsOf: recipe.steps.compactMap { $0.localImageName })
                deleteDocumentImages(named: imageNamesToDelete)

                // Delete CookingSession entries tied to this recipe
                let allSessions = (try? context.fetch(FetchDescriptor<CookingSession>())) ?? []
                for s in allSessions where s.recipeId == recipe.id {
                    context.delete(s)
                }

                context.delete(recipe)
            }

            if !toDelete.isEmpty {
                try context.save()
                print("🧹 Pruned \(toDelete.count) local recipes that no longer exist in CloudKit")
            }
        } catch {
            print("❌ Failed to prune local recipes: \(error)")
        }
    }

    private func deleteDocumentImages(named names: [String]) {
        guard !names.isEmpty else { return }
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        let exts = ["jpg", "jpeg", "png", "heic"]
        for base in names {
            for ext in exts {
                let url = documents.appendingPathComponent("\(base).\(ext)")
                if fm.fileExists(atPath: url.path) {
                    try? fm.removeItem(at: url)
                }
            }
        }
    }

    @MainActor
    private func pruneOrphanCookingSessions(context: ModelContext) {
        do {
            let localRecipes = try context.fetch(FetchDescriptor<Recipe>())
            let existingIDs = Set(localRecipes.map { $0.id })
            let sessions = try context.fetch(FetchDescriptor<CookingSession>())
            var removed = 0
            for s in sessions where !existingIDs.contains(s.recipeId) {
                context.delete(s)
                removed += 1
            }
            if removed > 0 { try context.save() }
            if removed > 0 { print("🗑️ Removed \(removed) orphan CookingSessions") }
        } catch {
            print("❌ Failed to prune orphan CookingSessions: \(error)")
        }
    }

    @MainActor
    private func sweepUnusedImages(context: ModelContext) {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return }

        // Build a set of referenced base names from all recipes and steps
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        var referenced: Set<String> = []
        for r in recipes {
            if let n = r.localImageName { referenced.insert(n) }
            for s in r.steps { if let n = s.localImageName { referenced.insert(n) } }
        }

        // Enumerate files in Documents and delete recipe-related images that are not referenced
        let exts = ["jpg", "jpeg", "png", "heic"]
        if let items = try? fm.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil) {
            var removed = 0
            for url in items {
                let ext = url.pathExtension.lowercased()
                guard exts.contains(ext) else { continue }
                let base = url.deletingPathExtension().lastPathComponent
                // Only target files that look like our saved recipe images (e.g., *_main or *_step_*)
                let isRecipeImage = base.hasSuffix("_main") || base.contains("_step_")
                guard isRecipeImage else { continue }
                if !referenced.contains(base) {
                    try? fm.removeItem(at: url)
                    removed += 1
                }
            }
            if removed > 0 { print("🧼 Swept \(removed) unused recipe images from Documents") }
        }
    }
}
