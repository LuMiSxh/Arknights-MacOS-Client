---
title: Development
description: Architecture, design, testing, release, and runtime contracts for contributors
order: 30
audience: developers
---

# Development

## Before handing off a change

1. Run the narrowest focused check while you iterate. Add regression coverage where behavior changed.
2. Update the affected guide or contract. Add user-visible changes to `CHANGELOG.md`.
3. Run the relevant formatter, inspect its diff, and rerun the focused check.
4. Run `just ci`.
5. For website and documentation changes, also run `just check web` and the production site build in [Documentation website](#documentation-website).

## Documentation authoring

Start every published Markdown file with YAML frontmatter:

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
| `code`                   | Optional. A code in the form `XX-XXX`. Requires a non-empty `domain`.                      |

- Public error codes come from `support-codes.json`. Do not edit the generated code pages, the generated tables in `docs/help/errors/README.md`, or `docs/help/errors/registry.json`. Each active code has one page at `/help/errors/<lowercase-code>/`.
- A top-level section with `audience: developers` appears under **Contributors** in the sidebar.
- A `draft: true` file fails the production build.
- Use `README.md` for a directory landing page. It maps to the directory route. Do not add `index.md`. Without a README, the build lists the visible children.
- Use relative Markdown links with the `.md` suffix. The build validates local targets and heading anchors. Update link fragments when you rename a heading. External links use only `https:` or `mailto:`.
- Use GitHub alert markers (`[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!CAUTION]`) in blockquotes. The launcher shows them as labeled text, so meaning must not depend on color. Use one marker per point. Do not nest alerts.
- Put diagrams in fenced `mermaid` blocks with short labels. The launcher shows the block as text, so the prose must explain the contract.

## Documentation website

The SvelteKit site in `web/` builds `docs/` and `CHANGELOG.md` into the project website. It is dark-only and uses the tokens in `web/src/lib/styles/arknights-client.css`.

- The home page shows one official Arknights Global wallpaper from `web/static/artwork/`, the only artwork the repository bundles. Show it uncropped at 16:9. Credit the artist, Hypergryph, and Yostar beside it.
- `--site-signal` is the accent that `WallpaperColorExtractor` derives from that wallpaper. `--site-signal-text` is its AA-readable text variant. Update both together when the wallpaper changes.
- Use the signal only for the primary download action, active navigation, and focus. Use tinted fills. Keep secondary controls as quiet neutral capsules.

Use Node 24.14 or newer and the `pnpm` version in `web/package.json`. The website has no Vitest suite. Validate it with these commands:

```sh
just check web
cd web
BASE_PATH=/Arknights-MacOS-Client pnpm build
```

`just check web` runs Svelte, type, and Prettier checks. Run `just format web` to accept Prettier changes. The build fails unless frontmatter, routes, links, heading anchors, canonical and social URLs, accessibility metadata, and base-path URLs are valid. For a UI or Mermaid change, also check light, dark, desktop, and mobile pages with `just dev web`.

`just ci` does not run these checks. A documentation-only edit does not trigger Pages. Run **Actions → Publish website → Run workflow** from `main`, or let the release workflow call it. Other branches fail before deployment.

### Blog posts

Write each post as one file in `docs/blog/`. Name the file `YYYY-MM-DD-slug.md`. The date in the file name must match `date`. The blog is not part of the documentation tree.

Use this frontmatter:

- `title`: required. The post title.
- `date`: required. An existing date in `YYYY-MM-DD` form.
- `summary`: required. One or two sentences. The listing and search show it.
- `draft`: optional. Set `true` to hide the post from production.

The post URL is `/blog/<slug>/`. The slug is the file name without the date. Keep the slug stable after you publish. The listing is at `/blog/`.

Drafts appear under `pnpm dev`. The listing marks them as Draft. Drafts do not appear in production output.

Use a fenced block with the info string `share-chart` to show relative sizes. Write the block as YAML or JSON:

````markdown
```share-chart
title: Chip family
items:
  - label: M1
    share: 0.31
  - label: M2
    share: 0.27
```
````

- `title` is required. It names the chart.
- `items` is a non-empty list. Each item needs a `label` and a `share`.
- A `share` is a number from 0 to 1. The build fails for any other value.
- The chart shows no numbers. Screen readers hear a coarse wording, such as "about a third".
- The bars keep the order you write.
- Quote a value that contains a colon, such as `"Chip family: TODO"`. Unquoted colons break the YAML.

To add developer notes, use `<details>` and `<summary>`. Use no attributes. Leave a blank line before and after the Markdown inside. Other raw HTML is escaped.
