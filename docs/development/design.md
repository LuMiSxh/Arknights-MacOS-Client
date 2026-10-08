---
title: Design
description: Interface and interaction principles for the native macOS launcher
order: 20
---

# Design

The launcher must feel like a current macOS app first and an Arknights launcher second.

## Home

- Let the artwork fill the window and extend beneath the native traffic-light area. Add no title strip.
- Anchor the official Arknights wordmark below the traffic lights at the upper left. Keep the native Settings control at the upper right.
- Keep one compact, capsule-shaped Liquid Glass control bar at the bottom. When a HUD surface expands, use a fixed-radius rounded rectangle so rows and controls have room.
- Show only the current state, version, and one primary action.
- Show download progress in the same bar. The rail follows the outer pill edge with a protected inner inset, so text, rail, and actions share one geometry. In the compact state, show the percentage first, then transfer size, speed, and remaining time.
- Put repair, paths, display options, and legal information in Settings.

## Visual language

- The signal color is a single accent, sampled from the active hero artwork by default. Use Arknights cyan `#18D1FF` only as the fallback when no dynamic color is available. Controls never introduce cyan independently.
- Use black and steel for fallback surfaces and text. Native controls provide Liquid Glass, focus, hover, and keyboard behavior.
- Primary and download actions use native capsule shapes. Branding stays rectangular.
- Install, Update, and Play use the dynamic artwork accent as a prominent Liquid Glass tint. Dynamic accents can also mark progress, selection, and interaction highlights. Secondary actions use quiet filled neutral surfaces with a restrained macOS 26-style border.
- Disabled controls use the muted surface, border, and foreground from the shared control matrix. A disabled default action must differ from a normal secondary or danger action.
- Identical controls, surfaces, spacing, radii, and states come from `Shared/UI` tokens and components. Feature views provide state and semantics only.
- Neutral panels carry ordinary content. Success, warning, and danger tones mark only the state they explain.
- Avoid fake window chrome, decorative metadata, large status slogans, and rounded card grids. The Endfield launcher is only a layout reference; do not use its yellow palette.

### Motion

- Motion must feel physical and springy, never decorative for its own sake. Pick a semantic curve from `LauncherMotion` (`press`, `release`, `hover`, `state`, `morph`, `expansion`, `reveal`, `present`, `dismiss`, `crossfade`), not a raw duration. Every curve resolves to no animation under Reduce Motion. `LauncherMotion.fade` keeps a quiet opacity change where a state change would otherwise be missed.
- Controls answer touch immediately: a critically damped press to `LauncherMotion.pressedScale`, a springy release that slightly overshoots, and a small hover lift. Prominent capsule actions add a pointer-following sheen tinted by their foreground. Reduce Motion keeps only the opacity dip and centers the sheen. Reduce Transparency removes it.
- The primary operation morphs between states: the capsule springs to the new width and the glyph uses Magic Replace. A ready Play shows a slow breathing accent halo. Download progress draws a soft glow at the outline's leading edge. Work without measurable progress circles an accent glint around an outline that breathes on the Play halo's cycle. A finished installation sends one success ripple from its checkmark.
- HUD pills rise out of the control bar with a staggered blur-and-scale entrance and leave faster. On macOS 26 they share one glass group.
- Status, version, and music HUDs keep the shared `expansion` spring. Expanded content materialises from the top trailing corner. Sibling pills recede while one panel is open.
- Overlays such as the update dialog spring in from a softened, slightly lower and smaller state and dismiss quickly. Native sheets keep their platform lifecycle. `ThemedModalView` content fades up from a soft blur while the accent rule draws across the header.
- Artwork and theme colors use `crossfade`; new artwork resolves from a light blur. Settings pages do not animate card insertion, progress stays linear, and frequent search-result updates use a quiet transition.
- Continuous decorative motion (breathing halo, progress sweep) runs only through `DecorativeMotionClock` while `decorativeMotionEnabled` is true. It pauses when the window is hidden, occluded, or inactive and never exceeds 30 frames per second.

## Interaction contract

