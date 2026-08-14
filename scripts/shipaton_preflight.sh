#!/usr/bin/env bash

# Local-only readiness checks. This script never authenticates, uploads, submits,
# publishes, creates store products, or changes signing configuration.

set -u

repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_dir" || exit 2

passes=0
warnings=0
blockers=0

pass() {
    passes=$((passes + 1))
    printf 'PASS  %s\n' "$1"
}

warn() {
    warnings=$((warnings + 1))
    printf 'WARN  %s\n' "$1"
}

block() {
    blockers=$((blockers + 1))
    printf 'BLOCK %s\n' "$1"
}

require_file() {
    if [[ -f "$1" ]]; then
        pass "$2"
    else
        block "$2 (missing: $1)"
    fi
}

printf 'Decide For Me — local Shipaton preflight\n\n'

require_file "DecideForMe.xcodeproj/project.pbxproj" "Xcode project exists"
require_file "DecideForMe.xcodeproj/xcshareddata/xcschemes/DecideForMe.xcscheme" "Shared scheme exists"

if plutil -lint DecideForMe.xcodeproj/project.pbxproj >/dev/null; then
    pass "Xcode project parses"
else
    block "Xcode project does not parse"
fi

if plutil -lint ExportOptions.plist >/dev/null; then
    pass "Export options parse"
else
    block "Export options do not parse"
fi

if rg -q 'PRODUCT_BUNDLE_IDENTIFIER = org\.smolkin\.DecideForMe;' DecideForMe.xcodeproj/project.pbxproj; then
    pass "Expected bundle identifier is configured"
else
    block "Expected bundle identifier org.smolkin.DecideForMe is not configured"
fi

if rg -q 'MARKETING_VERSION = 1\.0\.0;' DecideForMe.xcodeproj/project.pbxproj \
    && rg -q 'CURRENT_PROJECT_VERSION = 1;' DecideForMe.xcodeproj/project.pbxproj; then
    pass "First-release version/build assumptions are 1.0.0 (1)"
else
    warn "Version/build differ from the documented first-release assumption"
fi

if rg -q 'TARGETED_DEVICE_FAMILY = "1,2";' DecideForMe.xcodeproj/project.pbxproj; then
    pass "App targets iPhone and iPad"
else
    warn "iPhone/iPad target-family assumption changed"
fi

icon_manifest="DecideForMe/Assets.xcassets/AppIcon.appiconset/Contents.json"
icon_file="$(python3 - "$icon_manifest" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = json.load(handle)
for image in manifest.get("images", []):
    if image.get("size") == "1024x1024" and image.get("filename"):
        print(image["filename"])
        break
PY
)"
if [[ -n "$icon_file" && -f "$(dirname "$icon_manifest")/$icon_file" ]]; then
    dimensions="$(sips -g pixelWidth -g pixelHeight "$(dirname "$icon_manifest")/$icon_file" 2>/dev/null | awk '/pixelWidth|pixelHeight/ {print $2}' | paste -sd x -)"
    if [[ "$dimensions" == "1024x1024" ]]; then
        pass "1024x1024 App Store icon exists"
    else
        block "App icon exists but is $dimensions, not 1024x1024"
    fi
else
    block "1024x1024 App Store icon artwork is missing from the asset catalog"
fi

screenshot="$(rg --files fastlane AppStore 2>/dev/null | while IFS= read -r candidate; do
    dimensions="$(sips -g pixelWidth -g pixelHeight "$candidate" 2>/dev/null | awk '/pixelWidth|pixelHeight/ {print $2}' | paste -sd x -)"
    if [[ "$dimensions" == "1179x2556" ]]; then
        printf '%s\n' "$candidate"
        break
    fi
done)"
if [[ -n "$screenshot" ]]; then
    pass "Required 1179x2556 screenshot exists ($screenshot)"
else
    block "Required 1179x2556 screenshot is missing"
fi

metadata_dir="fastlane/metadata/en-US"
metadata_missing=()
for field in name subtitle description keywords support_url privacy_url; do
    [[ -s "$metadata_dir/$field.txt" ]] || metadata_missing+=("$field.txt")
done
if [[ ${#metadata_missing[@]} -eq 0 ]]; then
    pass "Core en-US App Store metadata files exist"
else
    block "Core en-US App Store metadata is incomplete (${metadata_missing[*]})"
fi

if rg -q -i 'RevenueCat|Purchases' DecideForMe DecideForMe.xcodeproj/project.pbxproj 2>/dev/null; then
    pass "RevenueCat integration evidence exists in the app target"
else
    block "RevenueCat Purchases/Ads is not integrated"
fi

if rg -q '^[[:space:]]*(upload_to_app_store|submit_for_review|lane[[:space:]]+:release)([[:space:](]|$)' \
    fastlane .github 2>/dev/null; then
    block "Automated App Store release/submission behavior is present; preserve Michael's final gate"
else
    pass "No automated App Store release/submission lane is present"
fi

if rg -q -i 'URLSession|WKWebView|WebKit|Analytics|AdSupport|AppTrackingTransparency' DecideForMe 2>/dev/null; then
    warn "Network, web, analytics, ads, or tracking API references need privacy review"
else
    pass "Current app source has no network, web, analytics, ads, or tracking API references"
fi

if rg -q -i 'rejection|metadata rejected|invalid binary|app review' . \
    --hidden --glob '!**/.git/**' --glob '!SHIPATON-PREFLIGHT.md' \
    --glob '!scripts/shipaton_preflight.sh'; then
    warn "Possible local App Review/rejection evidence exists and needs human interpretation"
else
    warn "No local rejection evidence found; App Store Connect history still needs Michael verification"
fi

if [[ -f "release-evidence/first-public-release.txt" ]]; then
    pass "Local first-public-release evidence marker exists"
else
    block "No local proof that the first public store release is eligible and in-window"
fi

if [[ -f "release-evidence/demo-video-url.txt" ]] \
    && [[ -s "release-evidence/demo-video-url.txt" ]]; then
    pass "Public demo-video URL is recorded"
else
    block "Public <=2-minute demo-video URL is not recorded"
fi

if [[ -f "release-evidence/store-url.txt" ]] \
    && [[ -s "release-evidence/store-url.txt" ]]; then
    pass "Published store URL is recorded"
else
    block "Published eligible-store URL is not recorded"
fi

printf '\nSummary: %d pass, %d warning, %d blocker\n' "$passes" "$warnings" "$blockers"
if [[ "$blockers" -gt 0 ]]; then
    exit 1
fi
