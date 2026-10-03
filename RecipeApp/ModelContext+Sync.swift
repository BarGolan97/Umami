import Foundation
import SwiftData

/// A `Sendable` snapshot of a `Recipe` and its relationships, safe to hand to the
/// CloudKit sync layer from a background task. SwiftData models are bound to their
/// `ModelContext` and must not be read across threads/actors, so we copy the values
/// we need on the context's own thread before spawning any async work.
struct RecipeSyncSnapshot: Sendable {
    struct StepSnapshot: Sendable {
        let order: Int
        let text: String
        let durationSec: Int?
        let localImageName: String?
    }

    struct IngredientSnapshot: Sendable {
        let name: String
        let quantity: Double?
        let unit: String?
    }

    let id: String
    let title: String
    let totalTimeMinutes: Int
    let difficulty: String
    let calories: Int
    let rating: Double
    let tags: [String]
    let localImageName: String?
    let steps: [StepSnapshot]
    let ingredients: [IngredientSnapshot]

    /// Copies the values out of the live model. Call this synchronously on the same
    /// thread that owns the model's `ModelContext` (e.g. before starting a `Task`).
    init(recipe: Recipe) {
        self.id = recipe.id
        self.title = recipe.title
        self.totalTimeMinutes = recipe.totalTimeMinutes
        self.difficulty = recipe.difficulty
        self.calories = recipe.calories
        self.rating = recipe.rating
        self.tags = recipe.tags
        self.localImageName = recipe.localImageName
        self.steps = recipe.steps.map {
            StepSnapshot(order: $0.order, text: $0.text, durationSec: $0.durationSec, localImageName: $0.localImageName)
        }
        self.ingredients = recipe.ingredients.map {
            IngredientSnapshot(name: $0.name, quantity: $0.quantity, unit: $0.unit)
        }
    }
}

extension ModelContext {
    /// Saves the recipe locally and syncs to CloudKit.
    /// The CloudKit sync happens in the background - local save is prioritized.
    /// - Parameter recipe: The recipe to save and sync
    func saveAndSync(_ recipe: Recipe) {
        do {
            // 1. קודם כל מבצעים שמירה מקומית כדי לוודא שהדאטה בטוח
            try self.save()

            // 2. Snapshot the model on this (the context's) thread BEFORE going async,
            //    so the background task never touches the live SwiftData model.
            let snapshot = RecipeSyncSnapshot(recipe: recipe)

            // 3. שולחים ל-CloudKit באמצעות הפונקציה החדשה שיצרנו
            // (זו שתומכת גם במתכון וגם בשלבים המקושרים אליו)
            Task {
                do {
                    try await CloudKitManager.shared.saveRecipeWithSteps(snapshot: snapshot)
                    print("✅ Recipe '\(snapshot.title)' synced to CloudKit successfully")
                } catch {
                    // Log the error but don't crash - local save already succeeded
                    print("❌ CloudKit Sync Error for '\(snapshot.title)': \(error.localizedDescription)")
                    // In production, you might want to queue this for retry
                }
            }
        } catch {
            print("❌ ModelContext Save Error: \(error)")
        }
    }
}
