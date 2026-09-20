---
title: Design
description: Interface and interaction principles for the native macOS launcher
order: 20
---

# Design

The launcher should feel like a current macOS app first and an Arknights launcher second.

## Home

- Let the artwork fill the window.
- Extend the artwork beneath the native traffic-light area; do not add a separate title strip.
- Anchor the official Arknights wordmark below the traffic lights at the upper-left corner.
- Keep the native Settings control in the upper-right corner.
- Keep one compact, capsule-shaped Liquid Glass control bar at the bottom; when a HUD surface expands, use a fixed-radius rounded rectangle so its rows and controls have room to breathe.
- Show only the current state, version, and one primary action.
- The primary-action slot changes between **Install**, **Pause**, **Resume**, **Update**, **Play**, and **Stop** as the selected region moves through installation and game-session states.
- Download progress appears in the same control bar; the progress rail follows the outer pill edge with a protected inner inset so text, rail, and action controls share one geometry.
- Keep the progress percentage first in the compact download state, with transfer size, speed, and remaining time subordinate to it.
- Put repair, paths, display options, and legal information in Settings.

## Visual language

- The launcher's signal color is a single accent, sampled from the active hero artwork by default. Arknights cyan `#18D1FF` is used only as the fallback when no dynamic color is available; controls do not introduce cyan independently.
- Black and steel are used for fallback surfaces and readable text.
- Native controls provide Liquid Glass, focus, hover, and keyboard behavior.
- Primary and download actions use native capsule shapes; branding remains rectangular.
- Install, Update, and Play use the dynamic artwork accent as a prominent Liquid Glass tint. Dynamic artwork or theme accents may also mark progress, the current selection, and interaction highlights. Secondary actions use quiet filled neutral surfaces with a restrained macOS 26-style border treatment.
- Disabled controls use an explicit muted surface, border, and foreground from the shared control matrix. A disabled default action must remain visually distinct from a normal secondary or danger action.
- Identical controls, surfaces, spacing, radii, and state treatments come from `Shared/UI` design tokens and components. Feature views provide state and semantics only.
- Keep semantic panels quiet: neutral panels carry ordinary content, while success, warning, and danger tones are reserved for the state they explain.
- Avoid fake window chrome, decorative metadata, large status slogans, and rounded card grids.
- The Endfield launcher is only a layout reference. Its yellow palette is not part of this app.
- Crossfade artwork, theme colors, primary actions, and compact status pills with short native transitions; Reduce Motion replaces movement and scaling with opacity or no animation.
- Keep expansion motion consistent across status, version, and music HUDs: collapsed surfaces stay compact capsules, expanded surfaces use the same fixed-radius panel geometry, and Reduce Motion removes the expansion movement.
- Use a short spring only for structural pill expansion. Native sheets, modals, and controls keep their platform lifecycles; settings pages do not animate card insertion, progress stays linear within its rail, and frequent search-result updates use a quiet opacity transition.

## Interaction contract

The home screen exposes one primary operation at a time. Its action is derived from the current state: **Install** or **Resume** when the selected region is absent or partial, **Pause** during a cancellable download, **Update** when a newer game manifest is available, **Play** when the region is ready, and **Stop** while that region's game session is active. These actions reuse one control and never appear as competing buttons. Secondary controls remain neutral.

Installation, update, repair, prefix preparation, and game launch share one exclusive activity gate. A refresh may report state in the background, but it must not start a second file operation, launch a game during installation, or replace the active region's state with a stale request. Update checks may discover a new version; they never download game data without the user selecting the update action.

Each region owns its game directory and installed manifest. The active region is the only one shown in the home action and status capsule. Regions share the configured Wine prefix only within their publisher family, and launching a region must repoint that family's `G:` drive first. See [Installation architecture](architecture/installation.md) and [Launch and process lifecycle](architecture/launch-and-process-lifecycle.md) for the implementation boundary.

Report failures in the same status area as the operation that failed. Keep the message actionable, expose **Report a Problem** when diagnostic context is available, and leave recovery actions such as **Check Again**, **Repair**, or Rosetta installation next to the relevant state. Do not turn a transient check failure into an install or play action.

## Accessibility and input

- Give every icon-only control an accessible label and a useful hint; visible labels and VoiceOver labels should describe the same action.
- Keep all settings, gallery items, document links, and modal Done actions keyboard reachable. A focused primary action must remain the focused control when its title changes between Install, Pause, Resume, Play, and Stop.
- Use semantic controls instead of gesture-only or hover-only actions. Never make Return or Space trigger Play or Install from an unrelated focused control.
- Respect Reduce Motion, Reduce Transparency, Differentiate Without Color, VoiceOver, Full Keyboard Access, and the largest practical text size. A state change must remain understandable without animation, color, or precise pointer input.
- Keep English labels free to wrap. Avoid fixed-width labels and truncation that hides the operation or error name.
- Rendered Markdown uses the native default pointer on text and links so text selection does not leave an I-beam cursor over document content.

