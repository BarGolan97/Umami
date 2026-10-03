//
//  AIUsageManager.swift
//  RecipeApp
//
//  Tracks free-tier AI Cooking Assistant usage. Free users get a fixed number
//  of questions per day; the counter resets automatically at midnight.
//

import Foundation

@MainActor
@Observable
final class AIUsageManager {
    static let shared = AIUsageManager()

    /// Free users may ask this many AI questions per calendar day.
    static let freeDailyLimit = 20

    private let countKey = "aiQuestionCount"
    private let dateKey = "aiQuestionCountDate"
    private let defaults = UserDefaults.standard

    /// Number of questions asked today (after applying a daily reset).
    private(set) var usedToday: Int = 0

    private init() {
        rolloverIfNeeded()
    }

    /// Questions remaining today for a free user.
    var remainingToday: Int {
        max(0, Self.freeDailyLimit - usedToday)
    }

    /// Whether the user may ask another question right now.
    func canAsk(isPro: Bool) -> Bool {
        if isPro { return true }
        rolloverIfNeeded()
        return remainingToday > 0
    }

    /// Records a consumed free question. No-op for Pro users (never call it for them).
    func recordQuestion() {
        rolloverIfNeeded()
        usedToday += 1
        defaults.set(usedToday, forKey: countKey)
        defaults.set(Date(), forKey: dateKey)
    }

    // MARK: - Daily Rollover

    /// Resets the counter when the stored date is not today.
    private func rolloverIfNeeded() {
        let storedDate = defaults.object(forKey: dateKey) as? Date
        if let storedDate, Calendar.current.isDateInToday(storedDate) {
            usedToday = defaults.integer(forKey: countKey)
        } else {
            usedToday = 0
            defaults.set(0, forKey: countKey)
            defaults.set(Date(), forKey: dateKey)
        }
    }
}
