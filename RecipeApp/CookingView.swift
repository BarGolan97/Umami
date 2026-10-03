import SwiftUI
import SwiftData
import AVFoundation
import UIKit
import Combine

// ---------------------------------------------------------
// ✨ Premium CookingView - Vision Pro Elite Implementation
// ---------------------------------------------------------
struct CookingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    
    @Bindable var recipe: Recipe
    
    // Shared Timer Service
    @ObservedObject private var timerService = RecipeTimerService.shared

    @State private var currentIndex: Int = 0
    @State private var showCongratulations: Bool = false
    @State private var lastSaveAt: Date = .distantPast
    @State private var showStepTransition: Bool = false
    @State private var isHoveringNext: Bool = false
    @State private var isHoveringPrevious: Bool = false
    @State private var recipeFinished: Bool = false
    @State private var showAIChat: Bool = false
    
    @Query private var sessions: [CookingSession]
    
    private var steps: [Step] { recipe.steps.sorted { $0.order < $1.order } }
    private var stepCount: Int { steps.count }
    private var safeIndex: Int { min(max(0, currentIndex), max(0, stepCount - 1)) }
    
    private var currentStep: Step? {
        guard stepCount > 0 else { return nil }
        return steps[safeIndex]
    }
    
    // Design tokens - REDUCED SPACING
    private let primarySpacing: CGFloat = 24  // Reduced from 40
    private let secondarySpacing: CGFloat = 16  // Reduced from 24
    private let cornerRadius: CGFloat = 28
    private let shadowRadius: CGFloat = 20

    init(recipe: Recipe) {
        self._recipe = Bindable(wrappedValue: recipe)
        let recipeIdValue: String = recipe.id
        self._sessions = Query(
            filter: #Predicate<CookingSession> { $0.recipeId == recipeIdValue },
            sort: [SortDescriptor(\CookingSession.updatedAt, order: .reverse)]
        )
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let isCompact = w < 1000
            let isUltraWide = w >= 1400
            
            HStack(alignment: .top, spacing: 0) {
                // MARK: - Left Side: Premium Instructions Panel
                instructionPanel(isCompact: isCompact, isUltraWide: isUltraWide)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // MARK: - Premium Divider with Glow
                premiumDivider
                
                // MARK: - Right Side: Timer or AI Chat Panel
                Group {
                    if showAIChat {
                        AICookingPanel(
                            recipe: recipe,
                            currentStep: currentStep,
                            currentStepIndex: safeIndex,
                            totalSteps: stepCount,
                            onDismiss: {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showAIChat = false
                                }
                            }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        timerPanel(isCompact: isCompact, isUltraWide: isUltraWide)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                }
                .frame(width: isCompact ? 360 : (isUltraWide ? 520 : 440))
                .frame(maxHeight: .infinity)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showAIChat)
            }
        }
        .background {
            // Premium layered background
            ZStack {
                Color.black.opacity(0.02)
                
                // Subtle gradient overlay
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.03),
                        Color.clear,
                        Color.blue.opacity(0.02)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
        .glassBackgroundEffect(displayMode: .always)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .hoverEffect()
            }
            
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(recipe.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Cooking Mode")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    // Step counter badge
                    Text("\(safeIndex + 1)/\(stepCount)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())

                    // Timer / AI segmented toggle
                    PanelSegmentedToggle(
                        showAIChat: $showAIChat,
                        stepHasTimer: currentStep?.durationSec != nil
                    )
                }
            }
        }
        // MARK: - Premium Bottom Navigation Ornament
        .ornament(
            visibility: .visible,
            attachmentAnchor: .scene(.bottom),
            contentAlignment: .center
        ) {
            premiumNavigationOrnament
        }
        .onAppear(perform: restoreSession)
        .onDisappear {
            if !recipeFinished {
                upsertSession(forceSave: true)
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.75), value: currentIndex)
        .fullScreenCover(isPresented: $showCongratulations) {
            CongratulationsView(recipe: recipe)
        }
        .onChange(of: timerService.activeTimers) { _, _ in
            upsertSession(forceSave: false)
        }
        .sensoryFeedback(.selection, trigger: currentIndex)
    }

    // MARK: - Instruction Panel
    
    private func instructionPanel(isCompact: Bool, isUltraWide: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: primarySpacing) {
                if let step = currentStep {
                    stepContent(step: step, isCompact: isCompact, isUltraWide: isUltraWide)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 1.05).combined(with: .opacity)
                        ))
                } else {
                    emptyStepState
                }
            }
            .padding(.horizontal, isCompact ? 32 : (isUltraWide ? 60 : 48))  // Reduced padding
            .padding(.vertical, isCompact ? 24 : 32)  // Reduced padding
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }
    
    private func stepContent(step: Step, isCompact: Bool, isUltraWide: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {  // Reduced from 32
            // MARK: - Step Header with Animation - MADE SMALLER
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("STEP")
                    .font(.callout.weight(.medium))  // Reduced from title3
                    .foregroundStyle(.tertiary)
                    .fontDesign(.rounded)
                
                Text("\(safeIndex + 1)")
                    .font(.system(size: isCompact ? 48 : 56, weight: .bold, design: .rounded))  // Reduced from 72/96
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())
                    .shadow(color: .orange.opacity(0.3), radius: 20, x: 0, y: 10)
                
                Spacer()
                
                // Step indicator dots
                HStack(spacing: 6) {
                    ForEach(0..<min(stepCount, 5), id: \.self) { index in
                        Circle()
                            .fill(index == safeIndex ? Color.orange : Color.secondary.opacity(0.3))
                            .frame(width: index == safeIndex ? 8 : 6, height: index == safeIndex ? 8 : 6)
                            .scaleEffect(index == safeIndex ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: safeIndex)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
            
            // MARK: - Instruction Text FIRST - Above image for better visibility
            VStack(alignment: .leading, spacing: 12) {
                Text(step.text)
                    .font(.system(size: isCompact ? 22 : 26, weight: .medium, design: .default))  // Slightly smaller but still readable
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Duration badge if available
                if let duration = step.durationSec, duration > 0 {
                    Button {
                        guard showAIChat else { return }
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showAIChat = false
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "clock.fill")
                                .symbolRenderingMode(.hierarchical)
                            Text(formatDuration(duration))
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                }
            }
            .id(step.persistentModelID)
            
            // MARK: - Step Ingredients
            StepIngredientsView(step: step, allIngredients: recipe.ingredients)
            
            // MARK: - Premium Step Image - SMALLER & AFTER TEXT
            StepImageView(
                localImageName: step.localImageName,
                imageURL: step.imageURL,
                maxHeight: isCompact ? 320 : (isUltraWide ? 550 : 480)  // Significantly reduced from 320/480/550
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: shadowRadius, x: 0, y: 12)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.3), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .hoverEffect(.highlight)
        }
    }
    
    private var emptyStepState: some View {
        VStack(spacing: 20) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 80))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse)
            
            Text("No Steps Available")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text("This recipe doesn't have any steps yet")
                .font(.body)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Timer Panel
    
    private func timerPanel(isCompact: Bool, isUltraWide: Bool) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            // MARK: - Premium Timer Display
            if let step = currentStep {
                VStack(spacing: 32) {
                    InteractiveRecipeTimerView(
                        step: step,
                        timerService: timerService,
                        isFloating: false,
                        preferredDiameter: isCompact ? 260 : (isUltraWide ? 340 : 300)
                    )
                    .id(step.persistentModelID)
                    .transition(.scale.combined(with: .opacity))
                }
                .padding(.horizontal, 32)
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "timer")
                        .font(.system(size: 60))
                        .foregroundStyle(.quaternary)
                        .symbolEffect(.pulse)
                    Text("No Timer")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            
            Spacer()
            
            // MARK: - Premium Progress Section
            premiumProgressSection(isCompact: isCompact)
        }
        .background {
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color.orange.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Glass effect
                Color.white.opacity(0.02)
            }
        }
    }
    
    private func premiumProgressSection(isCompact: Bool) -> some View {
        VStack(spacing: 20) {
            // Custom Progress Bar
            VStack(spacing: 12) {
                // Progress track
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.tertiary.opacity(0.2))
                            .frame(height: 6)
                        
                        // Active progress
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .orange.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geo.size.width * CGFloat(safeIndex + 1) / CGFloat(max(1, stepCount)),
                                height: 6
                            )
                            .shadow(color: .orange.opacity(0.5), radius: 4, x: 0, y: 2)
                    }
                }
                .frame(height: 6)
                
                // Progress labels
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.orange)
                        Text("\(safeIndex + 1) of \(stepCount)")
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                    }
                    
                    Spacer()
                    
                    if safeIndex < stepCount - 1 {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.forward")
                                .font(.caption)
                            Text("Step \(safeIndex + 2)")
                                .font(.caption.weight(.medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
            }
            .padding(24)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
    
    // MARK: - Premium Divider
    
    private var premiumDivider: some View {
        ZStack {
            // Subtle glow effect
            LinearGradient(
                colors: [
                    .clear,
                    .orange.opacity(0.1),
                    .clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 2)
            .blur(radius: 8)
            
            // Main divider line
            Rectangle()
                .fill(.tertiary.opacity(0.2))
                .frame(width: 1)
        }
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Premium Navigation Ornament
    
    private var premiumNavigationOrnament: some View {
        HStack(spacing: 20) {
            // Previous button
            Button {
                moveTo(index: safeIndex - 1)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "chevron.left")
                        .font(.title3.weight(.semibold))
                    Text("Previous")
                        .font(.body.weight(.medium))
                }
                .foregroundStyle(safeIndex == 0 ? .tertiary : .primary)
                .frame(height: 52)
                .padding(.horizontal, 24)
            }
            .disabled(safeIndex == 0)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(.secondary.opacity(0.1))
            .hoverEffect(.highlight)
            .scaleEffect(isHoveringPrevious ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: isHoveringPrevious)
            .onHover { hovering in
                isHoveringPrevious = hovering
            }

            // Next/Finish button
            Button {
                if safeIndex == stepCount - 1 {
                    finishRecipe()
                } else {
                    moveTo(index: safeIndex + 1)
                }
            } label: {
                HStack(spacing: 12) {
                    Text(safeIndex == stepCount - 1 ? "Finish Cooking" : "Next Step")
                        .font(.title3.weight(.semibold))
                    Image(systemName: safeIndex == stepCount - 1 ? "checkmark.circle.fill" : "chevron.right")
                        .font(.title3.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                }
                .foregroundStyle(.white)
                .frame(height: 52)
                .padding(.horizontal, 32)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(safeIndex == stepCount - 1 ? .green : .orange)
            .shadow(color: (safeIndex == stepCount - 1 ? Color.green : Color.orange).opacity(0.4), radius: 12, x: 0, y: 6)
            .hoverEffect(.highlight)
            .scaleEffect(isHoveringNext ? 1.08 : 1.0)
            .animation(.spring(response: 0.3), value: isHoveringNext)
            .onHover { hovering in
                isHoveringNext = hovering
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 20)
        .background {
            Capsule()
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        }
        .glassBackgroundEffect(displayMode: .always)
    }

    // MARK: - Logic Helpers

    private func restoreSession() {
        guard stepCount > 0 else { return }
        if let s = sessions.first(where: { $0.recipeId == recipe.id }) {
            currentIndex = min(max(0, s.stepIndex), max(0, stepCount - 1))
        } else {
            // No session found - always start from the beginning
            currentIndex = 0
        }
    }

    private func moveTo(index: Int) {
        guard stepCount > 0 else { return }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            currentIndex = min(max(0, index), stepCount - 1)
        }
        upsertSession(forceSave: true)
    }
    
    private func finishRecipe() {
        recipeFinished = true
        let historyEntry = RecipeHistoryEntry(
            recipeId: recipe.id,
            recipeTitle: recipe.title,
            recipeImageName: recipe.localImageName,
            finishedAt: .now,
            totalTimeMinutes: recipe.totalTimeMinutes
        )
        modelContext.insert(historyEntry)
        for s in sessions.filter({ $0.recipeId == recipe.id }) { modelContext.delete(s) }
        try? modelContext.save()
        showCongratulations = true
    }

    private func upsertSession(forceSave: Bool) {
        let now = Date()
        if !forceSave, now.timeIntervalSince(lastSaveAt) < 5 { return }
        lastSaveAt = now

        let currentRemaining: Int = {
            guard let step = currentStep else { return 0 }
            let id = step.persistentModelID
            if let state = timerService.getState(for: id) {
                return state.remaining
            } else {
                return step.durationSec ?? 0
            }
        }()

        if let s = sessions.first(where: { $0.recipeId == recipe.id }) {
            s.stepIndex = safeIndex
            s.remainingSec = currentRemaining
            s.updatedAt = .now
            try? modelContext.save()
        } else {
            let s = CookingSession(recipeId: recipe.id, stepIndex: safeIndex, remainingSec: currentRemaining, updatedAt: .now)
            modelContext.insert(s)
            try? modelContext.save()
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return String(format: "%ds", secs)
        }
    }
}

// ---------------------------------------------------------
// ✨ Step Ingredients - Shows relevant ingredients for each step
// ---------------------------------------------------------
private struct StepIngredientsView: View {
    let step: Step
    let allIngredients: [Ingredient]
    
    @AppStorage("measurementSystem") private var measurementSystemRaw: String = MeasurementSystem.metric.rawValue
    
    private var converter: UnitConverter {
        UnitConverter(system: MeasurementSystem(rawValue: measurementSystemRaw) ?? .metric)
    }
    
    /// Match ingredients whose name appears in the step text
    private var matchedIngredients: [Ingredient] {
        let stepText = step.text.lowercased()
        return allIngredients.filter { ingredient in
            let name = ingredient.name.lowercased()
            if stepText.contains(name) { return true }
            let words = name.split(separator: " ").map(String.init)
            return words.contains { word in
                word.count >= 4 && stepText.contains(word.lowercased())
            }
        }
    }
    
    var body: some View {
        if !matchedIngredients.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                // Header row
                HStack(spacing: 8) {
                    Image(systemName: "basket.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .orange.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolRenderingMode(.hierarchical)
                    
                    Text("You'll Need")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    
                    // Subtle separator line
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.orange.opacity(0.3), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                }
                
                // Ingredient items - clean vertical list
                VStack(spacing: 0) {
                    ForEach(Array(matchedIngredients.enumerated()), id: \.element.id) { index, ingredient in
                        ingredientRow(ingredient)
                        
                        if index < matchedIngredients.count - 1 {
                            Rectangle()
                                .fill(.secondary.opacity(0.08))
                                .frame(height: 0.5)
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.15), .white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
    
    private func ingredientRow(_ ingredient: Ingredient) -> some View {
        let ingredientIcon = resolveIngredientIcon(for: ingredient.name)

        return HStack(spacing: 12) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(.orange.opacity(0.35))

                if let customAssetName = ingredientIcon.customAssetName {
                    Image(customAssetName)
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.18), radius: 0.6, x: 0, y: 0.3)
                } else {
                    Image(systemName: ingredientIcon.fallbackSystemName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.monochrome)
                        .opacity(0.98)
                        .shadow(color: .black.opacity(0.18), radius: 0.6, x: 0, y: 0.3)
                }
            }
            .frame(width: 40, height: 40)
            
            // Name
            Text(ingredient.name.capitalized)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            // Quantity badge
            if let q = ingredient.quantity {
                let unit = ingredient.unit ?? ""
                let (convertedQty, convertedUnit) = converter.convert(quantity: q, unit: unit)
                let formatted = UnitConverter.formatQuantity(convertedQty)
                
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(formatted)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text(convertedUnit)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(.orange.opacity(0.35))
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

// ---------------------------------------------------------
// ✨ Premium StepImageView with Advanced Loading States
// ---------------------------------------------------------
struct StepImageView: View {
    let localImageName: String?
    let imageURL: URL?
    var maxWidth: CGFloat? = nil
    var maxHeight: CGFloat? = nil
    
    @State private var isLoading: Bool = false
    @State private var loadError: Bool = false
    
    var body: some View {
        Group {
            if let localName = localImageName,
               let docImage = RecipeImageLoader.loadImage(named: localName) {
                ZStack {
                    // Sophisticated background
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.05),
                            Color.black.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    Image(uiImage: docImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                }
                .frame(maxWidth: maxWidth ?? .infinity, maxHeight: maxHeight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Step visual instruction")
            } else if let url = imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        ZStack {
                            // Sophisticated background
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.05),
                                    Color.black.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                        .frame(maxWidth: maxWidth ?? .infinity, maxHeight: maxHeight)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Step visual instruction")
                    default:
                        EmptyView()
                    }
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
                .tint(.orange)
            Text("Loading image...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 6) {
                Text("Image Unavailable")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Unable to load step image")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var placeholderState: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundStyle(.tertiary)
                .symbolRenderingMode(.hierarchical)
            
            Text("No Image")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
}

// ---------------------------------------------------------
// ✨ Premium Interactive Timer with Enhanced Visual Design
// ---------------------------------------------------------
struct InteractiveRecipeTimerView: View {
    let step: Step
    @ObservedObject var timerService: RecipeTimerService
    var isFloating: Bool = false
    var preferredDiameter: CGFloat? = nil
    
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    @State private var isDragging: Bool = false
    @State private var showControls: Bool = true
    @State private var pulseAnimation: Bool = false
    
    // Premium Design Constants
    private let strokeWidth: CGFloat = 14.0
    private let knobSize: CGFloat = 36.0
    private let timerColor: Color = .orange
    
    // MARK: - Helpers
    private func formatTime(_ totalSeconds: Int, showHours: Bool = false) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if showHours || hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func parseDuration(from text: String) -> Int? {
        let lower = text.lowercased()
        var totalSeconds = 0
        
        // Match MM:SS format
        if let mmss = try? NSRegularExpression(pattern: "(\\b\\d{1,2}):(\\d{2})\\b") {
            let matches = mmss.matches(in: lower, range: NSRange(lower.startIndex..<lower.endIndex, in: lower))
            if let m = matches.first, m.numberOfRanges == 3,
               let r1 = Range(m.range(at: 1), in: lower), let r2 = Range(m.range(at: 2), in: lower) {
                totalSeconds = max(totalSeconds, (Int(lower[r1]) ?? 0) * 60 + (Int(lower[r2]) ?? 0))
            }
        }
        
        // Match minutes
        if let reM = try? NSRegularExpression(pattern: "(\\d+(?:\\.\\d+)?)\\s*(minutes|minute|mins|min|m)\\b") {
            let matches = reM.matches(in: lower, range: NSRange(lower.startIndex..<lower.endIndex, in: lower))
            for m in matches {
                if m.numberOfRanges >= 2, let r = Range(m.range(at: 1), in: lower), let val = Double(lower[r]) {
                    totalSeconds += Int(val * 60)
                }
            }
        }
        
        return totalSeconds > 0 ? totalSeconds : nil
    }
    
    // MARK: - Body
    var body: some View {
        let id = step.persistentModelID
        let state = timerService.getState(for: id)
        let baseDuration = step.durationSec ?? parseDuration(from: step.text) ?? 0
        let totalTime = state?.originalDuration ?? baseDuration
        let remaining = state?.remaining ?? totalTime
        let effectiveTotal = baseDuration
        
        let showHours = totalTime >= 3600
        let progress = effectiveTotal > 0 ? Double(remaining) / Double(effectiveTotal) : 0
        
        let diameter = preferredDiameter ?? (isFloating ? 260 : 300)
        let timeFontSize = max(22, diameter * (showHours ? 0.16 : 0.22))
        
        let trackPadding = knobSize / 2 + 6
        
        VStack(spacing: isFloating ? 20 : 28) {
            if effectiveTotal > 0 {
                
                // MARK: - Premium Timer Dial
                ZStack {
                    // Outer glow ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    timerColor.opacity(state?.isRunning == true ? 0.3 : 0.1),
                                    timerColor.opacity(state?.isRunning == true ? 0.1 : 0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .blur(radius: state?.isRunning == true ? 8 : 4)
                        .scaleEffect(state?.isRunning == true ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: state?.isRunning)
                    
                    // Background Track
                    Circle()
                        .stroke(.tertiary.opacity(0.15), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                        .padding(trackPadding)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Active Progress with Premium Gradient
                    Circle()
                        .trim(from: 0.0, to: CGFloat(progress))
                        .stroke(
                            AngularGradient(
                                gradient: Gradient(stops: [
                                    .init(color: timerColor, location: 0.0),
                                    .init(color: timerColor.opacity(0.85), location: 0.5),
                                    .init(color: timerColor.opacity(0.7), location: 1.0)
                                ]),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees((progress * 360) - 90)
                            ),
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                        )
                        .rotationEffect(Angle(degrees: -90))
                        .padding(trackPadding)
                        .animation(.linear(duration: isDragging ? 0 : 0.8), value: progress)
                        .shadow(color: timerColor.opacity(0.5), radius: 12, x: 0, y: 6)
                    
                    // Premium Knob
                    GeometryReader { geometry in
                        let size = geometry.size.width
                        let trackRadius = (size / 2) - trackPadding
                        let angle = Angle(degrees: (progress * 360) - 90)
                        
                        let centerX = size / 2
                        let centerY = size / 2
                        let x = centerX + trackRadius * cos(CGFloat(angle.radians))
                        let y = centerY + trackRadius * sin(CGFloat(angle.radians))
                        
                        ZStack {
                            // Knob glow
                            Circle()
                                .fill(timerColor.opacity(0.3))
                                .blur(radius: 8)
                                .frame(width: knobSize + 8, height: knobSize + 8)
                            
                            // Main knob
                            Circle()
                                .fill(.white)
                                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                                .frame(width: knobSize, height: knobSize)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [.white.opacity(0.5), .clear],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 2
                                        )
                                )
                                .overlay(
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [timerColor, timerColor.opacity(0.8)],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: 5
                                            )
                                        )
                                        .frame(width: 10, height: 10)
                                )
                        }
                        .position(x: x, y: y)
                        .scaleEffect(isDragging ? 1.3 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: isDragging)
                    }
                    .allowsHitTesting(false)
                    
                    // Center Time Display
                    VStack(spacing: 6) {
                        Text(formatTime(remaining, showHours: showHours))
                            .font(.system(size: timeFontSize, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .foregroundStyle(
                                isDragging ? timerColor :
                                (state?.isFinished == true ? .green : .primary)
                            )
                            .scaleEffect(isDragging ? 1.15 : 1.0)
                            .animation(.spring(response: 0.3), value: isDragging)
                            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                        
                        if !isDragging {
                            HStack(spacing: 4) {
                                if state?.isRunning == true {
                                    Circle()
                                        .fill(timerColor)
                                        .frame(width: 6, height: 6)
                                        .opacity(pulseAnimation ? 1.0 : 0.3)
                                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseAnimation)
                                        .onAppear { pulseAnimation = true }
                                }
                                
                                Text(state?.isRunning == true ? "Running" : (remaining == 0 ? "Complete" : "Paused"))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .transition(.opacity)
                        }
                    }
                    
                    // Invisible Touch Layer
                    Circle()
                        .fill(Color.white.opacity(0.001))
                        .contentShape(Circle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    handleDrag(value: value, id: id, effectiveTotal: effectiveTotal)
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
                .frame(width: diameter, height: diameter)
                .hoverEffect(.highlight)
                .sensoryFeedback(.selection, trigger: remaining)
                
                // MARK: - Premium Controls
                HStack(spacing: isFloating ? 24 : 36) {
                    // Restart button
                    Button {
                        SoundPlayer.playRestart()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            timerService.restart(for: id)
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.title3.weight(.semibold))
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(.secondary.opacity(0.1))
                    .hoverEffect(.highlight)
                    
                    // Play/Pause button
                    Button {
                        if state?.isRunning == true {
                            SoundPlayer.playPop()
                            withAnimation(.spring(response: 0.3)) {
                                timerService.pause(for: id)
                            }
                        } else {
                            SoundPlayer.playPop()
                            withAnimation(.spring(response: 0.3)) {
                                timerService.start(for: id, duration: effectiveTotal)
                            }
                        }
                    } label: {
                        Image(systemName: state?.isRunning == true ? "pause.fill" : "play.fill")
                            .font(.title2.weight(.bold))
                            .frame(width: 60, height: 60)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(timerColor)
                    .buttonBorderShape(.circle)
                    .shadow(color: timerColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    .hoverEffect(.highlight)
                    .scaleEffect(state?.isRunning == true ? 1.0 : 1.05)
                    .animation(.spring(response: 0.3), value: state?.isRunning)
                }
                .padding(.top, 8)
                
            } else {
                // No timer state
                VStack(spacing: 16) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.system(size: 60))
                        .foregroundStyle(.quaternary)
                        .symbolRenderingMode(.hierarchical)
                    Text("No Timer Required")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                .frame(height: diameter)
            }
            
            // Floating Timer Button
            if !isFloating && effectiveTotal > 0 {
                Button {
                    let stepID = step.persistentModelID
                    
                    // Check if there's already an open window for this step
                    if let existingKey = timerService.getCurrentWindowKey(for: stepID) {
                        // Window exists - bring it to front
                        openWindow(id: "floatingTimer", value: existingKey)
                    } else {
                        // No window - create a new one
                        let newKey = timerService.createWindowKey(for: stepID)
                        openWindow(id: "floatingTimer", value: newKey)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "pip.enter")
                            .font(.subheadline)
                        Text("Open Floating Timer")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.primary)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                }
                .buttonStyle(.plain)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(.tertiary.opacity(0.2), lineWidth: 1)
                )
                .hoverEffect(.highlight)
            }
        }
    }
    
    // MARK: - Drag Logic
    
    private func handleDrag(value: DragGesture.Value, id: PersistentIdentifier, effectiveTotal: Int) {
        isDragging = true
        
        if timerService.getState(for: id) == nil {
            timerService.createPausedIfNeeded(for: id, duration: effectiveTotal)
        }
        
        let r = (preferredDiameter ?? (isFloating ? 260 : 300)) / 2
        let dx = value.location.x - r
        let dy = value.location.y - r
        
        let angleRadians = atan2(dy, dx)
        var angleDegrees = angleRadians * 180 / .pi + 90
        if angleDegrees < 0 { angleDegrees += 360 }
        
        let newProgress = angleDegrees / 360.0
        let newTime = Int(newProgress * Double(effectiveTotal))
        
        timerService.updateRemaining(for: id, newTime: newTime)
        timerService.pause(for: id)
    }
}

// ---------------------------------------------------------
// ✨ Enhanced Timer Service
// ---------------------------------------------------------
@MainActor
class RecipeTimerService: ObservableObject {
    static let shared = RecipeTimerService()
    
    struct TimerState: Equatable {
        var originalDuration: Int
        var remaining: Int
        var isRunning: Bool
        var isFinished: Bool = false
    }
    
    @Published var activeTimers: [PersistentIdentifier: TimerState] = [:]
    
    // Track the current window instance for each step
    // This allows us to close a specific window and open a new one
    private(set) var floatingWindowInstances: [PersistentIdentifier: UUID] = [:]
    
    private var timer: AnyCancellable?
    
    private init() {
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        for (id, state) in activeTimers {
            if state.isRunning && state.remaining > 0 {
                var newState = state
                newState.remaining -= 1
                if newState.remaining == 0 {
                    newState.isRunning = false
                    newState.isFinished = true
                    SoundPlayer.playTimesUp()
                }
                activeTimers[id] = newState
            }
        }
    }
    
    func getState(for stepID: PersistentIdentifier) -> TimerState? {
        activeTimers[stepID]
    }
    
    func start(for stepID: PersistentIdentifier, duration: Int) {
        if let existing = activeTimers[stepID] {
            var newState = existing
            newState.isRunning = true
            if newState.remaining == 0 {
                newState.remaining = duration
                newState.isFinished = false
            }
            activeTimers[stepID] = newState
        } else {
            activeTimers[stepID] = TimerState(
                originalDuration: duration,
                remaining: duration,
                isRunning: true
            )
        }
    }
    
    func pause(for stepID: PersistentIdentifier) {
        if var s = activeTimers[stepID] {
            s.isRunning = false
            activeTimers[stepID] = s
        }
    }
    
    func resume(for stepID: PersistentIdentifier) {
        if var s = activeTimers[stepID] {
            s.isRunning = true
            activeTimers[stepID] = s
        }
    }
    
    func restart(for stepID: PersistentIdentifier) {
        if var s = activeTimers[stepID] {
            s.remaining = s.originalDuration
            s.isRunning = true
            s.isFinished = false
            activeTimers[stepID] = s
        }
    }
    
    func stop(for stepID: PersistentIdentifier) {
        activeTimers.removeValue(forKey: stepID)
    }
    
    func stopAll() {
        activeTimers.removeAll()
    }
    
    func createPausedIfNeeded(for stepID: PersistentIdentifier, duration: Int) {
        if activeTimers[stepID] == nil {
            activeTimers[stepID] = TimerState(
                originalDuration: duration,
                remaining: duration,
                isRunning: false
            )
        }
    }
    
    func updateRemaining(for stepID: PersistentIdentifier, newTime: Int) {
        if var s = activeTimers[stepID] {
            let t = max(0, min(newTime, s.originalDuration))
            s.remaining = t
            s.isFinished = (t == 0)
            activeTimers[stepID] = s
        }
    }
    
    // Window management
    
    /// Creates a new window key for a step. Each call creates a unique instance.
    func createWindowKey(for stepID: PersistentIdentifier) -> StepWindowKey {
        let instanceID = UUID()
        floatingWindowInstances[stepID] = instanceID
        return StepWindowKey(stepID: stepID, instanceID: instanceID)
    }
    
    /// Gets the current window key for a step (if one was created)
    func getCurrentWindowKey(for stepID: PersistentIdentifier) -> StepWindowKey? {
        guard let instanceID = floatingWindowInstances[stepID] else { return nil }
        return StepWindowKey(stepID: stepID, instanceID: instanceID)
    }
    
    /// Clears the window instance for a step (call when window is closed)
    func clearWindowInstance(for stepID: PersistentIdentifier) {
        floatingWindowInstances.removeValue(forKey: stepID)
    }
}

// ---------------------------------------------------------
// ✨ Panel Segmented Toggle
// ---------------------------------------------------------
/// A proper segmented control with a sliding orange indicator.
private struct PanelSegmentedToggle: View {
    @Binding var showAIChat: Bool
    let stepHasTimer: Bool

    @Namespace private var toggleNamespace

    var body: some View {
        HStack(spacing: 0) {
            // Timer tab
            segmentButton(icon: "timer", isSelected: !showAIChat, showBadge: stepHasTimer && showAIChat) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAIChat = false
                }
            }

            // AI tab
            segmentButton(icon: "sparkles", isSelected: showAIChat, showBadge: false) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showAIChat = true
                }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func segmentButton(icon: String, isSelected: Bool, showBadge: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 34, height: 30)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(Color.orange)
                                .matchedGeometryEffect(id: "activeSegment", in: toggleNamespace)
                                .shadow(color: .orange.opacity(0.35), radius: 6, x: 0, y: 2)
                        }
                    }

                if showBadge {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .offset(x: -2, y: 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
    }
}

// ---------------------------------------------------------
// ✨ Enhanced Sound Player
// ---------------------------------------------------------
extension SoundPlayer {
    private static var restartPlayer: AVAudioPlayer?
    
    static func playRestart() {
        if let url = Bundle.main.url(forResource: "restart", withExtension: "wav") {
            try? restartPlayer = AVAudioPlayer(contentsOf: url)
            restartPlayer?.play()
        }
    }
}
