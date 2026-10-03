import Foundation

/// Configuration for reaching the Gemini proxy.
///
/// IMPORTANT: The Gemini API key is NOT stored in the app anymore. It lives on
/// the proxy server (see `Proxy/` in the repo). The app only knows the public
/// proxy URL, which is not a secret.
enum SecretsManager {

    /// Base URL of the Gemini proxy Worker (no trailing slash).
    /// Set this to the URL printed by `wrangler deploy`.
    /// Example: "https://recipeapp-gemini-proxy.your-subdomain.workers.dev"
    nonisolated static let geminiProxyBaseURL = "https://recipeapp-gemini-proxy.climbingusto.workers.dev"
}
