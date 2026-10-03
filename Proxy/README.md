# RecipeApp — AI Proxy

This folder is the **server** that sits between the app and the AI provider. It
keeps the API key off the app and makes it easy to change models or even switch
providers later — without shipping a new app version.

If you only read one section, read **"How it works"** and **"How to change
things later"**.

---

## Why this exists

Any API key shipped inside the app binary can be extracted by anyone who
downloads the app. The only real fix is to keep the key on a server you control.
As a bonus, the server also lets you:

- swap the AI model or provider without an app update,
- rotate/revoke the key instantly,
- rate-limit and monitor usage.

---

## How it works

```
  iOS/visionOS app                Cloudflare Worker (this folder)          Google
 ┌────────────────┐   neutral    ┌──────────────────────────────┐  Gemini ┌────────┐
 │ GeminiService  │ ───JSON────▶ │ worker.js                    │ ───────▶│ Gemini │
 │ (Swift)        │   POST /chat │  • holds GEMINI_API_KEY       │  API    │  API   │
 │                │ ◀──JSON──── │  • picks model + fallback     │ ◀───────│        │
 └────────────────┘  {text,model}│  • translates neutral↔Gemini │         └────────┘
                                  └──────────────────────────────┘
```

- The app speaks a **provider-neutral** format — it does NOT know the word
  "Gemini", the model name, or any key.
- The Worker is the only place that knows the provider. All Gemini-specific code
  is isolated in three functions in `worker.js`: `callGemini`, `neutralToGemini`,
  `geminiToText`.

### The neutral format (contract between app and server)

Request the app sends — `POST {proxyBaseURL}/chat`:

```json
{
  "system": "system prompt string",
  "messages": [ { "role": "user" | "assistant", "text": "..." } ],
  "temperature": 0.7,
  "maxTokens": 4096,
  "topP": 0.9
}
```

Response the app expects:

```json
{ "text": "assistant reply", "model": "gemini-2.5-flash" }
```

Errors return a non-200 status with `{ "error": "..." }`. A `429` tells the app
it was rate-limited.

---

## Current live setup (as deployed 2026-09-13)

| Thing | Value |
|---|---|
| Worker name | `recipeapp-gemini-proxy` |
| Live URL | `https://recipeapp-gemini-proxy.climbingusto.workers.dev` |
| Endpoint | `POST /chat` |
| Secret (server-side) | `GEMINI_API_KEY` — set as an encrypted **Secret** in the Worker |
| Models used | `gemini-2.5-flash` (primary), `gemini-2.5-flash-lite` (fallback on 429) |
| App wiring | `RecipeApp/SecretsManager.swift` → `geminiProxyBaseURL` |
| App request/parse code | `RecipeApp/GeminiService.swift` |

The Gemini API key itself is **only** in the Worker's Secret — never in this
repo, never in the app.

---

## How to edit the Worker (dashboard, no tools to install)

1. Go to https://dash.cloudflare.com → **Compute → Workers & Pages**.
2. Click `recipeapp-gemini-proxy` → **Edit code**.
3. Make your change (or paste an updated `worker.js`), then **Deploy**.

Always keep this repo's `worker.js` as the source of truth — paste from here so
the file and the live Worker stay in sync.

Test after any change (should return `{"text":"...","model":"..."}`):

```bash
curl -X POST \
  "https://recipeapp-gemini-proxy.climbingusto.workers.dev/chat" \
  -H "Content-Type: application/json" \
  -d '{"messages":[{"role":"user","text":"say hi"}]}'
```

---

## How to change things later  ⭐

### 1. Change the Gemini model (e.g. to a newer Gemini)
Edit `MODEL_CHAIN` at the top of `worker.js`. First entry = primary, the rest =
fallbacks tried on rate limit. Deploy. **No app change needed.**

```js
const MODEL_CHAIN = ["gemini-3-flash", "gemini-2.5-flash"];
```

### 2. Change AI behaviour (temperature, length, etc.)
Defaults live in the app in `GeminiService.buildRequest` (temperature, maxTokens,
topP). The Worker just passes them through (`neutralToGemini`). Change them in the
app if you want new defaults, or hard-code overrides in `neutralToGemini`.

The system prompt (the assistant's personality/rules) lives in the app:
`GeminiService.buildSystemPrompt`.

### 3. Switch to a different provider (Claude, OpenAI, …)
This is a **Worker-only change** — the app is untouched, so even existing
installed apps get the new provider immediately.

In `worker.js`:
1. Add a new secret in the dashboard, e.g. `ANTHROPIC_API_KEY`.
2. Write a `callClaude(neutral, apiKey)` that:
   - translates the neutral request to that provider's format,
   - calls the provider's endpoint with the key,
   - returns `{ text, model }` in the neutral format.
3. In `fetch`, call your new function instead of `callGemini`.

The neutral↔vendor translation is deliberately isolated so only this one adapter
changes. For Claude, the latest models are Opus 4.8 / Sonnet 4.6 / Haiku 4.5;
see https://docs.anthropic.com for the Messages API shape.

### 4. Rotate / replace the API key
Dashboard → Worker → **Settings → Variables and Secrets** → edit `GEMINI_API_KEY`
→ Deploy. No app change.

### 5. Change the Worker URL
If you rename/recreate the Worker, update `geminiProxyBaseURL` in
`RecipeApp/SecretsManager.swift`, rebuild, and ship an app update.

---

## Deploy from scratch (if you ever recreate the Worker)

### Option A — Dashboard, no install
1. https://dash.cloudflare.com → **Compute → Workers & Pages → Create → Workers**.
2. Name it `recipeapp-gemini-proxy` → **Deploy** (placeholder).
3. **Edit code** → paste all of `worker.js` → **Deploy**.
4. **Settings → Variables and Secrets → Add**: name `GEMINI_API_KEY`, type
   **Secret**, value = the restricted key → Deploy.
5. Put the Worker URL in `RecipeApp/SecretsManager.swift`.

### Option B — CLI (needs Node/npm)
```bash
npm i -g wrangler
cd Proxy
wrangler login
wrangler secret put GEMINI_API_KEY   # paste the restricted key
wrangler deploy
```

---

## Getting / restricting the Gemini key (Google)

1. Create a key at https://aistudio.google.com/apikey (or Google Cloud Console →
   APIs & Services → Credentials).
2. Restrict it: **API restrictions → only "Generative Language API"**.
3. If you ever enable billing, set a low **daily quota** in
   Google Cloud Console → Generative Language API → Quotas as a cost backstop.
   (On the free tier the cap is already fixed, so cost stays at $0.)

---

## Safe migration when shipping (retiring old keys)

The old app versions still contain the old embedded keys. To avoid breaking
users mid-cook:

1. Ship the proxy-based build.
2. Use `ForceUpdateManager` (CloudKit version gate) to require the update.
3. **Only then** revoke the old keys in Google:
    - all previously embedded Gemini keys (in AI Studio / Google Cloud Console).

---

## Optional hardening — App Attest (recommended before wide release)

Right now the `/chat` endpoint is open: anyone who finds the URL can call it
(bounded only by the Gemini quota). To ensure only the genuine app can use it,
add Apple **App Attest**:

- App: generate an assertion per request, send it in an `X-App-Attest` header.
- Worker: verify the assertion before forwarding; reject if invalid.

The verification hook is already stubbed in `worker.js` (see the comment in
`fetch`). Ask and we'll wire it up.
