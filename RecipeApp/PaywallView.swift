//
//  PaywallView.swift
//  RecipeApp
//
//  Umami Pro paywall — visionOS-native glass design, matching OnboardingView.
//

import SwiftUI
import StoreKit

// MARK: - Design Tokens (shared with onboarding palette)
private enum PDS {
    static let accent        = Color(red: 0.92, green: 0.55, blue: 0.22)
    static let accentSubtle  = Color(red: 0.92, green: 0.55, blue: 0.22).opacity(0.12)
    static let accentGlow    = Color(red: 0.92, green: 0.55, blue: 0.22).opacity(0.20)

    static let textPrimary   = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let textTertiary  = Color.white.opacity(0.40)
    static let separator     = Color.white.opacity(0.08)

    static let brand         = Font.system(size: 24, weight: .bold, design: .rounded)
    static let title         = Font.system(size: 22, weight: .bold, design: .rounded)
    static let eyebrow       = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let body          = Font.system(size: 15, weight: .regular, design: .default)
    static let caption       = Font.system(size: 12, weight: .medium, design: .rounded)
    static let button        = Font.system(size: 16, weight: .semibold, design: .rounded)
}

// MARK: - Benefit Model
private struct ProBenefit: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
}

// MARK: - Paywall View
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.purchase) private var purchaseAction
    @Environment(EntitlementManager.self) private var entitlement

    @State private var selectedProductID: String?
    @State private var animateIn = false
    @State private var errorMessage: String?
    @State private var isProcessing = false

    private let benefits: [ProBenefit] = [
        ProBenefit(icon: "sparkles", title: "Unlimited AI Sous-Chef",
                   subtitle: "Ask your cooking assistant anything, any time — no daily limit."),
        ProBenefit(icon: "bolt.fill", title: "Priority AI Model",
                   subtitle: "Faster, higher-quality answers while you cook."),
        ProBenefit(icon: "wand.and.stars", title: "Future Pro Features",
                   subtitle: "Immersive kitchens, hands-free voice, and more — included.")
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                    benefitsSection
                    plansSection
                    footer
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 30)
            }
            .frame(width: 480)
            .frame(maxHeight: 720)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 36, style: .continuous))
            .shadow(color: .black.opacity(0.3), radius: 50, y: 24)
            .scaleEffect(animateIn ? 1.0 : 0.92)
            .opacity(animateIn ? 1.0 : 0)
        }
        .onAppear {
            if selectedProductID == nil {
                // Default to the best-value plan (first in display order that exists).
                selectedProductID = entitlement.products.first(where: { $0.id == ProProduct.yearly })?.id
                    ?? entitlement.products.first?.id
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                animateIn = true
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(PDS.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }

            ZStack {
                Circle().fill(PDS.accentSubtle).frame(width: 80, height: 80)
                Circle().strokeBorder(PDS.accent.opacity(0.18), lineWidth: 1).frame(width: 80, height: 80)
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(PDS.accent)
                    .symbolRenderingMode(.hierarchical)
            }

            VStack(spacing: 8) {
                Text("UMAMI PRO")
                    .font(PDS.eyebrow)
                    .foregroundStyle(PDS.accent.opacity(0.9))
                    .tracking(2.5)

                Text("Cook Without Limits")
                    .font(PDS.title)
                    .foregroundStyle(PDS.textPrimary)

                Text("Unlock your AI Sous-Chef and everything Umami has to offer.")
                    .font(PDS.body)
                    .foregroundStyle(PDS.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, 24)
    }

    // MARK: - Benefits
    private var benefitsSection: some View {
        VStack(spacing: 14) {
            ForEach(benefits) { benefit in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(PDS.accentSubtle)
                            .frame(width: 44, height: 44)
                        Image(systemName: benefit.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(PDS.accent)
                            .symbolRenderingMode(.hierarchical)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(PDS.textPrimary)
                        Text(benefit.subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(PDS.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.bottom, 28)
    }

    // MARK: - Plans
    private var plansSection: some View {
        VStack(spacing: 12) {
            if entitlement.products.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .tint(PDS.accent)
                    .padding(.vertical, 20)
                Text("Loading plans…")
                    .font(PDS.caption)
                    .foregroundStyle(PDS.textTertiary)
            } else {
                ForEach(orderedProducts, id: \.id) { product in
                    PlanCard(
                        product: product,
                        isSelected: selectedProductID == product.id,
                        isBestValue: product.id == ProProduct.yearly
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedProductID = product.id
                        }
                    }
                }

                purchaseButton

                if let errorMessage {
                    Text(errorMessage)
                        .font(PDS.caption)
                        .foregroundStyle(.red.opacity(0.9))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private var orderedProducts: [Product] {
        // Already sorted by EntitlementManager, but keep it explicit here too.
        entitlement.products
    }

    private var selectedProduct: Product? {
        entitlement.products.first { $0.id == selectedProductID }
    }

    private var purchaseButton: some View {
        Button(action: handlePurchase) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView().tint(.white)
                } else {
                    Text(ctaTitle)
                        .font(PDS.button)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(PDS.accent)
                    .shadow(color: PDS.accentGlow, radius: 16, y: 6)
            )
        }
        .buttonStyle(.plain)
        .disabled(isProcessing || selectedProduct == nil)
        .padding(.top, 6)
    }

    private var ctaTitle: String {
        guard let product = selectedProduct else { return "Continue" }
        if product.hasFreeTrial {
            return "Start 7-Day Free Trial"
        }
        return product.id == ProProduct.lifetime ? "Unlock Forever" : "Subscribe"
    }

    // MARK: - Footer
    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                Task {
                    isProcessing = true
                    await entitlement.restore()
                    isProcessing = false
                    if entitlement.isPro { dismiss() }
                }
            } label: {
                Text("Restore Purchases")
                    .font(PDS.caption)
                    .foregroundStyle(PDS.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(isProcessing)
            .hoverEffect(.highlight)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Text("·").foregroundStyle(PDS.textTertiary)
                Link("Privacy Policy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(PDS.textTertiary)

            Text("Subscriptions renew automatically until cancelled. Manage in Settings.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(PDS.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    // MARK: - Actions
    private func handlePurchase() {
        guard let product = selectedProduct else { return }
        errorMessage = nil
        Task {
            isProcessing = true
            defer { isProcessing = false }
            do {
                let result = try await purchaseAction(product)
                let success = try await entitlement.completePurchase(result)
                if success { dismiss() }
            } catch {
                errorMessage = "Purchase failed. Please try again."
            }
        }
    }
}

// MARK: - Plan Card
private struct PlanCard: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? PDS.accent : PDS.textTertiary)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(product.planTitle)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(PDS.textPrimary)

                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(PDS.accent, in: Capsule())
                        }
                    }

                    if product.hasFreeTrial {
                        Text("7-day free trial, then \(product.displayPrice)\(product.periodSuffix)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PDS.textSecondary)
                    } else {
                        Text(product.id == ProProduct.lifetime ? "One-time purchase" : "Billed \(product.periodDescription)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(PDS.textSecondary)
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(PDS.textPrimary)
                    if !product.periodSuffix.isEmpty {
                        Text(product.periodSuffix.trimmingCharacters(in: .whitespaces))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(PDS.textTertiary)
                    }
                }
            }
            .padding(16)
            .background(
                shape.fill(isSelected ? PDS.accent.opacity(0.18) : Color.white.opacity(0.05))
            )
            .overlay(
                shape.stroke(isSelected ? PDS.accent : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.02)
    }
}

// MARK: - Product Display Helpers
private extension Product {
    var planTitle: String {
        switch id {
        case ProProduct.monthly:  return "Monthly"
        case ProProduct.yearly:   return "Yearly"
        case ProProduct.lifetime: return "Lifetime"
        default:                  return displayName
        }
    }

    var hasFreeTrial: Bool {
        subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// e.g. "/mo", "/yr", or "" for lifetime.
    var periodSuffix: String {
        guard let period = subscription?.subscriptionPeriod else { return "" }
        switch period.unit {
        case .month where period.value == 1: return "/mo"
        case .year where period.value == 1:  return "/yr"
        case .week:  return "/wk"
        case .day:   return "/day"
        default:     return ""
        }
    }

    /// e.g. "monthly", "yearly".
    var periodDescription: String {
        guard let period = subscription?.subscriptionPeriod else { return "once" }
        switch period.unit {
        case .month where period.value == 1: return "monthly"
        case .year where period.value == 1:  return "yearly"
        case .week:  return "weekly"
        default:     return "periodically"
        }
    }
}
