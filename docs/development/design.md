---
title: Design
description: Interface and interaction principles for the native macOS launcher
order: 20
---

# Design

The launcher must feel like a current macOS app. It must feel like an Arknights launcher second.

## Interface rules

Pages that do not follow these rules yet are tracked in [UI rework for 1.0](ui-rework-1.0.md).

### Wording

1. Use sentence case for page subtitles, panel headers, row labels, rail captions, setup question headers, and dialog titles. Use Title Case for buttons and menu items. Keep capitals in feature names, such as Game Mode, Battery Saver, Dynamic Theme, MetalFX, and Discord.
2. Do not end labels, headers, subtitles, or dialog titles with a period. A dialog title may end with "?". Put a full sentence in the detail. Keep periods in paragraphs.
3. Start every button with a verb. Name the object when the row has another action or the action is destructive.
4. Add "…" only when a button opens a dialog, sheet, or panel that asks for input or confirmation. A button that opens a browser, Finder, or Mail has no ellipsis. Give it an external-link icon.
5. Repeat the trigger text, without "…", as the main button of a confirmation.
6. Write a switch label as a noun phrase that names the feature. Write a detail that says what On does.
7. Use these terms for users: server, game environment, runtime, sign-in window, and the game. Name the architecture of a runtime when it matters. Use one term for each concept: rail, page, panel, row, dialog, setup, and docs.
8. Use developer terms (Wine, DXMT, prefix, gamepolicyctl, partial files, and registry) in three places only:
   - A control that selects that technology. Explain the control in user terms.
   - About, in its **Technical details** section, and collapsed expert panels.
   - "(Wine prefix)" once, in a game environment confirmation.
9. Write sizes and times as "120 FPS", "1280 × 720", "50%", and "04:00 server time". Format byte sizes with `ByteCountFormatter`. Show "None" when nothing is stored. Write "and", not "&". Use the typographic apostrophe (’), not the straight one.
10. Use single words for Settings rail page names and rail captions. A setup rail label equals its page title exactly and may wrap.
11. Give each setup question header the same text as its Settings row label.
12. Use different names for adjacent levels. A page and its panel differ. A panel and its only row differ.

### Explanations

13. Give every row a detail when its label does not make the effect obvious. Use one or two sentences of at most 25 words. Write in present tense. Start with what the control does.
14. Never put information needed to choose correctly only in a tooltip. This covers permissions, restarts, when changes apply, and data loss. A tooltip gives background only, in at most 40 words.
15. Show a fact that applies to every row of a page or panel once. Use a page note or a panel footnote.
16. Add one **Learn more** link to each panel that needs a longer explanation. Link it to the matching page in `docs/help`.

### Layout and buttons

17. Place the label and its detail on the left of a row, and the control at the trailing edge. Use the shared footnote component for other text inside a panel.
18. Give a row at most two buttons. Move further choices into a menu.
19. Use a switch for on or off. Use a segmented control for up to three short options. Use a menu for other choices.
20. Place a dependent setting directly below its parent. Hide it while the parent is off. Disable it with a reason when something outside it blocks it.
21. Use the danger tone (red) only for actions that lose data or sign the user out. Such an action always uses the danger tone, `role: .destructive`, an ellipsis, and a confirmation.
22. Use the warning tone and a confirmation for a risky but reversible change. Keep a recoverable action, such as clearing a cache, neutral.
23. Title a confirmation `<Verb> <object>?` and name its scope: the server or the runtime. Say what is lost and what stays, in at most two sentences. Make Cancel the default.
24. Use the accent on the primary action. A normal button may carry an accent hint, such as an icon. Accent buttons have no per-screen limit.

### Disabled, busy, and errors

