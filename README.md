# 🍳 Umami — Spatial Recipe App for Apple Vision Pro

**An immersive cooking experience: pin your ingredients, steps and timers exactly where you need them in your kitchen, and ask an AI chef anything along the way.**

[**Download on the App Store**](https://apps.apple.com/us/app/umamai-spatial-recipe-app/id6759262245)

---

## ✨ Features

- **Spatial recipe canvas**: pin the ingredient list next to the fridge, float the steps above the stove, and place timers over your pots and pans
- **Hands-free control**: navigate recipes, start timers and check off ingredients with a look and a pinch, with no messy screens
- **AI chef assistant**: an "Ask me anything" panel powered by Gemini that understands which recipe step you're on
- **Dynamic timers** placed in your space
- **Premium recipe library** with high-fidelity photography, designed for the spatial experience

---

## 🛠️ Built With

- **Swift** · **SwiftUI** · **visionOS**
- **AI:** Google Gemini, called through a Cloudflare Worker proxy so no API key ships inside the app (see [`Proxy/`](Proxy/))
- **Distribution:** App Store Connect

---

## 🤖 How It Was Built

Umami was co-created by **Bar Golan** ([@BarGolan97](https://github.com/BarGolan97)) and **Yonatan Golestany** ([@climbingusto](https://github.com/climbingusto)) using **AI-assisted development**, primarily with **Claude Code**, alongside ChatGPT and Gemini.

We handled the full product cycle together:
- Designing the concept, features and spatial user experience
- Directing the AI through implementation and refining its output
- Testing, debugging and iterating on Apple Vision Pro
- Preparing and publishing the app on the App Store

---

## ▶️ Running the Project

1. Open `RecipeApp.xcodeproj` in **Xcode** (with the visionOS SDK installed)
2. To use the AI chef with your own key, deploy the proxy in [`Proxy/`](Proxy/) and set its URL in `RecipeApp/SecretsManager.swift`
3. Select the **Apple Vision Pro** simulator or a connected device
4. Press **Run** (⌘R)
