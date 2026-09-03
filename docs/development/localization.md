---
title: Localization
description: English source copy and reviewed German translation workflow
order: 30
---

# Localization

The native launcher defaults to the preferred language configured by macOS, including the per-app language override in System Settings. Onboarding and General settings can override that choice with English or German immediately; the launcher stores this preference independently. English is the authoritative source language and fallback; German is the first reviewed translation.

The website documentation is currently English-only and is not part of the native String Catalog workflow. Keep repository source, Markdown documentation, and contributor-facing comments in English. Localize user-visible launcher copy through the catalogs instead of adding a second hard-coded language path.

> [!IMPORTANT]
> The launcher UI is localized, but technical identifiers and third-party content are not. Keep file names, paths, serialized values, API fields, log messages, error codes, terminal commands, Wine and registry identifiers, official game or operator names, and remote Yostar content unchanged. Bundled licenses and third-party notices remain verbatim unless an authoritative localized source is available.

## Source and generated files

> [!IMPORTANT]
> The Apple String Catalogs in `Sources/ArknightsClient/Resources` are the source of truth for copy. `CFBundleDevelopmentRegion` and `CFBundleLocalizations` in `Resources/Info.plist` define the source and shipping languages. `Package.swift` processes the catalogs as SwiftPM resources. The localization check reads and cross-validates all three instead of maintaining a separate language list in Python.

Large features may own a dedicated catalog; closely related smaller surfaces may share `Localizable.xcstrings`. Use stable symbolic keys namespaced by the owning feature, such as `onboarding.action.continue` or `settings.installation.repair`. English copy and translator comments belong in the catalogs; every shipping translation must be reviewed by a fluent speaker.

The current catalogs are `Localizable.xcstrings`, `Launcher.xcstrings`, `Settings.xcstrings`, and `Customization.xcstrings`. The validation script requires every catalog to declare source language `en`, every key to use the feature-namespaced dotted form (`lowerCamelCase` segments), a non-empty translator comment, and a translated, non-empty value for both `en` and `de`. `CFBundleLocalizations` must declare that same shipping locale set; `just check` rejects drift between the catalogs, `Package.swift`, and `Resources/Info.plist`. Keep related keys in the catalog owned by the feature that presents them; the file name is part of the generated symbol namespace.

SwiftPM copies the catalogs into its resource bundle, but Apple's command-line SwiftPM integration does not currently compile them into the `.strings` resources that Foundation uses for lookup. The supported `just` build, test, preview, and packaging commands therefore run `scripts/localization.py compile` after SwiftPM builds and before consuming the bundle. The same commands generate the type-safe Swift declarations in `Shared/Localization/GeneratedStringSymbols_*.swift` on demand. These ignored files carry a catalog fingerprint and are regenerated only when missing or stale.

> [!WARNING]
> Do not edit generated symbols directly. A normal command prepares them automatically; force a local regeneration after changing the generation pipeline with:

```sh
just format localization
```

The generated symbols are not repository state. A pristine checkout is ready through the documented `just` commands without adding thousands of derived lines to reviews.

## Adding or changing copy

1. Add or update the catalog key, English value, translator comment, and every shipping translation.
2. Regenerate the catalog outputs.
3. Expose the generated symbol through the owning feature's small `…Strings` namespace. Do not create one application-wide hand-written strings type.
4. Use `LocalizedStringResource` in SwiftUI. Convert it with `L10n.string` only when an API requires a concrete `String`.
5. Verify English, German, and English fallback for unsupported locales. Check interpolated values and accessibility labels as well as visible text.

For interpolated copy, preserve the same placeholder meaning and ordering in every language. Prefer the generated resource function's typed arguments (for example, a version, region, or byte count) over string concatenation. Keep technical values such as paths, URLs, version numbers, and error codes as arguments or code spans so translators do not have to rewrite them.

The normal local sequence is:

```sh
just format localization
just check
```

`just format localization` runs Apple's `xcstringstool` and refreshes ignored generated Swift symbols. `just check` validates catalog structure, Swift formatting, unit tests, scripts, and the runtime configuration. `just ci` adds deterministic integration tests and the release Swift build. A changed catalog is not complete until the generated symbols are current and the affected UI has been reviewed in both languages.

> [!WARNING]
> Copy changes are incomplete until all shipping translations are reviewed and the generated files are current. Japanese and Korean catalog entries must not ship until native review is available.

Do not use a translated string as a persistence key, JSON value, file name, UserDefaults key, API field, or test fixture identifier. Keep those contracts in stable English/code values and localize only the presentation layer. If a string is supplied by Yostar or another third party, preserve it as received unless the feature explicitly formats it as native text.

## Layout review

German copy is often longer than English. Prefer flexible layout, wrapping, and semantic controls over fixed text widths. Before release, review onboarding, installation, Settings, alerts, confirmations, support actions, and VoiceOver labels in both languages. Use Xcode's expanded pseudo-language when performing the final clipping review; it is a layout aid, not a shipping translation.

Check stateful copy as well as the initial screen: checking, downloading, paused, failed, update available, Rosetta recovery, empty galleries, and destructive confirmations. A translated accessibility label must still identify the object and action without relying on its icon or color. When a value is hidden or abbreviated visually, expose the complete localized value to VoiceOver where it is useful.
