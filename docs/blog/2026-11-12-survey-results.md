---
title: Survey results for version 1.0.0
date: 2026-11-12
summary: What you told me in the survey, how version 1.0.0 answers it, and the new native ARM64 runtime.
---

The survey ran from October 27 to November 10, and thank you to everyone who filled it in. Most of you play daily, and 60% had no problems at all. The top request was a resizable game window, with a battery saver or FPS limit second. Version 1.0.0 delivers both. It also adds a native ARM64 runtime that cut CPU use by about 43% in my LS-5 test.

This post covers the results, the changes in 1.0.0, the ARM64 runtime, and what I plan next.

> [!NOTE]
> Version 1.0.0 is not out yet. It releases on a later date, so treat everything below as a preview.

## Survey results

### Who answered

Nearly everyone is on a recent macOS: macOS 26 or macOS 27, beta included.

```share-chart
title: "macOS version"
type: pie
items:
  - label: macOS 26
    share: 0.47
  - label: macOS 27 (including beta)
    share: 0.44
  - label: macOS 15
    share: 0.07
  - label: Other
    share: 0.02
```

The Macs cover every chip from M1 to M5. M4 came out slightly ahead.

```share-chart
title: "Chip family"
type: pie
items:
  - label: M1
    share: 0.18
  - label: M2
    share: 0.16
  - label: M3
    share: 0.18
  - label: M4
    share: 0.20
  - label: M5
    share: 0.16
  - label: A18 Pro (MacBook Neo)
    share: 0.11
  - label: Other or not sure
    share: 0.02
```

This is a daily habit for most of you, and a few-times-a-week one for nearly everyone else.

```share-chart
title: "How often do you play?"
type: pie
items:
  - label: Daily
    share: 0.56
  - label: A few times a week
    share: 0.36
  - label: Weekly
    share: 0.08
```

Many of you came from mobile, and quite a few from a Windows PC.

```share-chart
title: "What players used before (more than one answer allowed)"
items:
  - label: Mobile
    share: 0.64
  - label: Windows PC
    share: 0.29
  - label: Other Wine or emulator setup
    share: 0.27
  - label: New to this client
    share: 0.16
```

### Problems and wishes

Most of you had no problems. Of those who did, window size and fullscreen came up most.

```share-chart
title: "Problems players hit (more than one answer allowed)"
items:
  - label: None
    share: 0.60
  - label: Window size or fullscreen
    share: 0.17
  - label: Heat or fan noise
    share: 0.07
  - label: Audio or music
    share: 0.05
  - label: Crash
    share: 0.05
  - label: Graphics glitch
    share: 0.05
  - label: Other
    share: 0.07
```

That matches the wish list. A resizable game window was the clear first choice. A battery saver or FPS limit came second.

```share-chart
title: "Features players wanted most (up to three answers)"
items:
  - label: Resizable game window
    share: 0.64
  - label: Battery saver or FPS limit
    share: 0.40
  - label: Screenshot shortcut
    share: 0.27
  - label: Discord Rich Presence
    share: 0.27
  - label: Daily reset and play-time notifications
    share: 0.20
  - label: Menu bar mode or launch at login
    share: 0.13
  - label: Better multi-display handling
    share: 0.09
  - label: Export and import settings
    share: 0.04
```

### How the launcher is doing

- Most respondents play on Global.
- 89% found the update pace about right.
- About seven in ten found the settings clear. A few found the groups confusing.
- Onboarding was clear for everyone (100%).
- About half did not know about **Report a Problem…**. I take that as my problem to fix, not yours.

## What 1.0.0 changes and why

Each change below starts with what you asked for and how to use the result. The developer notes explain how it works. Skip them if you only care about the player side.

### Custom window size

About two in three of you asked for a resizable game window, so this came first.

- Choose **Custom…** in the game **Window size** menu and enter a width and height in points.
- Or use **Measure With a Window…** to copy the size of a window you already have.
- If a size is too large for your screen, it scales down when the game starts.

<details>
<summary>Developer notes</summary>

The game used to offer only presets, so I added a free width and height next to them. The size is a `GameDisplaySize` in Core, so the settings UI and the launch code read one definition.

The measuring window locks to 16:9, 16:10, or 4:3. A size you copy from it therefore has a shape the game can use.

At launch, `launchWindowSize(on:)` fits the stored size into the visible screen below the title bar and caps it at a maximum. It scales the size for that launch only. The number you saved stays as you entered it.

</details>

### Native fullscreen Space

Window size and fullscreen were also the most common trouble, reported by about one in six of you. Fullscreen now opens the game in its own macOS Space. You can switch apps and Spaces the way you normally do.

