# Personal AI integration boundary

The **Ask** tab is the conversational surface for private, personalized insights. It is intentionally separate from the Today dashboard and Wellness League so a model-runtime PR can evolve without coupling model loading to either feature.

## Current flow

```text
PersonalAssistantView
    -> PersonalAssistantViewModel
        -> PersonalModelRuntime protocol
            -> custom Core AI model, when bundled
            -> Apple SystemLanguageModel, when available
        -> PersonalInsightEngine when no model can answer
```

The conversation receives a versioned `PersonalModelContext` with each user turn. Version 2 contains one `WellnessInsightContext` produced by the platform-independent insight engine: aggregate trends, explicit daily goal states, the current weekly score, the user's selected focus, and record provenance. It does not contain raw HealthKit samples, Screen Time app identities, domains, or activity events. Missing measurements remain `unavailable` rather than becoming zeros or failed goals.

The custom and Apple model paths use a stateful `LanguageModelSession`, so the model can follow the current in-memory conversation. The newest verified aggregate context is included on every turn to avoid treating an older turn's measurements as current. The app does not persist chat history; starting a new conversation or terminating the app clears it.

Computer Coach is deliberately not part of this screen. The existing gateway accepts a fixed daily-brief schema and rejects arbitrary prompts. Keeping Personal AI on-device preserves that security contract rather than silently broadening it.

## Runtime contract for an incoming PR

An optimized model implementation should conform to `PersonalModelRuntime` in `PhoneLLM/PersonalModelRuntime.swift`:

```swift
protocol PersonalModelRuntime: Sendable {
    func prepare() async -> PersonalModelReadiness
    func respond(
        to prompt: String,
        context: PersonalModelContext
    ) async throws -> PersonalModelResponse
    func reset() async
}
```

This boundary leaves the incoming implementation responsible for model readiness, inference, conversation state, and cancellation behavior. The existing view model remains responsible for input limits, UI state, and a deterministic fallback.

A merge should preserve these invariants:

1. Inference for the Ask tab remains on-device unless the product adds a separate, explicit consent and transport design.
2. Only reviewed fields in versioned `PersonalModelContext` cross the model boundary; no raw samples or Screen Time identities are added.
3. Missing data is treated as unknown.
4. Responses do not diagnose, predict disease, claim causation, recommend medication or supplements, or assess emergencies.
5. The runtime reports its real source and does not label deterministic text as model-generated.
6. Reset creates a genuinely new model session and discards the old transcript.
7. Model failure falls back safely and never blocks the rest of the app.

## What the earlier Core AI proof-of-concept contributes

The referenced `cmedipally7/iOSCoreMLPOC` repository validates three useful mechanics:

- locating the exported resource folder through `metadata.json`;
- constructing `CoreAILanguageModel` and passing it to `LanguageModelSession`; and
- retaining that session across prompts.

This repository already has the proof-of-concept's separate `.aimodel` copy workaround in the Core AI Xcode scheme. Its button-based test screen is therefore not imported; the Ask tab supplies the production-facing state and privacy boundaries that the proof-of-concept intentionally does not cover.

## Remaining production work

- Stream tokens into the current assistant bubble when the selected runtime supports streaming.
- Add explicit cancellation and thermal/memory-pressure handling for long generations.
- Decide whether model assets ship in the app or through a reviewed asset-delivery flow, including integrity and license checks.
- Evaluate the tuned model against wellness safety, unsupported questions, prompt injection, missing data, and long conversations on every supported device class.
- Add an accessible, user-controlled history design before persisting any conversation.
