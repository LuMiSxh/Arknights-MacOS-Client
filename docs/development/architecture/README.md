---
title: Architecture
description: Source layout, ownership, lifecycle, and boundaries for the launcher
order: 10
---

# Architecture

Arknights Client is a native SwiftUI launcher around a bundled Windows compatibility runtime. The
launcher owns downloads, updates, settings, diagnostics, and process state. It does not ship game
files. It does not run Wine until the user selects **Play**. Start with the system map. Then read the
flow that matches your change:

- [Installation architecture](installation.md): manifests, resumable downloads, per-region state.
- [Launch and process lifecycle](launch-and-process-lifecycle.md): Rosetta, compatibility components,
  process monitoring, shutdown.
- [Wine prefix architecture](wine-prefix.md): prefix topology, isolation, migrations, maintenance.
- [Communication and boundaries](communication-and-boundaries.md): publisher requests, announcements,
  notices, update checks, stale results.
- [Data and persistence](data-and-persistence.md): `AppPaths`, `UserDefaults`, caches, logs, removable
  files.

The primary composition and ownership sources are [`LauncherViewModel`](../../../Sources/ArknightsClient/Features/Launcher/State/LauncherViewModel.swift),
[`LauncherState`](../../../Sources/ArknightsClient/Core/Lifecycle/LauncherState.swift),
and [`AppPaths`](../../../Sources/ArknightsClient/Shared/Persistence/AppPaths.swift).

## System map

Data and side effects flow through the feature controllers. Each view receives only the controller or
values it needs. The root is not a service locator.

```mermaid
flowchart TB
	App[SwiftUI app] --> Root[LauncherViewModel]
	Root --> Lifecycle[LauncherLifecycleStore]
	Root --> Install[InstallationController]
	Root --> Game[GameSessionController]
	Root --> Refresh[LauncherRefreshController]
	Root --> Communication[LauncherCommunicationController]
	Root --> Settings[LauncherPreferencesController]
	Root --> Customization[CustomizationController]
	Root --> Storage[Storage controllers]
	Install -->|exclusive activity| Lifecycle
	Game -->|exclusive activity| Lifecycle
	Refresh -->|readiness and presentation| Lifecycle
	Communication --> Popup[Popup presentation]
	Customization --> Assets[Artwork and icon stores]
	Settings --> Defaults[UserDefaults]
	Install --> GameFiles[Regional game directories]
	Game --> Prefix[Publisher-family Wine prefix]
```

An arrow means ownership or an explicit callback, not free two-way access. For example,
`InstallationController` can update lifecycle state. A view must not use `LauncherViewModel` to start a
download.

## Source layout

| Folder           | Responsibility                                                                              |
| ---------------- | ------------------------------------------------------------------------------------------- |
| `Application`    | App entry point, dependency composition, macOS lifecycle                                    |
| `Core`           | Cross-feature lifecycle state and launcher activity leases in `Core/Lifecycle`              |
| `Features`       | Feature-owned UI, state, domain models, services, external work                             |
| `Infrastructure` | Feature-independent network and system I/O primitives                                       |
| `Shared`         | Cross-feature domain, configuration, persistence, diagnostics, support, shared UI contracts |
| `Resources`      | SwiftPM resources copied into the application bundle                                        |

`Features` is organized by behavior, not by technical layer:

- `Launcher`: composition, shared lifecycle presentation, home, Settings, documents, popups, launcher
  updates.
- `Game`: installation, Wine runtime, Intel translation, game-file compatibility components.
- `Customization`: artwork, icons, preset gallery.
- `Audio`: background playback, Now Playing, settings, HUD controls.
- `Onboarding`: resumable flow, progress persistence, step views.

Rules:

- Feature-specific components stay in their feature. `Shared/UI/Components` holds only presentation
  contracts that multiple features use, such as action buttons, modal chrome, and Settings panels.
- `Infrastructure` holds feature-independent I/O, such as bounded HTTP loading and chunked transfer
  support. It does not decide if a response is a valid game manifest or how a controller shows an error.
  The owning feature keeps that policy.
- `Infrastructure` and `Shared` never import feature-owned types. Features map transport and storage
  errors at their boundary.
- Launcher copy is English literals in small feature-local `…Strings` namespaces. The UI that uses the
  copy owns it. There is no runtime language-selection layer.

