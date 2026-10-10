---
title: License automation
description: How the project keeps the published third-party license documents complete and current
order: 45
audience: developers
---

# License automation

`scripts/licenses.py` keeps the third-party notices complete. It replaces hand-maintained lists. The logic is in `scripts/lib/licenses.py`. The website publishes the full documents. The app bundles one compact file with the same content.

## Sources of truth

| Input                                | What it declares                                                             |
| ------------------------------------ | ---------------------------------------------------------------------------- |
| `docs/legal/licenses/index.json`     | The client index: SwiftPM packages, website packages, and bundled resources. |
| `docs/legal/licenses/*.txt`          | The license texts that the client index names.                               |
| `Package.resolved`                   | The exact SwiftPM versions.                                                  |
| `web/package.json`                   | The packages that the website embeds.                                        |
| `Sources/ArknightsClient/Resources/` | The resource files that the app bundles.                                     |
| `runtime.json`                       | The runtime pins and the source URLs.                                        |
| `Licenses/index.json` in the runtime | The runtime components. Runtime 0.7.0 and newer ship it.                     |

## Index entries

Each entry in the client index has these fields.

| Field                       | Rule                                                                                                       |
| --------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `name`, `version`, `source` | Required. `source` is an HTTPS URL.                                                                        |
| `spdx`                      | An SPDX expression. Use `NOASSERTION` when the license is not known.                                       |
| `files`                     | License texts in `docs/legal/licenses/`. A project-authored resource can have none.                        |
| `status`                    | `verified` or `unverified`. A `verified` entry needs `basis`. An `unverified` entry can list `candidates`. |
| `scope`                     | `app` (default), `website`, or `runtime-fallback`.                                                         |
| `ecosystem`, `package`      | `swiftpm` or `npm`, and the package identity. The check compares the version with the lock data.           |
| `paths`                     | Resource file names in `Sources/ArknightsClient/Resources/`.                                               |
| `runtimeComponent`          | A key of `components` in `runtime.json`. The script derives `version` and `source` from it.                |

The key `textOrigins` records where each license text came from. Take a text from the package checkout or `node_modules` first. If neither has it, copy the canonical SPDX text from the `spdx/license-list-data` repository and record the tag. Never mark a license `verified` without a text or a project record that proves it.

The scope `runtime-fallback` lists the components of the pinned runtime. The script uses these entries only when no prepared runtime supplies a `Licenses/index.json`. Keep them equal to the runtime inventory of the pinned release. A grouped entry can name several libraries in `note`.

## Add a dependency

1. Add the package to `Package.swift` or `web/package.json`.
2. Add its license text to `docs/legal/licenses/`.
3. Add an entry to `docs/legal/licenses/index.json`. Add a `textOrigins` entry for the text.
4. Run `uv run --locked scripts/licenses.py`. This updates the generated blocks in `docs/legal/third-party-notices.md`, `docs/legal/source-code.md`, and `docs/legal/license-texts.md`. It also rewrites `docs/legal/ThirdPartyNotices.deflate`.
5. Run `uv run --locked scripts/licenses.py --check`.

For a new resource file, add its name to `paths` of an entry. Mark the entry `unverified` if the origin or the license of the file is not known.

## What `--check` does

`--check` fails when:

- An entry has a wrong field, an unsafe path, or a duplicate name.
- A package in `Package.resolved` has no entry, or the version differs.
- A dependency in `web/package.json` has no entry, or the version differs.
- A bundled resource has no entry.
- A listed text file is missing, a text file has no entry, or `textOrigins` has no record for it.
- A generated block in `docs/legal/` is stale. This includes the license-text page.
- `docs/legal/ThirdPartyNotices.deflate` is missing or stale.

`just check scripts` runs it through `scripts/tests/test_licenses.py`. A component with the status `unverified` is a warning, not an error. Add `--runtime DIR` to check the license index of a prepared runtime. Add `--strict` to turn warnings into errors.

## Publish the texts

`docs/legal/license-texts.md` holds the full text of every license in the client index. Each component has its own heading. A text that two components share appears once. The website publishes the page at `/legal/license-texts/`.

Without a prepared runtime, the page lists the `runtime-fallback` entries. To merge the runtime index into the page, run `uv run --locked scripts/licenses.py --runtime .build/runtime`. Then commit the result. Run `--check` with the same `--runtime` option to find a stale page.

## Build the app

`scripts/build_app.py` calls the same code with `--bundle`. It writes one file, `Contents/Resources/ThirdPartyNotices.deflate`. The file replaces the loose notice and license files of earlier builds.

The file is raw-deflate data of one Markdown document. The document has a table of the app components and the merged runtime components. Each distinct license text appears once. A table row names the text by its id. The website components are not in the file. The app decodes the file with the Compression framework when the user opens **Third-Party Notices** in **Settings → About**.

Compression saves about 80 KB of the 115 KB document. The runtime texts increase the saving. The repository keeps a copy of the file at `docs/legal/ThirdPartyNotices.deflate` for the `--check` mode. That copy has no runtime components unless you generate it with `--runtime`.

The app bundle also keeps `LICENSE`, `CHANGELOG.md`, and `RUNTIME.json` as plain copies. The build generates only the notices, so only the notices use deflate. [Bundled resources](architecture/README.md#bundled-resources) states the rule. The bundle does not contain `Licenses/` or `NOTICE.md` of the runtime. `scripts/download_runtime.py` keeps them in `.build/runtime` for the checks and the merge.

A runtime archive before 0.7.0 has no license files. The build then warns and lists the `runtime-fallback` entries.

## Strict mode

Pass `--strict-licenses` to `scripts/build_app.py` or `scripts/build_dmg.py`. Run `uv run --locked scripts/licenses.py --check --strict --runtime .build/runtime` for the same rules without a build. Strict mode fails when:

- the runtime archive has no `Licenses/index.json` or no `NOTICE.md`, or
- any component in the app or the runtime has the status `unverified`.

The default build only warns. The release workflow creates a draft, and the project rule is to keep a draft until the review is complete. Enable `--strict-licenses` in the release workflow when the pinned runtime ships its license files and every component is verified.
