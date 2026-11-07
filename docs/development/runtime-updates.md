---
title: Runtime updates
description: How to pin one runtime archive per architecture and keep every mention current
order: 46
audience: developers
---

# Runtime updates

[`runtime.json`](../../runtime.json) is the single source of truth for the pinned runtimes. It has schema 3 and two lanes: `x86` and `arm`. Each lane carries the archive name, version, URL, SHA-256, size, interface, component versions, provenance, `minimumMacOS`, and `prefixRevision`.

One launcher release serves both architectures. The architecture is a user choice inside the app, not a separate app build or Sparkle channel. The launcher downloads the runtime for the chosen architecture on first use or after a switch.

## Runtime lanes

A lane is one runtime architecture. The x86 lane runs the WineCX and DXMT binaries through Rosetta 2. The arm lane runs native ARM64 Wine with FEX and Mesa.

| Lane  | Minimum macOS | Wine prefix    | Runtime content        |
| ----- | ------------- | -------------- | ---------------------- |
| `x86` | 15.0          | `Prefix`       | WineCX, DXMT, MoltenVK |
| `arm` | 26.0          | `Prefix-ARM64` | Wine, FEX, Mesa, DXMT  |

The top-level `architecture` value is the default lane for `just runtime` and local tooling. The launcher selects a lane explicitly from its saved selection; it never reads the x86 interface for an ARM runtime.

The ARM64 runtime is built in the [wine-build-new](https://github.com/riverfog7/wine-build-new) repository.

There is no runtime feed, no runtime update check, and no previous-runtime rollback. A runtime change ships with a new client version. The app update replaces a stale pinned runtime for each lane that it uses.

## Update one lane

1. Run `just runtime update TAG --architecture LANE`. For example, `just runtime update v0.9.0 --architecture x86` or `just runtime update v0.9.0+arm --architecture arm`.
2. Read the changed files with `git diff`.
3. Run `just check scripts` and `just runtime check`.
4. Download the new lane with `uv run --locked scripts/download_runtime.py --architecture LANE`.
5. Test a fresh and an existing prefix through install or update, game start, and clean exit.
6. Confirm that the other lane pin and its prefix are unchanged.

`TAG` is a release tag or `latest`. `latest` is the default. It selects the newest published release for the requested lane and skips drafts. It skips prereleases unless you add `--include-prerelease`.

> [!WARNING]
> `latest` without `--include-prerelease` selects the newest stable release. That release can be older than the current pin. Read the tag in the output before you commit.

| Option                   | Use                                                                                                    |
| ------------------------ | ------------------------------------------------------------------------------------------------------ |
| `--tag TAG`              | A release tag or `latest`.                                                                             |
| `--architecture LANE`    | The lane to pin: `x86` or `arm`. Defaults to `runtime.json.architecture`. The tag must match the lane. |
| `--include-prerelease`   | Lets `latest` select a prerelease.                                                                     |
| `--moltenvk-version VER` | The MoltenVK version. Required only if its commit changed.                                             |
| `--sha256 SHA256`        | The archive checksum. Read from `provenance.json` by default.                                          |
| `--size BYTES`           | The archive size. Read from the release metadata by default.                                           |
| `--check`                | Verifies the pin and writes nothing. It uses no network.                                               |

## What the script reads

The script reads three assets of the release over HTTPS. It does not download the runtime archive. When `provenance.json` has no archive size, the script reads the size from the GitHub release metadata. Pass `--size` to keep the update offline.

| Asset                                              | Use                                         |
| -------------------------------------------------- | ------------------------------------------- |
| `Arknights-MacOS-Runtime-TAG.tar.gz.sha256`        | The archive checksum.                       |
| `Arknights-MacOS-Runtime-TAG-source.tar.gz.sha256` | The build recipe checksum.                  |
| `provenance.json`                                  | The commits, versions, size, and interface. |

The script fails and writes nothing in these cases:

- A `.sha256` file differs from `provenance.json` in name or checksum.
- `provenance.json` names another tag.
- The release interface of the lane differs from that lane's block in `runtime.json`. The script never rewrites the interface. Change it by hand and review the Swift runtime code.
- The release tag names another lane than `--architecture`. For example, `v0.9.0+arm` with `--architecture x86`.
- The MoltenVK commit changed. `provenance.json` has no MoltenVK version. Pass `--moltenvk-version`.

## What the script rewrites

| Target                                          | Fields                                                                                             |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `runtime.json`                                  | `lanes.LANE.runtime`, `lanes.LANE.minimumMacOS`, and the component sources that the release names. |
| `docs/legal/third-party-notices.md`             | The `runtime` blocks `components` and `build`.                                                     |
| `docs/legal/source-code.md`, `license-texts.md` | The script calls `scripts/licenses.py`. That script regenerates them.                              |

A second run with the same tag changes nothing. The other lane is never rewritten.

## Manual steps

Change these by hand when the release changes them.

- The `interface` block of the lane. Increase `prefixRevision` when a runtime or prefix configuration change must reach existing installations. The archive checksum is part of the effective runtime revision, so a binary-only refresh replays the runtime migrations without a `prefixRevision` increase.
- The `minimumMacOS` value of the lane when the runtime raises its deployment target.
- The `components` and `provenance` entries when the runtime adds or removes a component. Every component needs a paired `Repository` and `Commit` entry.
- The `features` object in the lane's `interface`. It records `hardwareCursor`, `metalFXSpatialUpscaling`, and `nativeFullscreenSpace`. The client treats a missing feature as `false` and sends no unsupported override.
- The `libraries` list in `docs/legal/licenses/index.json` only if the client index itself gains a component. The runtime closure is not part of the client.

## Check the pin

`just runtime check` runs `scripts/update_runtime.py --check`. The test suite also checks a fixture pin. The check fails when:

- A lane's `runtime.version`, `runtime.name`, `runtime.url`, or tag architecture disagrees with the tag in the archive URL.
- `runtime.sizeBytes` or `runtime.sha256` is invalid.
- A generated `runtime` block in a document differs from `runtime.json`.
- The file still has `armInterface`, a top-level `runtime`, a top-level `interface`, or `buildRecipe`.

## Add a marker

A marker pair surrounds a generated block. The generator replaces the lines between the two markers.

```md
<!-- runtime:begin NAME -->
<!-- runtime:end NAME -->
```

1. Write a render function in `scripts/lib/runtime_update.py`. It takes `runtime.json` data and returns Markdown that ends with a newline.
2. Add the function to the dictionary in `render_documents`. The key is the document path. The value maps `NAME` to the function result.
3. Add the marker pair to the document. Use a lowercase `NAME` with hyphens.
4. Run `uv run --locked scripts/update_runtime.py --tag TAG --architecture LANE`. Add a test to `scripts/tests/test_update_runtime.py`.

[License automation](license-automation.md#generated-blocks) owns the marker rules. The `runtime` blocks belong to this script.
