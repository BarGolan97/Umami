import SwiftUI
import SwiftData

// MARK: - CongratulationsView
struct CongratulationsView: View {

    // --- Data ---
    let recipe: Recipe
    @Environment(\.modelContext) private var context

    // --- Callbacks ---
    var onBackToHome: () -> Void = {}
    var onBackToRecipe: () -> Void = {}

    // --- State ---
    @State private var rating: Int = 0
    @State private var isFavorite: Bool = false
    @State private var notes: String = ""

    // Animation states
    @State private var showHero = false
    @State private var showBadge = false
    @State private var showTitle = false
    @State private var showRating = false
    @State private var showNotes = false
    @State private var showButtons = false
    @State private var pulseGlow = false
    @State private var isExiting = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Helpers
    private var notesIsEmpty: Bool {
        notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commitNote() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let existing = recipe.notes, !existing.isEmpty {
            recipe.notes = existing + "\n\n" + trimmed
        } else {
            recipe.notes = trimmed
        }
        context.saveAndSync(recipe)
        notes = ""
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Layer 0: Confetti
            PremiumConfettiView()
                .opacity(showHero ? 1 : 0)
                .allowsHitTesting(false)

            // Layer 1: Main content
            VStack(spacing: 28) {
                Spacer(minLength: 0)
                heroSection
                ratingSection
                notesSection
                actionButtons
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            isFavorite = recipe.isFavorite
            rating = Int(recipe.rating)
            triggerEntrance()
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: 20) {
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                .orange, .yellow, .orange.opacity(0.6),
                                .yellow.opacity(0.3), .orange
                            ],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 164, height: 164)
                    .blur(radius: 6)
                    .opacity(pulseGlow ? 0.9 : 0.5)

                // Image container
                Group {
                    if let localName = recipe.localImageName,
                       let docImage = RecipeImageLoader.loadImage(named: localName) {
                        Image(uiImage: docImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        ZStack {
                            Color.gray.opacity(0.15)
                            VStack(spacing: 6) {
                                Image(systemName: "icloud.and.arrow.down")
                                    .font(.title2)
                                Text("Loading…")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 148, height: 148)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [
                                    .orange, .yellow, .white.opacity(0.9),
                                    .yellow, .orange
                                ],
                                center: .center
                            ),
                            lineWidth: 3.5
                        )
                )
                .shadow(color: .orange.opacity(0.25), radius: 24, x: 0, y: 8)

                // Completion badge
                ZStack {
                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 44, height: 44)

                    Image(systemName: "checkmark.circle.fill")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .green)
                        .font(.system(size: 34, weight: .medium))
                }
                .offset(x: 52, y: 52)
                .scaleEffect(showBadge ? 1 : 0)
                .opacity(showBadge ? 1 : 0)
            }
            .scaleEffect(showHero ? 1 : 0.4)
            .opacity(showHero ? 1 : 0)

            // Title
            VStack(spacing: 6) {
                Text("Bon Appétit!")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("You made **\(recipe.title)**!")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .opacity(showTitle ? 1 : 0)
            .offset(y: showTitle ? 0 : 14)
        }
    }

    // MARK: - Rating Section
    private var ratingSection: some View {
        HStack(spacing: 14) {
            // Star rating
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Image(systemName: "star.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(star <= rating ? Color.yellow : Color.primary.opacity(0.15))
                        .scaleEffect(star <= rating ? 1.15 : 1.0)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                rating = star
                            }
                            recipe.rating = Double(star)
                            context.saveAndSync(recipe)
                        }
                        .hoverEffect(.highlight)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(.regularMaterial, in: Capsule())

            // Favorite button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                    recipe.isFavorite.toggle()
                    isFavorite = recipe.isFavorite
                    context.saveAndSync(recipe)
                }
            } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isFavorite ? .red : .secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonBorderShape(.circle)
            .buttonStyle(.bordered)
            .hoverEffect(.highlight)
        }
        .opacity(showRating ? 1 : 0)
        .offset(y: showRating ? 0 : 14)
    }

    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CHEF'S NOTES")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.tertiary)
                .padding(.leading, 18)

            HStack(spacing: 12) {
                TextField("What would you change next time?", text: $notes)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, design: .rounded))
                    .submitLabel(.done)
                    .onSubmit { commitNote() }

                Button(action: { commitNote() }) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 38, height: 38)
                }
                .disabled(notesIsEmpty)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .buttonBorderShape(.circle)
            }
            .padding(.leading, 18)
            .padding(.trailing, 8)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
        }
        .frame(maxWidth: 420)
        .opacity(showNotes ? 1 : 0)
        .offset(y: showNotes ? 0 : 14)
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 16) {
            // Back to Recipe button
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Recipe")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .hoverEffect(.highlight)

            // Home button
            Button {
                triggerExit {
                    NotificationCenter.default.post(name: .returnToHome, object: nil)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Home")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .buttonBorderShape(.capsule)
            .hoverEffect(.highlight)
        }
        .frame(maxWidth: 420)
        .opacity(showButtons ? 1 : 0)
        .offset(y: showButtons ? 0 : 14)
        .allowsHitTesting(!isExiting)
    }

    // MARK: - Entrance Animation Sequence
    private func triggerEntrance() {
        withAnimation(.spring(response: 0.7, dampingFraction: 0.65)) {
            showHero = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.5).delay(0.35)) {
            showBadge = true
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
            showTitle = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.50)) {
            showRating = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.70)) {
            showNotes = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.90)) {
            showButtons = true
        }
        withAnimation(
            .easeInOut(duration: 2.5)
            .repeatForever(autoreverses: true)
            .delay(0.6)
        ) {
            pulseGlow = true
        }
    }

    // MARK: - Exit Animation Sequence
    private func triggerExit(completion: @escaping () -> Void) {
        guard !isExiting else { return }
        isExiting = true

        // Reverse order: buttons → notes → rating → title → hero
        withAnimation(.easeIn(duration: 0.2)) {
            showButtons = false
        }
        withAnimation(.easeIn(duration: 0.2).delay(0.06)) {
            showNotes = false
        }
        withAnimation(.easeIn(duration: 0.2).delay(0.12)) {
            showRating = false
        }
        withAnimation(.easeIn(duration: 0.2).delay(0.18)) {
            showTitle = false
            showBadge = false
        }
        withAnimation(.easeIn(duration: 0.25).delay(0.24)) {
            showHero = false
            pulseGlow = false
        }

        // Dismiss this cover FIRST and let it fully close, THEN reset the navigation stack.
        // SwiftUI won't pop a pushed view (CookingView) while it's presenting a cover, so
        // resetting the path too early leaves you stranded on the last cooking step.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            // Reset the nav stack FIRST (this runs synchronously via .onReceive, so Home
            // becomes the screen underneath the cover), THEN dismiss the cover — so it
            // reveals Home directly instead of flashing the last cooking step.
            completion()
            dismiss()
        }
    }
}

