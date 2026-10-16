# Worklog

## 2026-10-16 — Studio CI migration

Goal: preserve the paused release pipeline while moving future compute to the local Studio. Changed runner routing and hosted-image Xcode selection only; original signing/upload steps and triggers remain. The workflow remains disabled. YAML parsing passed; no signing, store upload or release was executed or credited as verified. Repository STUDIO_CI profile variables retain the original hosted label for rollback. Local release credentials and app-specific signing must be verified at an authorized future build.
