#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_root"

if rg -n 'CoreAILanguageModels|\.\./coreai-models|qwen2_5_1_5b' \
    HealthInsight HealthInsight.xcodeproj; then
  echo "Standalone dependency check failed" >&2
  exit 1
fi

test_binary_dir="$(mktemp -d)"
trap 'rm -rf "$test_binary_dir"' EXIT
swiftc HealthInsight/ScoringRules.swift Tests/CoreLogic/main.swift \
  -o "$test_binary_dir/health-insight-core-tests"
"$test_binary_dir/health-insight-core-tests"

while IFS= read -r plist_file; do
  plutil -lint "$plist_file" >/dev/null
done < <(find . -type f -name '*.plist' \
  -not -path './.git/*' -not -path './web-demo/*' | sort)

while IFS= read -r json_file; do
  python3 -m json.tool "$json_file" >/dev/null
done < <(find HealthInsight -type f -name 'Contents.json' | sort)

if xcodebuild -version >/dev/null 2>&1; then
  swiftc -frontend -parse HealthInsight/*.swift
  xcodebuild \
    -project HealthInsight.xcodeproj \
    -scheme HealthInsight \
    -destination 'generic/platform=iOS Simulator' \
    CODE_SIGNING_ALLOWED=NO \
    build
else
  echo "Skipping simulator build: the full Xcode app is not active."
fi

echo "Standalone validation passed"
