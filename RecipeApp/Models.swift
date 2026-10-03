import Foundation
import SwiftData

@Model
final class Recipe {
    // ❌ הורדנו את @Attribute(.unique) כי זה גורם לקריסה עם CloudKit
    // הקוד ב-CloudKitManager ימנע את הכפילויות ידנית.
    var id: String = UUID().uuidString
    
    var title: String = ""
    var isFavorite: Bool = false
    
    // מתכון מובנה - לא יימחק גם אם לא קיים בענן
    var isBuiltIn: Bool = false
    
    // שדה לתמונה מקומית (Assets)
    var localImageName: String?
    
    var imageURLString: String?
    @Transient
    var imageURL: URL? {
        get { imageURLString.flatMap(URL.init(string:)) }
        set { imageURLString = newValue?.absoluteString }
    }
    
    var totalTimeMinutes: Int = 0
    var difficulty: String = ""
    var calories: Int = 0
    var rating: Double = 0
    var defaultServings: Int = 4
    
    // 🆕 שדה חדש להערות שף (הערות משתמש)
    var notes: String?
    
    var tagsRaw: String = ""

    @Transient
    private var _cachedTags: [String]?
    @Transient
    private var _cachedTagsRaw: String?

    @Transient
    var tags: [String] {
        get {
            if let cached = _cachedTags, _cachedTagsRaw == tagsRaw {
                return cached
            }
            let parsed = tagsRaw.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            _cachedTags = parsed
            _cachedTagsRaw = tagsRaw
            return parsed
        }
        set {
            tagsRaw = newValue.joined(separator: ",")
            _cachedTags = newValue
            _cachedTagsRaw = tagsRaw
        }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \Ingredient.recipe)
    var _ingredients: [Ingredient]?
    
    @Transient
    var ingredients: [Ingredient] {
        get { _ingredients ?? [] }
        set { _ingredients = newValue }
    }
    
    @Relationship(deleteRule: .cascade, inverse: \Step.recipe)
    var _steps: [Step]?
    
    @Transient
    var steps: [Step] {
        get { _steps ?? [] }
        set { _steps = newValue }
    }

    init(id: String = UUID().uuidString,
         title: String,
         localImageName: String? = nil,
         imageURL: URL? = nil,
         totalTimeMinutes: Int,
         difficulty: String,
         calories: Int,
         rating: Double,
         defaultServings: Int = 4,
         notes: String? = nil,
         tags: [String] = [],
         ingredients: [Ingredient] = [],
         steps: [Step] = [],
         isBuiltIn: Bool = false) {
        self.id = id
        self.title = title
        self.localImageName = localImageName
        self.imageURLString = imageURL?.absoluteString
        self.totalTimeMinutes = totalTimeMinutes
        self.difficulty = difficulty
        self.calories = calories
        self.rating = rating
        self.defaultServings = defaultServings
        self.notes = notes
        self.tagsRaw = tags.joined(separator: ",")
        self.ingredients = ingredients
        self.steps = steps
        self.isBuiltIn = isBuiltIn
    }
}

extension Recipe {
    /// Human-friendly total time for display, e.g. "45 min", "1h", "1h 30m".
    /// Anything under an hour stays in minutes; 60+ minutes is shown in hours.
    var formattedTotalTime: String {
        Self.formatTotalTime(minutes: totalTimeMinutes)
    }

    static func formatTotalTime(minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) min" }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
}

@Model
final class Ingredient {
    var name: String = ""
    var quantity: Double?
    var unit: String?
    var recipe: Recipe?

    init(name: String, quantity: Double? = nil, unit: String? = nil) {
        self.name = name
        self.quantity = quantity
        self.unit = unit
    }
}

@Model
final class Step {
    var order: Int = 0
    var text: String = ""
    var durationSec: Int?
    
    var localImageName: String?
    
    var imageURLString: String?
    @Transient
    var imageURL: URL? {
        get { imageURLString.flatMap(URL.init(string:)) }
        set { imageURLString = newValue?.absoluteString }
    }
    var recipe: Recipe?

    init(order: Int,
         text: String,
         durationSec: Int? = nil,
         localImageName: String? = nil,
         imageURL: URL? = nil) {
        self.order = order
        self.text = text
        self.durationSec = durationSec
        self.localImageName = localImageName
        self.imageURLString = imageURL?.absoluteString
    }
}

@Model
final class CookingSession {
    // גם כאן הסרנו את ה-Unique
    var id: String = UUID().uuidString
    var recipeId: String = ""
    var stepIndex: Int = 0
    var remainingSec: Int?
    var updatedAt: Date = Date.now
    
    init(recipeId: String, stepIndex: Int = 0, remainingSec: Int? = nil, updatedAt: Date = .now) {
        self.recipeId = recipeId
        self.stepIndex = stepIndex
        self.remainingSec = remainingSec
        self.updatedAt = updatedAt
    }
}

@Model
final class ShoppingItem {
    var name: String = ""
    var qty: String?
    var isChecked: Bool = false
    
    init(name: String, qty: String? = nil) {
        self.name = name
        self.qty = qty
    }
}

@Model
final class RecipeHistoryEntry {
    var id: String = UUID().uuidString
    var recipeId: String = ""
    var recipeTitle: String = ""
    var recipeImageName: String?
    var finishedAt: Date = Date.now
    var totalTimeMinutes: Int = 0

    init(
        recipeId: String,
        recipeTitle: String,
        recipeImageName: String? = nil,
        finishedAt: Date = Date.now,
        totalTimeMinutes: Int = 0
    ) {
        self.recipeId = recipeId
        self.recipeTitle = recipeTitle
        self.recipeImageName = recipeImageName
        self.finishedAt = finishedAt
        self.totalTimeMinutes = totalTimeMinutes
    }
}
