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

- The launcher's signal color is a single accent, sampled from the active hero artwork by default; Arknights cyan `#18D1FF` is the fallback whenever no artwork is loaded or no accent can be extracted, and stays available as a user-facing option to turn dynamic theming off.
- Black and steel are used for fallback surfaces and readable text.
- Native controls provide Liquid Glass, focus, hover, and keyboard behavior.
- Primary and download actions use native capsule shapes; branding remains rectangular.
- Install, Update, and Play use the accent color as a prominent Liquid Glass tint; secondary actions stay neutral.
- Avoid fake window chrome, decorative metadata, large status slogans, and rounded card grids.
- The Endfield launcher is only a layout reference. Its yellow palette is not part of this app.
- Crossfade artwork, theme colors, primary actions, and compact status pills with short native transitions; Reduce Motion replaces movement and scaling with opacity or no animation.

## Settings and documents

- Use a compact material navigation rail for General, Audio, Updates, Installation, Storage, and About.
- Keep navigation neutral. The selected section uses a quiet graphite fill and a two-pixel cyan marker rather than the system accent color.
- Keep links and ordinary controls monochrome; cyan indicates progress or a primary game action.
- Group related controls in quiet Liquid Glass panels instead of form-style gray boxes.
- Explain destructive or expensive actions in user terms. Repair checks every game file and downloads missing or damaged files again.
- Keep developer terminology out of the interface; diagnostics may refer to launcher and Wine logs because users need those names when reporting a problem.
- Render bundled Markdown as native text. Tables may scroll horizontally, but headings and ordinary paragraphs must fit the document width.
- Link the author and repository directly from About.
- About links to the project's Ko-fi page as an optional way to support development.

## Dock menu

- Offer Play only for installed regions and disable every Play entry during refreshes or while another launcher or game operation is active.
- Route Dock launches through the normal region refresh and game-launch guards. Open the main window when an update, Rosetta, or another recovery step needs user attention.
- Keep Settings available as a native keyboard-accessible menu action.

## First-run setup

- Present setup as an operation briefing inside the launcher window: a persistent route on the left, one focused task on the right, and the active installation status inside the relevant step.
- Check for a newer launcher before explaining version-specific settings. If one exists, stop setup at the update action until the newer launcher is installed and reopened.
- Verify functional Intel execution through Rosetta 2 after the launcher preflight. Explain macOS 27 upgrade and Legacy Game Test Mode recovery before the first game launch.
- Let the official game download continue while the user configures display, artwork, theme, icons, updates, and audio. Do not duplicate installer progress or cancellation state inside the setup module.
- Apply choices immediately through the same actions used in Settings. A skipped or completed assistant can be opened again from Settings → General.
- End with a plain statement that the launcher is an unofficial community project. Route launcher, Wine, and embedded-browser reports to the pre-filled GitHub form; route account, payment, and game-service issues to official Yostar support.

## Artwork

The default image comes from the official Global launcher configuration and is cached locally. It is not committed or included in the DMG.

The service currently exposes one active image rather than a playlist. Do not manufacture a carousel from historical CDN URLs. If the official API adds an ordered image collection later, the home screen may crossfade that collection and turn the wordmark rail into a timed position indicator.

A user can choose a local image. The app copies that image into its Application Support folder, so moving the original does not break the launcher. Public releases must not bundle official wallpapers without explicit permission; the [Global Fan Kit terms](https://www.arknights.global/fankit/precautions) do not clearly permit redistribution inside third-party software.

## Notices

When the official configuration enables a notice, present its HTML as native formatted text once per app launch. Never execute notice content in a web view.

## App icon

The source icon is an Icon Composer document with separate structure, glass glyph, and cyan signal layers. Packaging includes an asset-catalog rendition so macOS 26 recognizes the icon instead of placing a legacy ICNS on a gray backing plate.

Launcher and game operator presets are independent. The Launcher gallery uses its dark navy plate, signal corner, and glass facet around the operator. The Game gallery places the operator over the bundled crystalline cyan launcher background. Dynamic Theme recolors only a Launcher operator preset; it never modifies the Game icon. A local image can override either destination without changing the other.

Settings gives Launcher Icon and Game Icon their own operator and local-image actions. Each action opens an isolated picker for its destination and previews only the icon that will change. Artwork remains a separate gallery destination without an in-gallery mode switch.

The Wine game process uses the original executable icon for **Use Default**, but scales it to the same 412/512 visual grid as the launcher and other native Dock icons. Preset and custom game icons use the same normalized canvas. Never patch icon resources inside `Arknights.exe`.