Repository scripts derive their configuration from these sources:

| Data                       | Source                              |
| -------------------------- | ----------------------------------- |
| Shipping product metadata  | `Resources/Info.plist`              |
| Target and resource layout | SwiftPM's evaluated `Package.swift` |
| Runtime layout             | `runtime.json`                      |

`scripts/lib/project_config.py` cross-validates the first two sources before builds and checks. Scripts
must not keep separate lists of app names, executables, platforms, architectures, or package resources.

### Bundled resources

`Shared/Resources/BundledResource.swift` is the only place that names a file or directory in the app bundle. Each entry states its path, its kind, its origin, and its encoding.

| Origin    | Staged by                       | Read from                                                    |
| --------- | ------------------------------- | ------------------------------------------------------------ |
| `app`     | `scripts/build_app.py`          | `Bundle.main`                                                |
| `package` | `resources:` in `Package.swift` | `AppResourceBundle.bundle` (`Bundle.module` in SwiftPM runs) |

Use these rules:

- Load a file with `BundledResource.data(in:)`, `text(in:)`, or `decode(_:in:)`. Do not call `Bundle.url(forResource:)` for a bundled resource.
- The loader throws `BundledResourceError`. `missing` means the bundle has no such resource. `unreadable` means the file system failed. `corrupt` means the content is not valid deflate data, UTF-8, or JSON. The owning feature maps the error.
- A file that the build copies from the repository stays `identity`: the bundle holds the same bytes as the source. This applies to `LICENSE`, `CHANGELOG.md`, `RUNTIME.json`, and images. A document that the build generates uses `deflate`. Today only `ThirdPartyNotices.deflate` does. Compression would save about 32 KB for `LICENSE` and `CHANGELOG.md`. The saving does not justify unreadable copies in the bundle.
- `scripts/lib/bundled_resources.py` lists the same resources with their sources. `just check scripts` and `scripts/tests/test_bundled_resources.py` fail when the two lists differ. A new `package` resource also needs an entry in `Package.swift`.
- `WallpaperTags.json` is the bundled fallback. The remote manifest layers over it and does not change the loader rules.

The app does not load the icon files by name. `Info.plist` names them.

Unit, deterministic integration, and live-contract tests are separate. [Testing architecture](../testing.md)
covers target ownership, isolation, fixtures, CI cadence, and the manual Wine/game matrix.

`LauncherViewModel` is the composition root. It constructs the feature controllers, wires the few
transitions that cross feature boundaries, and provides the application shell that the debug simulator
uses. It does no network, filesystem, installation, Wine, audio, customization, or update work.
Feature-local views receive their owning controller, or explicit values and actions, never the complete
root model. Put new policy beside the owning feature. Add only the smallest callback at composition time.

Each long-lived state and each asynchronous task has one feature owner:

| Owner                             | Responsibility                                                                                       |
| --------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `LauncherLifecycleStore`          | Exclusive activity, refresh state, launch readiness, status, failure UI                              |
| `InstallationController`          | Region, install directory, installed state, resumable install/update/repair tasks, progress, removal |
| `GameSessionController`           | Runtime discovery, prefix maintenance, launch options, Wine processes, Game Mode, diagnostics        |
| `IntelTranslationController`      | Rosetta preflight, installation, recovery state, launch eligibility                                  |
| `LauncherRefreshController`       | Concurrent configuration and branding refreshes, stale-result rejection, region transitions          |
| `CustomizationController`         | Artwork, Dynamic Theme, launcher and game icons, presets                                             |
| `BackgroundMusicController`       | Playlist parsing, playback, Now Playing metadata, fades, music-link presentation                     |
| `LauncherCommunicationController` | Launcher releases, announcements, Yostar notices, popup order                                        |
| `LauncherPreferencesController`   | Persisted settings and the region-aware server-reset timer                                           |
| `StorageMaintenanceController`    | Targeted DXMT, browser, and gallery cache cleanup                                                    |
| `StorageOverviewController`       | Async usage measurement for installations, runtime data, caches, logs                                |

Installation, maintenance, and the Wine-backed game lifecycle share the exclusive `LauncherActivity`
state machine, because they can touch the same game files or runtime. Refresh and presentation stay
orthogonal, so safe metadata checks and actionable errors can exist while a game runs.

