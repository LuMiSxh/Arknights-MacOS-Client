# Troubleshooting

## Log locations

All logs write to the central macOS log directory or the isolated game/prefix folder.

| File                     | Path                                                                 | Contents                                                                     |
| ------------------------ | --------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Launcher log             | `~/Library/Logs/com.lumisxh.arknights-client/launcher.log`           | Launcher lifecycle, state transitions, Yostar API checks, download streaming, and prefix migration events. |
| Previous launcher log    | `~/Library/Logs/com.lumisxh.arknights-client/launcher.previous.log`  | Rotated backup created automatically once `launcher.log` exceeds 4 MB.       |
| Wine and game log        | `~/Library/Logs/com.lumisxh.arknights-client/wine.log`               | Output from the Windows runtime, DXMT, MoltenVK, and system drivers.         |
| Unity engine log         | `~/Library/Logs/com.lumisxh.arknights-client/unity.log`              | Unity's C# exceptions, asset loading, and engine diagnostics (mapped via `L:\unity.log`). |
| Chromium log             | `~/Library/Logs/com.lumisxh.arknights-client/chromium.log`           | Embedded browser network requests, CEF frame events, and JavaScript logs (mapped via `L:\chromium.log`). |
| CrashSight telemetry     | `<GameDir>/Arknights_Data/Plugins/x86_64/wesight/crashsight_data/`   | In-game crash telemetry from Yostar's CrashSight SDK.                        |
| Installed state          | `<GameDir>/.arknights-client-state.json`                             | Recorded manifest hashes and version metadata for the current installation. |
| Prefix migration state   | `<WinePrefix>/.arknights-runtime-migrations.json`                    | Completed Wine, DXMT, and registry migration steps for the prefix.          |
| macOS crash reports      | `~/Library/Logs/DiagnosticReports/`                                  | Native `.crash` reports if `ArknightsClient`, `wine64`, or Rosetta crashes.  |

`<GameDir>` defaults to `~/Library/Application Support/com.lumisxh.arknights-client/Games/Arknights-Global` (or `Arknights-Japan` / `Arknights-Korea`).

Open **Settings** (`Cmd + ,`) → **Installation** → **Show Logs** to select every active log file in Finder at once.

## Diagnostic launch flags

Pass command-line arguments when launching from the terminal:

```bash
open "dist/Arknights Client.app" --args --graphics-diagnostics
```

- `--graphics-diagnostics` temporarily sets `DXMT_LOG_LEVEL=info` and the Wine Mac driver's `+macdrv` channel, so swapchain creation, backing scale factors, and Direct3D 11 pipeline details appear in `wine.log`.
- `--no-retina` forces Wine to launch at 1x DPI regardless of display scaling; useful if the game window opens with incorrect proportions on a custom HiDPI monitor.

The same 1x override can be made persistent without a terminal flag:

```bash
defaults write com.lumisxh.arknights-client forceDisableRetina -bool YES
```

Revert with `-bool NO`.

## Common issues

**"Arknights Client is damaged and can't be opened."** Builds are ad-hoc signed but not notarized. Right-click `Arknights Client.app` in Finder, select **Open**, and confirm the dialog. Alternatively, remove the quarantine attribute directly: `xattr -d com.apple.quarantine "/Applications/Arknights Client.app"`.

**Payment page shows "Access Temporarily Restricted."** Akamai's bot protection rate-limited the IP after repeated checkout attempts. Restart the router for a fresh dynamic IP, or switch to a mobile hotspot, and wait 1–2 hours for the limit to expire.

**Blank or slow social sign-in (Google, Apple, Facebook).** The OAuth flow starts a CEF background process through Wine on first use; allow 5–15 seconds for it to negotiate TLS and initialize. Repeatedly clicking the login button while it initializes does not help.

**Game window does not appear within 90 seconds** (the launcher stays on "Starting…" and times out with `runtimeWindowTimeout`). Open `wine.log` and check for Rosetta 2 or Metal errors; confirm Rosetta is installed with `softwareupdate --install-rosetta --agree-to-license`. If the log shows no obvious error, reset the Wine prefix migration state via **Settings** → **Installation** → **Repair** and launch again.

## Reporting bugs

Include the Mac model and macOS version, the installed game region, and excerpts from `launcher.log`, `wine.log`, and `unity.log`/`chromium.log` around the time of the issue. The **Report a Problem** button in **Settings** → **Installation** opens a pre-filled GitHub issue with system specs and a recent log tail already attached.
