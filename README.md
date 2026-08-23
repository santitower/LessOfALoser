# LessOfALoser

LessOfALoser is an iPhone prototype that combines Apple Health sleep and step data with a coarse Screen Time total, then generates a private daily wellness brief either on the phone or with a personal computer reached over Tailscale.

The architecture deliberately keeps measurement and language generation separate:

1. HealthKit and Device Activity provide user-authorized data.
2. Swift calculates daily values and recent baselines.
3. A deterministic rules layer creates a safe fallback.
4. A selected private model explains only the verified summary.

No personal health data belongs in this repository, and the starter contains no analytics or public cloud model integration.

## Included

- Read-only HealthKit authorization for sleep and steps
- Sleep interval de-duplication across overlapping samples
- Daily step totals using `HKStatisticsCollectionQuery`
- Individual Screen Time authorization with Family Controls
- Privacy-preserving `DeviceActivityReportExtension`
- Coarse daily Screen Time sharing through a local App Group container
- 28-day baseline comparisons in the platform-independent `WellnessCore` module
- On-device Foundation Models coaching with a deterministic fallback
- Optional iOS 27 Core AI target for an exported Qwen 2.5 1.5B model
- Optional Computer Coach using Tailscale HTTPS and Ollama on a personal computer
- In-app Quick Connect plus a one-tap `lessofaloser://connect` link
- Aggregate-only gateway validation, Tailscale identity checks, and safe automatic fallback
- Wellness League preview with weekly consistency points, rank movement, podiums, streaks, duels, and preset friend reactions
- Synthetic social profiles and a local-score toggle while the consent/account backend remains intentionally unimplemented
- Swift unit tests and a GitHub Actions workflow

## Requirements

- Xcode 26 or newer
- An iPhone running iOS 26 or newer
- An Apple Developer team for device signing
- An Apple Intelligence-compatible device with Apple Intelligence enabled for generated coaching
- Apple approval for the Family Controls distribution entitlement before App Store or TestFlight distribution

The optional custom-model build requires Xcode 27, iOS 27, and a separately exported Core AI model bundle. See [the Core AI integration guide](docs/CORE_AI.md).

An older iPhone can instead use a computer running Tailscale, Python 3, and Ollama. See [the Private Computer Coach guide](docs/REMOTE_COMPUTER.md).

The social competition tab is a local, synthetic-data UI prototype. See [the Wellness Leagues design and backend boundary](docs/SOCIAL_LEAGUES.md).

HealthKit and Device Activity should be tested on a physical iPhone. The deterministic `WellnessCore` package can be tested on macOS without Xcode.

## Generate and open the project

The repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the project file is reproducible.

```sh
brew install xcodegen
xcodegen generate
open LessOfALoser.xcodeproj
```

In Xcode:

1. Select your development team for the `PhoneLLM` and `ScreenTimeReport` targets.
2. Replace the `com.santitower` bundle prefix if you do not control it.
3. Register the `group.com.santitower.LessOfALoser` App Group for both targets.
4. Enable HealthKit on the app target.
5. Enable Family Controls on the app and report extension targets.
6. Build to a physical iPhone and grant Health and Screen Time access.

For distribution, request the Family Controls managed capability for both the app and report extension identifiers in the Apple Developer portal.

## Custom local model

The generated project contains two application schemes:

- `LessOfALoser` targets iOS 26 and uses Apple's on-device system model when available.
- `LessOfALoser-CoreAI` targets iOS 27 and first tries an exported Qwen model through Apple's `coreai-models` package.

The Qwen model is not committed to GitHub. Follow [docs/CORE_AI.md](docs/CORE_AI.md) to export and install it locally. If the model is missing or cannot load, the same build automatically falls back to Apple's system model and then to deterministic rules.

## Run core tests

```sh
swift test
```

## Privacy boundary

Screen Time is not a HealthKit database. Apple provides activity results inside a privacy-preserving report extension. This prototype stores only the aggregate number of daily activity minutes in a shared local App Group container. It does not persist app names, web domains, opaque application tokens, or raw activity events.

Before distributing this pattern, confirm it against the current Apple Developer Program terms and App Review requirements. A production version should include an accessible privacy policy, deletion controls, safety evaluations, and a formal review of its wellness claims.

## Safety boundary

LessOfALoser is general wellness software. It must not:

- diagnose or predict a condition;
- monitor emergencies;
- claim that Screen Time caused a sleep or activity change;
- recommend medication, supplement, or treatment changes;
- interpret missing data as a negative health signal.

Every model receives aggregated JSON facts rather than raw HealthKit samples. If a custom model is missing or refuses a request, the app tries the next local backend before displaying the deterministic fallback.

When Computer Coach is enabled, the same aggregate summary leaves the iPhone only through the user's private Tailscale network. The gateway does not accept raw HealthKit samples, Screen Time app identities, arbitrary prompts, or model tools.

## Project layout

```text
PhoneLLM/                 SwiftUI app, HealthKit client, local coach
ScreenTimeReport/         Device Activity report extension
desktop_gateway/          Aggregate-only Tailscale-to-Ollama gateway
Resources/CoreAI/         Local-only custom model resources (Git-ignored)
Sources/WellnessCore/     Shared models, trend engine, local snapshot store
Tests/WellnessCoreTests/  Platform-independent tests
docs/CORE_AI.md            Qwen/Core AI export and build instructions
docs/REMOTE_COMPUTER.md    Tailscale Computer Coach setup and security model
docs/SOCIAL_LEAGUES.md     Competition score, consent, and backend boundary
project.yml               XcodeGen project definition
```

## Useful Apple documentation

- [HealthKit](https://developer.apple.com/documentation/healthkit)
- [Sleep analysis](https://developer.apple.com/documentation/healthkit/hkcategoryvaluesleepanalysis)
- [Device Activity reports](https://developer.apple.com/documentation/deviceactivity/deviceactivityreportextension)
- [Family Controls entitlement](https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement)
- [Foundation Models](https://developer.apple.com/documentation/foundationmodels)
- [Apple Core AI Models](https://github.com/apple/coreai-models)

## Contributing

Group contributions are welcome. Create a branch from `main`, keep personal health exports out of commits and test fixtures, run `swift test`, and open a pull request describing the behavior change and its privacy impact.