The home screen exposes one primary operation at a time. The current state selects its action:

| State                               | Action                    |
| ----------------------------------- | ------------------------- |
| Selected region absent or partial   | **Install** or **Resume** |
| Cancellable download                | **Pause**                 |
| Newer game manifest available       | **Update**                |
| Region ready                        | **Play**                  |
| The region's game session is active | **Stop**                  |

These actions reuse one control, never compete as buttons, and secondary controls stay neutral.

Installation, update, repair, prefix preparation, and game launch share one exclusive activity gate. A background refresh must not start a second file operation, launch a game during installation, or replace the active region's state with a stale request. Update checks never download game data until the user selects the update action.

Each region owns its game directory and installed manifest. The home action and status capsule show only the active region. Regions share the Wine prefix only within their publisher family. Launching a region must first repoint that family's `G:` drive. See [Installation architecture](architecture/installation.md) and [Launch and process lifecycle](architecture/launch-and-process-lifecycle.md).

Present failures in the shared failure dialog with actionable guidance and matching recovery actions. For blocking failures, the status capsule shows **Needs Attention** and **Details** and does not duplicate error text, support codes, or Rosetta recovery controls. During onboarding, keep Rosetta prerequisites and installation recovery in the setup step. Do not turn a transient check failure into an install or play action.

## Accessibility and input

- Give every icon-only control an accessible label and a useful hint. Visible and VoiceOver labels describe the same action.
- Keep settings, gallery items, document links, and modal Done actions keyboard reachable. A focused primary action stays focused when its title changes.
- Use semantic controls, not gesture-only or hover-only actions. Return and Space never trigger Play or Install from an unrelated focused control.
- Respect Reduce Motion, Reduce Transparency, Differentiate Without Color, VoiceOver, Full Keyboard Access, and the largest practical text size. State changes must stay clear without animation, color, or precise pointer input.
- Let English labels wrap. Avoid fixed-width labels and truncation that hides the operation or error name.
- Rendered Markdown uses the native default pointer on text and links, so no I-beam appears over documents.

## Feedback and review

Use native controls and the shared action families in `Shared/UI/Components` before you add a feature-local variant. Only a different interaction contract justifies a custom control, not padding or tint. Keep primary emphasis on the current game action; secondary links, settings, diagnostics, and legal text stay quiet.

