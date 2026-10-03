import SwiftUI

// MARK: - Data Models

struct AIChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: MessageRole
    let text: String
    let timestamp: Date = Date()
    var usedFallbackModel: Bool = false

    enum MessageRole {
        case user
        case assistant
    }

    static func == (lhs: AIChatMessage, rhs: AIChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - AI Cooking Panel

/// Minimalist inline AI panel that replaces the timer panel.
struct AICookingPanel: View {
    let recipe: Recipe
    let currentStep: Step?
    let currentStepIndex: Int
    let totalSteps: Int
    let onDismiss: () -> Void

    @State private var messages: [AIChatMessage] = []
    @State private var inputText: String = ""
    @State private var isTyping: Bool = false
    @State private var showPaywall: Bool = false
    @FocusState private var isInputFocused: Bool

    @Environment(EntitlementManager.self) private var entitlement
    @Environment(AIUsageManager.self) private var usage

    var body: some View {
        VStack(spacing: 0) {
            // Scrollable content area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if messages.isEmpty {
                            emptyState
                        } else {
                            // New Chat button at top of conversation
                            newChatButton
                                .padding(.top, 16)
                                .padding(.bottom, 8)
                        }

                        ForEach(messages) { msg in
                            MessageRow(message: msg)
                                .id(msg.id)
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                        }

                        if isTyping {
                            typingIndicator
                                .id("typing")
                                .padding(.horizontal, 20)
                                .padding(.bottom, 12)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: messages.count) { _, _ in
                    withAnimation(.spring(response: 0.3)) {
                        if let last = messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isTyping) { _, on in
                    if on {
                        withAnimation(.spring(response: 0.3)) {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }

            // Input bar pinned at bottom
            inputBar
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - New Chat Button

    private var newChatButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                messages.removeAll()
                inputText = ""
                isTyping = false
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle")
                    .font(.system(size: 12, weight: .medium))
                Text("New Chat")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(.hoverEffect, Capsule())
        }
        .buttonStyle(SpatialButtonStyle(shape: Capsule()))
        .hoverEffect(.highlight)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)

            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.orange.opacity(0.7))
                .padding(.bottom, 14)

            Text("Ask me anything")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary.opacity(0.8))

            Spacer().frame(height: 36)

            // Suggestions — contextual per step, kept minimal
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.query) { s in
                    SuggestionButton(icon: s.icon, label: s.label) {
                        sendMessage(s.query)
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var suggestions: [(icon: String, label: String, query: String)] {
        guard let step = currentStep else {
            return [
                ("questionmark.circle", "What should I prep first?", "What should I prepare or have ready before I start cooking this recipe?"),
                ("list.bullet", "Summarize the whole recipe", "Give me a quick summary of all the steps in this recipe so I know what to expect.")
            ]
        }

        var items: [(icon: String, label: String, query: String)] = []
        let text = step.text.lowercased()
        let isFirstStep = currentStepIndex == 0
        let isLastStep = currentStepIndex == totalSteps - 1

        // 1. Highly specific phrase-level suggestions first (catches exact scenarios)
        let phraseMatches = phraseLevelSuggestions(for: text)
        items.append(contentsOf: phraseMatches)

        // 2. Keyword-level suggestions (broader category matching)
        if items.count < 3 {
            let keywordMatches = keywordSuggestions(for: text)
            for kw in keywordMatches where items.count < 3 {
                // Avoid duplicating labels
                if !items.contains(where: { $0.label == kw.label }) {
                    items.append(kw)
                }
            }
        }

        // 3. Timer-based: when there's a wait, users want to know what "done" looks like
        if step.durationSec != nil && items.count < 3 {
            if !items.contains(where: { $0.label.contains("ready") || $0.label.contains("done") || $0.label.contains("know") }) {
                items.append(("eye", "How do I know it's ready?", "What should I look for to know this step is done? Any visual or texture cues?"))
            }
        }

        // 4. First step: users often wonder about prep
        if isFirstStep && items.count < 3 {
            items.append(("tray", "Anything to prep ahead?", "Is there anything I should have prepped or set up before starting this step?"))
        }

        // 5. Last step: users care about serving
        if isLastStep && items.count < 3 {
            items.append(("fork.knife", "How should I serve this?", "What's the best way to serve this dish? Any tips for presentation or side dishes?"))
        }

        // 6. Fallback — only if nothing matched
        if items.isEmpty {
            items.append(("questionmark.circle", "Walk me through this", "Can you walk me through this step in simple terms? I'm not sure what to do."))
            items.append(("lightbulb", "Any tips for this step?", "Do you have any tips or tricks that would help me get this step right?"))
        }

        // Limit to 3 suggestions for a clean, focused UI
        return Array(items.prefix(3))
    }

    // MARK: - Phrase-Level Suggestions (highly specific to exact scenarios)

    /// Matches specific phrases/combinations that indicate a precise cooking situation.
    /// These are the "wow, it read my mind" suggestions.
    private func phraseLevelSuggestions(for text: String) -> [(icon: String, label: String, query: String)] {
        var results: [(icon: String, label: String, query: String)] = []

        // --- TIRAMISU / LADYFINGER scenarios ---
        if text.contains("ladyfinger") || text.contains("savoiardi") {
            if text.contains("dip") || text.contains("coffee") {
                results.append(("clock", "My cookies are falling apart", "The ladyfingers are getting too soggy and breaking when I dip them. How long should I actually dip each one?"))
                results.append(("questionmark.circle", "Coffee too hot?", "Does the coffee temperature matter for dipping? Should it be cold, warm, or room temperature?"))
            }
        }

        // Mascarpone mixing — overmixing is the #1 tiramisu fail
        if text.contains("mascarpone") && (text.contains("mix") || text.contains("add")) {
            results.append(("exclamationmark.triangle", "It looks lumpy", "My mascarpone mixture is lumpy and not smooth. Did I do something wrong? Can I fix this?"))
            results.append(("thermometer.medium", "Does temperature matter?", "Does the mascarpone need to be at room temperature? Mine was cold from the fridge."))
        }

        // Egg yolk + sugar beating — users don't know what "pale and thick" means
        if text.contains("egg yolk") && text.contains("sugar") {
            results.append(("eye", "What does 'thick' look like?", "You say beat until thick — what exactly should it look like? What color and consistency am I aiming for?"))
            results.append(("clock", "Can I do this by hand?", "I don't have a mixer. Can I whisk the egg yolks and sugar by hand? How long will it take?"))
        }

        // Folding whipped cream into a mixture — deflating is the big fear
        if text.contains("fold") && (text.contains("cream") || text.contains("egg white") || text.contains("meringue")) {
            results.append(("arrow.uturn.down", "I think I'm deflating it", "The mixture is getting flat and runny as I fold. Am I doing this wrong? What motion should I use?"))
            results.append(("questionmark.circle", "How many folds is enough?", "How do I know when to stop folding? Should I still see streaks or should it be fully mixed?"))
        }

        // Spreading cream layers evenly
        if text.contains("spread") && (text.contains("cream") || text.contains("mascarpone") || text.contains("mixture")) {
            results.append(("hand.raised", "How thick should the layer be?", "How thick should this layer be? Should I use all of it or save some?"))
        }

        // Chilling for hours (tiramisu, cheesecake, mousse)
        if (text.contains("chill") || text.contains("refrigerat")) && (text.contains("hour") || text.contains("overnight")) {
            results.append(("snowflake", "Can I leave it overnight?", "Is it okay to chill this longer than the time stated? Like overnight? Will the texture change?"))
            results.append(("eye", "How do I know it's set?", "How can I tell if it's properly set? Should it jiggle or be completely firm?"))
        }

        // Dusting cocoa/sugar on top
        if text.contains("dust") && (text.contains("cocoa") || text.contains("sugar") || text.contains("powder")) {
            results.append(("sparkles", "How much should I dust?", "How thick should the dusting be? Should I be generous or just a light layer?"))
        }

        // --- CARBONARA-specific: the egg scramble risk ---
        if text.contains("egg") && text.contains("pasta") && (text.contains("toss") || text.contains("pour")) {
            results.append(("exclamationmark.triangle", "Won't the eggs scramble?", "I'm scared the eggs will scramble when they hit the hot pasta. How do I prevent this?"))
            results.append(("flame", "How hot should the pan be?", "Should the pan be on the heat or off when I add the egg mixture?"))
        }

        // Off the heat technique
        if text.contains("off the heat") || text.contains("off heat") || text.contains("remove from heat") {
            if text.contains("egg") || text.contains("cream") || text.contains("cheese") {
                results.append(("flame", "Why off the heat?", "Why do I need to take it off the heat for this? What happens if the pan is still hot?"))
            }
        }

        // --- LAVA CAKE: exact timing is critical ---
        if text.contains("bake") && text.contains("exactly") {
            results.append(("clock", "What if my oven is different?", "My oven might run hot or cold. How do I adjust the time? What should I look for to know it's done?"))
            results.append(("exclamationmark.triangle", "What if I overbake?", "What happens if I leave it in too long? Is there a way to tell if the center is still molten?"))
        }

        // Inverting / unmolding (lava cake, panna cotta)
        if text.contains("invert") || text.contains("unmold") || text.contains("turn onto") {
            results.append(("exclamationmark.triangle", "It's stuck!", "The cake won't come out of the ramekin cleanly. What should I do? Can I save it?"))
        }

        // Greasing ramekins
        if text.contains("grease") && text.contains("ramekin") {
            results.append(("questionmark.circle", "Butter or spray?", "Should I use butter, oil, or cooking spray to grease the ramekins? Does it matter?"))
        }

        // --- CHOCOLATE WORK ---
        if text.contains("melt") && text.contains("chocolate") {
            results.append(("flame", "Can I microwave it instead?", "Can I melt the chocolate in the microwave instead of a double boiler? What's the safest way?"))
            results.append(("drop", "It's getting clumpy", "The chocolate is seizing up and getting thick and grainy. What went wrong and can I fix it?"))
        }

        // Double boiler / bowl over simmering water
        if text.contains("bowl over") || text.contains("heatproof bowl") || text.contains("double boiler") {
            results.append(("drop", "Is water getting in?", "The bowl shouldn't touch the water right? What happens if water gets into the chocolate?"))
        }

        // Whipping cream to stiff peaks / over-whip risk
        if text.contains("whip") && text.contains("cream") && text.contains("stiff") {
            results.append(("exclamationmark.triangle", "It turned into butter!", "I think I over-whipped and it looks like butter. Can I fix this or do I need to start over?"))
            results.append(("eye", "What do stiff peaks look like?", "How do I know when the cream is at stiff peaks? What should it look like when I lift the whisk?"))
        }

        // Whisking egg whites
        if text.contains("egg white") && (text.contains("whisk") || text.contains("whip") || text.contains("beat")) {
            results.append(("exclamationmark.triangle", "They won't get fluffy", "I've been whisking but the egg whites aren't getting thick or foamy. What am I doing wrong?"))
            results.append(("questionmark.circle", "Does the bowl matter?", "Do I need a specific type of bowl? I heard plastic bowls can be a problem."))
        }

        // --- WATER BATH / BAIN MARIE (cheesecake, creme brulee) ---
        if text.contains("water bath") || (text.contains("roasting pan") && text.contains("water")) {
            results.append(("drop", "How much water do I add?", "How high should the water come up the sides of the ramekins or pan? Does the water need to be hot?"))
            results.append(("exclamationmark.triangle", "Water leaking into pan", "I'm worried water will leak into the springform pan. How do I prevent that?"))
        }

        // Set but wobbly (custard, cheesecake)
        if text.contains("set") && text.contains("wobbly") {
            results.append(("eye", "How wobbly is right?", "How much wobble is okay? I can't tell if it's done or still too liquid in the middle."))
        }

        // --- CARAMELIZING SUGAR (creme brulee torch) ---
        if text.contains("torch") || text.contains("caramelize") && text.contains("sugar") {
            results.append(("flame", "I don't have a torch", "I don't have a kitchen torch. Can I use the oven broiler instead? How do I do it?"))
            if text.contains("torch") {
                results.append(("eye", "What color should it be?", "How dark should I caramelize the sugar? I don't want it to taste burnt."))
            }
        }

        // Steeping (vanilla, spices in cream)
        if text.contains("steep") || (text.contains("vanilla") && text.contains("heat")) {
            results.append(("clock", "Can I steep longer?", "Does steeping longer make it more flavorful, or can I over-steep and ruin the flavor?"))
        }

        // --- RISOTTO: ladle by ladle ---
        if text.contains("ladle") || (text.contains("broth") && text.contains("one") && text.contains("time")) {
            results.append(("arrow.triangle.2.circlepath", "How much per ladle?", "How much broth should I add each time? And how do I know when to add the next ladle?"))
            results.append(("flame", "What heat level?", "Should this be on low, medium-low, or medium heat? My rice is cooking too fast/slow."))
        }

        // Toasting rice
        if text.contains("toast") && text.contains("rice") {
            results.append(("eye", "How do I know it's toasted?", "What does properly toasted rice look and smell like? I don't want to burn it."))
        }

        // --- LONG SIMMERING (Bolognese, Ramen, Pho, Short Ribs) ---
        if text.contains("simmer") && (text.contains("hour") || text.contains("2.5") || text.contains("12")) {
            results.append(("flame", "What heat level exactly?", "How low is 'low heat'? Should there be small bubbles or almost no movement at all?"))
            results.append(("questionmark.circle", "Can I use a slow cooker?", "Can I do this in a slow cooker or Instant Pot instead of simmering on the stove?"))
        }

        // Cooking with wine / deglazing
        if text.contains("wine") || text.contains("deglaze") {
            if text.contains("deglaze") {
                results.append(("drop", "I don't have wine", "I don't have wine. What else can I use to deglaze the pan? Stock, vinegar, or something else?"))
            }
            if text.contains("wine") {
                results.append(("questionmark.circle", "What wine should I use?", "Does it matter what kind of wine I use? Is cooking wine okay or should I use a drinking wine?"))
            }
        }

        // Browning meat thoroughly
        if text.contains("brown") && (text.contains("beef") || text.contains("meat") || text.contains("chicken") || text.contains("pork")) {
            results.append(("eye", "How brown is brown enough?", "How do I know when the meat is properly browned? Should I see a crust forming?"))
            results.append(("exclamationmark.triangle", "The meat is steaming", "The meat seems to be steaming rather than browning. What am I doing wrong?"))
        }

        // --- SMASH BURGER specific ---
        if text.contains("smash") {
            results.append(("hand.raised", "How flat do I smash it?", "How thin should I smash the patty? Should I press it once or multiple times?"))
        }

        if text.contains("crust") && (text.contains("brown") || text.contains("cook undisturbed")) {
            results.append(("eye", "How do I get a good crust?", "The patty isn't getting crusty. Should I press harder or is the pan not hot enough?"))
        }

        // Cook undisturbed / don't touch
        if text.contains("undisturbed") || text.contains("without moving") || text.contains("don't touch") || text.contains("do not move") {
            results.append(("clock", "Can I peek?", "Can I lift it to check the bottom, or will that ruin the crust? How do I know when to flip without looking?"))
        }

        // Melting cheese with a lid
        if text.contains("cheese") && (text.contains("lid") || text.contains("cover") || text.contains("foil")) && text.contains("melt") {
            results.append(("eye", "Cheese isn't melting", "I covered it but the cheese isn't melting evenly. Should I add a splash of water?"))
        }

        // --- PAD THAI / STIR-FRY / WOK ---
        if text.contains("wok") || text.contains("stir-fry") || text.contains("stir fry") {
            results.append(("flame", "My wok isn't hot enough", "How do I know if my wok is hot enough? It says stir-fry but the food just seems to be boiling."))
        }

        // Noodle soaking
        if text.contains("soak") && text.contains("noodle") {
            results.append(("clock", "How soft should they get?", "How soft should the noodles be after soaking? They're still kind of stiff — is that okay?"))
            results.append(("drop", "What water temperature?", "Should the water be hot, warm, or room temperature? Does it affect the noodles?"))
        }

        // Tamarind / fish sauce mixing
        if text.contains("tamarind") || text.contains("fish sauce") {
            results.append(("leaf", "It smells really strong", "The fish sauce/tamarind smells overpowering. Is this normal? Will it mellow out when cooked?"))
        }

        // Scrambling eggs quickly (in wok for pad thai, etc.)
        if text.contains("scramble") && text.contains("egg") && (text.contains("wok") || text.contains("pan")) {
            results.append(("flame", "Eggs are sticking", "The eggs are sticking to the pan. What should I do?"))
        }

        // --- BREAD / DOUGH specific ---
        // Yeast + foamy
        if text.contains("yeast") && (text.contains("foamy") || text.contains("foam") || text.contains("bubbly")) {
            results.append(("exclamationmark.triangle", "It's not foaming", "I waited but the yeast isn't foaming. Is my yeast dead? Should I start over with new yeast?"))
            results.append(("thermometer.medium", "Was my water too hot?", "Could the water have been too hot and killed the yeast? What temperature should it be?"))
        }

        // Dimpling dough (focaccia)
        if text.contains("dimple") || text.contains("press") && text.contains("finger") {
            results.append(("hand.raised", "How deep should I press?", "How deep should the dimples be? I don't want to poke through the dough."))
        }

        // --- CHEESECAKE specific ---
        // Cooling in oven
        if text.contains("oven off") || text.contains("turn off") || (text.contains("cool") && text.contains("inside") && text.contains("oven")) {
            results.append(("questionmark.circle", "Why cool in the oven?", "Why can't I just take it out? What happens if I skip this step and cool it on the counter?"))
            results.append(("eye", "Will it crack?", "I'm worried the cheesecake will crack on top. What causes cracking and how do I prevent it?"))
        }

        // Springform pan
        if text.contains("springform") {
            results.append(("questionmark.circle", "Can I use a regular pan?", "I don't have a springform pan. Can I use a regular cake pan instead? How do I remove it?"))
        }

        // Crust pressing
        if text.contains("press") && (text.contains("crust") || text.contains("biscuit") || text.contains("crumb")) {
            results.append(("hand.raised", "How firm should I press?", "How tightly should I pack the crust? Mine seems loose — should I press harder?"))
        }

        // --- PASTA specific ---
        if text.contains("al dente") {
            results.append(("fork.knife", "How do I check al dente?", "How do I know if the pasta is al dente? Should I taste it? What should it feel like?"))
        }

        if text.contains("pasta water") || (text.contains("reserve") && text.contains("water")) {
            results.append(("drop", "Why save pasta water?", "Why do I need to save the pasta water? What does it actually do for the sauce?"))
        }

        // Emulsifying sauce
        if text.contains("emulsif") || (text.contains("toss") && text.contains("pasta") && text.contains("water")) {
            results.append(("arrow.triangle.2.circlepath", "My sauce isn't creamy", "The pasta sauce is oily/watery instead of creamy. How do I get it to emulsify properly?"))
        }

        // Garlic golden / don't burn
        if text.contains("garlic") && (text.contains("golden") || text.contains("burn") || text.contains("fragrant")) {
            results.append(("flame", "My garlic is getting dark", "The garlic is turning brown really fast. Is it burning? Should I lower the heat?"))
        }

        // --- RAMEN / PHO broth ---
        if text.contains("bone") && (text.contains("boil") || text.contains("simmer")) {
            results.append(("drop", "My broth isn't milky", "The ramen broth is supposed to be milky/white but mine looks clear. What am I doing wrong?"))
        }

        if text.contains("impurities") || text.contains("scum") || (text.contains("discard") && text.contains("water") && text.contains("bone")) {
            results.append(("questionmark.circle", "Why boil and discard?", "Why do I need to boil the bones first and throw away the water? Can I skip this step?"))
        }

        // Charring / charred (pho)
        if text.contains("char") {
            results.append(("flame", "How charred should it be?", "How black should the charring be? I don't want to make it taste burned."))
        }

        // --- DEEP FRYING ---
        if text.contains("deep fry") || text.contains("deep-fry") || (text.contains("oil") && text.contains("fry") && (text.contains("°") || text.contains("submerge"))) {
            results.append(("thermometer.medium", "How do I check oil temp?", "I don't have a thermometer. How can I tell if the oil is hot enough for frying?"))
            results.append(("exclamationmark.triangle", "Oil is splattering", "The oil is popping and splattering a lot. Is that normal? How do I fry safely?"))
        }

        // Dredging / breading (piccata, schnitzel, eggplant parm)
        if text.contains("dredge") || (text.contains("flour") && (text.contains("dip") || text.contains("coat"))) {
            results.append(("questionmark.circle", "One hand or two?", "How do I bread this without making a huge mess? Any technique to keep my hands clean?"))
        }

        // Breadcrumb coating
        if text.contains("breadcrumb") || text.contains("coat with") {
            results.append(("hand.raised", "Coating falling off", "The breading keeps falling off when I cook it. How do I make it stick better?"))
        }

        // Layering (lasagna, eggplant parm)
        if text.contains("layer") && (text.contains("noodle") || text.contains("eggplant") || text.contains("sauce") || text.contains("cheese")) {
            results.append(("list.bullet", "Does the order matter?", "Does the order of the layers matter? What should go on the bottom vs the top?"))
        }

        // --- SUSHI ---
        if text.contains("sushi") || text.contains("nori") {
            results.append(("hand.raised", "Rice sticking to hands", "The sushi rice is sticking to my hands and everything. How do I work with it without making a mess?"))
        }

        if text.contains("roll") && (text.contains("sushi") || text.contains("nori") || text.contains("bamboo")) {
            results.append(("questionmark.circle", "It's falling apart", "My sushi roll is falling apart when I cut it. How do I roll it tighter?"))
        }

        // --- SCALLOPS / SHRIMP searing ---
        if text.contains("scallop") && (text.contains("sear") || text.contains("cook")) {
            results.append(("hand.raised", "Pat them dry?", "Do I need to pat the scallops dry first? Mine aren't getting a good sear."))
        }

        if text.contains("shrimp") && (text.contains("pink") || text.contains("cook")) {
            results.append(("eye", "How pink is done?", "How do I know when the shrimp are done? I don't want to overcook them — they turn rubbery."))
        }

        // --- REDUCING SAUCE ---
        if text.contains("reduce") && (text.contains("sauce") || text.contains("stock") || text.contains("liquid")) {
            results.append(("eye", "How thick should it get?", "How do I know when the sauce has reduced enough? Is there a test I can do?"))
        }

        return results
    }

    // MARK: - Keyword-Level Suggestions (broader category matching)

    /// Broader keyword matching for general cooking categories.
    private func keywordSuggestions(for text: String) -> [(icon: String, label: String, query: String)] {
        var results: [(icon: String, label: String, query: String)] = []

        // Baking / oven
        if text.contains("bake") || text.contains("oven") || text.contains("preheat") {
            if text.contains("preheat") {
                results.append(("thermometer.medium", "Does rack position matter?", "Which oven rack should I use for this recipe and does it matter?"))
            } else {
                results.append(("eye", "How do I tell when it's done?", "What should I look for to know when this is done baking? Color, texture, or any test I can do?"))
            }
        }
        // Kneading / dough
        if text.contains("knead") || text.contains("elastic") {
            results.append(("hand.raised", "How should the dough feel?", "How do I know if I've kneaded enough? What should the dough look and feel like when it's ready?"))
        }
        // Rising / proofing
        if text.contains("rise") || text.contains("proof") || text.contains("doubled") {
            results.append(("clock", "My dough isn't rising", "It's been a while and my dough doesn't seem to be rising. What could be wrong and can I fix it?"))
        }
        // Sauté / brown / sear
        if text.contains("sauté") || text.contains("saute") || text.contains("sear") {
            results.append(("flame", "Is my pan hot enough?", "How do I know when the pan is hot enough to start? Any quick test I can do?"))
        }
        // Simmer
        if text.contains("simmer") && !text.contains("hour") {
            results.append(("flame", "What does a simmer look like?", "I'm not sure if this is simmering or boiling. What should the bubbles look like?"))
        }
        // Whisk / beat (generic — not peaks-specific)
        if text.contains("whisk") || text.contains("beat") {
            if !text.contains("egg white") && !text.contains("cream") {
                results.append(("arrow.triangle.2.circlepath", "How long should I whisk?", "How do I know when I've whisked this enough? What should the texture look like?"))
            }
        }
        // Chop / dice / slice
        if text.contains("chop") || text.contains("dice") || text.contains("slice") || text.contains("mince") {
            results.append(("scissors", "What size pieces?", "How big or small should I cut these? Does the size affect cooking?"))
        }
        // Season / salt
        if text.contains("season") || (text.contains("salt") && text.contains("pepper")) {
            results.append(("leaf", "How much should I add?", "How much seasoning should I add? Is there a guideline or should I taste as I go?"))
        }
        // Fold (generic)
        if text.contains("fold") && !text.contains("cream") && !text.contains("egg white") {
            results.append(("arrow.uturn.down", "What does folding mean?", "How is folding different from mixing? What motion should I use so I don't deflate the mixture?"))
        }
        // Stretch / roll
        if text.contains("stretch") || (text.contains("roll") && !text.contains("spring roll") && !text.contains("sushi")) {
            results.append(("hand.point.up", "It keeps shrinking back", "I'm trying to stretch/roll this but it keeps pulling back. What should I do?"))
        }
        // Serve / plate
        if text.contains("serve") || text.contains("plate") || text.contains("garnish") {
            results.append(("sparkles", "How to make it look nice?", "Any quick plating tips to make this look really good?"))
        }
        // Chill / cool (short durations)
        if text.contains("cool") && !text.contains("hour") && !text.contains("overnight") {
            results.append(("snowflake", "Can I speed this up?", "Is there a faster way to cool this without ruining the result?"))
        }
        // Marinate / rest
        if text.contains("marinat") || text.contains("let sit") {
            results.append(("clock", "Does the wait matter?", "What happens if I skip or shorten the marinating time? Will it really affect the taste?"))
        }
        // Grill
        if text.contains("grill") {
            results.append(("flame", "How hot should the grill be?", "How do I know when the grill is at the right temperature?"))
        }
        // Toast
        if text.contains("toast") && !text.contains("rice") {
            results.append(("flame", "How toasted is enough?", "How do I know when this is toasted enough? I don't want to burn it."))
        }
        // Assemble
        if text.contains("assemble") {
            results.append(("list.bullet", "What order do I layer?", "What's the right order to assemble everything?"))
        }
        // Rest meat
        if text.contains("rest") && (text.contains("meat") || text.contains("steak") || text.contains("chicken")) {
            results.append(("clock", "Why let it rest?", "Why does the meat need to rest? What happens inside when it sits?"))
        }
        // Blanch
        if text.contains("blanch") {
            results.append(("drop", "Why the ice bath?", "Why do I need ice water after boiling? Can I skip that?"))
        }

        return results
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            TypingDots()
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            Spacer()
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 6) {
            // Free-tier remaining-questions hint
            if !entitlement.isPro {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: usage.remainingToday > 0 ? "sparkles" : "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(usage.remainingToday > 0
                             ? "\(usage.remainingToday) free questions left today"
                             : "Daily limit reached — upgrade to Umami Pro")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(usage.remainingToday > 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.orange))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }

            inputField
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .padding(.top, 8)
    }

    private var inputField: some View {
        HStack(spacing: 8) {
            TextField("Ask about this step...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...3)
                .focused($isInputFocused)
                .submitLabel(.send)
                .contentShape(.interaction, Rectangle())
                .onSubmit { sendCurrentMessage() }

            Button(action: sendCurrentMessage) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(inputIsEmpty ? Color.secondary.opacity(0.25) : Color.orange)
                    )
            }
            .buttonStyle(SpatialButtonStyle(shape: Circle()))
            .hoverEffect(.highlight)
            .disabled(inputIsEmpty)
            .animation(.easeInOut(duration: 0.2), value: inputIsEmpty)
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private var inputIsEmpty: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Free-tier gate: once the daily AI question limit is reached, show the paywall
        // instead of sending the message to Gemini.
        guard usage.canAsk(isPro: entitlement.isPro) else {
            isInputFocused = false
            showPaywall = true
            return
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            messages.append(AIChatMessage(role: .user, text: trimmed))
        }
        inputText = ""

        withAnimation(.spring(response: 0.3)) { isTyping = true }

        Task {
            do {
                let context = buildChatContext()
                let history = buildConversationHistory()

                let result = try await GeminiService.shared.sendMessage(
                    userMessage: trimmed,
                    recipe: context,
                    conversationHistory: history
                )

                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) { isTyping = false }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        var msg = AIChatMessage(role: .assistant, text: result.text)
                        msg.usedFallbackModel = result.model.contains("lite")
                        messages.append(msg)
                    }
                    // Count a consumed free question (Pro users are unlimited).
                    if !entitlement.isPro { usage.recordQuestion() }
                    SoundPlayer.playSweesh()
                }
            } catch {
                await MainActor.run {
                    withAnimation(.spring(response: 0.3)) { isTyping = false }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        let errorText: String
                        if let geminiError = error as? GeminiError {
                            switch geminiError {
                            case .noAPIKey:
                                errorText = "The AI assistant isn't available right now. Please try again later."
                            case .rateLimited:
                                errorText = "Too many requests — try again in a minute."
                            default:
                                errorText = "Something went wrong: \(geminiError.localizedDescription)"
                            }
                        } else {
                            errorText = "Couldn't connect to the AI. Check your internet connection and try again."
                        }
                        messages.append(AIChatMessage(role: .assistant, text: errorText))
                    }
                }
            }
        }
    }

    private func sendCurrentMessage() { sendMessage(inputText) }

    // MARK: - Chat Context Builders

    private func buildChatContext() -> RecipeChatContext {
        let sortedSteps = recipe.steps.sorted { $0.order < $1.order }

        let ingredientsList = recipe.ingredients.map { ing in
            let qty = ing.quantity.map { "\($0)" } ?? ""
            let unit = ing.unit ?? ""
            return "\(qty) \(unit) \(ing.name)".trimmingCharacters(in: .whitespaces)
        }.joined(separator: "\n")

        let allStepsFormatted = sortedSteps.enumerated().map { i, step in
            "Step \(i + 1): \(step.text)"
        }.joined(separator: "\n")

        let completedSteps = sortedSteps.prefix(currentStepIndex).map { "Step \($0.order + 1): \($0.text)" }
        let upcomingSteps = sortedSteps.dropFirst(currentStepIndex + 1).map { "Step \($0.order + 1): \($0.text)" }

        return RecipeChatContext(
            title: recipe.title,
            totalTimeMinutes: recipe.totalTimeMinutes,
            difficulty: recipe.difficulty,
            servings: recipe.defaultServings,
            ingredientsList: ingredientsList,
            allStepsFormatted: allStepsFormatted,
            currentStepNumber: currentStepIndex + 1,
            totalSteps: totalSteps,
            currentStepText: currentStep?.text,
            currentStepTimerSec: currentStep?.durationSec,
            completedSteps: completedSteps,
            upcomingSteps: upcomingSteps
        )
    }

    /// Converts chat messages into ChatTurn history for the API.
    /// Limited to last 5 messages (excluding the current user message) for context window efficiency.
    private func buildConversationHistory() -> [ChatTurn] {
        // Exclude the last message since it's the current user message we just appended
        let historyMessages = messages.dropLast()
        // Keep only the last 5 messages for history
        let recentHistory = historyMessages.suffix(5)
        return recentHistory.map { msg in
            ChatTurn(
                role: msg.role == .user ? "user" : "model",
                text: msg.text
            )
        }
    }
}

