import Foundation

// MARK: - AI Cooking Assistant Service
//
// The app speaks a PROVIDER-NEUTRAL format to our proxy — it does not know or
// care which model or vendor answers. The proxy (see Proxy/) holds the API key,
// picks the model, handles fallback/retries, and translates to whatever backend
// is in use (currently Gemini). Swapping to another Gemini model — or even to a
// different provider like Claude — is a proxy-only change; the app is unchanged.
//
// The type is still named GeminiService for now to avoid churn at the call site.

actor GeminiService {
    static let shared = GeminiService()

    /// Base URL of our proxy. No API key is ever embedded in the app.
    private let proxyBaseURL = SecretsManager.geminiProxyBaseURL

    private let requestTimeout: TimeInterval = 30

    /// Neutral chat endpoint on the proxy.
    private var chatURL: String { "\(proxyBaseURL)/chat" }

    // MARK: - Public API

    /// Sends a cooking-context-aware message and returns the response text.
    /// Model selection and rate-limit fallback happen inside the proxy; the
    /// returned `model` string simply reports which model actually answered.
    func sendMessage(
        userMessage: String,
        recipe: RecipeChatContext,
        conversationHistory: [ChatTurn]
    ) async throws -> (text: String, model: String) {
        // Make sure the proxy URL has been configured.
        guard !proxyBaseURL.contains("REPLACE-WITH-YOUR-WORKER-URL") else {
            throw GeminiError.noAPIKey
        }

        let systemPrompt = buildSystemPrompt(recipe: recipe)
        let request = try buildRequest(
            systemPrompt: systemPrompt,
            history: conversationHistory,
            userMessage: userMessage
        )

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        if httpResponse.statusCode == 200 {
            return try parseResponse(data: data)
        }

        if httpResponse.statusCode == 429 {
            throw GeminiError.rateLimited
        }

        let body = String(data: data, encoding: .utf8) ?? "No body"
        throw GeminiError.apiError(statusCode: httpResponse.statusCode, message: body)
    }

    // MARK: - System Prompt Builder

    private func buildSystemPrompt(recipe: RecipeChatContext) -> String {
        var prompt = """
        You are a professional cooking assistant integrated into a recipe app. You help the user while they cook.

        RULES:
        - Be concise and practical. No fluff, no filler phrases.
        - Answer in the same language the user writes in.
        - Default to 2-4 sentences. Straight to the point.
        - BUT if the question genuinely requires a longer answer (technique explanation, troubleshooting, multi-part question, or a list of tips), give a FULL and COMPLETE response. Do NOT truncate, summarize early, or stop mid-thought. It is better to give a thorough answer than to cut yourself short.
        - NEVER start with phrases like "Great question!", "That's a wonderful question!", "Absolutely!", or any similar empty validation. Jump straight into the answer.
        - You know the full recipe context below. Use it to give precise answers.
        - When referencing steps, use their number (e.g. "step 3").
        - If the user asks about a technique, explain it specifically for THIS recipe, not generically.
        - If the user makes a mistake, help them recover practically - don't just say "start over".
        - Be professional and direct. Like a calm, experienced chef standing next to them.

        RECIPE: "\(recipe.title)"
        Total time: \(recipe.totalTimeMinutes) min | Difficulty: \(recipe.difficulty) | Servings: \(recipe.servings)

        INGREDIENTS:
        \(recipe.ingredientsList)

        ALL STEPS:
        \(recipe.allStepsFormatted)

        CURRENT POSITION: Step \(recipe.currentStepNumber) of \(recipe.totalSteps)
        """

        if let currentText = recipe.currentStepText {
            prompt += "\nCURRENT STEP TEXT: \"\(currentText)\""
        }

        if let timer = recipe.currentStepTimerSec {
            prompt += "\nThis step has a timer: \(timer / 60) minutes (\(timer) seconds)"
        }

        if !recipe.completedSteps.isEmpty {
            prompt += "\nCOMPLETED STEPS: \(recipe.completedSteps.joined(separator: ", "))"
        }

        if !recipe.upcomingSteps.isEmpty {
            prompt += "\nUPCOMING STEPS: \(recipe.upcomingSteps.joined(separator: ", "))"
        }

        return prompt
    }

    // MARK: - Request Builder

    /// Builds the provider-neutral request body sent to the proxy.
    private func buildRequest(
        systemPrompt: String,
        history: [ChatTurn],
        userMessage: String
    ) throws -> URLRequest {
        var messages: [[String: Any]] = []

        // Conversation history — normalize roles to the neutral "user"/"assistant".
        for turn in history {
            let role = (turn.role == "model") ? "assistant" : "user"
            messages.append(["role": role, "text": turn.text])
        }

        // Current user message
        messages.append(["role": "user", "text": userMessage])

        let body: [String: Any] = [
            "system": systemPrompt,
            "messages": messages,
            "temperature": 0.7,
            "maxTokens": 4096,
            "topP": 0.9
        ]

        guard let url = URL(string: chatURL) else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = requestTimeout

        return request
    }

    // MARK: - Response Parser

    /// Parses the neutral proxy response: { "text": "...", "model": "..." }
    private func parseResponse(data: Data) throws -> (text: String, model: String) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = json["text"] as? String else {
            throw GeminiError.parsingFailed
        }
        let model = json["model"] as? String ?? "unknown"
        return (text: text.trimmingCharacters(in: .whitespacesAndNewlines), model: model)
    }
}

// MARK: - Supporting Types

struct RecipeChatContext {
    let title: String
    let totalTimeMinutes: Int
    let difficulty: String
    let servings: Int
    let ingredientsList: String
    let allStepsFormatted: String
    let currentStepNumber: Int
    let totalSteps: Int
    let currentStepText: String?
    let currentStepTimerSec: Int?
    let completedSteps: [String]
    let upcomingSteps: [String]
}

struct ChatTurn {
    let role: String  // "user" or "model"
    let text: String
}

enum GeminiError: LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parsingFailed
    case noAPIKey
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let code, let msg):
            return "API error (\(code)): \(msg)"
        case .parsingFailed:
            return "Failed to parse AI response"
        case .noAPIKey:
            return "AI service is not configured yet"
        case .rateLimited:
            return "Rate limit exceeded"
        }
    }
}
