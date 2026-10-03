//
//  OnboardingView.swift
//  RecipeApp
//
//  Onboarding — visionOS-native, premium design
//

import SwiftUI

// MARK: - Onboarding Page Model
struct OnboardingPage: Identifiable {
    let id = UUID()
    let eyebrow: String
    let title: String
    let body: String
    let iconName: String
    let accentDetail: String
}

// MARK: - Design Tokens
private enum DS {
    // visionOS-appropriate palette — warm neutrals, refined accent
    static let accent         = Color(red: 0.92, green: 0.55, blue: 0.22)     // Warm amber, less neon
    static let accentSubtle   = Color(red: 0.92, green: 0.55, blue: 0.22).opacity(0.12)
    static let accentGlow     = Color(red: 0.92, green: 0.55, blue: 0.22).opacity(0.20)

    // Text hierarchy — visionOS standard
    static let textPrimary    = Color.white
    static let textSecondary  = Color.white.opacity(0.72)
    static let textTertiary   = Color.white.opacity(0.40)

    // Surfaces
    static let separator      = Color.white.opacity(0.08)

    // Typography — visionOS uses rounded system font
    static let largeTitle     = Font.system(size: 24, weight: .bold, design: .rounded)
    static let eyebrow        = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let bodyText       = Font.system(size: 15.5, weight: .regular, design: .default)
    static let caption        = Font.system(size: 12, weight: .medium, design: .rounded)
    static let button         = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let brand          = Font.system(size: 24, weight: .bold, design: .rounded)
    static let pageNum        = Font.system(size: 12, weight: .regular, design: .monospaced)
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var animateIn = false
    @AppStorage("measurementSystem") private var measurementSystem: String = MeasurementSystem.metric.rawValue

