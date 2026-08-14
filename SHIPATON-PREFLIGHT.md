# RevenueCat Shipaton 2026 Preflight — Decide For Me

Status as of 2026-08-14: **not ready to submit or publish publicly**. This is a local,
no-submission audit. Nothing here proves contest eligibility, store approval, or
publication.

Michael has authorized validated builds to be uploaded to TestFlight. TestFlight is
the current distribution target and does not authorize App Store review, public
release, Devpost submission, or social promotion.

## Executive result

The app is a credible first-release candidate, but only the local build identity
and current private/draft state are evidenced. A Release device build succeeds and
the deterministic unit-test suite passes. The repository contains no evidence of a
previous public App Store release, but absence of evidence is not proof; Michael must
verify App Store Connect version history before relying on Shipaton eligibility.

The app does not yet include RevenueCat Purchases or RevenueCat Ads. No monetization
code was added because product type, price, entitlement, offering, and user experience
are product decisions. Integrating an arbitrary purchase now could produce the wrong
store model and privacy disclosures.

## Contest gates supplied for this audit

- Eligible platform: iOS/iPadOS (the target supports both).
- First public eligible-store release must occur from 2026-07-31 through 2026-09-30.
- An update to a previously public app is ineligible.
- The released build must use RevenueCat for a purchase or RevenueCat Ads.
- Final evidence needs a published store URL, a public demo video no longer than two
  minutes, a 1024x1024 icon, a 1179x2556 screenshot, and trial/promo access.
- Michael must explicitly approve every external upload, submission, publication,
  Devpost action, and social post.

## Proven locally

| Area | Evidence | Result |
|---|---|---|
| Source history | One repository commit dated 2026-06-28; no tags or release artifacts | Consistent with an unreleased candidate, not proof of store history |
| Portfolio record | `portfolio-traffic/portfolio.json` says `draft/private`, has no live store URL, and says an ASC record exists | Private/draft is the current local source of truth; eligibility remains `needs-verification` |
| Identity | Bundle `org.smolkin.DecideForMe`, version `1.0.0`, build `1` | Consistent across project, fastlane, workflow, and export options |
| Platforms | `TARGETED_DEVICE_FAMILY = "1,2"`; iOS 17.0 minimum | iPhone and iPad |
| Build | Xcode 16.2 Release build for generic iOS with signing disabled | Passed 2026-08-12 |
| Tests | 21 deterministic XCTest cases | Passed 2026-08-12 on the available iPhone simulator |
| Data behavior | Source has no backend, account, network, analytics, ads, tracking, or third-party dependency | Current options/history exist only in memory; reassess after RevenueCat integration |
| External-action gate | No fastlane release lane or `upload_to_app_store`; CI uploads only to TestFlight | App Store review remains manual |
| Archive-only lane | `fastlane build_ipa` performs no ASC authentication or upload | Fixed in this preflight; local signing assets are still required |

## Needs verification or is blocked

1. **Prior public-release history — eligibility blocker.** The local portfolio record
   says draft/private and no store URL is recorded. Michael must inspect App Store
   Connect for this exact bundle ID and confirm it has never reached Ready for Sale,
   Pending Developer Release, or another public-release state before 2026-07-31.
   Record the non-sensitive result and date under `release-evidence/`; do not store
   authenticated screenshots containing account data in the repository.
2. **RevenueCat — implementation blocker.** There is no SDK dependency, API-key
   configuration, offering, product, entitlement, paywall/ad surface, restore flow,
   purchase test, or privacy review. Choose Purchases or RevenueCat Ads before coding.
3. **App icon — store and contest blocker.** `AppIcon.appiconset` declares a universal
   1024 slot but contains no artwork file.
4. **Screenshots — store and contest blocker.** No screenshot assets exist, including
   the required 1179x2556 image. Because iPad is supported, prepare the currently
   required iPad App Store screenshot set as well.
5. **Store metadata — store blocker.** There is no `fastlane/metadata/en-US` package.
   Name, subtitle, description, keywords, support URL, privacy-policy URL, promotional
   text, category, age rating, copyright, and review notes are not recorded locally.
6. **Privacy declarations — decision blocker.** The current source appears compatible
   with “Data Not Collected,” but that answer cannot be finalized until the selected
   RevenueCat purchase/ads configuration and any diagnostics are known. No privacy
   manifest exists; the current first-party code does not show an obvious required-
   reason API, but the final dependency set must be checked.
7. **Signing/archive — needs verification.** The project uses automatic signing for
   development. CI/export assumes Apple Distribution, team `4R42A425CK`, and a manual
   profile named `DecideForMe AppStore`. Local existence/validity and CI secrets were
   deliberately not inspected. The installed Xcode is 16.2; the repository expects
   Xcode 26 in CI for a 2026 upload.
8. **Rejection state — needs verification.** No local rejection message or resolution
   is present. This does not prove there was no rejection; Michael must inspect App
   Review history. No speculative rejection fix was made.
9. **Release/Devpost evidence — submission blockers.** No public store URL, public
   <=2-minute demo URL, trial/promo instructions, or release-date evidence is recorded.

## Michael decisions required before implementation

Please review and decide these exact points:

1. Confirm whether App Store Connect shows **zero prior public releases** for
   `org.smolkin.DecideForMe`, and whether any rejection exists. If rejected, provide
   the exact non-secret review text before a fix is attempted.
2. Confirm the Shipaton entry should use **RevenueCat Purchases** or **RevenueCat Ads**.
   For Purchases, approve the product type, product identifier, price tier, entitlement
   identifier, offering identifier, what value is paid, restore behavior, and any
   trial/promo terms. For Ads, approve placement/frequency and the privacy tradeoff.
3. Approve the public product identity: app name/subtitle, primary category, support
   URL, privacy-policy URL, icon direction, and screenshot copy. Also decide whether
   iPad support should remain; removing it changes product scope and screenshot needs.
4. Approve the judge access plan (trial, promo offer/code, or other contest-compliant
   access) without committing credentials to this repository.
5. After a signed archive passes, upload to TestFlight. After a sandbox purchase/ad
   test is demonstrated, separately obtain Michael's approval for App Store review,
   public release timing, public demo upload, Devpost submission, and any social post.

## Safe execution sequence after those decisions

1. Record verified release/rejection history without secrets.
2. Implement the selected RevenueCat model with configuration injected outside source;
   include restore/error/loading behavior and tests.
3. Re-audit privacy labels/manifests and draft store metadata.
4. Add reviewed icon and phone/iPad screenshots; run
   `scripts/shipaton_preflight.sh`.
5. Build/test/archive locally or in CI and upload the validated build to TestFlight.
6. Stop before App Store review or public release. After Michael releases it publicly
   in-window, record the live store URL, release
   date evidence, demo URL, and judge access instructions for Devpost.

## Local validation

Run:

```bash
scripts/shipaton_preflight.sh
xcodebuild build -project DecideForMe.xcodeproj -scheme DecideForMe \
  -configuration Release -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO
xcodebuild test -project DecideForMe.xcodeproj -scheme DecideForMe \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=18.3' \
  CODE_SIGNING_ALLOWED=NO
```

The preflight script exits nonzero while any release/contest blocker remains. It is
intentionally local-only and does not inspect authenticated accounts.
