import SwiftUI
import SwiftData

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(EntitlementManager.self) private var entitlement

    @Query(sort: \Recipe.title) private var recipes: [Recipe]
    @Query(sort: \RecipeHistoryEntry.finishedAt, order: .reverse) private var historyEntries: [RecipeHistoryEntry]

    @AppStorage("measurementSystem") private var measurementSystemRaw: String = MeasurementSystem.metric.rawValue
    @AppStorage(RecipePreferenceKeys.preferredDiets) private var preferredDietsRaw: String = ""
    @AppStorage(RecipePreferenceKeys.excludedAllergens) private var excludedAllergensRaw: String = ""

    @State private var showClearHistoryDialog = false
    @State private var showResetPrefsDialog = false
    @State private var showPaywall = false
    @State private var appeared: Set<String> = []

    // Pending dietary edits (staged before "Apply")
    @State private var pendingDietsRaw: String = ""
    @State private var pendingAllergensRaw: String = ""
    @State private var hasUnappliedChanges: Bool = false
    @State private var showAppliedFeedback: Bool = false

    private var selectedDiets: Set<DietaryPreference> {
        preferredDietsRaw.rawValueSet(for: DietaryPreference.self)
    }
    private var selectedAllergens: Set<RecipeAllergen> {
        excludedAllergensRaw.rawValueSet(for: RecipeAllergen.self)
    }
    private var pendingDiets: Set<DietaryPreference> {
        pendingDietsRaw.rawValueSet(for: DietaryPreference.self)
    }
    private var pendingAllergens: Set<RecipeAllergen> {
        pendingAllergensRaw.rawValueSet(for: RecipeAllergen.self)
    }
    private var measurementSystem: MeasurementSystem {
        MeasurementSystem(rawValue: measurementSystemRaw) ?? .metric
    }
    private var matchingRecipesCount: Int {
        RecipePreferenceFilter.filter(recipes, diets: pendingDiets, allergens: pendingAllergens).count
    }

    var body: some View {
        ZStack {
            // Bright background matching FavoritesView
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 36) {

                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Settings")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Personalize your experience")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .settingsAppear("header", set: $appeared)

                    // MARK: - Umami Pro
                    SettingsCard {
                        if entitlement.isPro {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange.opacity(0.18))
                                        .frame(width: 48, height: 48)
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(.orange)
                                        .symbolRenderingMode(.hierarchical)
                                }

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Umami Pro")
                                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Active — unlimited AI Sous-Chef")
                                        .font(.system(size: 13, weight: .regular, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }

                                Spacer()

                                Text("PRO")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.orange, in: Capsule())
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange.opacity(0.18))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(.orange)
                                            .symbolRenderingMode(.hierarchical)
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Upgrade to Umami Pro")
                                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                                            .foregroundStyle(.white)
                                        Text("Unlimited AI Sous-Chef & more")
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.5))
                                    }

                                    Spacer()
                                }

                                Button {
                                    showPaywall = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16, weight: .semibold))
                                        Text("See Plans")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.orange)
                                    )
                                }
                                .buttonStyle(SpatialButtonStyle(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
                                .polishedHover()

                                SettingsActionButton(
                                    icon: "arrow.clockwise",
                                    iconColor: .white.opacity(0.7),
                                    title: "Restore Purchases",
                                    titleColor: .white
                                ) {
                                    Task { await entitlement.restore() }
                                }
                            }
                        }
                    }
                    .settingsAppear("pro", set: $appeared, delay: 0.025)

                    // MARK: - Measurement System (Section 1 - Lift hover)
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SettingsCardHeader(icon: "scalemass", title: "Units")

                            HStack(spacing: 12) {
                                MeasurementOption(
                                    title: "Metric",
                                    detail: "kg · g · ml",
                                    isSelected: measurementSystem == .metric
                                ) {
                                    withAnimation(.snappy(duration: 0.25)) {
                                        measurementSystemRaw = MeasurementSystem.metric.rawValue
                                    }
                                }

                                MeasurementOption(
                                    title: "Imperial",
                                    detail: "lb · oz · cups",
                                    isSelected: measurementSystem == .imperial
                                ) {
                                    withAnimation(.snappy(duration: 0.25)) {
                                        measurementSystemRaw = MeasurementSystem.imperial.rawValue
                                    }
                                }
                            }
                        }
                    }
                    .settingsAppear("units", set: $appeared, delay: 0.05)

                    // MARK: - Dietary Preferences (Section 2 - Plain hover)
                    SettingsCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                SettingsCardHeader(icon: "leaf", title: "Dietary Preferences")

                                Spacer()

                                Text("\(matchingRecipesCount)/\(recipes.count) recipes")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.4))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.06), in: Capsule())
                            }

                            VStack(spacing: 0) {
                                ForEach(Array(DietaryPreference.allCases.enumerated()), id: \.element.id) { idx, option in
                                    DietaryRow(
                                        title: option.title,
                                        subtitle: option.subtitle,
                                        isOn: pendingDiets.contains(option)
                                    ) {
                                        togglePendingDiet(option)
                                    }

                                    if idx < DietaryPreference.allCases.count - 1 {
                                        Divider()
                                            .opacity(0.1)
                                            .padding(.leading, 38)
                                            .padding(.vertical, 6)
                                    }
                                }
                            }

                            // Allergen sub-section
                            Divider().opacity(0.1).padding(.vertical, 4)

                            SettingsCardHeader(icon: "shield.checkered", title: "Allergen Exclusions")

                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 10
                            ) {
                                ForEach(RecipeAllergen.allCases) { allergen in
                                    AllergenToggle(
                                        title: allergen.title,
                                        isSelected: pendingAllergens.contains(allergen)
                                    ) {
                                        togglePendingAllergen(allergen)
                                    }
                                }
                            }

                            // Apply Changes button
                            if hasUnappliedChanges {
                                Button {
                                    applyDietaryChanges()
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 16, weight: .semibold))

                                        Text("Apply Changes")
                                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.orange)
                                    )
                                }
                                .buttonStyle(SpatialButtonStyle(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
                                .polishedHover()
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .padding(.top, 4)
                            }

                            if showAppliedFeedback {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.green)
                                    Text("Preferences applied")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.green.opacity(0.8))
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                .padding(.top, 2)
                            }
                        }
                    }
                    .settingsAppear("dietary", set: $appeared, delay: 0.1)

                    // MARK: - Recipe History (New section - Plain hover)
                    if !historyEntries.isEmpty {
                        SettingsCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    SettingsCardHeader(icon: "clock.arrow.circlepath", title: "Recipe History")

                                    Spacer()

                                    Text("\(historyEntries.count) cooked")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.4))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.white.opacity(0.06), in: Capsule())
                                }

                                VStack(spacing: 0) {
                                    ForEach(Array(historyEntries.enumerated()), id: \.element.id) { idx, entry in
                                        HistoryRow(entry: entry) {
                                            deleteHistoryEntry(entry)
                                        }

                                        if idx < historyEntries.count - 1 {
                                            Divider()
                                                .opacity(0.06)
                                                .padding(.leading, 56)
                                                .padding(.vertical, 2)
                                        }
                                    }
                                }
                            }
                        }
                        .settingsAppear("history", set: $appeared, delay: 0.15)
                    }

                    // MARK: - Data Management (Section 4 - Plain hover, no chevrons, button-style)
                    SettingsCard {
                        VStack(spacing: 12) {
                            SettingsActionButton(
                                icon: "arrow.counterclockwise",
                                iconColor: .white.opacity(0.7),
                                title: "Reset Preferences",
                                titleColor: .white
                            ) {
                                showResetPrefsDialog = true
                            }

                            if !historyEntries.isEmpty {
                                SettingsActionButton(
                                    icon: "trash",
                                    iconColor: .red.opacity(0.8),
                                    title: "Clear All History",
                                    titleColor: .red
                                ) {
                                    showClearHistoryDialog = true
                                }
                            }
                        }
                    }
                    .settingsAppear("data", set: $appeared, delay: 0.2)

                    // MARK: - Footer
                    HStack {
                        Spacer()
                        VStack(spacing: 4) {
                            Image("UmamiLogo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                                .opacity(0.5)

                            Text("Umami · v1.0")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                        Spacer()
                    }
                    .padding(.top, 12)
                    .settingsAppear("footer", set: $appeared, delay: 0.25)
                }
                .padding(.horizontal, 60)
                .padding(.top, 50)
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // Initialize pending values from saved preferences
            pendingDietsRaw = preferredDietsRaw
            pendingAllergensRaw = excludedAllergensRaw
        }
        .confirmationDialog("Clear all cooking history?", isPresented: $showClearHistoryDialog) {
            Button("Clear History", role: .destructive) { clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(historyEntries.count) cooking sessions.")
        }
        .confirmationDialog("Reset all preferences?", isPresented: $showResetPrefsDialog) {
            Button("Reset", role: .destructive) { resetPreferences() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Measurement system, dietary filters, and allergen exclusions will be cleared.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Actions

    private func togglePendingDiet(_ option: DietaryPreference) {
        var next = pendingDiets
        if next.contains(option) { next.remove(option) } else { next.insert(option) }
        withAnimation(.snappy(duration: 0.2)) {
            pendingDietsRaw = next.rawString
            hasUnappliedChanges = (pendingDietsRaw != preferredDietsRaw || pendingAllergensRaw != excludedAllergensRaw)
            showAppliedFeedback = false
        }
    }

    private func togglePendingAllergen(_ option: RecipeAllergen) {
        var next = pendingAllergens
        if next.contains(option) { next.remove(option) } else { next.insert(option) }
        withAnimation(.snappy(duration: 0.2)) {
            pendingAllergensRaw = next.rawString
            hasUnappliedChanges = (pendingDietsRaw != preferredDietsRaw || pendingAllergensRaw != excludedAllergensRaw)
            showAppliedFeedback = false
        }
    }

    private func applyDietaryChanges() {
        withAnimation(.snappy(duration: 0.3)) {
            preferredDietsRaw = pendingDietsRaw
            excludedAllergensRaw = pendingAllergensRaw
            hasUnappliedChanges = false
            showAppliedFeedback = true
        }
        // Auto-hide feedback after a short delay
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation(.easeOut(duration: 0.3)) {
                showAppliedFeedback = false
            }
        }
    }

    private func deleteHistoryEntry(_ entry: RecipeHistoryEntry) {
        withAnimation(.snappy(duration: 0.25)) {
            modelContext.delete(entry)
            try? modelContext.save()
        }
    }

    private func clearHistory() {
        for entry in historyEntries { modelContext.delete(entry) }
        try? modelContext.save()
    }

    private func resetPreferences() {
        measurementSystemRaw = MeasurementSystem.metric.rawValue
        preferredDietsRaw = ""
        excludedAllergensRaw = ""
        pendingDietsRaw = ""
        pendingAllergensRaw = ""
        hasUnappliedChanges = false
    }
}

// MARK: - Appear Animation

private extension View {
    func settingsAppear(_ key: String, set: Binding<Set<String>>, delay: Double = 0) -> some View {
        self
            .opacity(set.wrappedValue.contains(key) ? 1 : 0)
            .offset(y: set.wrappedValue.contains(key) ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(delay)) {
                    _ = set.wrappedValue.insert(key)
                }
            }
    }
}