Controllers use explicit, narrow dependencies and callbacks that the composition root configures. They
never depend on `LauncherViewModel` or implicit singleton state.

The state tree has three separate concerns:

| State branch              | Answers                                     | Examples                                               |
| ------------------------- | ------------------------------------------- | ------------------------------------------------------ |
| `activity`                | Which exclusive work owns the game/runtime? | install, migrate, launch, run, stop                    |
| `refresh` and `readiness` | Which metadata and prerequisites are known? | configuration, installed version, Rosetta availability |
| `presentation`            | What does the user see or act on?           | status text, failure message, update prompt            |

- Do not use a presentation message as a lifecycle lock.
- Do not clear an active lifecycle state because a refresh failed.
- `LauncherLifecycleStore` is the single gate for mutually exclusive work.
- The `installing(id:)` activity carries its operation ID. A stale cancelled installation task
  cannot finish a newer operation.

```mermaid
flowchart TD
	Root[LauncherViewModel composition root] --> Lifecycle[LauncherLifecycleStore]
	Root --> Installation[InstallationController]
	Root --> Session[GameSessionController]
	Root --> Refresh[LauncherRefreshController]
	Root --> Communication[LauncherCommunicationController]
	Root --> Customization[CustomizationController]
	Root --> Preferences[LauncherPreferencesController]
	Root --> Storage[StorageMaintenanceController]
	Root --> StorageOverview[StorageOverviewController]
	Installation --> Lifecycle
	Session --> Lifecycle
	Refresh --> Lifecycle
	Communication --> Popup[Popup presentation]
	Customization --> Artwork[Artwork and icons]
```

First-run setup is the separate `Onboarding` feature. It has its own `@Observable` coordinator and
`UserDefaults` progress store. It never downloads files or persists launcher settings. Each step calls
the same region, installer, display, artwork, icon, update, and audio actions as the main interface.

- A mandatory launcher-update preflight runs before setup. An available release blocks the remaining
  steps until the user installs and reopens the newer app.
- Interrupted setup resumes at its saved step.
- If the game is absent, setup returns to Region & Install before later steps.

## Targets

The package splits into SwiftPM targets in stages. The `Status` column shows the current state. Until a
row says `done`, its folders still build inside the `ArknightsClient` target and the same rules apply
as folder rules.

### Target map

A target depends only on targets with a lower number. A dependency on a higher number is a cycle. The
compiler rejects a cycle.

| No. | Target                    | Source folders                                                                                  | Depends on                                           | Linked products       | Status  |
| --- | ------------------------- | ----------------------------------------------------------------------------------------------- | ---------------------------------------------------- | --------------------- | ------- |
| 1   | `ArknightsInfrastructure` | `Infrastructure`                                                                                | none                                                 | none                  | done    |
| 2   | `ArknightsCore`           | `Shared`, `Core`, `Resources`                                                                   | 1                                                    | none                  | planned |
| 3   | `ArknightsCustomization`  | `Features/Customization`                                                                        | 1, 2                                                 | none                  | planned |
| 4   | `ArknightsGameInstallation` | `Features/Game/Installation`, `Features/Game/Compatibility`                                   | 1, 2, 3                                              | `CCommonCrypto`       | planned |
| 5   | `ArknightsGameRuntime`    | `Features/Game/Runtime`, `Features/Game/Playtime`, `Features/Game/Storage`                      | 1, 2, 3, 4                                           | none                  | planned |
| 6   | `ArknightsAudio`          | `Features/Audio`                                                                                | 2, 3                                                 | `YouTubePlayerKit`    | planned |
| 7   | `ArknightsOnboarding`     | `Features/Onboarding`                                                                           | 2, 3, 4, 5                                           | none                  | planned |
| 8   | `ArknightsLauncherUI`     | `Features/Launcher` (including `LauncherViewModel`)                                             | 1, 2, 3, 4, 5, 6, 7                                  | `Sparkle`             | planned |
| 9   | `ArknightsClient`         | `Application`                                                                                   | 2, 6, 7, 8                                           | none                  | current |

Changes from the first plan:

- `ArknightsCustomization` moves from number 5 to number 3. Installation, Runtime, and Audio use
  Customization types (see the evidence below). Customization uses none of them.
