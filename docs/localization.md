# Localization

The native launcher defaults to the preferred language configured by macOS, including the per-app language override in System Settings. Onboarding and General settings can override that choice with English or German immediately; the launcher stores this preference independently. English is the authoritative source language and fallback; German is the first reviewed translation.

The launcher UI is localized, but technical identifiers and third-party content are not. Keep file names, paths, serialized values, API fields, log messages, error codes, terminal commands, Wine and registry identifiers, official game or operator names, and remote Yostar content unchanged. Bundled licenses and third-party notices remain verbatim unless an authoritative localized source is available.

## Source and generated files

The Apple String Catalogs in `Sources/ArknightsClient/Resources` are the source of truth for copy. `CFBundleDevelopmentRegion` and `CFBundleLocalizations` in `Resources/Info.plist` define the source and shipping languages. `Package.swift` processes the catalogs as SwiftPM resources. The localization check reads and cross-validates all three instead of maintaining a separate language list in Python.

Large features may own a dedicated catalog; closely related smaller surfaces may share `Localizable.xcstrings`. Use stable symbolic keys namespaced by the owning feature, such as `onboarding.action.continue` or `settings.installation.repair`. English copy and translator comments belong in the catalogs; every shipping translation must be reviewed by a fluent speaker.

SwiftPM compiles the catalogs into the shipping `.strings` resources. Apple's command-line SwiftPM integration does not generate the type-safe Swift declarations, so the supported `just` build, test, preview, and packaging commands generate `Shared/Localization/GeneratedStringSymbols_*.swift` on demand. These ignored files carry a catalog fingerprint and are regenerated only when missing or stale.

Do not edit generated symbols directly. A normal command prepares them automatically; force a local regeneration after changing the generation pipeline with:

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

Copy changes are incomplete until all shipping translations are reviewed and the generated files are current. Japanese and Korean catalog entries must not ship until native review is available.

## Layout review

German copy is often longer than English. Prefer flexible layout, wrapping, and semantic controls over fixed text widths. Before release, review onboarding, installation, Settings, alerts, confirmations, support actions, and VoiceOver labels in both languages. Use Xcode's expanded pseudo-language when performing the final clipping review; it is a layout aid, not a shipping translation.
