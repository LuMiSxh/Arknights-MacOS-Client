---
title: Survey results for version 0.8.0
date: 2026-11-10
summary: What survey respondents told me, and what version 0.8.0 will change in response.
draft: true
---

## Who answered

The survey ran from October 27 to November 4. Most respondents ran macOS 26 or macOS 27, including the beta.

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

The chips ran from M1 to M5, and M4 was the most common.

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

Most of you play daily or a few times a week.

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

Most of you played on mobile before, and many used a Windows PC.

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

Most of you hit no problems, and window size or fullscreen was the most common one.

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

Resizable game window was the top wish, followed by a battery saver or FPS limit.

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

### How it went

Most respondents play on Global. 89% found the update pace about right. About seven in ten found the settings clear, but a few found the groups confusing. Onboarding was clear for everyone (100%). About half did not know about **Report a Problem…**.

## What 0.8.0 changes and why

> [!NOTE]
> Version 0.8.0 is not out yet. It releases on a later date, so everything below is a look ahead.

- Custom window size. About two in three of you asked for a resizable game window. In 0.8.0, choose **Custom…** in the game **Window size** menu, enter a width and height in points, or use **Measure With a Window…** to read the size of a resizable window. A size too large for the screen scales down when the game starts.

  <details>
  <summary>Developer notes</summary>

  `GameWindowSizeChoice` and `GameDisplaySize` in `Sources/ArknightsCore/Shared/Domain/GameDisplayChoices.swift` hold the sizes. `GameWindowMeasureView.swift` in `Sources/ArknightsLauncherUI/Settings` reads the size of a window, so you can copy a size from a window you already have. The sizes sit in Core, so the settings UI and the launch code share one definition.

  </details>

- Native fullscreen Space. Window size and fullscreen were the most common trouble spot, reported by about one in six of you. In 0.8.0, fullscreen mode opens the game in its own macOS Space, so you can switch apps and Spaces normally. A second cursor in fullscreen is fixed by the **Cursor** setting. Set it to **macOS** under **Settings → Game → Display**. Older runtimes keep the game cursor.

  <details>
  <summary>Developer notes</summary>

  The fullscreen logic lives in `Sources/ArknightsGameRuntime/Runtime/GameSessionController+LaunchSteps.swift`. `GameFullscreenDisplay.nativeSpaceContent` in `Sources/ArknightsCore/Shared/Domain/GameDisplay.swift` removes the notch height from the game's height, so the game does not draw under the notch.

  </details>

- Frame rate limit. About two in five of you wanted a battery saver or FPS limit. In 0.8.0, set **Frame rate limit** in **Settings → Game → Display** to 30, 60, or 120 FPS. The launcher passes the cap you choose to DXMT unchanged.

  <details>
  <summary>Developer notes</summary>

  `GameFrameRateLimit` in `Sources/ArknightsCore/Shared/Domain/GameFrameRateLimit.swift` holds the cap. The launcher passes it to DXMT unchanged, so the number you pick is the number the game uses.

  </details>

- Battery Saver. About one in fourteen of you reported heat or fan noise. If you hear fan noise or feel heat, try **MetalFX** rendering, a lower resolution, or **Battery Saver**. Set **Rendering** to **MetalFX** under **Settings → Game → Display**, or lower the **Window size** or fullscreen **Resolution**. **Battery Saver** is under **Settings → Game → Performance**. It applies at your next launch, caps the frame rate at 30 or 60 FPS, lowers **Rendering** from Retina, and turns off **Game Mode**.

  <details>
  <summary>Developer notes</summary>

  Battery Saver's preference feeds `LaunchOptions` and `Sources/ArknightsGameRuntime/Runtime/GameSessionController+Launch.swift`. The settings UI is `Sources/ArknightsLauncherUI/Settings/GamePerformanceSettingsPanel.swift`. The value is read only at launch, so a running game never needs a live update.

  </details>

- Daily reset reminders. About one in five of you asked for daily reset and play-time notifications. 0.8.0 adds the daily reset part. The launcher can show a macOS notification before the daily reset. Set the **Daily reset reminder** under **Settings → Integration → Notifications**, and choose the servers under **Servers**; the reset happens at 04:00 server time, and daylight saving does not move it.

  <details>
  <summary>Developer notes</summary>

  `ResetReminderPlan` in `Sources/ArknightsLauncherUI/Reminders/ResetReminderPlan.swift` schedules reminders for the next 7 days, and macOS shows them when the launcher is closed. `ResetReminderController` refreshes them when the system time zone changes. `GameRegion.serverTimeZone` uses a fixed UTC offset, not a named zone, so Global is UTC−7 all year.

  </details>

- Screenshots. Just over one in four of you wanted a screenshot shortcut. Screenshots are off by default, so choose a **Shortcut** under **Settings → Integration** to save a PNG of the game window while the game runs. The default is **⌃⌥S**, and **Record Shortcut…** lets you use other keys; macOS asks for Screen Recording permission the first time.

  <details>
  <summary>Developer notes</summary>

  `GameScreenshotController` captures the window, and `ScreenshotFileWriter` writes the PNG. The recorder is `Sources/ArknightsLauncherUI/Settings/ScreenshotShortcutRecorder.swift`, and the shortcut value is modeled by `ScreenshotShortcut`. The shortcut is a plain value, so the recorder and the capture code do not need to know about each other.

  </details>

