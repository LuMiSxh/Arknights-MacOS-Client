---
title: Development
description: Architecture, design, testing, localization, release, and runtime contracts for contributors
order: 30
---

# Development

These documents describe how Arknights Client is organized, tested, localized, packaged, and maintained. The launcher targets Apple Silicon and macOS 15 or newer and supports Yostar's official Global, Japan, and Korea PC clients.

Start with [Architecture](architecture/README.md) for ownership and process boundaries. Before changing behavior, check [Testing architecture](testing.md), [Design](design.md), and [Localization](localization.md) as applicable. [Error recovery](error-recovery.md) defines stable support codes, failure presentation, and guarded actions. [Releases and updates](releases-and-updates.md) documents the release and runtime workflow. The user-facing [Runtime compatibility](../help/runtime-compatibility.md) guide is also the runtime contract for development and packaging.

Proposals are retained under `proposals/` for project history and are hidden from the primary development index until accepted. They are not implementation or support commitments.

## Before handing off a change

1. Run the narrowest focused check while iterating and add regression coverage where behavior changed.
2. Update the affected guide or contract and add user-visible changes to `CHANGELOG.md`.
3. Run the relevant formatter, inspect its diff, and rerun the focused check.
4. Run `just ci` before completion. Website and documentation changes additionally require `just check web` and the production site build documented below.

Keep the branch and pull-request strategy proportional to the change; the repository does not require a special branch naming convention.

## Documentation authoring

The website treats Markdown as a checked content source. Start every published file with a YAML frontmatter block:

```yaml
---
title: Installation architecture
description: Manifest validation and installation boundaries
order: 20
audience: developers
toc: true
---
```

`title` and `description` are required. `order` is a finite number used for sorting; `hidden`, `draft`, and `toc` are booleans; and `audience` is `all`, `developers`, or `users`. An optional `code` must be one uppercase English word and must be paired with a non-empty `domain`; error codes are unique across documentation files. Public codes are registered in `docs/help/errors/registry.json`, use `/help/errors/<lowercase-code>/`, and must have exactly one matching page. `audience` is currently descriptive metadata, while `hidden` controls navigation and `toc` controls the page table of contents. A `draft: true` file fails the production build rather than silently publishing an unfinished page.

The site renders the frontmatter title in its page header. A first-level Markdown heading that exactly matches `title` is removed from the body, so use that heading when the same document is also read in the repository or launcher. A different first heading remains visible and is useful only when the page deliberately needs a second title.

### Directories and routes

Use `README.md` for a directory landing page. Its metadata defines the directory title, description, order, visibility, audience, and table-of-contents setting; its body becomes the introduction above the child-page list. Without a README, the build creates a landing page from the directory name and its visible children. Add a README when the section needs context, a recommended reading order, or links that are not represented by child files.

`README.md` maps to the directory route (`docs/development/README.md` becomes `/development/`). Do not add `index.md`: the website rejects it so repositories and the generated site use one unambiguous convention. The repository root `README.md` remains a project entry point and is not copied into the docs tree.

### Alerts

Use GitHub alert markers in uppercase blockquotes. The website and the launcher's bundled Markdown parser recognize the same five markers, but the launcher reduces them to a labeled native text block; do not make the meaning depend on alert color.

| Marker         | Use it for                                                          |
| -------------- | ------------------------------------------------------------------- |
| `[!NOTE]`      | Context, scope, or a limitation that prevents a wrong assumption    |
| `[!TIP]`       | An optional shortcut or a more convenient route                     |
| `[!IMPORTANT]` | A required invariant or decision readers must follow                |
| `[!WARNING]`   | A likely failure, data loss, unsafe command, or external dependency |
| `[!CAUTION]`   | A high-impact release, security, credential, or irreversible action |

Keep alerts short and actionable. Use one marker for one point instead of nesting alerts or using them as visual section headers. All alert variants intentionally share the same geometry and typography on the website; only their semantic color changes.

### Mermaid diagrams

Put diagrams in fenced `mermaid` blocks. The website lazy-loads Mermaid only on pages that contain such a block, renders with a strict security level, and keeps the source as a fallback when rendering fails. Use ordinary flowcharts or sequence diagrams with concise labels, keep both light and dark themes readable, and avoid HTML, scripts, external assets, or behavior that requires Mermaid callbacks. The native launcher currently shows fenced code as text, so the surrounding prose must explain the contract without requiring the diagram.

### Links and content checks

Prefer relative Markdown links for repository documents, with the `.md` suffix. The production website build resolves those links to site routes, validates local targets and heading anchors, rejects unsafe or protocol-relative links, and permits only `https:`/`mailto:` external links. Keep link fragments in sync when renaming headings. Raw HTML is escaped by the website renderer; use Markdown instead.

## Documentation website

The SvelteKit site in `web/` builds these Markdown files into the project website. Every published document requires YAML frontmatter with at least `title` and `description`; `order`, `hidden`, `audience`, and `toc` refine navigation and presentation.

The site uses Anasthasia's components and base tokens with a launcher-specific flavour in `web/src/lib/styles/arknights-client.css`. Keep that local flavour aligned with the launcher's compact graphite surfaces and reserve cyan for the primary download action and active navigation. Reuse library components for matching UI contracts, including semantic badges for compact supported and unsupported states.

Use Node 24.14 or newer and the `pnpm` version declared by `web/package.json`; the lockfile is the dependency source of truth. Use `just dev web` for local editing. Before opening a change, run `just format web` if needed and `just check web` for Svelte/type and Prettier checks. The check command does not run the content/prerender build; run the production check explicitly from the website directory:

```sh
cd web
BASE_PATH=/Arknights-MacOS-Client pnpm build
```

That build reads `docs/` and `CHANGELOG.md` at prerender time and fails unless frontmatter, routes,
links, heading anchors, canonical/social URLs, navigation visibility, accessibility metadata, and
deployment-base paths are valid. A documentation-only edit does not trigger Pages automatically.
Pages is built from `main` alongside a manually triggered release or through **Actions → Publish
website → Run workflow**, defined in `.github/workflows/pages.yml`.

> [!IMPORTANT]
> Run the manual Pages workflow from `main`. Other branches fail before deployment, and documentation changes never dispatch it automatically.
