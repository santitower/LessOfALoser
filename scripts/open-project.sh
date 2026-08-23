#!/bin/sh

set -eu

repository_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
project_path="$repository_root/LessOfALoser.xcodeproj"
xcode_download_url="https://developer.apple.com/download/all/?q=Xcode%2026.3"

if xcode_path=$(xcode-select -p 2>/dev/null); then
  case "$xcode_path" in
    *.app/Contents/Developer)
      xcode_app_path=${xcode_path%/Contents/Developer}
      ;;
    *)
      xcode_app_path=
      ;;
  esac
else
  xcode_path=
  xcode_app_path=
fi

if [ -z "$xcode_app_path" ] || [ ! -x "$xcode_path/usr/bin/xcodebuild" ]; then
  cat >&2 <<EOF
LessOfALoser needs the full Xcode app. Xcode Command Line Tools and XcodeGen
cannot open or run an iPhone project by themselves.

This Mac is currently using:
  ${xcode_path:-no developer directory}

If this Mac runs macOS Sequoia 15.6 or newer, download Xcode 26.3 here:
  $xcode_download_url

Move Xcode.app to /Applications, open it once, then run:
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ./scripts/open-project.sh
EOF
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  cat >&2 <<'EOF'
XcodeGen is not installed. Install it once, then rerun this script:
  brew install xcodegen
  ./scripts/open-project.sh
EOF
  exit 1
fi

cd "$repository_root"
xcodegen generate
open -a "$xcode_app_path" "$project_path"

cat <<'EOF'
Opened LessOfALoser in Xcode.

Choose the LessOfALoser scheme (not LessOfALoser-CoreAI), select an iPhone or
iOS 26 simulator, and press the Run button.
EOF