    // Total pages = info pages + 1 measurement preference page at the end
    private var totalPageCount: Int { pages.count + 1 }
    private var isMeasurementPage: Bool { currentPage == pages.count }

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            eyebrow: "WELCOME",
            title: "A Kitchen\nBuilt for You",
            body: "Handpicked recipes from Italian, Asian, Mexican, and more — organized by cuisine, season, and mood. Ready when you are.",
            iconName: "book.fill",
            accentDetail: "Curated with care"
        ),
        OnboardingPage(
            eyebrow: "COOKING",
            title: "Cook Step\nby Step",
            body: "Clear guided steps with built-in timers. Save your progress mid-cook and pick up right where you left off.",
            iconName: "timer",
            accentDetail: "Timers · Progress saving"
        ),
        OnboardingPage(
            eyebrow: "PERSONALIZE",
            title: "Make It\nYours",
            body: "Adjust servings and ingredients update automatically. Add notes, rate favorites, and build a collection that feels like yours.",
            iconName: "slider.horizontal.3",
            accentDetail: "Servings · Notes · Ratings"
        ),
        OnboardingPage(
            eyebrow: "EXPERIENCE",
            title: "Beautiful\n& Immersive",
            body: "Rich recipe cards, smooth navigation, and a refined interface — crafted for a cooking experience that feels natural.",
            iconName: "sparkles",
            accentDetail: "Spatial · Immersive"
        )
    ]

    var body: some View {
        ZStack {
            // Scrim — subtle, not heavy
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { /* block taps */ }

            // Main window
            VStack(spacing: 0) {

                // ═══════════════════════════════════════════════════
                // HEADER
                // ═══════════════════════════════════════════════════
                VStack(spacing: 14) {
                    // Brand mark
                    HStack(spacing: 10) {
                        Image("UmamiLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())

                        Text("Umami")
                            .font(DS.brand)
                            .foregroundStyle(DS.textPrimary)
                    }

                    // Thin separator
                    Rectangle()
                        .fill(DS.separator)
                        .frame(height: 0.5)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 30)
                .padding(.bottom, 6)

                // ═══════════════════════════════════════════════════
                // SWIPEABLE PAGES
                // ═══════════════════════════════════════════════════
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page, isActive: currentPage == index)
                            .tag(index)
                    }
                    
                    // Measurement preference page
                    MeasurementPreferencePage(
                        selectedSystem: Binding(
                            get: { MeasurementSystem(rawValue: measurementSystem) ?? .metric },
                            set: { measurementSystem = $0.rawValue }
                        ),
                        isActive: isMeasurementPage
                    )
                    .tag(pages.count)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 310)

                // ═══════════════════════════════════════════════════
                // FOOTER
                // ═══════════════════════════════════════════════════
                VStack(spacing: 18) {

                    // Progress indicator — refined capsule dots
                    HStack(spacing: 5) {
                        ForEach(0..<totalPageCount, id: \.self) { i in
                            Capsule()
                                .fill(i == currentPage ? DS.accent : DS.textTertiary.opacity(0.5))
                                .frame(
                                    width: i == currentPage ? 22 : 6,
                                    height: 5
                                )
                                .animation(
                                    .spring(response: 0.35, dampingFraction: 0.7),
                                    value: currentPage
                                )
                        }
                    }
                    .padding(.bottom, 2)

                    // CTA Button
                    Button(action: handlePrimary) {
                        HStack(spacing: 8) {
                            Text(isLastPage ? "Get Started" : "Continue")
                                .font(DS.button)

                            Image(systemName: isLastPage
                                  ? "arrow.right.circle.fill"
                                  : "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DS.accent)
                                .shadow(color: DS.accentGlow, radius: 16, y: 6)
                        )
                    }
                    .buttonStyle(.plain)

                    // Skip — only before last page
                    if !isLastPage {
                        Button(action: handleSkip) {
                            Text("Skip")
                                .font(DS.caption)
                                .foregroundStyle(DS.textTertiary)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 30)
                .animation(.easeInOut(duration: 0.22), value: currentPage)
            }
            .frame(width: 460)
            // ─── visionOS native glass ────────────────────────
            .glassBackgroundEffect(
                in: RoundedRectangle(cornerRadius: 36, style: .continuous)
            )
            .shadow(color: .black.opacity(0.3), radius: 50, y: 24)
            // Entrance animation
            .scaleEffect(animateIn ? 1.0 : 0.92)
            .opacity(animateIn ? 1.0 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                    animateIn = true
                }
            }
        }
    }

    // MARK: - Helpers

    private var isLastPage: Bool { currentPage >= totalPageCount - 1 }

    private func handlePrimary() {
        if !isLastPage {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                currentPage += 1
            }
        } else {
            dismiss()
        }
    }

    private func handleSkip() { dismiss() }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.28)) {
            animateIn = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isPresented = false
        }
    }
}

// MARK: - Single Page
struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer()

            // ── Icon ──────────────────────────────────────────
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(DS.accentSubtle)
                    .frame(width: 72, height: 72)

                Circle()
                    .strokeBorder(
                        DS.accent.opacity(0.18),
                        lineWidth: 1
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: page.iconName)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DS.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.65)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.65).delay(0.06),
                value: appeared
            )

            Spacer().frame(height: 20)

            // ── Eyebrow ───────────────────────────────────────
            Text(page.eyebrow)
                .font(DS.eyebrow)
                .foregroundStyle(DS.accent.opacity(0.9))
                .tracking(2.5)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(.easeOut(duration: 0.36).delay(0.10), value: appeared)

            Spacer().frame(height: 10)

            // ── Title ─────────────────────────────────────────
            Text(page.title)
                .font(DS.largeTitle)
                .foregroundStyle(DS.textPrimary)
                .lineSpacing(4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.40).delay(0.14), value: appeared)

            Spacer().frame(height: 14)

            // ── Body ──────────────────────────────────────────
            Text(page.body)
                .font(DS.bodyText)
                .foregroundStyle(DS.textSecondary)
                .lineSpacing(5.5)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(.easeOut(duration: 0.40).delay(0.18), value: appeared)

            Spacer().frame(height: 18)

            // ── Accent tag ────────────────────────────────────
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DS.accent.opacity(0.6))
                    .frame(width: 2.5, height: 12)

                Text(page.accentDetail)
                    .font(DS.caption)
                    .foregroundStyle(DS.textTertiary)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.32).delay(0.24), value: appeared)

            Spacer()
        }
        .padding(.horizontal, 32)
        .onChange(of: isActive) { _, active in
            if active {
                appeared = false
                withAnimation {
                    appeared = true
                }
            } else {
                appeared = false
            }
        }
        .onAppear {
            if isActive { appeared = true }
        }
    }
}

