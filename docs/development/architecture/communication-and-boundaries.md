---
title: Communication and boundaries
description: Document launcher update, announcement, notice, service, and support boundaries
order: 40
---

# Communication and boundaries

The launcher has no project-owned application server. Each remote source has its own owner,
validation policy, and failure path. Keep the channels separate when you add a message or update
surface.

## Launcher communication

Read-only channels feed the launcher. Each runs independently at launch, on its own precondition,
with no order between them. Announcements and Yostar notices can enqueue a popup. Launcher updates use
status state and the themed Sparkle UI.

| Channel                                                                 | Owner                         | Payload                                                   | User-visible result                                                |
| ----------------------------------------------------------------------- | ----------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------ |
| Yostar game/config API (Global, Japan, Korea)                           | `LauncherAPI`                 | Region configuration, branding, CDN and manifest location | Readiness, artwork, region notice, or an actionable launcher error |
| Gryphline (Taiwan) and Hypergryph (China clients) metadata/payload APIs | `LauncherAPI`                 | Region configuration, branding, CDN and manifest location | Readiness, artwork, or an actionable launcher error                |
| Repository announcements                                                | `LauncherAnnouncementService` | Bounded JSON feed from `main`                             | Once-only Markdown popup with an optional HTTPS action             |
| Sparkle appcast                                                         | `LauncherUpdaterController`   | Signed launcher update metadata and archive               | Update status, then Sparkle's themed update UI on request          |
| Repository wallpaper tags                                               | `PresetCatalogService`        | Bounded `WallpaperTags.json` from `main`                  | Gallery search tags layered over the bundled manifest              |

- **Sparkle appcast** (`SUFeedURL`): The launcher checks it silently when automatic launcher-update
  checks are on, and before onboarding. A newer version becomes launcher status state and enables the
  update action. `LauncherUpdaterController` wraps `SPUUpdater` and `LauncherUpdateUserDriver`. Sparkle
  validates the feed and handles download, signature verification, replacement, and relaunch. The
  driver supplies the themed UI.