25. Show the reason for every disabled control in the same panel. Use a detail swap, a panel footnote, or one page banner when the whole page is locked.
26. Write each reason as something the user can do, such as "Quit the game to change these settings." Take every reason from one activity-to-reason mapping.
27. Make disabled controls look disabled. This includes switches, sliders, and tinted buttons.
28. Keep a saved choice that became unavailable selectable as `<Name> (unavailable)`. Its detail says what happens instead.
29. Change a busy button's label, such as to "Checking…". Keep its width. Disable only that button.
30. Show a failure inline under the step or row that failed. Use the shared inline failure component. It states what happened, what to do, and the **Support code**.
31. Show a blocked macOS permission as a status row directly under the feature it blocks. Show the row while that feature is on, or while a denial has turned it off. The row has a warning icon, a sentence-case label without a period, and **Open System Settings**.

### Settings-only

- S1. Order panels on each page: most used first, then an optional collapsed advanced panel, then the **Danger zone** last. Put every destructive action in its page's **Danger zone**.
- S2. Show at most six visible rows in a panel. Split a larger panel by user task.
- S3. Keep page actions inside the page. The floating footer holds only **Done**.
- S4. Name the page and panel in every `docs/help` path. A rename updates `docs/help`, design.md, CHANGELOG.md, and setup in the same change.
- S5. When an override changes a row's effective value, show that value in the row's detail.
- S6. Hide a panel that has no working controls.

### Setup-only

- O1. Use only **Continue**, **Download and Continue**, **Install Update**, or **Finish Setup** as the footer primary button.
- O2. Do not start a download until the server, runtime, and install location are chosen.
- O3. Show Rosetta 2 only while x86_64 is selected.
- O4. Show the questions that matter for the first launch in each step. Put the other options in a collapsed **More options** section. Accepting every default produces a working setup.
- O5. Order setup questions as the Settings pages order them. A setup control that changes a setting uses the same action and label as in Settings.
- O6. Show a running download on every step, with a **Pause** button. **Back** never cancels work.
- O7. A step that cannot continue says why on the page. It offers one action. It never shows an empty panel.
- O8. Make every step and state reachable in the developer preview.
- O9. Move a step transition in the direction of travel, or crossfade.

## Home

- Let the artwork fill the window. Extend it under the traffic lights. Do not add a title strip.
- Show Branding at the upper left. Branding shows the server logo and its scrim. Turn off Branding to hide both.
- Show the Settings button at the upper right.
- Show one compact control bar at the bottom. Make it a capsule. When the HUD expands, use a rounded rectangle with a fixed radius.
- Show only the current state, the version, and one primary action.
- Show download progress in the same bar. Draw the progress rail along the outer edge of the bar, with an inner inset. Use crisp strokes only. Do not add a blurred glow or glint. In the compact state, show the percentage first. Then show transfer size, speed, and remaining time.
- Show a runtime download with the same status line and progress rail as a game download.
- When the installed runtime is older than the launcher's pin, show **Runtime update required** and make the primary action **Update Runtime**.
- Give each Home surface its own Home theme. Home controls and Branding each take Automatic, Dark, or Light. Home ignores the Appearance setting.

## Visual language

### Color roles

- Get every color from a `LauncherTheme` role. Read the theme with `@Environment(\.launcherTheme)`.
- Use these role groups:
  - Text: `textPrimary`, `textSecondary`, `textTertiary`.
  - Surfaces: `groupFill`, `controlFill`, `fieldFill`, `footerFill`.
  - Edges: `hairline`, `dialogHairline`, `controlStroke`, `rowDivider`.
  - Accent: `accentFill` for solid fills, `accentInk` for text and icons on a surface, `onAccent` for text on `accentFill`.
  - Danger: `danger` for solid fills, `dangerInk` for text, `dangerGlassTint` for glass.
- Do not write a color literal or `Color(red:` in a view.
- `LauncherPalette` is being retired. Do not add members to it. Use `LauncherTheme` roles instead.

### Accent