- Discord Rich Presence. Just over a quarter of you wanted Discord Rich Presence. In 0.8.0, it is off by default, so turn it on under **Settings → Integration → Discord presence**. Your Discord profile then shows **Playing Arknights**, your server, and how long the session has run.

  <details>
  <summary>Developer notes</summary>

  `DiscordPresenceController` in `Sources/ArknightsPresence` drives the status. `DiscordIPCConnection` in `Sources/ArknightsInfrastructure/Presence` talks to the Discord app on your Mac. Presence is off by default, so a new install does not connect to Discord until you turn it on.

  </details>

- Music fixes. In 0.8.0, the music volume stays where you set it. Launcher music plays until the game window appears, then fades out once. Tracks that YouTube cannot play are skipped, the launcher shows when music is unavailable, and it also remembers when you mute the music.

  <details>
  <summary>Developer notes</summary>

  The track fixes live in `BackgroundMusicController` and its extensions in `Sources/ArknightsAudio`. A track change finishes even when YouTube skips the playing event. The music volume is stored in `LauncherPreferencesStore`, and a change during a fade-in keeps the new value, so the fade never overwrites it.

  </details>

- Report a Problem. About half of you did not know about **Report a Problem…**, so 0.8.0 puts it in more places. **Report a Problem…** is in the **Help** menu, the Dock menu, and **Settings → Help**. The **Help** section separates problems on this Mac from account and payment problems, and the report form asks for logs only when a maintainer requests them.

  <details>
  <summary>Developer notes</summary>

  `IssueReportURL` in `Sources/ArknightsCore/Shared/Support` builds the report URL in one place, so the menu entries and the Help section use the same report link.

  </details>

- New support codes. In 0.8.0, the launcher shows a support code when a failure has a specific fix. Each of the 24 codes has its own help page with steps to try, such as **IN-DSK** for low disk space. Old codes such as **BASALT** link to their new pages.

  <details>
  <summary>Developer notes</summary>

  `SupportCode` in `Sources/ArknightsCore/Shared/Support/SupportCode.swift` is the single catalog. `SupportCode+Documentation.swift` generates the code table in `docs/help/errors/README.md`, so the help page cannot drift from the app. `SupportCodeStabilityTests` pins the codes, so a renamed code fails a test.

  </details>

- Settings reorganization. A few of you found the settings groups confusing. 0.8.0 groups settings by task. The **Arknights** group holds **Game**, **Servers**, **Storage**, and **Playtime**, and the **Launcher** group holds **Appearance**, **Integration**, and **Updates**; the **Support** group holds **Help** and **About**, and recovery actions now live under **Help**.

  <details>
  <summary>Developer notes</summary>

  `SettingsGroup` in `Sources/ArknightsLauncherUI/Settings/SettingsSection.swift` defines the captions, and `SettingsSection.group` assigns each page to a group. A page belongs to one group in one place, so moving a page changes one line. The Game page now has Display, Performance, and Compatibility, Installation is now Servers, and Audio is now Integration.

  </details>

- Light mode, adaptive home pills, and artwork. 0.8.0 adds a light mode. Choose **System**, **Light**, or **Dark** under **Settings → Appearance**. **Home controls** and **Branding** under **Settings → Appearance → Dynamic Theme** can follow the brightness of the artwork, or stay dark or light.

  <details>
  <summary>Developer notes</summary>

  The design system uses one color theme for dark and light, and `LauncherTheme` supplies the color roles that views read. Warning, success, and danger text needed their own readable colors in light mode. The glow effects, hover zoom, and bouncy motion were removed.

  </details>

- Gryphline Taiwan leaves Canary Features in 0.8.0 and becomes a normal server. There is no switch to turn on.

  <details>
  <summary>Developer notes</summary>

  Canary Features no longer gates the Taiwan server. Canary Features currently has no features, so the Taiwan server needs no opt-in.

  </details>

- Under the hood. I split the code into feature targets, and I improved task scheduling, cancellation, error handling, and logging with recovery. The launcher also uses one shared set of UI components.

  <details>
  <summary>Developer notes</summary>

  Installation and runtime no longer depend on Customization, and the child-process runner is shared. The Wine spawn gate waits for events instead of polling. `Task.detached` was removed, because a detached task drops the caller's actor and cancellation.

  </details>

### Still on my list

- Choppy sound when switching windows. This is still on my list and I willl look into it. I dont think i will get this read for 0.8.0 though.

- Login page swipe glitch. I will look at it for 0.8.0.
- Resizing the game window while it runs. I built a proof of concept that rescales the window during play. It worked, but only sometimes: it scaled in roughly one of thirteen drags, RAM and GPU use roughly doubled, and the game sometimes glitched. That is why 0.8.0 offers sizes only before the game starts. I will keep working on it. Windows does not support this either.
- Per-app volume tools, such as SoundSource and FineTune, cannot control the game. The game's audio is handled in Wine, so this was also true before 0.8.0. I do not have a fix to promise.
- The macOS window frame in windowed mode. I plan to look at it.
- Other requests. Keyboard shortcuts for basic actions cannot work in the launcher, because those are in-game shortcuts. Play-time notifications do not make sense for the launcher, and I should have left them out of the survey. I will look into export and import settings.

## What comes next

- The launcher is available only in English. I would add more languages, such as Traditional Chinese, but only if players help translate it. No coding knowledge is needed.
- The menu bar item and launch at login are still in progress for 0.8.0.
- I plan to make the next bigger release 1.0.0, a stable major version instead of 0.9.

```contact
title: Help translate the launcher
text: I look for volunteers who speak Chinese or another language. No coding knowledge is needed. Tell me which language you speak and how much time you can give.
topic: translation
```
