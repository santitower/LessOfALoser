# Experimental Core AI model backend

LessOfALoser can use a custom Qwen model through Apple's Core AI runtime. This is an optional iOS 27 path; it does not replace the iOS 26 build that uses Apple's system on-device model.

## Runtime order

The coach tries each backend in this order:

1. Bundled Qwen 2.5 1.5B model through Core AI.
2. Apple's on-device `SystemLanguageModel` when available.
3. Deterministic, non-generative wellness rules.

Every backend receives only the same aggregated trend JSON. Raw HealthKit and Screen Time samples are never sent to the language model.

## Requirements

- Xcode 27 or newer.
- An iPhone or iPad running iOS 27 or newer.
- Sufficient free storage and runtime memory.
- The `coreai-models` Swift package from Apple.
- An exported Core AI model resource folder.

The proof of concept in `cmedipally7/iOSCoreMLPOC` reports an approximately 890 MB 4-bit Qwen 2.5 1.5B bundle on an iPhone 16 Pro Max. Treat that number as a device-specific observation, not a guaranteed production benchmark.

## Export Qwen

Follow Apple's official export recipe:

```sh
git clone https://github.com/apple/coreai-models.git
cd coreai-models
brew install uv
uv run coreai.llm.export \
  Qwen/Qwen2.5-1.5B-Instruct \
  --platform iOS \
  --max-context-length 4096 \
  --output-dir ./exports
```

Locate the generated directory containing `metadata.json`, an `.aimodel` directory, and `tokenizer/`. From the LessOfALoser repository, install it with:

```sh
./scripts/install-core-ai-model.sh /absolute/path/to/exported-model-folder
```

Then regenerate and open the project:

```sh
xcodegen generate
open LessOfALoser.xcodeproj
```

Select the `LessOfALoser-CoreAI` scheme and a physical iOS 27 device.

The Core AI target intentionally uses the same application identifier as the standard target. It is an alternate build of LessOfALoser rather than a second app installed beside it, which keeps the embedded Screen Time extension and App Group identifiers valid.

## Why the model is not in GitHub

The exported bundle is large, model licensing is separate from application-source licensing, and normal Git repositories are a poor distribution mechanism for binary models. Each developer should export it locally for the proof of concept. A production app should use a reviewed asset-delivery strategy and verify the model's license, attribution, integrity, and update process.

## Build-resource workaround

As observed in `iOSCoreMLPOC`, Xcode may treat `.aimodel` as a nested bundle during signing. The experimental scheme copies tokenizer and metadata resources during the target build, then copies `.aimodel` directories in a scheme post-action. This is suitable for device prototyping only. Validate archive signing and App Store distribution independently before treating it as a release solution.

## Sources

- Apple Core AI Models: https://github.com/apple/coreai-models
- Apple Qwen 2.5 export recipe: https://github.com/apple/coreai-models/blob/main/models/qwen2/README.md
- Integration proof of concept: https://github.com/cmedipally7/iOSCoreMLPOC

The integration in this repository is implemented against Apple's public package and documentation; no source file from the proof-of-concept repository is copied.