## Feedback and review

Use native controls and the shared action families in `Shared/UI/Components` before adding a feature-local variant. A custom control is justified only when the interaction contract differs, not merely because its padding or tint is different. Keep primary emphasis on the current game action; secondary links, settings, diagnostics, and legal text should remain quiet.

For a UI change, exercise the affected state through the debug simulator where possible, then check both an empty and an installed region, an active operation, and a failure/recovery path. Repeat with keyboard navigation, VoiceOver, Reduce Motion, and both normal and large text before release. The detailed release matrix lives in [Testing architecture](testing.md#manual-compatibility-matrix).

## Modals and popups

- Use a quiet modal header with a restrained neutral rule. The current operation owns the only prominent action color.
- Keep modal actions in a floating footer with a clear default action and neutral dismiss/support actions. Use a responsive second row when the action set cannot fit at the preferred width.
- Keep native confirmation dialogs for destructive or system actions. A custom modal explains context and recovery; it does not replace the system confirmation contract.

## Settings and documents

- Use a compact list navigation rail for General, Audio, Updates, Installation, Storage, and About.
- Keep the navigation rail quiet. The selected section uses a quiet graphite fill with a dynamic accent marker and selected label/icon; hover remains neutral.
- Keep links and ordinary controls quiet; use the dynamic accent for progress, the current primary game action, selected state, and intentional interaction highlights.
- Group related controls in quiet Liquid Glass panels instead of form-style gray boxes. Use native capsules for settings controls and shared neutral capsules for secondary actions.
- Switch Settings pages immediately without scale, card, or other decorative page transitions.
- Warning and danger panels keep quiet neutral backgrounds; semantic color is limited to the header, icon, edge, and relevant actions.
- Use semantic colors consistently: danger for destructive settings and failure codes, warning for cautionary state, success for completed state, and the dynamic accent for the current primary operation and intentional selection or highlight state.
- Explain destructive or expensive actions in user terms. Repair checks every game file and downloads missing or damaged files again.
- Keep developer terminology out of the interface; diagnostics may refer to launcher and Wine logs because users need those names when reporting a problem.
- Render bundled Markdown as native text. Parse each document once when it opens. Tables adapt their column widths and may scroll horizontally, but headings and ordinary paragraphs must fit the document width. Missing or unreadable documents show an explicit error state.
- Link the author and repository directly from About.
- About links to the project's Ko-fi page as an optional way to support development.
- Present About documents as a low-height document shelf when space allows, with a stacked fallback for narrow widths. Keep legal and publisher links in a quiet trust rail below support information.

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
- End with a plain statement that the launcher is an unofficial community project. Route launcher, Wine, and embedded-browser reports to the pre-filled GitHub form; route account, payment, and game-service issues through the [publisher support routing table](../help/README.md#publisher-support-routing).

## Artwork

The default image comes from the official Global launcher configuration and is cached locally. It is not committed or included in the DMG.

The service currently exposes one active image rather than a playlist. Do not manufacture a carousel from historical CDN URLs. If the official API adds an ordered image collection later, the home screen may crossfade that collection and turn the wordmark rail into a timed position indicator.

> [!WARNING]
> A user can choose a local image. The app copies that image into its Application Support folder, so moving the original does not break the launcher. Public releases must not bundle official wallpapers without explicit permission; the [Global Fan Kit terms](https://www.arknights.global/fankit/precautions) do not clearly permit redistribution inside third-party software.

## Notices

> [!WARNING]
> When the official configuration enables a notice, present its HTML as native formatted text once per app launch. Never execute notice content in a web view.

## App icon

The source icon is an Icon Composer document with separate structure, glass glyph, and signal layers. Packaging includes an asset-catalog rendition so macOS 26 recognizes the icon instead of placing a legacy ICNS on a gray backing plate.

Launcher and game operator presets are independent. The Launcher gallery uses its dark navy plate, signal corner, and glass facet around the operator. The Game gallery places the operator over the bundled crystalline launcher background. Dynamic Theme recolors only a Launcher operator preset; it never modifies the Game icon. A local image can override either destination without changing the other. Gallery controls use the same neutral search, filter, preview, and dismissal language as Settings; semantic system icons carry meaning without adding decorative color.

Settings gives Launcher Icon and Game Icon their own operator and local-image actions. Each action opens an isolated picker for its destination and previews only the icon that will change. Artwork remains a separate gallery destination without an in-gallery mode switch.

> [!IMPORTANT]
> The Wine game process uses the original executable icon for **Use Default**, but scales it to the same 412/512 visual grid as the launcher and other native Dock icons. Preset and custom game icons use the same normalized canvas. Never patch icon resources inside `Arknights.exe`.
