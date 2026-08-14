# Design

The launcher should feel like a current macOS app first and an Arknights launcher second.

## Home

- Let the artwork fill the window.
- Extend the artwork beneath the native traffic-light area; do not add a separate title strip.
- Use one angular wordmark with a cyan rail for identity.
- Keep one compact Liquid Glass control bar at the bottom.
- Show only the current state, version, and one primary action.
- The primary action changes between **Install**, **Update**, and **Play**.
- Download progress appears in the same control bar; there is no recurring download screen.
- Put repair, paths, display options, and legal information in Settings.

## Visual language

- Arknights cyan `#18D1FF` is the only signal color.
- Black and steel are used for fallback surfaces and readable text.
- Native controls provide Liquid Glass, focus, hover, and keyboard behavior.
- Primary and download actions use native capsule shapes; branding remains rectangular.
- Avoid fake window chrome, decorative metadata, large status slogans, and rounded card grids.
- The Endfield launcher is only a layout reference. Its yellow palette is not part of this app.

## Artwork

The default image comes from the official Global launcher configuration and is cached locally. It is not committed or included in the DMG.

A user can choose a local image. The app copies that image into its Application Support folder, so moving the original does not break the launcher. Public releases must not bundle official wallpapers without explicit permission; the [Global Fan Kit terms](https://www.arknights.global/fankit/precautions) do not clearly permit redistribution inside third-party software.
