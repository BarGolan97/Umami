# AI Chef Assistant - UI Design Plan

## Overview
Add a premium AI cooking assistant to CookingView as a trailing ornament that floats beside the cooking window in 3D space on Vision Pro.

## Design Concept
- **Collapsed state**: Small glass pill on the right edge with sparkle icon + "AI Chef"
- **Expanded state**: 380x520 chat panel with header, quick questions, messages, input bar
- **No AI backend** - mock responses only, ready for future Gemini integration

## What Gets Created

### New File: `AICookingAssistantView.swift`
Contains all AI assistant UI:
- `AIChatMessage` - chat message model (role: user/assistant, text, timestamp)
- `QuickQuestion` - quick question model (icon, text, query)
- `AICookingAssistantView` - main view with collapsed pill ↔ expanded panel
- `ChatBubbleView` - message bubbles (orange for user, glass material for AI)
- `TypingIndicatorView` - three animated bouncing dots
- Welcome state with sparkle icon and contextual greeting
- Quick questions strip - contextual suggestions based on current step
- Text input bar with send button (capsule + orange send circle)
- Mock response generator (placeholder for future AI backend)

### Modified File: `CookingView.swift` (2 small changes)
1. Add `@State private var isAIChatExpanded` state variable
2. Add trailing `.ornament()` with `AICookingAssistantView`

## Design Details

### Matches Existing Design Language
- Same cornerRadius (28pt), shadowRadius (20pt)
- Orange accent color throughout
- `.glassBackgroundEffect`, `.ultraThinMaterial`, `.regularMaterial`
- White gradient stroke borders
- `.hoverEffect(.highlight)` on all interactive elements
- Spring animations matching existing curves
- `.symbolEffect(.pulse)` on sparkle icon
- `SoundPlayer.playPop()` on AI response received

### Chat Bubbles
- **User messages**: Orange gradient, right-aligned, white text
- **AI messages**: Glass material (ultraThinMaterial), left-aligned, primary text
- Timestamp below each bubble

### Quick Questions (contextual per step)
- "Explain this step" (always shown)
- "How do I know when it's done?" (shown when step has duration)
- "What temperature?"
- "Substitutions"
- "Common mistakes"

### Interaction Flow
1. User sees small "AI Chef" pill floating on trailing edge
2. Tap → expands to full chat panel with spring animation
3. Content fades in with stagger (header → questions → messages → input)
4. User taps quick question or types custom question
5. User message appears as orange bubble
6. Typing indicator shows (3 bouncing dots)
7. Mock AI response appears after 1.5s delay
8. Tap X → content fades out, panel collapses back to pill

### Vision Pro Specifics
- Trailing ornament = floats in 3D space beside the window
- User looks left (instructions), center (timer), right (AI)
- Quick questions = one-tap, minimal typing for messy hands
- Sensory feedback on new messages