- `ArknightsGameInstallation` and `ArknightsGameRuntime` stay in this order. Runtime uses Installation.
  Installation must not use Runtime (see cycle 2).

The scan found no other cross-folder reference that breaks this direction. These references are the
allowed ones:

| From                  | To                                  | Types that cross the boundary                                                                                     |
| --------------------- | ----------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `Core`, `Shared`      | none                                | `Shared` names no `Core` or feature type. `Core` names only `Shared` types (`LauncherLog`, `SupportCode`).          |
| Installation          | `Core`, `Shared`, `Infrastructure`, Customization | `LauncherBranding` and `CustomizationError` (`LauncherAPI.swift:58`, `InstallationSupportFailure.swift:60`). |
| Runtime               | Installation, Customization         | `InstallationController`, `GameCompatibilityManager` (`GameSessionController.swift:38,44`), `PresetCatalogService` (`StorageMaintenanceController.swift:13`). |
| Audio                 | Customization                       | `LauncherIconManager` (`BackgroundMusicController.swift:48`).                                                      |
| Onboarding            | Customization, Installation, Runtime | `CustomizationController`, `InstallationController`, `RosettaAvailability` (`OnboardingCoordinator.swift:34`).     |
| `LauncherUI`          | every other library                 | Composition. `LauncherViewModel` builds all controllers.                                                           |
| `ArknightsClient`     | `LauncherUI`, Audio, Onboarding, `Core` | `ArknightsClientApp.swift:8,104,199,200`.                                                                      |

### Resolved cycles

Both cycles that blocked Stage 4 are removed from the code. This subsection records the current state.

**Cycle 1: lower features used types that `Features/Launcher` owns. Resolved.**

- `LauncherPreferencesController` and `LauncherUpdateCheckOutcome` live in `Core/Preferences`. They use
  only `Shared` types.
- Each feature has its own strings type. No lower feature uses `LauncherStrings` or `SettingsStrings`:
  - Customization uses `CustomizationStrings`.
  - Installation uses `InstallationStrings`.
  - Runtime uses `RuntimeStrings`, `StorageStrings`, and `PlaytimeStrings`.
  - Audio uses `AudioStrings`.

**Cycle 2: Installation and Runtime used each other. Resolved.**

- Installation and Compatibility throw `GameCompatibilityError`, which lives in
  `Features/Game/Compatibility`. The Installation target owns this type.
- Runtime maps `GameCompatibilityError` to `GameRuntimeError` in
  `GameRuntimeError.mappingCompatibilityFailure(_:)`. `WineRuntime.launch` calls this mapping.
- Runtime still uses Installation. This direction is allowed.
- Support codes do not change. `SupportCodeStabilityTests` pins them.

### Direction rules

- A target imports only targets with a lower number in the table.
- `ArknightsInfrastructure` imports no other target. It receives limits and policy as init arguments.
- `ArknightsCore` names no feature type. `Shared` and `Core` stay together because `Core` names
  `Shared` types and `Shared` names no `Core` type.
- A feature target never imports `ArknightsLauncherUI`. Composition code passes values and closures down.
- Only these targets link an external product: Installation (`CCommonCrypto`, used by
  `HypergryphManifestCipher.swift`), Audio (`YouTubePlayerKit`, six files), and `LauncherUI`
  (`Sparkle`, used by `LauncherUpdateUserDriver.swift` and `LauncherUpdaterController.swift`).
- A symbol that another target uses gets `package` access. A symbol that only its own target uses
  stays `internal`. The compiler then enforces the direction. The `checks.py` layering check stays
  on until the last checkpoint proves that the compiler enforces every rule.

### Isolation settings

Rule R1 sets the default isolation for each target. Rule R2 sets `NonisolatedNonsendingByDefault`.