- **Update gate**: `LauncherUpdaterController` rejects checks while the lifecycle is installing,
  migrating, launching, or running the game. It postpones a pending relaunch until idle. A stale
  activity lease cannot change this gate. See
  [Activity leases](launch-and-process-lifecycle.md#activity-leases).
- **Announcements**: `checkAnnouncements()` reads the GitHub Contents API in raw form when
  announcements are on. [Announcement feed](#announcement-feed) owns the feed schema, limits, and
  eligibility rules.
- **Wallpaper tags**: The Artwork gallery fetches the manifest once per launch. Cached tags apply
  before the network answers. [Wallpaper tagging](../wallpaper-tagging.md) owns the manifest rules.
- **Preset sources**: `PresetRemoteSources` names every community mirror and the Fankit gallery API.
  A failed fetch keeps the cached data.
- **Yostar branding response**: It rides on the `api.branding(region:)` call that `refresh()` already
  makes for hero artwork. If `noticePopOpen` is true and `noticeContent` differs from the last notice
  shown, the launcher converts the HTML to native attributed text and queues it. The guard is in
  memory only. It resets on every region switch and launch, so an active notice reappears each
  session.

The three launch checks run in parallel. They meet in one popup queue:

```mermaid
sequenceDiagram
	participant App as SwiftUI launcher
	participant Releases as Sparkle appcast
	participant Contents as GitHub Contents API
	participant Yostar as Yostar branding API
	participant Queue as Popup queue

	par Launcher update check
		App->>Releases: Check signed appcast
		Releases-->>App: Validated update metadata
		alt Newer version
			App->>App: Record available version and show update action
			App->>App: Open custom Sparkle update UI on user action
		end
	and Announcement check
		App->>Contents: GET contents/announcements.json (raw)
		Contents-->>App: Validated feed
		alt First enabled, unseen, eligible entry
			App->>Queue: enqueue announcement popup
		end
	and Branding fetch (shared with artwork)
		App->>Yostar: GET branding/config
		Yostar-->>App: noticePopOpen, noticeContent
		alt New notice content this session
			App->>Queue: enqueue notice popup
		end
	end
Queue->>Queue: Show now, or append to pendingPopups and dedup by id
```

Announcements and Yostar notices share one queue (`enqueuePopup`):

- If nothing shows, the popup shows now and is recorded as seen. Otherwise it joins `pendingPopups` and
  is recorded as seen only when `dismissPopup` promotes it.
- The queue silently drops a duplicate ID of the shown or a queued popup.
- Announcements persist a set of seen IDs. Yostar notices keep nothing beyond the session. Their ID
  embeds a fresh UUID, so only the upstream content comparison catches a repeat.

## Announcement feed

The launcher fetches project messages from [`announcements.json`](../../../announcements.json) on `main` at startup and when the user enables the setting. See [Launcher communication](#launcher-communication) for how the launcher fetches, filters, and queues them.

Use announcements for short, time-sensitive messages. They do not replace the changelog or troubleshooting guides. Keep the body useful without the action link.

The launcher selects the first eligible entry. `just announcement set` inserts or replaces an entry at the top, so the message that must win goes first. An entry counts as seen when the user dismisses its popup. A text change does not show it again. Use a new `id` for a follow-up. The preference store keeps the latest 100 seen IDs.

#### Previewing a popup

1. Run the isolated debug simulator with `just preview`.
2. Open Settings → Developer.
3. Under **HUD and popups**, set **Popup** to **Custom Markdown** and type the message.
4. Press **Show Popup** to see it in the real popup modal.

#### Publishing

Prepare a feed entry with:

```sh
just announcement set \
	feedback-2026-08 \
	"Help improve Arknights Client" \
	/tmp/feedback.md \
	"Open GitHub Issues" \
	https://github.com/LuMiSxh/Arknights-MacOS-Client/issues
```

The recipe takes snake-case arguments and writes camel-case JSON. `action_title` and `action_url` can be `""`. Four more optional arguments set a version range and display window: `min_version`, `max_version`, `starts_at`, and `ends_at`. The command validates the entry and writes all fields, with `null` for unused optional values.

Review `announcements.json`, run `just check`, commit it to `main`, and push. Publishing needs repository write access. GitHub can briefly cache the response, so changes may not reach every client immediately. To hide an entry from installations that have not fetched it yet, run `just announcement remove ID`.

#### Feed schema and eligibility

The feed root needs `schemaVersion: 1` and an `announcements` array of at most 20 entries. The launcher rejects a feed larger than 128 KiB. `manage_announcements.py` enforces the field rules below, and the launcher repeats the safety checks before it displays an entry.

| Field                               | Purpose                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| `id`                                | Stable lowercase identifier (`[a-z0-9][a-z0-9._-]{0,79}`) used for once-only display |
| `enabled`                           | Allows an entry to remain in the file without being presented                        |
| `title`                             | Popup title, at most 120 characters                                                  |
| `body`                              | Markdown body, at most 4,000 characters                                              |
| `actionTitle` / `actionURL`         | Optional button and HTTPS destination; set both or neither                           |
| `minimumVersion` / `maximumVersion` | Optional inclusive `X.Y.Z` launcher-version range                                    |
| `startsAt` / `endsAt`               | Optional ISO-8601 UTC window ending in `Z`; the end is exclusive                     |

An entry is eligible only when it is enabled, unseen, inside its date window, and compatible with the running version. The launcher shows at most one new entry per check and logs a failed fetch without blocking installation or launch.

#### Popup Markdown

The popup uses the launcher's native Markdown parser, not the website renderer. It supports headings, paragraphs, bullet items, tables, fenced code, dividers, inline emphasis, and the five GitHub alert markers, and ignores frontmatter. Advanced Markdown can appear as plain text. Verify content in the real popup.

> [!WARNING]
> Remote Markdown renders as text and formatting only. It cannot execute HTML, JavaScript, shell commands, or native code.

## Refresh concurrency

`LauncherRefreshController` starts the game configuration and branding requests for the current region
independently. Each refresh receives a UUID generation.

- Cancelling a refresh invalidates its generation before a later task can publish.
- The controller accepts branding assets only when the refresh ID and active region both still match.
  A slow response from a previous region cannot replace current artwork, notices, or readiness.
- A late official image never replaces user-selected artwork. The controller captures a
  custom-artwork generation at refresh start and checks it again before it applies the asset.

This diagram shows the generation check:

```mermaid
flowchart LR
	Start[Start refresh] --> ID[Create refresh UUID]
	ID --> Config[Fetch game configuration when needed]
	ID --> Branding[Fetch branding and notice]
	Branding --> Assets[Load cached/downloaded assets]
	Config --> Check{Generation still current?}
	Assets --> Check
	Check -->|yes| Publish[Publish state and presentation]
	Check -->|no| Drop[Drop stale result]
	Install[Installation starts] --> Cancel[Cancel metadata refresh]
	Cancel --> Drop
```

> [!IMPORTANT]
> Every asynchronous remote result needs an ownership check before it mutates observable state.
> Cancellation alone is not enough: a request can complete between cancellation and its callback.

## Boundaries

- Game files come from first-party HTTPS endpoints. No release includes them.
- Manifest paths cannot escape the selected game directory. See
  [Installation architecture](installation.md#manifest-and-path-safety).
- The launcher never handles credentials or intercepts Vuplex pages. Remote action links must use HTTPS.
- [`RUNTIME.json`](../../../runtime.json) pins the runtime lane, versions, and source revisions.

> [!WARNING]
> A popup or notice is not an authorization boundary. Keep remote content out of process execution,
> filesystem paths, and credentials. If a new feed needs more than text and an HTTPS action, define and
> review a separate contract. Do not expand the existing parser implicitly.

## Failure policy

Remote requests fail closed for the feature they serve:

- Branding request fails: cached or custom artwork and the last known state stay. An installed game
  stays available.
- Game configuration request fails: actionable when no game is installed. Logged and tolerated when an
  installed game has enough state.
- Announcements feed is unavailable: no popup. Launch is not blocked.
- Sparkle check fails: the launcher records the failure. The running launcher and the game continue.
  The onboarding preflight has its own update gate.

Never make an optional message or metadata source a lifecycle dependency without updating the state
model and recovery contract.

## Privacy and support boundary

The launcher collects no project telemetry. The website privacy page lists the hosts it contacts.
The embedded browser stays an official game helper. The compatibility components never inspect login,
payment, or page contents.

Route account, payment, and service issues to the publisher's official support. See the
[publisher support routing table](../../help/README.md#publisher-support-routing). Route launcher,
runtime, and packaging issues to the repository issue form. Before you share a log, remove account
identifiers and local paths.