// MARK: - Plain Hover (highlight only, no lift)

private extension View {
    @ViewBuilder
    func settingsPlainHover() -> some View {
        #if os(visionOS)
        self.hoverEffect(.highlight)
        #else
        self
        #endif
    }
}

// MARK: - Settings Card

private struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 1)
            )
    }
}

// MARK: - Card Header

private struct SettingsCardHeader: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.orange)

            Text(title)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Measurement Option (Section 1 - Lift hover)

private struct MeasurementOption: View {
    let title: String
    let detail: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isSelected ? .orange : .white.opacity(0.25))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.orange.opacity(0.12) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        isSelected ? Color.orange.opacity(0.4) : Color.white.opacity(0.08),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: RoundedRectangle(cornerRadius: 16, style: .continuous)))
        .polishedHover()
        .animation(.snappy(duration: 0.25), value: isSelected)
    }
}

// MARK: - Dietary Row (Section 2 - Plain hover, no lift)

private struct DietaryRow: View {
    let title: String
    let subtitle: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? .orange : .white.opacity(0.2))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Spacer()
            }
            .padding(.vertical, 4)
            .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .settingsPlainHover()
    }
}

// MARK: - Allergen Toggle (Section 3 - Lift hover)

private struct AllergenToggle: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isSelected ? .white : .white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isSelected ? Color.red.opacity(0.45) : Color.white.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.red.opacity(0.35) : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(SpatialButtonStyle(shape: RoundedRectangle(cornerRadius: 12, style: .continuous)))
        .polishedHover()
        .animation(.snappy(duration: 0.2), value: isSelected)
    }
}