// MARK: - Notification
extension Notification.Name {
    static let returnToHome = Notification.Name("returnToHome")
}

// MARK: - Premium Confetti
struct PremiumConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    ConfettiPieceView(particle: p, bounds: geo.size)
                }
            }
            .onAppear {
                particles = (0..<35).map { _ in
                    ConfettiParticle.random(in: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ConfettiParticle: Identifiable {
    let id = UUID()
    let color: Color
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let startX: CGFloat
    let startY: CGFloat
    let speed: Double
    let drift: CGFloat
    let rotationSpeed: Double
    let delay: Double

    static func random(in size: CGSize) -> ConfettiParticle {
        let palette: [Color] = [
            Color(red: 1.0, green: 0.62, blue: 0.04),
            Color(red: 1.0, green: 0.84, blue: 0.10),
            Color(red: 1.0, green: 0.42, blue: 0.42),
            Color(red: 0.55, green: 0.80, blue: 1.0),
            Color(red: 0.70, green: 0.55, blue: 1.0),
            Color(red: 0.40, green: 0.95, blue: 0.70),
            .white.opacity(0.7)
        ]

        // Shape variety via dimensions
        let shapeType = Int.random(in: 0...2)
        let baseSize = CGFloat.random(in: 5...10)
        let w: CGFloat
        let h: CGFloat
        let cr: CGFloat

        switch shapeType {
        case 0: // circle
            w = baseSize; h = baseSize; cr = baseSize / 2
        case 1: // rounded rect
            w = baseSize; h = baseSize * 0.7; cr = 2
        default: // strip / capsule
            w = baseSize * 0.4; h = baseSize * 2.2; cr = baseSize * 0.2
        }

        return ConfettiParticle(
            color: palette.randomElement()!,
            width: w,
            height: h,
            cornerRadius: cr,
            startX: CGFloat.random(in: 0...size.width),
            startY: CGFloat.random(in: -60...(-10)),
            speed: Double.random(in: 3.5...7.0),
            drift: CGFloat.random(in: -40...40),
            rotationSpeed: Double.random(in: 180...540),
            delay: Double.random(in: 0...1.5)
        )
    }
}

struct ConfettiPieceView: View {
    let particle: ConfettiParticle
    let bounds: CGSize

    @State private var y: CGFloat = 0
    @State private var x: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var opacity: Double = 1.0

    var body: some View {
        RoundedRectangle(cornerRadius: particle.cornerRadius)
            .fill(particle.color)
            .frame(width: particle.width, height: particle.height)
            .rotationEffect(.degrees(rotation))
            .position(x: x, y: y)
            .opacity(opacity)
            .onAppear {
                x = particle.startX
                y = particle.startY

                withAnimation(
                    .linear(duration: particle.speed)
                    .delay(particle.delay)
                    .repeatForever(autoreverses: false)
                ) {
                    y = bounds.height + 60
                    rotation += particle.rotationSpeed
                }
                withAnimation(
                    .easeInOut(duration: particle.speed * 0.5)
                    .delay(particle.delay)
                    .repeatForever(autoreverses: true)
                ) {
                    x = particle.startX + particle.drift
                }
                withAnimation(
                    .easeInOut(duration: 1.2)
                    .delay(particle.delay)
                    .repeatForever(autoreverses: true)
                ) {
                    opacity = 0.4
                }
            }
    }
}