If you saw a second cursor in fullscreen, set **Cursor** to **macOS** under **Settings → Game → Display**. Older runtimes keep the game cursor.

<details>
<summary>Developer notes</summary>

The Wine runtime creates the Space. The launcher asks for it with `ARKNIGHTS_RUNTIME_NATIVE_FULLSCREEN_SPACE`, but only when the installed runtime advertises `nativeFullscreenSpace` and the display mode is fullscreen. That check is why older runtimes keep their old fullscreen behavior.

A native Space puts the window below the camera housing on notched displays. The launcher gives the game `nativeSpaceContent`, which is the screen height minus the notch.

Wine can still ask for the full monitor rectangle. The runtime therefore also corrects mouse positions by the measured shift. Without that, clicks land a notch height off.

</details>

### Frame rate limit

About two in five of you wanted a battery saver or an FPS limit. Set **Frame rate limit** in **Settings → Game → Performance** to 30, 60, or 120 FPS. The launcher hands the cap you pick to DXMT unchanged.

<details>
<summary>Developer notes</summary>

The cap is a three-value enum, `GameFrameRateLimit`. The launcher writes it into `DXMT_CONFIG` as `d3d11.preferredMaxFrameRate`. DXMT is the layer that presents frames, so a cap works there.

My first version snapped the cap to a divisor of the display refresh rate. I removed that, because the number in the menu should be the number the game gets.

</details>

### Battery Saver

About one in fourteen of you reported heat or fan noise. If your Mac gets loud or warm, try one of these:

- Set **Rendering** to **MetalFX** under **Settings → Game → Display**.
- Lower the **Window size** or the fullscreen **Resolution**.
- Turn on **Battery Saver** under **Settings → Game → Performance**.

**Battery Saver** applies at your next launch. It caps the frame rate at 30 or 60 FPS, lowers **Rendering** from Retina, and turns off **Game Mode**.

<details>
<summary>Developer notes</summary>

Battery Saver is a transform on the launch options, `applyingBatterySaver`, so it never touches your saved settings. It only lowers values. The cap drops to the saver cap if yours is higher, and Game Mode turns off.

Retina rendering falls back to MetalFX, or to Standard when MetalFX is unavailable, because Retina is the only mode that draws more pixels. The Metal HUD and the synchronization mode stay as you set them.

The transform runs when the launcher builds the launch request, so a running game is never changed.

</details>

### Daily reset reminders

About one in five of you asked for daily reset and play-time notifications. I built the reset part. The launcher can show a macOS notification before the daily reset.

- Turn on the **Daily reset reminder** under **Settings → Integration → Notifications**.
- Pick the servers under **Servers**.

The reset happens at 04:00 server time, and daylight saving does not move it.

<details>
<summary>Developer notes</summary>

macOS only delivers notifications that already exist. The launcher therefore schedules one-shot local notifications for a rolling 7 days instead of running a timer.

`ResetReminderPlan` builds them from your preferences alone and keeps at most 48, well under the 64 pending requests macOS allows. `ResetReminderController` refills the window at launch, on wake, and when the clock or time zone changes.

Each request fires at an absolute UTC instant. Its ID holds the server date and lead time, so a changed timing replaces old requests.

`GameRegion.serverTimeZone` uses a fixed offset, so Global is UTC−7 all year. The text names no local time, because a request made before a daylight-saving switch would keep a stale one.

</details>

### Screenshots

Just over one in four of you wanted a screenshot shortcut. Screenshots are off by default.

- Choose a **Shortcut** under **Settings → Integration**.
- The launcher then saves a PNG of the game window while the game runs.
- The default is **⌃⌥S**, and **Record Shortcut…** lets you use other keys.
- macOS asks for Screen Recording permission the first time.

<details>
<summary>Developer notes</summary>

`GameScreenshotController` captures only the game window through ScreenCaptureKit. It saves a PNG without overwriting an existing file.

It registers the global shortcut only while the game runs and Screen Recording access is granted. The launcher therefore never takes a key from other apps otherwise. It asks for the permission only when you pick a shortcut or take a screenshot.

ScreenCaptureKit can still refuse after the permission check passes, so the controller treats a refusal as a denied permission too. If the game session ends during a capture, the launcher drops the file and any error.

</details>

### Discord Rich Presence

Just over a quarter of you asked for it. It is off by default, so turn it on under **Settings → Integration → Discord presence**. Your Discord profile then shows **Playing Arknights**, your server, and how long the session has run.

<details>
<summary>Developer notes</summary>

The launcher talks to the Discord app on your Mac over its local IPC socket, using `DiscordIPCConnection`. The handshake has a timeout, and message size and reconnects are bounded. A missing or slow Discord cannot stall the launcher.

