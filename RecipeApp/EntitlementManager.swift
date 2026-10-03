//
//  EntitlementManager.swift
//  RecipeApp
//
//  StoreKit 2 wrapper — the single source of truth for Umami Pro access.
//

import Foundation
import StoreKit

// MARK: - Product Identifiers

enum ProProduct {
    static let monthly = "com.umami.pro.monthly"
    static let yearly = "com.umami.pro.yearly"
    static let lifetime = "com.umami.pro.lifetime"

    /// All Umami Pro product identifiers.
    static let all: [String] = [monthly, yearly, lifetime]

    /// Display order for the paywall (best-value first).
    static let displayOrder: [String] = [yearly, monthly, lifetime]
}

// MARK: - Store Error

enum StoreError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "The purchase could not be verified by the App Store."
        }
    }
}

// MARK: - Entitlement Manager

/// Loads Umami Pro products, tracks entitlements, and exposes a live `isPro` flag.
/// Mirrors the shared-singleton style of `RecipeTimerService` but uses the modern
/// `@Observable` macro so it can be injected cleanly via `.environment`.
@MainActor
@Observable
final class EntitlementManager {
    static let shared = EntitlementManager()

    /// The single source of truth used throughout the app to unlock Pro features.
    private(set) var isPro: Bool = false

    /// Products loaded from StoreKit, sorted for display (yearly, monthly, lifetime).
    private(set) var products: [Product] = []

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Start listening for transaction updates (renewals, refunds, Ask-to-Buy).
        updatesTask = listenForTransactions()

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Product Loading

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: ProProduct.all)
            // Sort into a stable, best-value-first display order.
            products = fetched.sorted { lhs, rhs in
                let li = ProProduct.displayOrder.firstIndex(of: lhs.id) ?? Int.max
                let ri = ProProduct.displayOrder.firstIndex(of: rhs.id) ?? Int.max
                return li < ri
            }
        } catch {
            print("⚠️ Failed to load Pro products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    /// Processes the result of a purchase performed via the SwiftUI `PurchaseAction`
    /// (`@Environment(\.purchase)`), which is the supported flow on visionOS.
    /// Returns whether the user is now Pro.
    @discardableResult
    func completePurchase(_ result: Product.PurchaseResult) async throws -> Bool {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return isPro
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - Restore

    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    /// Recomputes `isPro` from the user's current entitlements.
    func refreshEntitlements() async {
        var hasPro = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard ProProduct.all.contains(transaction.productID) else { continue }

            // Skip revoked transactions and expired subscriptions.
            if transaction.revocationDate != nil { continue }
            if let expiration = transaction.expirationDate, expiration < Date() { continue }

            hasPro = true
        }

        isPro = hasPro
    }

    // MARK: - Transaction Listener

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? self.checkVerified(update) {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }

    // MARK: - Verification

    nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}
