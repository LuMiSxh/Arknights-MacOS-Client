---
title: Design
description: Interface and interaction principles for the native macOS launcher
order: 20
---

# Design

The launcher must feel like a current macOS app first, and an Arknights launcher second.

## Interface rules

### Wording

1. Use sentence case for page subtitles, panel headers, row labels, rail captions, setup questions, and dialog titles. Use Title Case for buttons and menu items. Keep capitals in feature names, such as Game Mode, Battery Saver, Dynamic Theme, MetalFX, and Discord.
2. Do not end a label, header, subtitle, or dialog title with a period. A dialog title may end with "?". Keep periods in paragraphs.
3. Start every button with a verb. Name the object when the row has another action or the action is destructive.
4. Add "…" only when a button opens a dialog, sheet, or panel that asks for input or confirmation. A button that opens a browser, Finder, or Mail has no ellipsis and carries an external-link icon.
5. Repeat the trigger text, without "…", as the main button of a confirmation.
6. Write a switch label as a noun phrase naming the feature. Write a detail that says what On does.
7. Use these user terms: server, game environment, runtime, sign-in window, and the game. Name the runtime architecture when it matters. Use one term for each concept: rail, page, panel, row, dialog, setup, and docs.
8. Use developer terms (Wine, DXMT, prefix, gamepolicyctl, partial files, and registry) only in a control that selects that technology, in the Runtime page's **Details** panel, in collapsed expert panels, or as "(Wine prefix)" once in a game environment confirmation. Explain such a control in user terms.
9. Write sizes and times as "120 FPS", "1280 × 720", "50%", and "04:00 server time". Format byte sizes with `ByteCountFormatter` and show "None" when nothing is stored. Write "and", not "&". Use the typographic apostrophe (’).
10. Use single words for Settings rail page names and captions. A setup rail label equals its page title exactly and may wrap.
11. Give each setup question header the same text as its Settings row label.
12. Use different names for adjacent levels. A page and its panel differ, and a panel and its only row differ.

### Explanations

13. Give every row a detail when the label does not make the effect obvious: one or two present-tense sentences of at most 25 words, starting with what the control does.
14. Never put information needed to choose correctly only in a tooltip. This covers permissions, restarts, when changes apply, and data loss. A tooltip gives background only, in at most 40 words.
15. Show a fact that applies to every row of a page or panel once, in a page note or a panel footnote.
16. Add one **Learn more** link to each panel that needs a longer explanation, pointing at the matching page in `docs/help`.

### Layout and buttons

17. Place the label and detail on the left of a row and the control at the trailing edge. Use the shared footnote component for other text inside a panel.
18. Give a row at most two buttons. Move further choices into a menu.
19. Use a switch for on or off, a segmented control for up to three short options, and a menu for other choices.
20. Place a dependent setting directly below its parent. Hide it while the parent is off, and disable it with a reason when something outside it blocks it.
21. Use the danger tone (red) only for actions that lose data or sign the user out. Such an action always uses the danger tone, `role: .destructive`, an ellipsis, and a confirmation.
22. Use the warning tone and a confirmation for a risky but reversible change. Keep a recoverable action, such as clearing a cache, neutral.
23. Title a confirmation `<Verb> <object>?` and name its scope: the server or the runtime. Say what is lost and what stays, in at most two sentences. Make Cancel the default.
24. Use the accent on the primary action. A normal button may carry an accent hint, such as an icon. Accent buttons have no per-screen limit.

### Disabled, busy, and errors