| Target                      | Default isolation                | `NonisolatedNonsendingByDefault`                                  | Reason                                                                                          |
| --------------------------- | -------------------------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `ArknightsInfrastructure`   | nonisolated                      | After audit of `BoundedFileReader` and `HTTPChunkSession` callers  | Network, file, and hashing code must not run on the main actor.                                 |
| `ArknightsCore`             | nonisolated                      | After audit                                                        | Mixed content. `LauncherLifecycleStore` and views keep explicit `@MainActor`.                    |
| `ArknightsCustomization`    | nonisolated                      | After the `Task.detached` offloads are `@concurrent`               | Image I/O runs off the main actor (12 `Task.detached` sites, `CustomizationImageIO.swift`).      |
| `ArknightsGameInstallation` | nonisolated                      | After the `@concurrent` audit                                      | Installer, hashing, and compatibility code run off the main actor. Controllers keep `@MainActor`. |
| `ArknightsGameRuntime`      | nonisolated                      | After the `@concurrent` audit                                      | Wine and prefix work run off the main actor. The Playtime and Storage views keep `@MainActor`.   |
| `ArknightsAudio`            | `.defaultIsolation(MainActor.self)` | After audit                                                     | The controller, `YouTubePlayerKit` calls, and the views run on the main actor. Confirm at C20.   |
| `ArknightsOnboarding`       | `.defaultIsolation(MainActor.self)` | After audit                                                     | The coordinator and the step views run on the main actor. `OnboardingProgressStore` may need `nonisolated`. Confirm at C21. |
| `ArknightsLauncherUI`       | `.defaultIsolation(MainActor.self)` | After audit                                                     | Views, `LauncherViewModel`, and Sparkle callbacks run on the main actor.                         |
| `ArknightsClient`           | `.defaultIsolation(MainActor.self)` | After audit                                                     | The app entry point and the delegate run on the main actor.                                      |

Rules:

- Turn on `NonisolatedNonsendingByDefault` for one target at a time. First mark each function that
  must leave the caller's actor `@concurrent`. Record each changed function in the checkpoint.
- Replace each `Task.detached(priority:) { … }.value` offload with a `@concurrent` function in the
  target that owns it.
- Do not turn on `.defaultIsolation(MainActor.self)` for a target that holds `Sendable` value types
  or off-main work, unless each such type is marked `nonisolated`.

### Resource owner

`ArknightsCore` owns the SwiftPM resources (decision O-3). `AppResourceBundle` moves into this target
and uses this target's `Bundle.module`. `Resources/` moves with it. `scripts/lib/project_config.py`
reports the one target that declares resources. Scripts read the resource path from `project_config`.
They never hard-code `Sources/ArknightsClient/...`.

## Platform boundary

The native side runs on Apple Silicon and macOS 15 or newer. The packaged Wine runtime is x86-64.
Before launch, the launcher verifies that macOS can run an Intel process through Rosetta 2.

Wine receives a private prefix, a private Unix home, private temporary directories, and only the
selected game directory, as `G:`. The prefix reduces accidental access to host files. It is not a macOS
security sandbox. See [Runtime compatibility](../../help/runtime-compatibility.md) and
[Storage](../../help/storage.md).

> [!WARNING]
> Never describe the Wine prefix as a security boundary equal to App Sandbox. The Windows client can
> access a custom game directory by design. The runtime also runs native macOS binaries under the
> launcher's user account.

## Change guide

Before you change behavior, find its owner and external contract:

| Change                                 | Start here                                         | Also update or verify                                                                                                         |
| -------------------------------------- | -------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Game files, manifests, paths           | `Features/Game/Installation`                       | [Installation architecture](installation.md), installer tests                                                                 |
| Wine startup, prefix, process, display | `Features/Game/Runtime`                            | [Launch and process lifecycle](launch-and-process-lifecycle.md), [Runtime compatibility](../../help/runtime-compatibility.md) |
| Compatibility wrapper or bridge        | `Features/Game/Compatibility` and `RuntimeSupport` | restore/update behavior, runtime notices, release validation                                                                  |
| Publisher endpoint, refresh            | `LauncherAPI` and `LauncherRefreshController`      | [Communication and boundaries](communication-and-boundaries.md), live contracts                                               |
| Persisted setting, app-owned path      | `LauncherPreferencesStore` or `AppPaths`           | [Data and persistence](data-and-persistence.md), storage tests                                                                |
| Launcher activity or lifecycle state   | `Core/Lifecycle`                                   | [Launch and process lifecycle](launch-and-process-lifecycle.md), lease tests                                                  |
| User-facing copy                       | owning feature's `…Strings` namespace              | English literals and accessibility review                                                                                     |

Run focused checks while you iterate. Follow [Testing architecture](../testing.md) before a full
release validation. A change to the runtime layout, a prefix migration, or installer safety is complete
only after a reviewer checks the fixture-backed tests and a manual compatibility check passes.
