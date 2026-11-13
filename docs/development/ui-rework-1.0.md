---
title: UI rework for 1.0
description: Frozen page and panel names, the 1.0 interface decisions, and the packages that finish the rework
order: 21
audience: developers
---

# UI rework for 1.0

Use this plan to bring the launcher in line with the [interface rules](design.md#interface-rules).

## Goal

After 1.0.0, page names and panel names are frozen.
Row labels may change only when their docs change in the same pull request.

## Decisions (2026-11-12)

- Put a **Danger zone** at the bottom of each page.
- Add a **Runtime** page to the Arknights group. It holds these panels:
  - **Active runtime**: choose and switch the runtime, with **Recommended**.
  - **Maintenance**: update the runtime and show the Rosetta 2 status for x86_64.
  - **Compatibility**: Wine sync, moved from Game. Always expanded.
  - **Runtime patches**: collapsed, warning tone, moved from Help.
  - **Danger zone**: **Remove Runtime…** and **Remove Other Runtime…**.
- Move **App Data Folder** to Storage, in the **Logs and data** panel.
- Installation keeps **Server**, **Location** (one row), **Maintenance** (**Repair**), and the **Danger zone** (**Uninstall Game…**, which names the server).
- Hide **Canary Features** while it is empty.
- Help keeps **Report**, **Get help**, **Troubleshooting** (**Setup assistant**, **Debug logging**, and **Rebuild**), and a **Danger zone** (**Delete Environment…**, **Reset All Settings…**).
- Use **Dynamic Theme** as the only name for the theme feature.
- Battery Saver applies whenever it is on. Its detail says so.
- Use a segmented control for both frame rate limits.
- Setup has one **Install** step: runtime, then location, then Rosetta 2 (x86_64 only).
- Each setup step has a **More options** section. Setup keeps every option. There are no separate basic and advanced modes.
- Global stays preselected. The **Install** step names the server before the download.
- Show setup failures inline, using the shared inline failure component.
- Force one setup rerun in 1.0. The rerun reuses the current server, runtime, location, and preferences. It downloads nothing unless something changes. It says why it runs.
- Music in setup is one on/off question. Put the volume and **Now playing** under **More options**.

## Done

- The display override gates the frame rate, Game Mode, and HUD in the runtime.
- Runtime patch opt-outs.
- The notification warning placement.
- **Repair** without an ellipsis.
- The switch warning shows only when a game environment exists.
- Settings sheet sizing, disabled control visuals, and the footer fade.
- The developer preview runtime simulation.
- R1 shared components and activity lock reasons.
- O2 setup labels.
- R7 Appearance panels and the **Dynamic Theme** label.
- R3 Runtime page, including the Runtime patches move from Help and the sentence-case **Danger zone** header.
- R4 Installation: one **Game files** row in **Location**, the server named on uninstall, and **Canary Features** hidden while no server needs it.
- R5 Help: **Delete Environment…** and **Reset All Settings…** in the **Danger zone**, and the sentence-case **Debug logging** label.
- R6 Storage: copy as literals at the view, `StorageOverviewCopy` and its Known Debt entry removed, **App Data Folder** in **Logs and data**, and **Refresh sizes** moved out of the footer.
- R8 Game: page note, **Battery Saver** panel with **Battery Saver mode**, segmented frame rate limits, and override notes in the details.
- R9 Integration, Updates, and About copy, external-link buttons, and **Checking…** while busy.
- R2 Disabled reasons on every page, with page banners for locked pages and footnotes elsewhere. Rule 31 now covers a feature that a denial turned off.
- **Active runtime** clutter: no **Runtime** row, summary detail, secondary status line, **Recommended** badge, conditional size and macOS requirement.
- **Game files** status in the detail line.
- O1 **Install** step and the forced rerun (setup schema 4).
- O3 **More options** on steps with secondary options.
- O4 Server step without **Canary Features**, with a publisher and anti-cheat note.
- O5 Inline setup failures and rail download progress with **Pause** and **Resume**.
- O6 Ready step copy, page titles equal rail labels, and direction-aware transitions.

## Packages

Each package lands as one pull request. Each one includes its docs and screenshots from `just preview`. Rework packages get no CHANGELOG entry. Run `just preview` only with user approval.

| Package | Scope                                                                                                                                                                            | Docs touched                                           |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| R1      | Shared components in `Shared/UI`: footnote, page lock banner, status row, inline failure, location row, and external-link button. Activity-to-reason mapping in `ArknightsCore`. | design.md                                              |
| R2      | Disabled reasons on every page.                                                                                                                                                  | design.md, `docs/help` pages for locked settings       |
| R3      | Runtime page.                                                                                                                                                                    | design.md, `docs/help` runtime pages                   |
| R4      | Installation restructure.                                                                                                                                                        | design.md, `docs/help` installation pages              |
| R5      | Help Danger zone and runtime patch panel move.                                                                                                                                   | design.md, `docs/help` troubleshooting and patch pages |
| R6      | Storage rewrite. Fixes the `StorageOverviewCopy` known debt and removes its Known Debt entry from AGENTS.md.                                                                     | design.md, `docs/help` storage pages                   |
| R7      | Appearance order and the Dynamic Theme label.                                                                                                                                    | design.md, `docs/help` appearance pages                |
| R8      | Game page: page note, Battery Saver panel, segmented frame rate control, and override note in the detail.                                                                        | design.md, `docs/help` game pages                      |
| R9      | Copy pass on Integration, Updates, and About.                                                                                                                                    | `docs/help` pages for those panels                     |
| O1      | Install step and forced rerun.                                                                                                                                                   | design.md, `docs/help` setup pages                     |
| O2      | Labels: footer, Rosetta 2, RT-ROS text, and Skip alert.                                                                                                                          | design.md, `docs/help` setup pages                     |
| O3      | **More options** on every step.                                                                                                                                                  | design.md                                              |
| O4      | Server step: no Canary Features panel, and a publisher and anti-cheat note.                                                                                                      | design.md, `docs/help` server pages                    |
| O5      | Inline failures and rail download progress with **Pause**.                                                                                                                       | design.md                                              |
| O6      | Ready step, copy, tokens, and transition.                                                                                                                                        | design.md                                              |
| L1      | After 1.0: copy lint in `scripts/lib`.                                                                                                                                           | design.md                                              |

## Open checks

- Check sheet resizing on macOS 15 and 27.
- Take screenshots of every reworked page and setup step with `just preview`, using the developer preview simulation pickers.
- Check the new layouts in the running app: the **Recommended** badge, the secondary lane line, the rail download block, the **More options** disclosure, and the step transition.
- Review the setup **More options** split. **Appearance** and **Discord presence** sit under **More options**.