25. Show the reason for every disabled control in the same panel: a detail swap, a panel footnote, or one page banner when the whole page is locked.
26. Write each reason as something the user can do, such as "Quit the game to change these settings." Take every reason from one activity-to-reason mapping.
27. Make disabled controls look disabled, including switches, sliders, and tinted buttons.
28. Keep a saved choice that became unavailable selectable as `<Name> (unavailable)`, with a detail that says what happens instead.
29. Change a busy button's label, such as to "Checking…", and keep its width. Disable only that button.
30. Show a failure inline under the step or row that failed, using the shared inline failure component. It states what happened, what to do, and the **Support code**.
31. Show a blocked macOS permission as a status row directly under the feature it blocks, while that feature is on or while a denial turned it off. The row has a warning icon, a sentence-case label without a period, and **Open System Settings**.
32. Use a blocking startup notice when saved data cannot be migrated. Give it a sentence-case title, one sentence of action, and only the actions that resolve it, such as **Delete Data Folder** and **Quit**. Do not offer ordinary dismissal.

### Settings-only

- S1. Order panels on each page: most used first, then an optional collapsed advanced panel, then the **Danger zone** last. Put every destructive action in its page's **Danger zone**. A menu picker in a **Danger zone** tints its chevron chip with the danger role, not the accent.
- S2. Show at most six visible rows in a panel. Split a larger panel by user task.
- S3. Keep page actions inside the page. The floating footer holds only **Done**.
- S4. Name the page and panel in every `docs/help` path. A rename updates `docs/help`, design.md, CHANGELOG.md, and setup in the same change.
- S5. When an override changes a row's effective value, show that value in the row's detail.
- S6. Hide a panel that has no working controls.

### Setup-only

- O1. Use only **Continue**, **Download and Continue**, **Install Update**, or **Finish Setup** as the footer primary button.
- O2. Do not start a download until the server, runtime, and install location are chosen.
- O3. Show Rosetta 2 only while x86_64 is the runtime in use. Explain the macOS 27 beta-only Legacy Game Test Mode recovery, and never present it as a stable-OS step.
- O4. Show the questions that matter for the first launch in each step. Put the other options in a collapsed **More options** section. Accepting every default produces a working setup.
- O5. Order setup questions as the Settings pages order them. A setup control that changes a setting uses the same action and label as in Settings.
- O6. Show a running download on every step, with **Pause** and **Resume** actions. **Back** never cancels work.
- O7. A step that cannot continue says why on the page. It offers one action. It never shows an empty panel.
- O8. Make every step and state reachable in the developer preview.
- O9. Move a step transition in the direction of travel, or crossfade.

## Home

- Let the artwork fill the window and extend it under the traffic lights. Do not add a title strip.
- Show Branding at the upper left: the server logo and its scrim. Turn off Branding to hide both. Show Settings at the upper right.
- Show one compact control bar at the bottom as a capsule, or as a rounded rectangle with a fixed radius while the HUD expands.
- Show only the current state, the version, and one primary action.
- Show download progress in the same bar, with the progress rail along the outer edge and an inner inset. Use crisp strokes only, with no blurred glow or glint. In the compact state show the percentage first, then transfer size, speed, and remaining time.
- Show a runtime download with the same status line and progress rail as a game download.
- Do not show a completion message after an install. Home moves straight to the next state.
- When the installed runtime is older than the launcher's pin, show **Runtime update required** and make the primary action **Update Runtime**. When the game is installed and the selected runtime is missing, show **Runtime setup required** and make the primary action **Set Up Runtime**.
- Give each Home surface its own Home theme. Home controls and Branding each take Automatic, Dark, or Light. Home ignores the Appearance setting.

## Visual language

### Color roles

- Get every color from a `LauncherTheme` role, read with `@Environment(\.launcherTheme)`. Do not write a color literal or `Color(red:` in a view.
- Role groups:
  - Text: `textPrimary`, `textSecondary`, `textTertiary`.
  - Surfaces: `groupFill`, `controlFill`, `trackFill`, `footerFill`.
  - Edges: `hairline`, `dialogHairline`, `controlStroke`, `rowDivider`.
  - Accent: `accentFill` for solid fills, `accentInk` for text and icons on a surface.
  - Danger: `danger` for solid fills, `dangerText` for text, `dangerInk` for a label on a danger button, `dangerGlassTint` for glass.

### Accent

