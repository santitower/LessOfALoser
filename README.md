# Health Insight

Health Insight is a standalone iPhone app that turns authorized Apple Health data into a daily
three-star wellness score, a seven-day summary, and private on-device coaching. The League tab is
currently a clearly local product preview; production accounts and shared standings will be added
on the separate `codex/health-insight-production` branch.

## What stays private

- Steps, active energy, and sleep samples are read directly from HealthKit.
- Exact measurements stay on the iPhone.
- Apple Foundation Models runs on-device when it is available.
- A deterministic coach remains available when Apple Intelligence is unavailable.
- No backend or secret is required to build and run the current app.

## Requirements

- macOS with the full Xcode 26 or newer application installed
- iOS 26 SDK
- An iOS 26+ simulator for UI testing
- A physical iPhone for real HealthKit measurements
- An Apple Developer team only when installing on a physical device

This repository no longer needs a sibling `coreai-models` checkout or a separately downloaded
Qwen model bundle.

## Open and run

1. Open `HealthInsight.xcodeproj` in Xcode.
2. Select the `HealthInsight` scheme.
3. Choose an iOS 26+ simulator and press Run for a UI smoke test.
4. For real data, select your Apple Developer team in Signing & Capabilities, choose a physical
   iPhone, run the app, and approve the Health permissions.

The simulator normally has no Health history. Zero values there do not indicate a production data
problem; validate HealthKit behavior on a physical iPhone with test data you control.

## Automated checks

Run:

```sh
./scripts/validate-project.sh
```

The script always checks standalone dependency boundaries, property lists, and the portable scoring
tests. When a full Xcode installation is active, it also parses every app source file and performs
an unsigned iOS Simulator build.

If `xcodebuild` reports that the active developer directory is Command Line Tools, install Xcode
and either select it in Xcode Settings or run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Current production boundary

The League screen uses sample people and does not contact a server yet. Do not present it as a live
leaderboard. The production backend will sync only weekly star totals, streak, and profile metadata;
it will not receive exact HealthKit measurements.
