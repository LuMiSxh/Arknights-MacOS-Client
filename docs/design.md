# Design

The launcher should feel like a current macOS app first and an Arknights launcher second.

## Home

- Let the artwork fill the window.
- Extend the artwork beneath the native traffic-light area; do not add a separate title strip.
- Anchor the official Arknights wordmark below the traffic lights at the upper-left corner.
- Keep the native Settings control in the upper-right corner.
- Keep one compact, capsule-shaped Liquid Glass control bar at the bottom.
- Show only the current state, version, and one primary action.
- The primary action changes between **Install**, **Update**, and **Play**.
- Download progress appears in the same control bar; there is no recurring download screen.
- Put repair, paths, display options, and legal information in Settings.

## Visual language

- Arknights cyan `#18D1FF` is the only signal color.
- Black and steel are used for fallback surfaces and readable text.
- Native controls provide Liquid Glass, focus, hover, and keyboard behavior.
- Primary and download actions use native capsule shapes; branding remains rectangular.
- Install, Update, and Play use cyan prominent Liquid Glass; secondary actions stay neutral.
- Avoid fake window chrome, decorative metadata, large status slogans, and rounded card grids.
- The Endfield launcher is only a layout reference. Its yellow palette is not part of this app.

## Settings and documents

- Use a compact material navigation rail for General, Installation, and About.
- Keep navigation neutral. The selected section uses a quiet graphite fill and a two-pixel cyan marker rather than the system accent color.
- Keep links and ordinary controls monochrome; cyan indicates progress or a primary game action.
- Group related controls in quiet Liquid Glass panels instead of form-style gray boxes.
- Explain destructive or expensive actions in user terms. Repair checks every game file and downloads missing or damaged files again.
- Keep developer terminology out of the interface; diagnostics may refer to launcher and Wine logs because users need those names when reporting a problem.
- Render bundled Markdown as native text. Tables may scroll horizontally, but headings and ordinary paragraphs must fit the document width.
- Link the author and repository directly from About.

## Artwork

The default image comes from the official Global launcher configuration and is cached locally. It is not committed or included in the DMG.

The service currently exposes one active image rather than a playlist. Do not manufacture a carousel from historical CDN URLs. If the official API adds an ordered image collection later, the home screen may crossfade that collection and turn the wordmark rail into a timed position indicator.

A user can choose a local image. The app copies that image into its Application Support folder, so moving the original does not break the launcher. Public releases must not bundle official wallpapers without explicit permission; the [Global Fan Kit terms](https://www.arknights.global/fankit/precautions) do not clearly permit redistribution inside third-party software.

## Notices

When the official configuration enables a notice, present its HTML as native formatted text once per app launch. Never execute notice content in a web view.

## App icon

The source icon is an Icon Composer document with separate structure, glass glyph, and cyan signal layers. Packaging includes an asset-catalog rendition so macOS 26 recognizes the icon instead of placing a legacy ICNS on a gray backing plate.