`DiscordPresenceController` holds no connection state. It turns launcher activity into an intent. `DiscordPresenceSession` owns the transport and the stale-result checks.

I send the session start time, and Discord renders the elapsed time itself. Presence is off by default, so a new install never connects to Discord.

</details>

### Music fixes

- The music volume now stays where you set it.
- Launcher music plays until the game window appears, then fades out once.
- Tracks that YouTube cannot play are skipped.
- The launcher shows when music is unavailable, and it remembers when you mute it.

<details>
<summary>Developer notes</summary>

Music had several bugs with one cause: the controller guessed what YouTube's player was doing. I moved playback state into a `MusicPhase`. Player calls now go through commands that tests can fake, with an injected clock.

Track starts follow player events instead of polling. **Next** and **Previous** use YouTube's own playlist navigation and finish when the player reports a different video, because the metadata event can stay stale. A one-second recheck covers the case where YouTube sends no event after buffering.

The volume is saved as `launcherMusicVolume`, and a change during a fade-in keeps the new value.

</details>

### Report a Problem

About half of you did not know **Report a Problem…** existed, so 1.0.0 puts it in more places.

- Find it in the **Help** menu, the Dock menu, and **Settings → Help**.
- The **Help** section now separates problems on this Mac from account and payment problems.
- The report form asks for logs only when a maintainer requests them.

<details>
<summary>Developer notes</summary>

Every entry point builds its link with `IssueReportURL`. It opens the problem-report issue form with fields already filled in: launcher version, macOS, chip and memory, runtime name, support code, operation, and server.

It also sets an `IssueReportSource` (`error`, `settings`, `help-menu`, `dock`, or `onboarding`), so I can see which entry point people actually use. That matters, since half of you did not know the action existed.

The form asks for diagnostics only when a maintainer requests them. The **Save Diagnostics…** archive reuses the same environment line.

</details>

### New support codes

When a failure has a specific fix, the launcher now shows a support code. Each of the 26 codes has its own help page with steps to try, such as **IN-DSK** for low disk space. Old codes such as **BASALT** link to their new pages.

<details>
<summary>Developer notes</summary>

The old codes were hard to read and did not map to one fix each. I replaced them and mapped every failure a user can see to a code. Retry and Repair actions now follow the same catalog.

The catalog is `support-codes.json`. `scripts/support_codes.py` generates and checks every file derived from it, so a stale help page or a missing page fails the check.

`SupportCodeStabilityTests` pins which error resolves to which code. People quote these codes in reports and old ones are linked from elsewhere, so a rename should fail a test instead of shipping by accident.

</details>

### Settings reorganization

A few of you found the settings groups confusing, so 1.0.0 groups settings by task.

- The **Arknights** group holds **Game**, **Installation**, **Storage**, and **Playtime**.
- The **Launcher** group holds **Appearance**, **Integration**, and **Updates**.
- The **Support** group holds **Help** and **About**.
- Recovery actions now live under **Help**.

<details>
<summary>Developer notes</summary>

This was mostly a regrouping, not new settings. `SettingsGroup` defines the three sidebar groups and their captions, so one definition builds the sidebar.

Recovery actions such as repair and reset moved to **Settings → Help → Troubleshooting**, because they are what you reach for when something is wrong. I split the long Game page into Display, Performance, and Compatibility. Audio became Integration, since it now also holds reminders and Discord presence.

</details>

### Light mode, adaptive home pills, and artwork

The launcher now has a light mode. Choose **System**, **Light**, or **Dark** under **Settings → Appearance**. **Home controls** and **Branding** under **Settings → Appearance → Dynamic Theme** can follow the brightness of the artwork, or stay dark or light.

<details>
<summary>Developer notes</summary>

I rebuilt the design system around one theme for dark and light instead of adding a second set of colors. `LauncherTheme` supplies named color roles, and views read only those roles. A lint with an allowlist flags colors written directly in views.

Fixed warning, success, and danger colors were unreadable on a light background, so they became theme text roles. **Home controls** and **Branding** use the artwork's measured luminance, which is cached, to choose dark or light.

I removed the glow effects, hover zoom, and bouncy motion at the same time.

</details>

### Gryphline Taiwan is a normal server

Gryphline Taiwan leaves Canary Features in 1.0.0 and becomes a normal server. There is no switch to turn on.

<details>
<summary>Developer notes</summary>

I removed the permission that gated the Taiwan server, so it is available like every other server. Canary Features is still in Settings, but it currently has no features. While it is on, the launcher says so.

</details>

### Under the hood