- The accent comes from the artwork. Dynamic Theme sets it.
- The accent marks the current primary operation, progress, selection, and interaction highlights.
- Install, Update, and Play use the accent as a prominent Liquid Glass tint.
- Keep secondary actions, retry buttons that are not the default, and status text neutral. A normal button may carry an accent hint, such as an icon. Links use the accent text role (`accentInk`), including About and the legal links.
- Do not use accent-colored shadows.
- Keep neutrals graphite. Do not tint surfaces, borders, or secondary controls with the accent hue.
- Use `LauncherVisuals.cyan` (#18D1FF) only as the fallback. Use it only when no artwork accent exists. Do not write any other fixed cyan value in UI styling.

### Light and dark mode

- Appearance has three values: System, Light, and Dark. Appearance applies to Settings, setup, and dialogs.
- Home has its own color scheme. Home controls and Branding each use a Home theme.
- Automatic follows the artwork. The score mixes the median brightness of the whole image with the median under the Home controls. The launcher caches the score for each artwork.
- A score between two thresholds keeps the previous choice. This stops the scheme from flickering near a boundary.
- Branding follows its own scheme. In light mode, the scrim is white. The scrim shows only when Branding is on.

### Glass and surfaces

- Guard every macOS 26 Liquid Glass API through `AdaptiveGlass.swift`. Use `adaptiveGlassEffect` and `launcherSurface` there.
- On macOS 26 and later, glass uses Liquid Glass. On macOS 15 to 25, a translucent material replaces it.
- On macOS 27, glass sits on a backplate. The backplate is black in dark mode and white in light mode.
- Danger uses tinted glass. The tint has 36% opacity in dark mode and 40% in light mode. Use `dangerInk` for danger text.
- Secondary actions use quiet filled neutral surfaces with a hairline border. Surfaces use no gradients. The only exception is a small tone shift inside one neutral.
- Do not place blurred blobs behind text. For legibility, use a scrim sized to the content.
- Neutral borders are hairlines at 6–12% opacity. Semantic and high-contrast borders may be stronger.

### Shape, spacing, and type

- Use radius tokens only from `LauncherTokens.Radius`.
- A nested radius equals the outer radius minus the padding. The minimum is 4 pt. Collapsed HUD surfaces and the primary action may use capsules.
- Put every margin, padding, gap, and fixed size on a 4 pt grid. Use a 2 pt step only inside small controls.
- Use one value for each role. Use `LauncherTokens.Spacing.page` (24 pt) for page margins. Use `LauncherTokens.Spacing.section` (20 pt) for section gaps. Use `LauncherTokens.Layout.railWidth` (192 pt) for the Settings and setup rails.
- Use size and color for hierarchy. Use regular and medium weights. Use semibold only for rare emphasis. Do not use bold or heavier. Do not change weight to show selection.
- Use fonts from `LauncherTokens.Typography`. Or use a semantic text style with an allowed weight. Do not write `.system(size:` in a view.

### Selection controls

- Selection controls show their on state in the accent. These controls are toggles, checkboxes, sliders, pickers, and segmented controls.
- Text fields use a neutral surface. A focused text field uses the accent for its border. Do not use a white focus ring.
- Keyboard focus rings use the accent at 90% opacity.

### Segmented controls

Use `AdaptiveSegmentedControl` for every segmented selection. The control follows these rules:

- Give every segment a text label. The label is the accessible name.
- Add an icon to every segment, or to none. The control shows icons only when every segment has one.
- The Appearance control uses icons. Home controls and Branding use text only.
- The selected segment has the selected accessibility trait.
- With Differentiate Without Color on, the selected segment also shows a checkmark.

## Motion

`LauncherMotion` (`Sources/ArknightsCore/Shared/UI/LauncherMotion.swift`) is the only motion source. Views do not use raw curves, springs, or durations. Use these APIs:

- `launcherAnimation(_:value:)` animates a value change with a `LauncherMotion.Role`. The roles are `press`, `release`, `hoverIn`, `hoverOut`, `state`, `select`, `morph`, `present`, and `dismiss`.
- `withLauncherAnimation(_:reduceMotion:hops:_:)` runs a state change with a role.
- `LauncherMotion.Curve` names a purpose for animations that are not roles, such as `crossfade`, `page`, and `disclosure`. Use it with `LauncherMotion.animation(_:reduceMotion:)` and `LauncherMotion.staggered(_:index:reduceMotion:)`.
- `LauncherMotion.Cycle` sets loop periods. The halo pulse and the indeterminate pulse use `Cycle.pulse` (3.2 s). The progress sweep uses its own phase timings.
- `LauncherMotion.fade(reduceMotion:)` returns the state animation. Under Reduce Motion, it returns a 0.15 s fade.

Under Reduce Motion, `launcherAnimation` and `withLauncherAnimation` use a 0.20 s fade. `LauncherMotion.animation(_:reduceMotion:)` and `staggered(_:index:reduceMotion:)` return no animation.

Rules:

- Springs have little or no bounce. Bounce is at most 0.15.
- Controls respond at once. A held control uses `press` and scales to 0.95. Subtle controls, such as segments, scale to 0.97. A released control uses `release`.
- A hovered control changes its surface or opacity. Do not scale or lift a control on hover.
- The primary action shows at most one ambient effect: a still accent halo. The halo plays one pulse when it appears. Its blur is 4.8–8 pt and its accent opacity is 0.11–0.25. It has no repeating loop. Show the halo only for an enabled Play.
- Controls show no pointer-following sheen.
- Overlays, such as the update dialog, enter with `present` and leave with `dismiss`. Overlays and the control bar enter with opacity and a small scale of 0.96. Native sheets keep their platform motion.
- Use the `.replace` symbol effect for symbol changes. Do not use the `.magic` symbol effect.
- Selection moves between items with `select`. The segmented thumb moves this way. The Settings rail slides the selected row between rows.
- Artwork and theme colors use `crossfade`. Settings pages do not animate card insertion. Determinate progress stays linear.

## Motion gating

`ContinuousMotion` (`Sources/ArknightsCore/Shared/UI/Components/ContinuousMotion.swift`) drives all continuous decorative motion. It updates at most 30 times per second. Use it for every loop, such as the progress sweep, the indeterminate pulse, the skeleton pulse, and the music title scroll. Do not add another timer or animation loop for decorative motion.

`DecorativeMotionVisibility` closes the motion gate when:

- The app is inactive or hidden.
- The window is not visible, is miniaturized, or is occluded.
- The game runs. This rule applies to every loop, including loops inside sheets.
- Low Power Mode is on.

Rules:

- A closed gate freezes each loop's phase. The loop resumes from that phase when the gate opens.
- Reduce Motion also freezes the loop. A caller can pass a fixed phase for Reduce Motion (`reducedMotionPhase`).
- The Home layer pauses its loops while a sheet, the update overlay, or setup covers it. Loops inside sheets and overlays run when the other conditions allow it.

## Interaction contract

The Home screen shows one primary operation at a time. The current state selects its action:

| State                               | Action                    |
| ----------------------------------- | ------------------------- |
| Selected server absent or partial   | **Install** or **Resume** |
| Cancellable download                | **Pause**                 |
| Newer game manifest available       | **Update**                |
| Selected runtime absent             | **Set Up Runtime**        |
| Server ready                        | **Play**                  |
| The server’s game session is active | **Stop**                  |

Use one control for these actions. Secondary controls stay neutral. Update checks never download game data. A download starts only when the user selects the update action. **Play** stays disabled until the selected runtime is installed and the server is ready.

Each server owns its game directory and installed manifest. The Home action and status capsule show only the active server. See [Installation architecture](architecture/installation.md) and [Launch and process lifecycle](architecture/launch-and-process-lifecycle.md).

Show a failure inline under the step or row that failed, using the shared inline failure component. Give actionable guidance and matching recovery actions. For a blocking failure, the status capsule shows **Needs attention** and a **Show Details** action. The capsule does not repeat the error text, the support code, or the Rosetta recovery controls. During setup, keep the Rosetta prerequisites and the installation recovery in the setup step. Do not turn a transient check failure into an install or play action.

## Accessibility and input

- Give every icon-only control an accessible label and a useful hint. The visible label and the VoiceOver label describe the same action.
- Keep settings, gallery items, document links, and modal Done actions reachable by keyboard. A focused primary action keeps focus when its title changes.
- Use semantic controls. Do not use gesture-only or hover-only actions. Return and Space never start Play or Install from an unrelated focused control.
- Support Reduce Motion, Reduce Transparency, Differentiate Without Color, VoiceOver, Full Keyboard Access, and the largest practical text size. State changes must stay clear without animation, color, or precise pointer input.
- Let English labels wrap. Do not use fixed-width labels. Do not truncate a label when the truncation hides the operation or the error name.

## Copy

- Write the version as "Version 1.2.3". Do not use a "v" prefix.
- Use one label for each action.
- **Runtime** is a user term for the files that run the game. Name the runtime (x86_64 or ARM64) when a choice or state depends on it. Do not use Wine internals to explain it.
- An advanced compatibility or display option names the technology it controls. Examples are MetalFX and Wine sync.
- Danger zones and destructive confirmations name the scope they change, such as the server, the runtime, or the game environment.

## Feedback and review

Use native controls first. Use the shared components in `Sources/ArknightsCore/Shared/UI/Components` before you add a local variant. Create a custom control only for a different interaction contract. Padding and tint do not justify a custom control. Keep primary emphasis on the current game action. Keep secondary actions, settings, diagnostics, and legal text quiet. Links still use `accentInk`.

For a UI change, use the debug simulator. Check these states: an empty region, an installed region, an active operation, and a failure with its recovery path. Repeat the checks with keyboard navigation, VoiceOver, Reduce Motion, and normal and large text. The release matrix is in [Testing architecture](testing.md#manual-compatibility-matrix).

## Modals and popups

- Use a quiet modal header with a hairline rule. The current operation owns the only prominent action color.
- Put modal actions in a floating footer. Make one action the default. Use neutral styles for dismiss and support actions. Use a second row when the actions do not fit.

## Settings and documents

- The Settings sheet adapts to the window size. `AppConstants.Settings` sets its margin and size limits.
- Group related controls in quiet glass panels. Switch Settings pages at once. Do not use page transitions. The selected rail row uses the accent.
- Use a grouped list rail. The Arknights group holds Game, Installation, Runtime, Storage, and Playtime. The Launcher group holds Appearance, Integration, and Updates. In Integration, the panels are Notifications, Music, Screenshots, and Discord. The Notifications panel holds the daily reset reminder, a server menu limited to installed servers, and a status row with **Open System Settings** when macOS blocks notifications. Help and About follow. Debug builds add Developer. Game opens first. Later, Settings reopens the last page while the app runs.
- In Settings → Runtime, panels appear in this order: Active runtime, Maintenance, Compatibility, Runtime patches, and Danger zone. The Active runtime panel shows each runtime with its summary and marks the selected one with a checkmark. A secondary line shows the installed version, the download size while the runtime is not installed, and the macOS requirement only when this Mac does not meet it. **ARM64 (Apple Silicon)** shows a **Recommended** badge beside its title. The panel offers **Switch to x86_64** or **Switch to ARM64**. While a runtime downloads, the panel offers **Pause**; a paused download shows **Resume**. While the game runs, a page banner gives the reason. While another operation runs, a footnote in each affected panel gives it. The Maintenance panel offers **Update Runtime** when the runtime is outdated and the Rosetta 2 status for the x86_64 runtime. The Compatibility panel holds the Wine sync setting and is always expanded. The Danger zone holds **Remove Runtime…** and **Remove Other Runtime…**. It asks for confirmation, keeps the game environment, and shows a failure inline with a support code. A switch that needs a download uses the same warning as setup. The new runtime applies at the next game launch. The page links to **Game runtime** with **About game runtimes**.
- Installation shows a page banner while the launcher is busy. It holds **Server**, **Location**, **Maintenance**, and a **Danger zone**. Location holds one row, **Game files**. Its detail shows the install folder and the install status, such as **Installed**. The row also holds **Show in Finder** and the **Change…** menu. Maintenance offers **Repair**. The Danger zone holds **Uninstall Game…**, which names the server in its confirmation. The **Canary Features** panel appears only while a server needs it.
- In Settings → Appearance, panels appear in this order: Artwork, Dynamic Theme, Appearance, Launcher shows, and Dock icons. The Dynamic Theme panel holds three rows: Follow the artwork, Home controls, and Branding.
- The Look step of setup asks for Artwork and Dynamic Theme. Its **More options** section asks for Home controls, Branding, Appearance, Launcher shows, and Dock icons, in that order.
- In Settings → Storage, panels appear in this order: Game installations, Shared runtime data, Recreatable caches, Logs and data, and Measurements. The page has no Danger zone. **Clear Caches** and **Clear Gallery Cache** are neutral. The Logs and data panel holds **Show Logs** and **App Data Folder** with **Show in Finder**. The Measurements panel holds **Refresh sizes**.
- In Settings → Game, a page note says changes apply the next time the game starts. The Performance panel holds **Frame rate limit** as a segmented control. The Battery Saver panel holds **Battery Saver mode** and, while it is on, **Battery Saver frame rate limit**. Battery Saver applies whenever it is on. While **Override in-game display settings** is off, the affected rows say so in their detail.
- The Updates page holds Automatic checks (**Launcher updates** and **Game updates**) and Project news (**Announcements**). About shows **Show in Finder**, **View on GitHub**, and **Donate**. **Technical details** holds the Wine, DXMT, and capability rows.
- In Settings → Help, the Troubleshooting panel holds Setup assistant, **Debug logging**, and **Rebuild**. **Rebuild** is neutral and asks for confirmation. Help also holds **Report** and **Get help**. Its Danger zone holds **Delete Environment…** and **Reset All Settings…**.
- In Settings → Runtime, the Runtime patches panel follows Compatibility. It uses the warning tone and holds one toggle per patch the selected runtime contains, then **Restore Defaults**. Turning a patch off opens a destructive confirmation that warns the game may break and how to undo it. Turning it on needs no warning. While a game runs, the page banner locks the panel.
- Explain destructive or expensive actions in user terms.
- Keep warning and danger panels on neutral backgrounds. Use semantic color only on the header, icon, edge, and relevant actions. Read every semantic color from `LauncherTheme`:
  - Danger: actions that lose data or sign the user out. Text uses `dangerText`. A danger button label uses `dangerInk`. A solid HUD or icon fill uses `dangerSurface`. Danger glass uses `dangerGlassTint` and `dangerGlassStroke`.
  - Warning: cautionary state, such as a risky but reversible change. Text and icons use `warningInk`. A solid fill or toggle uses `warning`. Warning glass uses `warningGlassTint` and `warningGlassStroke`.
  - Success: completed state. Text and icons use `successInk`.
  - Accent: the primary operation and intentional selection.
- Light mode darkens `dangerText`, `warningInk`, and `successInk` to at least 4.5:1 on the light sheet. Dark mode keeps the brand values.
- For a custom game window size, choose the **Custom…** row. Enter a width and height, or measure the game window. The launcher validates the size with `GameDisplaySize.validatedCustom`. It keeps the value you enter. It fits the size to the screen only at launch.
- Render bundled Markdown as native text. Parse it once when the document opens. Tables fit their column widths and scroll sideways when they are wide. A missing or unreadable document shows an error state.

## Dock menu

- Show a Play entry for each installed region. Disable every Play entry while a refresh or another launcher or game operation runs.
- Route a Dock launch through the normal refresh and launch guards. Open the main window when the launch does not start. For example, open it when an update, Rosetta, or another recovery step needs attention.

## First-run setup

- Present setup as an operation briefing in the launcher window. The left column shows the route. The right column shows one task. Installation status appears inside its step.
- Check for a newer launcher first. If one exists, stop setup at the update action. The user installs it and reopens the launcher. System Check checks nothing else.
- Verify Intel execution through Rosetta 2 in the Install step, only while x86_64 is selected. Explain the macOS 27 beta-only Legacy Game Test Mode recovery. Do not present it as a stable-OS step.
- Ask the daily reset reminder question in Updates and Integrations. The answers are Off (recommended), At reset, and 1 hour before. Ask macOS for notification permission only when the user picks a reminder, and keep Off if macOS refuses.
- Walk through these steps in order: System Check, Server, Install, Display, Look, Updates and Integrations, and Ready. The Install step covers the runtime, the install location, and Rosetta 2 for x86_64. Ask each question with an answer card (`OnboardingQuestion`). Use one answer, several answers with checkboxes, or action cards that open a chooser. Mark the recommended answer. End Display with a one-sentence summary.
- Each step shows its main choices. Put secondary options under a collapsed **More options** section. A step with no secondary options has no **More options** section. In Updates and Integrations, music is one on/off question; volume and **Now playing** sit under **More options**.
- The rail shows a running download on every step. The game download offers **Pause**, and **Resume** when partial files exist. The runtime download offers **Pause** while it downloads and **Resume** after a pause. **Back** never cancels work.
- While setup is visible, failures of setup-started work show inline under the item that failed, with the shared inline failure component. This covers the game install and update, the Rosetta 2 check and install, and the runtime install. The Home failure sheet waits and shows any pending failure when setup closes. When the game download fails on any step, the rail shows "Download failed" with the support code and **Retry**.
- The page title equals the rail label. A step change enters from the side of travel, and the old page fades. Reduce Motion fades only.
- The Server step starts no download and shows no **Canary Features** panel. It notes that each server has its own publisher and that anti-cheat may block or flag the game on a Mac. Global stays preselected. The Install step opens with "Installs <server> from <publisher>." Its footer is **Download and Continue** when the game or runtime is missing, otherwise **Continue**. The game download and runtime install start only there.
- The Install step offers **ARM64 (Apple Silicon)** and **x86_64**. Mark **ARM64 (Apple Silicon)** as **Recommended** when it is offered. Show the installed version, download size, and macOS requirement for each choice. **Download and Continue** installs the selected runtime. On older macOS, show only x86_64 and state that ARM64 requires macOS 26 or later. The step links to **Game runtime** with **About game runtimes**.
- Before a lane change in setup or Settings, show the runtime switch warning. Show it only when a game environment exists. It states that the runtimes use separate game environments, that the game may treat the switch as a fresh install and ask for sign-in and resources again, and that the switch can add a download. Apply the warning in both directions.
- Apply each choice at once. Use the same actions as Settings. The user reopens the assistant from Settings → Help → Troubleshooting.
- When a release requires a rerun, open with a "Something important changed" briefing. Explain why. The rerun reuses the current server, runtime, location, and preferences. It downloads nothing unless one of them changes. Hide Skip Setup until the user finishes. First runs stay skippable.
- End with a plain statement: the launcher is an unofficial community project. Route launcher, game compatibility, and embedded-browser reports to the pre-filled GitHub form. Route account, payment, and game-service issues through the [publisher support routing table](../help/README.md#publisher-support-routing).

## Artwork

The default image comes from the official Global launcher configuration. The launcher caches it locally. Neither the repository nor the DMG includes it. The service exposes one active image, not a playlist. Do not build a carousel from historical CDN URLs.

> [!WARNING]
> A user can choose a local image. The app copies it into its Application Support folder. Do not bundle official wallpapers in public releases without explicit permission. The [Global Fan Kit terms](https://www.arknights.global/fankit/precautions) do not clearly permit redistribution inside third-party software.

## Notices

> [!WARNING]
> When the official configuration enables a notice, show its HTML as native formatted text. Show it once for each app launch. Never run notice content in a web view.

## App icon

The source icon is an Icon Composer document. It has three layers: structure, glass glyph, and signal. The packaging includes an asset-catalog version. This version stops macOS 26 from placing a legacy ICNS on a gray backing plate.

An operator preset gives a matched pair: a Launcher icon and a Game icon from the same avatar. Dynamic Theme recolors only the Launcher icon of an operator preset. It never recolors the Game icon. A local image replaces one destination. It also ends automatic preset refreshes.

Settings offers one **Choose Operator…** action for both icons. It also offers a **Custom icons** row with one menu for each icon.

> [!IMPORTANT]
> For **Use Default**, the Wine game process uses the original executable icon. The icon scales to the same 412/512 visual grid as the launcher and native Dock icons. Preset and custom game icons use the same canvas. Never patch icon resources inside `Arknights.exe`.
