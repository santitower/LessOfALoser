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
- Up to seven coarse daily Screen Time totals in a local App Group container
- 28-day baseline comparisons in the platform-independent `WellnessCore` module
- One reviewed insight context shared by Today, League, Ask, and export
- Focusable daily path with explicit achieved, open, and unavailable goal states
- On-device Foundation Models coaching with a deterministic fallback
- Optional iOS 27 Core AI target for an exported Qwen 2.5 1.5B model
- Optional Computer Coach using Tailscale HTTPS and Ollama on a personal computer
- In-app Quick Connect plus a `lessofaloser://connect` link that prefills the computer address
- Aggregate-only gateway validation, Tailscale identity checks, and safe automatic fallback
- Dedicated Personal AI chat tab backed by a replaceable on-device model runtime
- In-memory conversations grounded in aggregate trends, with a verified no-model fallback
- User-initiated, versioned aggregate wellness export for private portability
- Companion web review with retrospective trends, model-context inspection, a local league preview, and PDF output
- Wellness League preview with weekly consistency points, rank movement, podiums, streaks, duels, and preset friend reactions
- No-login local league-pass export/import for real friend snapshots, with synthetic profiles kept visibly in preview mode
- Swift unit tests and a GitHub Actions workflow

## Requirements

- The full Xcode 26 app, not only Xcode Command Line Tools or XcodeGen
- An iPhone running iOS 26 or newer
- An Apple Developer team for device signing
- An Apple Intelligence-compatible device with Apple Intelligence enabled for generated coaching
- Apple approval for the Family Controls distribution entitlement before App Store or TestFlight distribution

Check [Apple's Xcode compatibility table](https://developer.apple.com/xcode/system-requirements/) before downloading. On macOS Sequoia 15.6 or newer, use Xcode 26.3; newer Xcode releases may require macOS Tahoe.

The optional custom-model build requires Xcode 27, iOS 27, and a separately exported Core AI model bundle. See [the Core AI integration guide](docs/CORE_AI.md).

An older iPhone can instead use a computer running Tailscale, Python 3, and Ollama. See [the Private Computer Coach guide](docs/REMOTE_COMPUTER.md).

The social competition tab starts as a clearly labeled synthetic preview and can switch to real,
manually exchanged aggregate league passes without a backend. See [the Wellness Leagues design
and backend boundary](docs/SOCIAL_LEAGUES.md).

HealthKit and Device Activity should be tested on a physical iPhone. The deterministic `WellnessCore` package can be tested on macOS without Xcode.

## Generate and open the project

The repository uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the project file is reproducible.

First verify that the full Xcode app is installed:

```sh
xcodebuild -version
```

If that command says the active developer directory is Command Line Tools, install [Xcode 26.3 from Apple Developer Downloads](https://developer.apple.com/download/all/?q=Xcode%2026.3), move `Xcode.app` to `/Applications`, open it once, and select it:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Then run the checked setup helper from the repository:

```sh
brew install xcodegen
./scripts/open-project.sh
```

The helper generates the project and explicitly opens it with Xcode. If Xcode is missing, it stops with a useful installation message instead of opening the `.xcodeproj` package as a Finder folder.

In Xcode:

1. Choose the `LessOfALoser` scheme, not the experimental `LessOfALoser-CoreAI` scheme.
2. For a quick UI demo, select an installed iOS 26 simulator and press Run.
3. For real Health and Screen Time data, select your development team for the `PhoneLLM` and `ScreenTimeReport` targets.
4. Replace the `com.santitower` bundle prefix if you do not control it.
5. Register the `group.com.santitower.LessOfALoser` App Group for both targets.
6. Enable HealthKit on the app target.
7. Enable Family Controls on the app and report extension targets.
8. Build to a physical iPhone and grant Health and Screen Time access.

For distribution, request the Family Controls managed capability for both the app and report extension identifiers in the Apple Developer portal.

## Custom local model

The generated project contains two application schemes:

- `LessOfALoser` targets iOS 26 and uses Apple's on-device system model when available.
- `LessOfALoser-CoreAI` targets iOS 27 and first tries an exported Qwen model through Apple's `coreai-models` package.

The Qwen model is not committed to GitHub. Follow [docs/CORE_AI.md](docs/CORE_AI.md) to export and install it locally. If the model is missing or cannot load, the same build automatically falls back to Apple's system model and then to deterministic rules.

The **Ask** tab keeps a local conversation with whichever on-device language model is available. Its UI depends on a small runtime protocol so an optimized model implementation can arrive in a later PR without rewriting the screen. See [the Personal AI integration boundary](docs/PERSONAL_AI.md).

The **Today** tab can also save a versioned aggregate JSON package. Open that file in the companion `web-demo` to create a retrospective review and PDF without granting a website direct Apple Health access. See [the Web review and report flow](docs/WEB_REVIEW.md).

## Run core tests

```sh
swift test
```

## Privacy boundary

Screen Time is not a HealthKit database. Apple provides activity results inside a privacy-preserving report extension. This prototype keeps at most seven aggregate daily activity-minute snapshots in a shared local App Group container so it can calculate the current week's score. It does not persist app names, web domains, opaque application tokens, or raw activity events, and it cannot backfill a day when the daily report was not produced.

Before distributing this pattern, confirm it against the current Apple Developer Program terms and App Review requirements. A production version should include an accessible privacy policy, deletion controls, safety evaluations, and a formal review of its wellness claims.

## Safety boundary

LessOfALoser is general wellness software. It must not:

- diagnose or predict a condition;
- monitor emergencies;
- claim that Screen Time caused a sleep or activity change;
- recommend medication, supplement, or treatment changes;
- interpret missing data as a negative health signal.

Every model receives aggregated JSON facts rather than raw HealthKit samples. If a custom model is missing or refuses a request, the app tries the next local backend before displaying the deterministic fallback.

When Computer Coach is enabled, the same aggregate summary leaves the iPhone only through the user's private Tailscale network. The gateway recomputes canonical observations from the numeric trends and does not accept raw HealthKit samples, Screen Time app identities, arbitrary prompts, or model tools.

## Project layout

```text
PhoneLLM/                 SwiftUI app, HealthKit client, local coach
ScreenTimeReport/         Device Activity report extension
desktop_gateway/          Aggregate-only Tailscale-to-Ollama gateway
Resources/CoreAI/         Local-only custom model resources (Git-ignored)
Sources/WellnessCore/     Shared models, trend engine, local snapshot store
Tests/WellnessCoreTests/  Platform-independent tests
web-demo/                 Companion retrospective, league, and PDF-ready web review
docs/CORE_AI.md            Qwen/Core AI export and build instructions
docs/BRANCH_INTEGRATION_REVIEW.md  Branch audit and adopted architecture
docs/PERSONAL_AI.md        Conversational model runtime and privacy contract
docs/WEB_REVIEW.md         Native export, web import, social storage, and report boundary
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