- The accent comes from the artwork, and Dynamic Theme sets it. It marks the current primary operation, progress, selection, and interaction highlights. Install, Update, and Play use it as a prominent Liquid Glass tint.
- Keep secondary actions, non-default retry buttons, status text, surfaces, borders, and secondary controls neutral. A normal button may carry an accent hint, such as an icon. Links, including About and the legal links, use `accentInk`.
- Do not use accent-colored shadows or tint neutrals with the accent hue.
- Use `LauncherVisuals.cyan` (#18D1FF) only when no artwork accent exists. Write no other fixed cyan value.

### Light and dark mode

- Appearance is System, Light, or Dark, and applies to Settings, setup, and dialogs.
- Home has its own color scheme. Home controls and Branding each use a Home theme.
- Automatic follows the artwork: the score mixes the median brightness of the whole image with the median under the Home controls, and the launcher caches it per artwork.
- A score between two thresholds keeps the previous choice, so the scheme does not flicker near a boundary.
- Branding follows its own scheme. In light mode the scrim is white, and the scrim shows only when Branding is on.

### Glass and surfaces

- Guard every macOS 26 Liquid Glass API through `AdaptiveGlass.swift`, using `adaptiveGlassEffect` and `launcherSurface`.
- On macOS 26 and later, glass uses Liquid Glass; on macOS 15 to 25, a translucent material replaces it. On macOS 27, glass sits on a backplate: black in dark mode and white in light mode.
- Danger uses tinted glass at 36% opacity in dark mode and 40% in light mode, with `dangerInk` for danger text.
- Secondary actions use quiet filled neutral surfaces with a hairline border. Surfaces use no gradients except a small tone shift inside one neutral.
- Do not place blurred blobs behind text. Use a scrim sized to the content.
- Neutral borders are hairlines at 6–12% opacity. Semantic and high-contrast borders may be stronger.

### Shape, spacing, and type

- Use radius tokens only from `LauncherTokens.Radius`. A nested radius equals the outer radius minus the padding, with a 4 pt minimum. Collapsed HUD surfaces and the primary action may use capsules.
- Put every margin, padding, gap, and fixed size on a 4 pt grid, with a 2 pt step only inside small controls.
- Use one value for each role: `LauncherTokens.Spacing.page` (24 pt) for page margins, `LauncherTokens.Spacing.section` (20 pt) for section gaps, and `LauncherTokens.Layout.railWidth` (192 pt) for the Settings and setup rails.
- Use size and color for hierarchy, with regular and medium weights. Use semibold only for rare emphasis; never bold or heavier, and never a weight change to show selection.
- Use fonts from `LauncherTokens.Typography`, or a semantic text style with an allowed weight. Do not write `.system(size:` in a view.

### Selection controls

- Toggles, checkboxes, sliders, pickers, and segmented controls show their on state in the accent.
- Text fields use a neutral surface. A focused field uses the accent for its border, not a white focus ring.
- Keyboard focus rings use the accent at 90% opacity.

### Segmented controls

`AdaptiveSegmentedControl` handles every segmented selection:

- Every segment takes a text label, which is its accessible name.
- Add an icon to every segment, or to none. The control shows icons only when every segment has one.
- The Appearance control uses icons. Home controls and Branding use text only.
- The selected segment has the selected accessibility trait, and shows a checkmark with Differentiate Without Color on.

## Motion

`LauncherMotion` (`Sources/ArknightsCore/Shared/UI/LauncherMotion.swift`) is the only motion source. Views do not use raw curves, springs, or durations.

- `launcherAnimation(_:value:)` animates a value change with a `LauncherMotion.Role`: `press`, `release`, `hoverIn`, `hoverOut`, `state`, `select`, `morph`, `present`, and `dismiss`. `withLauncherAnimation(_:reduceMotion:hops:_:)` runs a state change with a role.
- `LauncherMotion.Curve` names a purpose for animations that are not roles, such as `crossfade`, `page`, and `disclosure`. Use it with `LauncherMotion.animation(_:reduceMotion:)` and `LauncherMotion.staggered(_:index:reduceMotion:)`.
- `LauncherMotion.Cycle` sets loop periods. The halo and indeterminate pulses use `Cycle.pulse` (3.2 s); the progress sweep uses its own phase timings.
- `LauncherMotion.fade(reduceMotion:)` returns the state animation, which is a 0.15 s fade under Reduce Motion.

Under Reduce Motion, `launcherAnimation` and `withLauncherAnimation` use a 0.20 s fade, and `animation(_:reduceMotion:)` and `staggered(_:index:reduceMotion:)` return no animation.

Rules:

- Springs have little or no bounce, at most 0.15.
- Controls respond at once. A held control uses `press` and scales to 0.95, or 0.97 for subtle controls such as segments. A released control uses `release`.
- A hovered control changes its surface or opacity. Do not scale or lift it on hover.
- The primary action shows at most one ambient effect: a still accent halo that plays one pulse when it appears, with a 4.8–8 pt blur, 0.11–0.25 accent opacity, and no repeating loop. Show the halo only for an enabled Play.
- Controls show no pointer-following sheen.
- Overlays, such as the update dialog, enter with `present` and leave with `dismiss`. Overlays and the control bar enter with opacity and a small 0.96 scale. Native sheets keep their platform motion.
- Use the `.replace` symbol effect, never `.magic`.
- Selection moves between items with `select`: the segmented thumb and the Settings rail slide the selected row.
- Artwork and theme colors use `crossfade`. Settings pages do not animate card insertion. Determinate progress stays linear.

## Motion gating

`ContinuousMotion` (`Sources/ArknightsCore/Shared/UI/Components/ContinuousMotion.swift`) drives all continuous decorative motion, at most 30 times per second, for every loop: the progress sweep, the indeterminate and skeleton pulses, and the music title scroll. Do not add another timer or animation loop for decorative motion.

`DecorativeMotionVisibility` closes the gate when the app is inactive or hidden, the window is not visible, miniaturized, or occluded, the game runs (including loops inside sheets), or Low Power Mode is on.

- A closed gate freezes each loop's phase, which resumes when the gate opens.
- Reduce Motion also freezes the loop; a caller can pass a fixed `reducedMotionPhase`.
- The Home layer pauses its loops while a sheet, the update overlay, or setup covers it. Loops inside sheets and overlays run when the other conditions allow.

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

Use one control for these actions, and keep secondary controls neutral. Update checks never download game data, and a download starts only when the user selects the update action. **Play** stays disabled until the selected runtime is installed and the server is ready.

After a runtime update, the launcher updates the game environments of installed servers in the background, with no status or progress. **Play** stays enabled and cancels it. The server switcher stays available; other locked controls show "Wait for the game environment update to finish."

Each server owns its game directory and installed manifest, and the Home action and status capsule show only the active server. See [Installation architecture](architecture/installation.md) and [Launch and process lifecycle](architecture/launch-and-process-lifecycle.md).

Show a failure inline under the step or row that failed, as rule 30 requires, with actionable guidance and matching recovery actions. For a blocking failure, the status capsule shows **Needs attention** and **Show Details**, without repeating the error text, the support code, or the Rosetta recovery controls. During setup, keep the Rosetta prerequisites and the installation recovery in the setup step. Do not turn a transient check failure into an install or play action.

## Accessibility and input

- Give every icon-only control an accessible label and a useful hint. The visible label and the VoiceOver label describe the same action.
- Keep settings, gallery items, document links, and modal Done actions reachable by keyboard. A focused primary action keeps focus when its title changes.
- Use semantic controls, never gesture-only or hover-only actions. Return and Space never start Play or Install from an unrelated focused control.
- Support Reduce Motion, Reduce Transparency, Differentiate Without Color, VoiceOver, Full Keyboard Access, and the largest practical text size. State changes stay clear without animation, color, or precise pointer input.
- Let English labels wrap. Do not use fixed-width labels or truncate a label when that hides the operation or the error name.

## Copy

- Write the version as "Version 1.2.3", without a "v" prefix.
- Use one label for each action.
- **Runtime** is the user term for the files that run the game. Name it (x86_64 or ARM64) when a choice or state depends on it, and do not explain it with Wine internals.
- An advanced compatibility or display option names the technology it controls, such as MetalFX or Wine sync.
- Danger zones and destructive confirmations name the scope they change: the server, the runtime, or the game environment.

## Feedback and review

Use native controls first, then the shared components in `Sources/ArknightsCore/Shared/UI/Components`. Create a custom control only for a different interaction contract; padding and tint do not justify one. Keep primary emphasis on the current game action, and keep secondary actions, settings, diagnostics, and legal text quiet. Links still use `accentInk`.

For a UI change, use the debug simulator and check an empty region, an installed region, an active operation, and a failure with its recovery path. Repeat with keyboard navigation, VoiceOver, Reduce Motion, and normal and large text. The release matrix is in [Testing architecture](testing.md).

## Modals and popups

- Use a quiet modal header with a hairline rule. The current operation owns the only prominent action color.
- Put modal actions in a floating footer with one default action, neutral dismiss and support actions, and a second row when they do not fit.

## Settings and documents

- The Settings sheet adapts to the window size; `AppConstants.Settings` sets its margin and size limits.
- The rail strip shows the current game operation and a runtime install, with the same title as the Runtime page.
- Group related controls in quiet glass panels. Switch pages at once without transitions, and mark the selected rail row with the accent.
- The grouped rail holds Game, Installation, Runtime, Storage, and Playtime (Arknights), then Appearance, Integration, and Updates (Launcher), then Help and About, with Developer in debug builds. Integration holds Notifications, Music, Screenshots, and Discord. Game opens first; later, Settings reopens the last page while the app runs.
- Notifications holds the daily reset reminder, a server menu limited to installed servers, and a status row with **Open System Settings** when macOS blocks notifications.
- Runtime panels appear as Active runtime, Maintenance, Compatibility, Runtime patches, and Danger zone.
  - Active runtime shows only the runtime the launcher chose, with its summary and a checkmark once it is installed. It has no picker. A secondary line shows the installed version, the download size while the runtime is not installed, and the macOS requirement only when this Mac does not meet it. The panel offers **Download** while the runtime is missing, **Pause** while it downloads, and **Resume** on a paused download. A footnote notes a runtime that the user chose in the Danger zone. While the game runs, a page banner gives the reason; while another operation runs, a footnote in each affected panel gives it.
  - Maintenance offers **Update Runtime** when the runtime is outdated, and the Rosetta 2 status for the x86_64 runtime. It is hidden when it has neither.
  - Compatibility holds the Wine sync setting and is always expanded.
  - Runtime patches follows Compatibility, uses the warning tone, opens with a note to keep the defaults unless you know what a patch does, and holds one toggle per patch the selected runtime contains, then **Restore Defaults**. Its toggles use the warning role. Turning a patch off opens a destructive confirmation that warns the game may break and how to undo it; turning one on needs no warning. While a game runs, the page banner locks the panel.
  - Danger zone holds **Runtime choice**, **Remove Runtime…**, and **Remove Other Runtime…**. **Runtime choice** is a menu with **Automatic** (default) and each runtime this macOS allows, by its display name. It is the only place that writes a lane override. Removals ask for confirmation, keep the game environment, and show a failure inline with a support code.
  - A change of runtime uses the destructive runtime switch warning, but only when a game environment exists, and the new runtime applies at the next game launch. Choosing a runtime that is not installed keeps it selected; Home then offers its setup, and nothing downloads until the user asks. The page links to **Game runtime** with **About game runtimes**.
- Installation shows a page banner while the launcher is busy, with **Server**, **Location**, **Maintenance**, and a **Danger zone**. Location holds **Game files**, whose detail shows the install folder and status such as **Installed**, plus **Show in Finder** and the **Change…** menu. Maintenance offers **Verify Files** and **Repair**. **Verify Files** checks the files against the manifest without changing them and reports the result, with **Repair** when files are damaged or missing. The Danger zone holds **Uninstall Game…**, which names the server in its confirmation.
- Appearance panels appear as Artwork, Theme, Home screen, and Dock icons. Theme holds Dynamic Theme, Appearance, Home controls, and Branding colors. Home screen holds Branding, Game version, and Server time and reset countdown.
- The Look step of setup asks for the artwork and Dynamic Theme. Its **More options** section asks for Home controls, Branding colors, Appearance, what the launcher shows, and the Dock operator, in that order.
- Storage panels appear as Game installations, Shared runtime data, Recreatable caches, Logs and data, and Measurements, with no Danger zone. **Clear Caches** and **Clear Gallery Cache** are neutral. Logs and data holds **Show Logs** and **App Data Folder** with **Show in Finder**; Measurements holds **Refresh sizes**.
- Game's Performance panel holds **Frame rate limit** as a segmented control. Battery Saver holds **Battery Saver mode** and, while it is on, **Battery Saver frame rate limit**. Battery Saver applies whenever it is on. While **Override in-game display settings** is off, the affected rows say so in their detail.
- Updates holds Release channel (**Update channel** with **Stable** and **Canary**), Automatic checks (**Launcher updates** and **Game updates**), and Project news (**Announcements**). About shows **Show in Finder**, **View on GitHub**, and **Donate**. The Runtime page's **Details** panel shows the runtime version. Its **Technical details** row expands to show the Wine, DXMT, and capability rows.
- Help's Troubleshooting panel holds Setup assistant, **Debug logging**, and the neutral **Rebuild**, which asks for confirmation. Help also holds **Report** and **Get help**; its Danger zone holds **Delete Environment…** and **Reset All Settings…**.
- Explain destructive or expensive actions in user terms.
- Keep warning and danger panels on neutral backgrounds, with semantic color only on the header, icon, edge, and relevant actions. Read every semantic color from `LauncherTheme`:
  - Danger: actions that lose data or sign the user out. Text uses `dangerText`, a danger button label uses `dangerInk`, a solid HUD or icon fill uses `dangerSurface`, and danger glass uses `dangerGlassTint` and `dangerGlassStroke`.
  - Warning: cautionary state such as a risky but reversible change. Text and icons use `warningInk`, a solid fill or toggle uses `warning`, and warning glass uses `warningGlassTint` and `warningGlassStroke`.
  - Success: completed state; text and icons use `successInk`.
  - Accent: the primary operation and intentional selection.
- Light mode darkens `dangerText`, `warningInk`, and `successInk` to at least 4.5:1 on the light sheet; dark mode keeps the brand values.
- For a custom game window size, choose **Custom…** and enter a width and height or measure the game window. `GameDisplaySize.validatedCustom` validates it, keeps the entered value, and fits the size to the screen only at launch.
- Render bundled Markdown as native text, parsed once when the document opens. Tables fit their column widths and scroll sideways when they are wide. A missing or unreadable document shows an error state.

## Dock menu

- Show a Play entry for each installed region, disabled while a refresh or another launcher or game operation runs.
- Route a Dock launch through the normal refresh and launch guards, and open the main window when the launch does not start, such as when an update, Rosetta, or another recovery step needs attention.

## First-run setup

- Present setup as an operation briefing in the launcher window: the left column shows the route, the right column one task, and installation status sits inside its step.
- Check for a newer launcher first. If one exists, stop setup at the update action; the user installs it and reopens the launcher. System Check checks nothing else.
- Verify Intel execution through Rosetta 2 in the Install step, while x86_64 is the runtime in use.
- Ask the **Update channel** question in Updates and Integrations, with Stable (recommended) and Canary. Ask the daily reset reminder question in Updates and Integrations, with Off (recommended), At reset, and 1 hour before. Ask macOS for notification permission only when the user picks a reminder, and keep Off if macOS refuses.
- Walk through System Check, Server, Install, Display, Look, Updates and Integrations, and Ready. Install covers the runtime, the install location, and Rosetta 2 for x86_64. Ask each question with an answer card (`OnboardingQuestion`), using one answer, several answers with checkboxes, or action cards that open a chooser. Mark the recommended answer, and end Display with a one-sentence summary.
- Each step shows its main choices and puts secondary options under a collapsed **More options** section, which a step without secondary options omits. In Updates and Integrations, music is one on/off question; volume and **Now playing** sit under **More options**.
- The rail shows a running download on every step, and the game download offers **Resume** when partial files exist.
- While setup is visible, failures of setup-started work show inline under the failed item, using the shared inline failure component. This covers the game install and update, the Rosetta 2 check and install, and the runtime install. Home waits and shows any pending failure when setup closes.
- Runtime setup failures follow the game failure rule: Home shows **Needs attention** under the primary action, and the failure dialog opens once with details and **Retry** when a retry can help. A failed game download shows "Download failed" in the rail, with the support code and **Retry**.
- The page title equals the rail label. A step change enters from the side of travel and the old page fades; Reduce Motion fades only.
- The Server step starts no download. It notes that each server has its own publisher and that anti-cheat may block or flag the game on a Mac. Global stays preselected.
- The Install step subtitle reads "Set up the runtime and game files for <server> from <publisher>". Its footer is **Download and Continue** when the game or runtime is missing, otherwise **Continue**. Game downloads and runtime installs start only there.
- The Install step shows the runtime the launcher chose, with its installed version, download size, and macOS requirement. It offers no runtime choice. **Download and Continue** installs that runtime. The step links to **Game runtime** with **About game runtimes**.
- Before a lane change in Settings, show the runtime switch warning, but only when a game environment exists. It states that the runtimes use separate game environments, that the game may treat the switch as a fresh install and ask for sign-in and resources again, and that the switch can add a download. Apply it in both directions.
- Apply each choice at once, with the same actions as Settings. The user reopens the assistant from Settings → Help → Troubleshooting.
- When a release requires a rerun, open with a **Why setup is required** panel that explains why. The rerun reuses the current server, runtime, location, and preferences, and downloads nothing unless one of them changes. Hide Skip Setup until the user finishes; first runs stay skippable.
- End with a plain statement that the launcher is an unofficial community project. Route launcher, game compatibility, and embedded-browser reports to the pre-filled GitHub form. Route account, payment, and game-service issues through the [publisher support routing table](../help/README.md#publisher-support-routing).

## Artwork

The default image comes from the official Global launcher configuration and is cached locally. Neither the repository nor the DMG includes it. The service exposes one active image, not a playlist, so do not build a carousel from historical CDN URLs.

> [!WARNING]
> A user can choose a local image. The app copies it into its Application Support folder. Do not bundle official wallpapers in public releases without explicit permission. The [Global Fan Kit terms](https://www.arknights.global/fankit/precautions) do not clearly permit redistribution inside third-party software.

## Notices

> [!WARNING]
> When the official configuration enables a notice, show its HTML as native formatted text. Show it once for each app launch. Never run notice content in a web view.

## App icon

The source icon is an Icon Composer document with three layers: structure, glass glyph, and signal. Packaging includes an asset-catalog version, which stops macOS 26 from placing a legacy ICNS on a gray backing plate.

An operator preset gives a matched pair: a Launcher icon and a Game icon from the same avatar. Dynamic Theme recolors only the Launcher icon, never the Game icon. A local image replaces one destination, and it also ends automatic preset refreshes.

Settings offers one **Choose Operator…** action for both icons, plus a **Custom icons** row with one menu for each icon.

> [!IMPORTANT]
> For **Use Default**, the Wine game process uses the original executable icon. With **Rounded Dock icon** on, the runtime draws it on the 412/512 icon grid with rounded corners. A custom game icon is published unchanged. Never patch icon resources inside `Arknights.exe`.
