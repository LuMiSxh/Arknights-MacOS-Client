---
title: Development
description: Architecture, design, testing, release, and runtime contracts for contributors
order: 30
audience: developers
---

# Development

The launcher targets Apple Silicon and macOS 15 or newer. It supports Yostar Global, Japan, and Korea and Hypergryph China and China (Bilibili) by default. The Gryphline Taiwan client is behind Canary Features and has its own permission switch.

- [Architecture](architecture/README.md): ownership and process boundaries.
- [Wine prefix architecture](architecture/wine-prefix.md): prefix topology, isolation, migrations, drive mappings, persistent state, and process ownership.
- [Testing architecture](testing.md) and [Design](design.md): read before you change behavior.
- [Error recovery](error-recovery.md): stable support codes, failure presentation, and guarded actions.
- [Releases and updates](releases-and-updates.md): release and runtime workflow.
- [License automation](license-automation.md): third-party license index, checks, and packaging.
- [Runtime updates](runtime-updates.md): pin a runtime release and update every mention of it.
- [Wallpaper tagging and search](wallpaper-tagging.md): curated metadata for official artwork presets.
- [Runtime compatibility](../help/runtime-compatibility.md): a user guide that is also the runtime contract for development and packaging.

## Before handing off a change

1. Run the narrowest focused check while you iterate. Add regression coverage where behavior changed.
2. Update the affected guide or contract. Add user-visible changes to `CHANGELOG.md`.
3. Run the relevant formatter, inspect its diff, and rerun the focused check.
4. Run `just ci`.
5. For website and documentation changes, also run `just check web` and the production site build below.

## Documentation authoring

The website treats Markdown as a checked content source. Start every published file with YAML frontmatter:

```yaml
---
title: Installation architecture
description: Manifest validation and installation boundaries
order: 20
audience: developers
toc: true
---
```

| Key                      | Rule                                                                                       |
| ------------------------ | ------------------------------------------------------------------------------------------ |
| `title`, `description`   | Required.                                                                                  |
| `order`                  | Finite number for sorting.                                                                 |
| `hidden`, `draft`, `toc` | Booleans. `hidden` removes the page from navigation. `toc` controls the table of contents. |
| `audience`               | `all`, `developers`, or `users`.                                                           |
| `code`                   | Optional. One uppercase English word. Requires a non-empty `domain`.                       |

- Error codes are unique across documentation files.
- Register public codes in `docs/help/errors/registry.json`. They use `/help/errors/<lowercase-code>/` and need exactly one matching page.
- A top-level section with `audience: developers` appears under **Contributors** in the sidebar and not on the home page.
- A `draft: true` file fails the production build.
- Keep player pages short. Put implementation details here.

The site removes a first-level heading that exactly matches `title`, because the page header shows it. A different first heading stays visible.

### Directories and routes

Use `README.md` for a directory landing page. Its metadata sets the directory title, description, order, visibility, audience, and table of contents. Its body is the introduction above the child-page list. Without a README, the build creates a landing page from the visible children.

`README.md` maps to the directory route: `docs/development/README.md` becomes `/development/`. Do not add `index.md`. The website rejects it. The root `README.md` is not copied into the docs tree.

### Alerts

Use uppercase GitHub alert markers in blockquotes. The website and the launcher recognize the same five markers. The launcher shows them as a labeled text block, so meaning must not depend on color.

| Marker         | Use it for                                                          |
| -------------- | ------------------------------------------------------------------- |
| `[!NOTE]`      | Context, scope, or a limitation that prevents a wrong assumption    |
| `[!TIP]`       | An optional shortcut or a more convenient route                     |
| `[!IMPORTANT]` | A required invariant or decision readers must follow                |
| `[!WARNING]`   | A likely failure, data loss, unsafe command, or external dependency |
| `[!CAUTION]`   | A high-impact release, security, credential, or irreversible action |

Keep alerts short. Use one marker per point. Do not nest alerts or use them as section headers.

### Mermaid diagrams

Put diagrams in fenced `mermaid` blocks. The website loads Mermaid only on pages with such a block, renders at a strict security level, and keeps the source as a fallback. Use flowcharts or sequence diagrams with short labels, readable on the dark theme. Do not use HTML, scripts, external assets, or callbacks. The launcher shows fenced code as text, so the prose must explain the contract without the diagram.

### Links and content checks

Use relative Markdown links with the `.md` suffix. The production build resolves them to site routes, validates local targets and heading anchors, rejects unsafe and protocol-relative links, and permits only `https:` and `mailto:` external links. Update link fragments when you rename headings. The renderer escapes raw HTML.

## Documentation website

The SvelteKit site in `web/` builds these files into the project website. It uses Anasthasia's components and base tokens with a launcher-specific flavour in `web/src/lib/styles/arknights-client.css`. Like the launcher, it is dark-only.

- The home page shows one official Arknights Global wallpaper from `web/static/artwork/`, the only artwork the repository bundles. Show it uncropped at 16:9. Credit the artist, Hypergryph, and Yostar beside it.
- `--site-signal` is the accent that the launcher's `WallpaperColorExtractor` derives from that wallpaper. `--site-signal-text` is its AA-readable text variant. Update both together when the wallpaper changes.
- Use the signal only for the primary download action, active navigation, and focus. Use tinted fills, not solid ones. Keep secondary controls as quiet neutral capsules.

Use Node 24.14 or newer and the `pnpm` version in `web/package.json` (the lockfile is the source of truth). Use `just dev web` to edit, `just format web` if needed, and `just check web` for Svelte, type, and Prettier checks. It skips the content build. Run the production build:

```sh
cd web
BASE_PATH=/Arknights-MacOS-Client pnpm build
```

The build reads `docs/` and `CHANGELOG.md`. It fails unless frontmatter, routes, links, heading anchors, canonical and social URLs, navigation visibility, accessibility metadata, and deployment-base paths are valid.

A documentation-only edit does not trigger Pages. Pages builds from `main` with a manually triggered release or through **Actions → Publish website → Run workflow**, defined in `.github/workflows/pages.yml`.

> [!IMPORTANT]
> Run the manual Pages workflow from `main`. Other branches fail before deployment.