I split the code into feature targets and cleaned up task scheduling, cancellation, error handling, and logging with recovery. The launcher also uses one shared set of UI components. You will not see most of this.

<details>
<summary>Developer notes</summary>

Installation and runtime no longer depend on Customization, and the launcher shares one child-process runner.

The Wine spawn gate used to poll every 25 ms during shutdown. It now resumes waiters from each child's termination handler. The tests wait for events instead of sleeping, so they run faster and fail less at random.

I replaced `Task.detached` with `@concurrent` functions, because a detached task drops the caller's actor and its cancellation.

</details>

## A native ARM64 runtime, thanks to riverfog7

> [!IMPORTANT]
> Thank you, [riverfog7](https://github.com/riverfog7), for building the [ARM64 runtime](https://github.com/riverfog7/wine-build-new). It is the biggest change in 1.0.0, and it would not exist without your work.

Until now, the whole Wine runtime ran through Rosetta 2. The new ARM64 runtime runs Wine natively on Apple Silicon. Only the game's own x86 code is still translated, and that happens inside Wine.

### What it means in 1.0.0

- **ARM64 is the recommended runtime on macOS 26 or later.** macOS 15 can only use **x86_64**. On newer versions, **x86_64** stays available as a fallback.
- The runtime is no longer inside the app. Choose it under **Settings → Installation → Runtime**, and the launcher downloads, verifies, and installs it.
- You can switch between runtimes without restarting the launcher.
- Each runtime has its own game environment. After a switch, the game may look like a fresh install, so you may need to log in again.
- In my tests, every server starts on ARM64, China (Bilibili) included.
- One rough edge is left. On China (Bilibili), the first Bilibili window can push a windowed game to the background. Click the game to bring it back.

### Benchmarks

I measured ARM64 on the same Mac (M4, 16 GB) with the same settings as the earlier x86_64 runs: a 1280 × 800 window, **Retina**, and a 60 FPS cap.

- In LS-5 on autodeploy at 2x speed, the game uses about 43% less CPU and about half the GPU time.
- On the main menu, CPU use drops by about a third.
- Memory goes the other way. ARM64 uses about 17% more on the main menu and about 37% more in LS-5.

```chart
{
  "src": "/benchmarks/comparison.json",
  "mode": "stats",
  "title": "LS-5, autodeploy 2x"
}
```

```chart
{
  "src": "/benchmarks/comparison.json",
  "metric": "cpu_percent",
  "title": "CPU use in LS-5",
  "unit": "% of one core",
  "caption": "Lower is better. 100 % is one CPU core."
}
```

```chart
{
  "src": "/benchmarks/main-menu.json",
  "mode": "stats",
  "title": "Main menu"
}
```

The x86_64 runs are a few weeks older and used an older DXMT build. Part of the GPU gain likely comes from DXMT, not only from dropping Rosetta 2. The [performance page](../performance.md) explains how I measure.

<details>
<summary>Developer notes</summary>

riverfog7's [wine-build-new](https://github.com/riverfog7/wine-build-new) builds Wine with FEX in ARM64EC mode and signs the loader. The Arknights patches come from the [runtime repository](https://github.com/LuMiSxh/Arknights-MacOS-Runtime), which repacks the build into the launcher's runtime layout.

The launcher pins each runtime by version and SHA-256 in `runtime.json`, so a download that differs from the pin is rejected. Each runtime lane has its own Wine prefix, because the two builds should not share one game environment.

Porting the patches found one real bug. The Bilibili window check from patch 0007 read Wine's thread data on the macOS main thread, and on ARM64 that thread has none. China (Bilibili) therefore never showed a window until rc9. The fix computes the value once at driver init, on a Wine thread, and the check reads that result.

</details>

## What comes next

After 1.0.0, I want the launcher to settle. The next releases focus on stability and bug fixes. I will avoid large or breaking changes to the UI, the settings, and the code inside, so what you learn now keeps working.

I need help with:

- **Guides.** One of you asked for a guide that explains installing and updating step by step. 1.0.0 adds a quick start to the installation guide, but guides written by players, for players, are better. If you can explain a setup, a fix, or a workflow in plain words, I would love to add it to the help pages.
- **Translations.** The launcher is English only. I would like to add more languages, such as Traditional Chinese, but only with players who help translate it. You do not need to know how to code.
- **Testing.** Bug reports through **Report a Problem…** help the most, especially on the ARM64 runtime and on servers I play less, such as Japan, Korea, and Taiwan.

```contact
title: Help translate the launcher
text: I look for volunteers who speak Chinese or another language. No coding knowledge is needed. Tell me which language you speak and how much time you can give.
topic: translation
```
