# Worklog

## 2026-10-16 — Studio CI migration

Goal: preserve the paused release pipeline while moving future compute to the local Studio. Changed runner routing and hosted-image Xcode selection only; original signing/upload steps and triggers remain. The workflow remains disabled. YAML parsing passed; no signing, store upload or release was executed or credited as verified. Repository STUDIO_CI profile variables retain the original hosted label for rollback. Local release credentials and app-specific signing must be verified at an authorized future build.

## 2026-10-16 — Manual unsigned native Studio check

Add a separate manual check preserving the existing TestFlight workflow's Xcode selection and complete unit-test step for `DecideForMe.xcodeproj` / scheme `DecideForMe`. The shared scheme includes `DecideForMeTests`, whose 21 current XCTest methods target the actual `Decider` implementation. Preserve the existing iPhone 17 simulator destination and all test assertions; no new harness or selected-test filter is added.

After that existing gate, compile Release for generic iOS with the established unsigned Scanner flags: signing allowed/required NO and empty signing identity/entitlements. No extra dependency commands are needed because this project has no remote Swift package references. The existing Studio/hosted rollback profile is retained. The existing test command requires an available iPhone 17 simulator for the CI account.

The TestFlight workflow remains disabled and unchanged. Application source, tests, version and iOS17 deployment target are unchanged; no signing, archive, export, Fastlane or upload steps are included. YAML/structural/Bash syntax and trailing-whitespace checks pass. No native build or test was run during preparation, so no execution or runtime acceptance is claimed.

Root verification confirms available iPhone17 simulators under CIUID503 on installed26.2/27.0. The new workflow runs the same xcodebuild unit-test invocation once, without xcpretty or the old formatter/failure fallback: xcpretty is unavailable in the CI tool path. No test assertion or selected-test filter changes. Native Xcode output retains the actual failure status.