// MARK: - Message Row

private struct MessageRow: View {
    let message: AIChatMessage
    private var isUser: Bool { message.role == .user }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
            HStack {
                if isUser { Spacer(minLength: 48) }

                Text(message.text)
                    .font(.system(size: 14))
                    .lineSpacing(3)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        if isUser {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.orange)
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(.ultraThinMaterial)
                        }
                    }

                if !isUser { Spacer(minLength: 48) }
            }

            if !isUser && message.usedFallbackModel {
                Text("Lite model — response quality may be lower")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 14)
            }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Suggestion Button

private struct SuggestionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var isHovered: Bool = false
    private let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                    .frame(width: 20)

                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isHovered ? .secondary : .quaternary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                shape
                    .fill(.ultraThinMaterial)
                    .opacity(isHovered ? 1.0 : 0.8)
            )
            .overlay(
                shape
                    .stroke(.white.opacity(isHovered ? 0.25 : 0.08), lineWidth: isHovered ? 1.5 : 0.5)
            )
            .shadow(color: isHovered ? .orange.opacity(0.15) : .clear, radius: 8, x: 0, y: 4)
            .clipShape(shape)
            .contentShape(.hoverEffect, shape)
        }
        .buttonStyle(SpatialButtonStyle(shape: shape))
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .polishedHover(scale: 1.04)
    }
}

// MARK: - Typing Dots

private struct TypingDots: View {
    @State private var animate: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 5, height: 5)
                    .scaleEffect(animate ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
    }
}
