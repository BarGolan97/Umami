/**
 * RecipeApp — AI proxy (Cloudflare Worker)
 *
 * Purpose: keep the AI provider's API key OFF the client, AND keep the app
 * provider-agnostic. The app sends a NEUTRAL request; this Worker translates it
 * to the current backend (Gemini), handles model selection + rate-limit
 * fallback, and translates the answer back to the neutral format.
 *
 * Swapping models — or even swapping to a different provider (e.g. Claude,
 * OpenAI) — is a change to THIS FILE ONLY. The app never needs updating.
 *
 * ── Neutral request the app sends (POST /chat) ──
 *   {
 *     "system": "system prompt string",
 *     "messages": [ { "role": "user" | "assistant", "text": "..." }, ... ],
 *     "temperature": 0.7,
 *     "maxTokens": 4096,
 *     "topP": 0.9
 *   }
 *
 * ── Neutral response the app expects ──
 *   { "text": "assistant reply", "model": "gemini-2.5-flash" }
 *
 * Deploy:
 *   1. npm i -g wrangler
 *   2. cd Proxy && wrangler login
 *   3. wrangler secret put GEMINI_API_KEY   (paste the NEW restricted key)
 *   4. wrangler deploy
 *   5. Put the deployed URL in SecretsManager.geminiProxyBaseURL in the app.
 */

// Models tried in order. First is primary; the rest are fallbacks on rate limit.
const MODEL_CHAIN = ["gemini-2.5-flash", "gemini-2.5-flash-lite"];
const MAX_RETRIES_PER_MODEL = 2;
const RETRY_DELAY_MS = 2000;

const GOOGLE_BASE = "https://generativelanguage.googleapis.com/v1beta/models";

export default {
    async fetch(request, env) {
        if (request.method !== "POST") {
            return json({ error: "Method not allowed" }, 405);
        }

        const url = new URL(request.url);
        if (url.pathname !== "/chat") {
            return json({ error: "Not found" }, 404);
        }

        if (!env.GEMINI_API_KEY) {
            return json({ error: "Proxy not configured" }, 500);
        }

        // OPTIONAL HARDENING (recommended before wide release): verify Apple App
        // Attest so only the genuine app can call this endpoint. See README.md.
        // const attestation = request.headers.get("X-App-Attest");

        let neutral;
        try {
            neutral = await request.json();
        } catch {
            return json({ error: "Invalid JSON" }, 400);
        }

        if (!Array.isArray(neutral.messages) || neutral.messages.length === 0) {
            return json({ error: "messages required" }, 400);
        }

        return await callGemini(neutral, env.GEMINI_API_KEY);
    },
};

// ── Gemini backend adapter ───────────────────────────────────────────────────
// To switch providers later, replace this function with e.g. callClaude(...) and
// its own translation. The neutral <-> vendor mapping is isolated right here.

async function callGemini(neutral, apiKey) {
    const geminiBody = neutralToGemini(neutral);

    for (let m = 0; m < MODEL_CHAIN.length; m++) {
        const model = MODEL_CHAIN[m];
        const isLastModel = m === MODEL_CHAIN.length - 1;

        for (let attempt = 0; attempt < MAX_RETRIES_PER_MODEL; attempt++) {
            const isLastAttempt = attempt === MAX_RETRIES_PER_MODEL - 1;

            let resp;
            try {
                resp = await fetch(`${GOOGLE_BASE}/${model}:generateContent`, {
                    method: "POST",
                    headers: {
                        "Content-Type": "application/json",
                        "x-goog-api-key": apiKey,
                    },
                    body: JSON.stringify(geminiBody),
                });
            } catch {
                return json({ error: "Upstream request failed" }, 502);
            }

            if (resp.status === 200) {
                const data = await resp.json();
                const text = geminiToText(data);
                if (text === null) {
                    return json({ error: "Empty response from model" }, 502);
                }
                return json({ text, model }, 200);
            }

            if (resp.status === 429) {
                // Rate limited: retry this model, then fall back to the next.
                if (!isLastAttempt) {
                    await sleep(RETRY_DELAY_MS);
                    continue;
                }
                if (!isLastModel) break; // move to fallback model
                return json({ error: "Rate limit exceeded" }, 429);
            }

            // Any other error: surface it, don't retry.
            const bodyText = await resp.text();
            return json({ error: `Upstream error: ${bodyText}` }, resp.status);
        }
    }

    return json({ error: "Rate limit exceeded" }, 429);
}

// Neutral -> Gemini request shape.
function neutralToGemini(neutral) {
    const contents = neutral.messages.map((msg) => ({
        // Gemini uses "user" / "model"; neutral uses "user" / "assistant".
        role: msg.role === "assistant" ? "model" : "user",
        parts: [{ text: msg.text ?? "" }],
    }));

    const body = {
        contents,
        generationConfig: {
            temperature: neutral.temperature ?? 0.7,
            maxOutputTokens: neutral.maxTokens ?? 4096,
            topP: neutral.topP ?? 0.9,
        },
    };

    if (neutral.system) {
        body.system_instruction = { parts: [{ text: neutral.system }] };
    }

    return body;
}

// Gemini response -> plain text (or null if none).
function geminiToText(data) {
    const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
    return typeof text === "string" ? text.trim() : null;
}

// ── helpers ──────────────────────────────────────────────────────────────────

function json(obj, status) {
    return new Response(JSON.stringify(obj), {
        status,
        headers: { "Content-Type": "application/json" },
    });
}

function sleep(ms) {
    return new Promise((r) => setTimeout(r, ms));
}