For a UI change, use the debug simulator to check an empty and an installed region, an active operation, and a failure and recovery path. Repeat with keyboard navigation, VoiceOver, Reduce Motion, and normal and large text. The release matrix is in [Testing architecture](testing.md#manual-compatibility-matrix).

## Modals and popups

- Use a quiet modal header with a restrained neutral rule. The current operation owns the only prominent action color.
- Keep modal actions in a floating footer with a clear default and neutral dismiss and support actions. Use a second row when they do not fit.
- Keep native confirmation dialogs for destructive or system actions. A custom modal explains context and recovery and does not replace the system confirmation.

## Settings and documents

- Use a compact list navigation rail for Game, Appearance, Audio, Updates, Installation, Storage, Playtime, and About. Game opens first.
- Keep the rail quiet: the selected section uses a graphite fill with a dynamic accent marker and selected label and icon. Hover stays neutral.
- Group related controls in quiet Liquid Glass panels, not form-style gray boxes. Use native capsules for settings controls and shared neutral capsules for secondary actions.
- Switch Settings pages immediately, without scale, card, or other page transitions.
- Warning and danger panels keep neutral backgrounds. Semantic color is limited to the header, icon, edge, and relevant actions: danger for destructive settings and failure codes, warning for cautionary state, success for completed state, and the dynamic accent for the primary operation and intentional selection or highlight.
- Explain destructive or expensive actions in user terms, for example: Repair checks every game file and downloads missing or damaged files again.
- Keep developer terminology out of the interface. Diagnostics can name launcher and Wine logs, which users need when they report a problem.
- Render bundled Markdown as native text, parsed once when the document opens. Tables adapt their column widths and can scroll horizontally. Headings and paragraphs must fit the document width. Missing or unreadable documents show an explicit error state.
- Link the author and repository directly from About. About also links to the project's Ko-fi page as an optional way to support development.
- Present About documents as a low-height shelf when space allows, stacked when narrow. Keep legal and publisher links in a quiet trust rail below support information.

## Dock menu

- Offer Play only for installed regions. Disable every Play entry during refreshes and other launcher or game operations.
- Route Dock launches through the normal refresh and launch guards. Open the main window when an update, Rosetta, or another recovery step needs attention.
- Keep Settings available as a native, keyboard-accessible menu action.

## First-run setup

- Present setup as an operation briefing in the launcher window: a persistent route on the left, one task on the right, and installation status inside the relevant step.
- Check for a newer launcher first. If one exists, stop setup at the update action until the user installs and reopens it.
- Verify functional Intel execution through Rosetta 2 after the launcher preflight. Explain macOS 27 beta-only Legacy Game Test Mode recovery without presenting it as a stable-OS step.
- Let the game download continue while the user configures display, artwork, theme, icons, updates, and audio. Do not duplicate installer progress or cancellation in setup.
- Walk through System Check, Region, Display, Look, Updates & Audio, and Ready. Ask each question as answer cards (`OnboardingQuestion`): one answer, several answers with checkboxes, or action cards with a chevron that open a chooser. Mark the recommended answer. End Display with a one-sentence summary.
- Write copy for non-technical players. Titles, answers, and summaries describe what the player notices and contain no numbers. A technical name such as Retina or MetalFX can follow as a quiet secondary label. Exact values belong in Settings and `help:` tooltips.
- Apply choices immediately through the same actions as Settings. Users can reopen a skipped or completed assistant from Settings → Installation.
- Save the current step with raw values from 10 upward. Earlier launcher steps no longer decode, so setup resumes at System Check.
- When a release requires returning players to rerun setup, open with a "Something important changed" briefing that explains why, and hide Skip Setup until they finish. First runs stay skippable.
- End with a plain statement that the launcher is an unofficial community project. Route launcher, Wine, and embedded-browser reports to the pre-filled GitHub form. Route account, payment, and game-service issues through the [publisher support routing table](../help/README.md#publisher-support-routing).

## Artwork

The default image comes from the official Global launcher configuration and is cached locally. Neither the repository nor the DMG includes it.

The service exposes one active image, not a playlist. Do not build a carousel from historical CDN URLs. If the API adds an ordered collection, the home screen may crossfade it and turn the wordmark rail into a timed position indicator.

> [!WARNING]
> A user can choose a local image. The app copies it into its Application Support folder. Public releases must not bundle official wallpapers without explicit permission. The [Global Fan Kit terms](https://www.arknights.global/fankit/precautions) do not clearly permit redistribution inside third-party software.

## Notices

> [!WARNING]
> When the official configuration enables a notice, present its HTML as native formatted text once per app launch. Never execute notice content in a web view.

## App icon

The source icon is an Icon Composer document with separate structure, glass glyph, and signal layers. Packaging includes an asset-catalog rendition so macOS 26 does not place a legacy ICNS on a gray backing plate.

An operator preset applies a matched pair, a Launcher icon and a Game icon from the same avatar. The Launcher gallery uses a dark navy plate, signal corner, and glass facet around the operator. The Game gallery places the operator over the bundled crystalline launcher background. Dynamic Theme recolors only a Launcher operator preset, never the Game icon. A local image overrides one destination and ends automatic preset refreshes. Imported images keep their aspect ratio, centered inside the 412/512 canvas. Gallery controls use Settings' neutral search, filter, preview, and dismissal language. Semantic system icons carry meaning without decorative color.

Settings gives Launcher Icon and Game Icon separate operator and local-image actions. Each opens an isolated picker that previews only the icon that changes. Artwork stays a separate gallery destination without a mode switch.

> [!IMPORTANT]
> For **Use Default**, the Wine game process uses the original executable icon, scaled to the same 412/512 visual grid as the launcher and native Dock icons. Preset and custom game icons use the same canvas. Never patch icon resources inside `Arknights.exe`.