// MARK: - History Row (Minimalist design with delete)

private struct HistoryRow: View {
    let entry: RecipeHistoryEntry
    let onDelete: () -> Void

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: entry.finishedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 14) {
            // Recipe thumbnail
            Group {
                if let imageName = entry.recipeImageName,
                   let uiImage = RecipeImageLoader.loadImage(named: imageName, targetPixelSize: CGSize(width: 80, height: 80)) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.white.opacity(0.05))
            )

            // Recipe info
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.recipeTitle)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.35))

                    if entry.totalTimeMinutes > 0 {
                        Text("·")
                            .foregroundStyle(.white.opacity(0.2))
                        Text(Recipe.formatTotalTime(minutes: entry.totalTimeMinutes))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                    }
                }
            }

            Spacer()

            // Delete button
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(width: 32, height: 32)
                    .contentShape(.hoverEffect, Circle())
            }
            .buttonStyle(.plain)
            .settingsPlainHover()
        }
        .padding(.vertical, 8)
        .contentShape(.hoverEffect, RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Action Button (Bottom section - no chevron, button-style, plain hover)

private struct SettingsActionButton: View {
    let icon: String
    let iconColor: Color
    let title: String
    let titleColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(titleColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(SpatialButtonStyle(shape: RoundedRectangle(cornerRadius: 14, style: .continuous)))
        .settingsPlainHover()
    }
}

#Preview {
    SettingsView()
        .environment(EntitlementManager.shared)
        .environment(AIUsageManager.shared)
}
