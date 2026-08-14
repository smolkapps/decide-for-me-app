# Decide For Me

A tiny, native SwiftUI decision-maker for iOS. Enter your options (or tap a
preset), hit **Decide**, and watch it spin to a random pick — with haptics and a
capped history of past calls.

<p align="center"><em>Can't choose where to eat? Let the phone do it.</em></p>

## Features

- **Options editor** — add/remove your own choices; blanks and duplicates are rejected automatically.
- **Presets** — one-tap Yes/No, Coin Flip, Rock·Paper·Scissors, and Roll-a-D6.
- **Animated pick** — a suspenseful spin that lands on the real result.
- **No immediate repeats** — back-to-back decisions won't return the same option (when an alternative exists), so two-option sets strictly alternate.
- **Capped history** — the last 50 decisions are kept; older ones roll off.
- **Haptics** — light ticks while spinning, a success tap on the result.
- **No backend, no accounts, no special entitlements.** Everything runs on-device.

## Architecture

All decision logic lives in a **framework-free, unit-testable core** so it can be
exercised in isolation:

| File | Role |
|------|------|
| `DecideForMe/Decider.swift` | Pure `struct Decider` — options, capped history, no-repeat rule, and a **`decide(using:)` that takes an injectable `RandomNumberGenerator`** for deterministic testing. No SwiftUI/UIKit. |
| `DecideForMe/DeciderViewModel.swift` | `@MainActor ObservableObject` bridge — presentation state + the spin animation. Delegates every decision to `Decider`. |
| `DecideForMe/ContentView.swift` | Thin SwiftUI views (result card, Decide button, presets, options list, history). |
| `DecideForMe/Haptics.swift` | Small UIKit feedback wrapper. |
| `DecideForMeTests/DeciderTests.swift` | XCTest suite over the core, driven by a seeded SplitMix64 generator. |

The core has **no UI dependency**, which is what makes the `21`-case test suite
fully deterministic.

## Build & test

Requires Xcode 16.2+ (developed against it) and the iPhone 16 simulator.

```bash
# Run the unit tests
xcodebuild test -scheme DecideForMe \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

All 21 tests pass locally (`** TEST SUCCEEDED **`).

- **Bundle id:** `org.smolkin.DecideForMe`
- **Team ID:** `4R42A425CK`
- **Deployment target:** iOS 17.0

## TestFlight / CI

The archive + upload runs in **GitHub Actions on `macos-26` / Xcode 26** (local
Xcode 16.2 is too old to upload to App Store Connect in 2026). The workflow is
`.github/workflows/testflight.yml`; trigger it manually (`workflow_dispatch`) or
by pushing a `testflight-*` tag.

> **TestFlight only.** Neither the workflow nor the fastlane lanes submit to App
> Store review. `upload_to_testflight` / `altool --upload-app` push to the
> TestFlight processing track; promoting a build to the App Store is a separate,
> manual step in App Store Connect.

### Required GitHub secrets

Set these under **Settings → Secrets and variables → Actions** before running the
workflow:

| Secret | What it is | How to obtain |
|--------|-----------|---------------|
| `BUILD_CERTIFICATE_BASE64` | Apple **Distribution** certificate (`.p12`), base64-encoded | `base64 -i Distribution.p12` |
| `P12_PASSWORD` | Password set when exporting that `.p12` from Keychain | you choose it at export time |
| `BUILD_PROVISION_PROFILE_BASE64` | App Store provisioning profile (`.mobileprovision`) for `org.smolkin.DecideForMe`, named **`DecideForMe AppStore`**, base64-encoded | `base64 -i DecideForMe_AppStore.mobileprovision` — create via the ASC API or the Apple Developer portal, referencing the same dist cert as the `.p12` |
| `KEYCHAIN_PASSWORD` | Arbitrary string used to create the temp CI keychain | any value, e.g. `build-keychain-password` |
| `APPSTORE_API_KEY_ID` | App Store Connect API **Key ID** | App Store Connect → Users and Access → Integrations → App Store Connect API |
| `APPSTORE_ISSUER_ID` | App Store Connect API **Issuer ID** | same page |
| `APPSTORE_API_PRIVATE_KEY` | Contents of the ASC API key `.p8` file | downloaded once from that page |

Setting one from the CLI:

```bash
base64 -i Distribution.p12 | gh secret set BUILD_CERTIFICATE_BASE64 -R smolkapps/decide-for-me-app
```

### fastlane (local / alternative path)

`fastlane/Fastfile` provides:

- `fastlane beta` — build with the `app-store` export method and `upload_to_testflight` (`skip_waiting_for_build_processing: true`, `skip_submission: true`).
- `fastlane build_ipa` — archive/export only, no upload and no App Store
  Connect authentication. It still requires the local distribution certificate
  and `DecideForMe AppStore` provisioning profile used by the export settings.

There is intentionally **no `release` lane** and **no `upload_to_app_store` call**.
It authenticates with the ASC API key via these environment variables:

```bash
export APP_STORE_CONNECT_API_KEY_ID=...
export APP_STORE_CONNECT_ISSUER_ID=...
export APP_STORE_CONNECT_API_KEY_PATH=/path/to/AuthKey_XXXX.p8
fastlane beta
```

## License

[MIT](LICENSE) © 2026 Michael Smolkin
