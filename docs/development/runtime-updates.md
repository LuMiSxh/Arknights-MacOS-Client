---
title: Runtime updates
description: How to pin a runtime release and keep every mention of it current
order: 46
audience: developers
---

# Runtime updates

`scripts/update_runtime.py` pins a published Arknights macOS Runtime release. It changes `runtime.json` and every document that states the pin. The logic is in `scripts/lib/runtime_update.py`. It uses the same generated-block mechanism as [License automation](license-automation.md).

## Update the pin

1. Run `just runtime update TAG`. For example, `just runtime update v0.7.0-rc2`.
2. Read the changed files with `git diff`.
3. Run `just check scripts`.
4. Follow [Updating the pinned runtime](releases-and-updates.md#updating-the-pinned-runtime) for the compatibility tests.

`TAG` is a release tag or `latest`. `latest` is the default. It selects the newest published release. It skips drafts. It skips prereleases unless you add `prerelease`: `just runtime update latest prerelease`.

> [!WARNING]
> `latest` without `prerelease` selects the newest stable release. That release can be older than the current pin. Read the tag in the output before you commit.

The script has these options:

| Option                   | Use                                                        |
| ------------------------ | ---------------------------------------------------------- |
| `--tag TAG`              | A release tag (`v0.7.0-rc2`) or `latest`.                  |
| `--include-prerelease`   | Lets `latest` select a prerelease.                         |
| `--moltenvk-version VER` | The MoltenVK version. Required only if its commit changed. |
| `--check`                | Verifies the pin and writes nothing. It uses no network.   |

## What the script reads

The script reads three assets of the release over HTTPS. It does not download the runtime archive.

| Asset                                              | Use                                       |
| -------------------------------------------------- | ----------------------------------------- |
| `Arknights-MacOS-Runtime-TAG.tar.gz.sha256`        | The archive checksum.                     |
| `Arknights-MacOS-Runtime-TAG-source.tar.gz.sha256` | The build recipe checksum.                |
| `provenance.json`                                  | The commits, versions, and the interface. |

The script fails and writes nothing in these cases:

- A `.sha256` file differs from `provenance.json` in name or checksum.
- `provenance.json` names another tag.
- The interface of the release differs from the `interface` block of `runtime.json`. The script never rewrites that block. Change the interface by hand and review the Swift runtime code.
- The MoltenVK commit changed. `provenance.json` has no MoltenVK version. Pass `--moltenvk-version`.

## What the script rewrites

| Target                                                                       | Fields                                                                                       |
| ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------- |
| `runtime.json`                                                               | `runtime`, `buildRecipe`, `components`, and every field of `provenance`.                     |
| `docs/legal/third-party-notices.md`                                          | The `runtime` blocks `components` and `build`.                                               |
| `docs/legal/licenses/index.json`                                             | Nothing. The entry with `runtimeRelease` derives its name, version, and source from the pin. |
| `docs/legal/source-code.md`, `license-texts.md`, `ThirdPartyNotices.deflate` | The script calls `scripts/licenses.py`. That script regenerates them.                        |

A second run with the same tag changes nothing.

## Manual steps

The script cannot read some facts. Change them by hand when the release changes them.

- The `libraries` list of the `runtimeRelease` entry in `docs/legal/licenses/index.json`. It names the Nixpkgs libraries of the runtime. Copy it from the runtime inventory of the release. Keep `spdx`, `files`, and `note` equal to the same inventory.
- The licenses of Wine, DXMT, and MoltenVK in the same file.
- The prose of the documents. For example, the statement that the runtime has no media stack.
- `prefixRevision` in `runtime.json`.

## Check the pin

`just runtime check` runs `scripts/update_runtime.py --check`. `just check scripts` runs it too. The check fails when:

- `runtime.name`, `runtime.url`, `buildRecipe.url`, or `provenance.buildRepository` does not match the tag in the archive URL.
- A generated `runtime` block in a document differs from `runtime.json`.

## Add a marker

A marker pair surrounds a generated block. The generator replaces the lines between the two markers.

```md
<!-- runtime:begin NAME -->
<!-- runtime:end NAME -->
```

1. Write a render function in `scripts/lib/runtime_update.py`. It takes `runtime.json` data and returns Markdown that ends with a newline.
2. Add the function to the dictionary in `render_documents`. The key is the document path. The value maps `NAME` to the function result.
3. Add the marker pair to the document. Use a lowercase `NAME` with hyphens.
4. Run `just runtime update TAG` with the current tag, or run `just runtime check` to see the stale block.
5. Add a test to `scripts/tests/test_update_runtime.py`.

Rules:

- A marker must be on its own line.
- Every block in `render_documents` must exist in its document. A missing marker fails the run.
- Do not edit the lines between the markers by hand.
- Do not put a marker inside a table. Generate the whole table.
- The `licenses` blocks belong to `scripts/licenses.py`. The `runtime` blocks belong to this script. Each script ignores the markers of the other script.
- Use a derived value instead of a hand-written version in prose. For example, write "the pinned runtime", not a version number.