// MARK: - Measurement Preference Page
struct MeasurementPreferencePage: View {
    @Binding var selectedSystem: MeasurementSystem
    let isActive: Bool
    
    @State private var appeared = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            Spacer()
            
            // ── Icon ──────────────────────────────────────────
            ZStack {
                Circle()
                    .fill(DS.accentSubtle)
                    .frame(width: 72, height: 72)
                
                Circle()
                    .strokeBorder(
                        DS.accent.opacity(0.18),
                        lineWidth: 1
                    )
                    .frame(width: 72, height: 72)
                
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DS.accent)
                    .symbolRenderingMode(.hierarchical)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.65)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.65).delay(0.06),
                value: appeared
            )
            
            Spacer().frame(height: 20)
            
            // ── Eyebrow ───────────────────────────────────────
            Text("PREFERENCES")
                .font(DS.eyebrow)
                .foregroundStyle(DS.accent.opacity(0.9))
                .tracking(2.5)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 6)
                .animation(.easeOut(duration: 0.36).delay(0.10), value: appeared)
            
            Spacer().frame(height: 10)
            
            // ── Title ─────────────────────────────────────────
            Text("Choose Your\nMeasurement Units")
                .font(DS.largeTitle)
                .foregroundStyle(DS.textPrimary)
                .lineSpacing(4)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 8)
                .animation(.easeOut(duration: 0.40).delay(0.14), value: appeared)
            
            Spacer().frame(height: 20)
            
            // ── Selection Buttons ─────────────────────────────
            HStack(spacing: 12) {
                ForEach(MeasurementSystem.allCases, id: \.self) { system in
                    MeasurementOptionButton(
                        system: system,
                        isSelected: selectedSystem == system
                    ) {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedSystem = system
                        }
                    }
                }
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 6)
            .animation(.easeOut(duration: 0.40).delay(0.18), value: appeared)
            
            Spacer().frame(height: 18)
            
            // ── Accent tag ────────────────────────────────────
            HStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DS.accent.opacity(0.6))
                    .frame(width: 2.5, height: 12)
                
                Text("You can change this later in Settings")
                    .font(DS.caption)
                    .foregroundStyle(DS.textTertiary)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.32).delay(0.24), value: appeared)
            
            Spacer()
        }
        .padding(.horizontal, 32)
        .onChange(of: isActive) { _, active in
            if active {
                appeared = false
                withAnimation {
                    appeared = true
                }
            } else {
                appeared = false
            }
        }
        .onAppear {
            if isActive { appeared = true }
        }
    }
}

// MARK: - Measurement Option Button
private struct MeasurementOptionButton: View {
    let system: MeasurementSystem
    let isSelected: Bool
    let action: () -> Void
    
    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: system == .metric ? "ruler" : "scalemass")
                    .font(.system(size: 22, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                
                Text(system.displayName)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                
                Text(system.subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(isSelected ? DS.textPrimary.opacity(0.8) : DS.textTertiary)
            }
            .foregroundStyle(isSelected ? DS.textPrimary : DS.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                shape
                    .fill(isSelected ? DS.accent.opacity(0.25) : Color.white.opacity(0.06))
            )
            .overlay(
                shape
                    .stroke(isSelected ? DS.accent : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .polishedHover(scale: 1.06)
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(red: 0.08, green: 0.07, blue: 0.06)
            .ignoresSafeArea()
        OnboardingView(isPresented: .constant(true))
    }
}
