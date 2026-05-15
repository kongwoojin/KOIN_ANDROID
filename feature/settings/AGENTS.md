# Feature Settings Module - AGENTS.md

`feature/settings` is a Compose-first Orbit module for migrating the legacy settings screen.

## Keep In Mind

- Build all new settings UI with Jetpack Compose + Orbit MVI.
- Keep settings-related screens, ViewModels, and state models in this module.
- Navigation hand-offs to legacy activities must follow the module-graph boundaries described below.
  - `NotificationActivity`: use the existing `Navigator.navigateToNotificationSetting(context)` — this method exists today in `core/navigation/Navigator.kt`.
  - `UserInfoActivity`, `TermActivity`, `DeveloperSettingActivity`: these targets live in `koin/` (the app module), which is a **higher-level consumer** of `feature/*`. A `feature/settings` class must NOT reference `koin/` Activities directly — doing so would reverse the dependency direction. The only allowed path is to extend `Navigator` in `core/navigation` and add the implementation in `koin/navigation/NavigatorImpl.kt`, then call the new method from `feature/settings`. This is a **follow-up issue**; do not implement it in this scaffold issue.
  - `ChangePasswordContract` (`ActivityResultContract<Unit, Boolean>` in `feature/user`): this scaffold issue does NOT decide the change-password navigation strategy — it is out of scope. When the migration issue addresses this, one of the following paths must be chosen and `feature/settings/build.gradle.kts` updated accordingly:
    (a) Introduce a shared activity-result bridge contract in `core/navigation` (or another shared module), with the `koin` app providing the actual launcher integration. OR
    (b) Explicitly add `implementation(projects.feature.user)` to `feature/settings` and use `ChangePasswordContract` directly.
    A "settings-local wrapper" is not a standalone option — it cannot compile without one of (a) or (b) in place first.
  - `OssLicensesMenuActivity` (Google Play OSS Licenses library — called at `koin/src/main/java/in/koreatech/koin/ui/setting/SettingActivity.kt:154`): this is an existing branch that must not be lost during migration. When migrating this row, either (a) add `com.google.android.gms:play-services-oss-licenses` to `feature/settings` dependencies and launch `OssLicensesMenuActivity` locally, or (b) add a shared navigation contract for it similar to the app-owned targets above.
  - For external targets such as browser URLs, launch the explicit external `Intent` directly from the feature instead of routing through `Navigator`.
- Reuse shared design-system, analytics, and onboarding components before adding module-local alternatives.
- ViewModels must call use cases — never repositories directly.

## Read First

- Root `AGENTS.md`
- `core/AGENTS.md`
- `core/designsystem/AGENTS.md`
- `core/navigation/AGENTS.md`
- `feature/user/AGENTS.md` (settings → user profile navigation)
- `core/onboarding/AGENTS.md` (settings → onboarding/login gate)
