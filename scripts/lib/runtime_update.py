# SPDX-License-Identifier: MPL-2.0

"""Pin a published Arknights macOS Runtime release and keep every mention current.

A release publishes `provenance.json` and two `.sha256` files. `update` reads them over
HTTPS, checks that they agree, and rewrites the release-derived fields of `runtime.json`.
`render_documents` fills the generated `runtime` blocks of the documents from
`runtime.json` alone, so `check` runs offline. The blocks use the marker syntax of the
license generator: `<!-- runtime:begin NAME -->` and `<!-- runtime:end NAME -->`.
"""

from __future__ import annotations

import json
import re
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Any

from runtime_config import (
    COMMIT_PATTERN,
    SHA256_PATTERN,
    RuntimeLayout,
    load_runtime_config,
)

from lib.common import fail
from lib.licenses import (
    Component,
    apply_blocks,
    load_client_components,
    read_json,
    runtime_release,
    tree_url,
)

REPOSITORY = "LuMiSxh/Arknights-MacOS-Runtime"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
RELEASES_API = f"https://api.github.com/repos/{REPOSITORY}/releases?per_page=100"
RUNTIME_CONFIG = Path("runtime.json")
NOTICES_DOCUMENT = Path("docs/legal/third-party-notices.md")
BLOCK_NAMESPACE = "runtime"
TAG_PATTERN = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?$")
MAXIMUM_ASSET_BYTES = 8 * 1_024 * 1_024
PRETTIER_WIDTH = 80
COMPONENT_ROWS = (
    ("wine", "WineCX / Wine", "Wine "),
    ("dxmt", "DXMT", ""),
    ("moltenvk", "MoltenVK", ""),
)

Fetch = Callable[[str], bytes]


def https_fetcher(user_agent: str) -> Fetch:
    """Return a bounded HTTPS GET that follows redirects to HTTPS URLs only."""

    def fetch(url: str) -> bytes:
        if urllib.parse.urlparse(url).scheme != "https":
            fail(f"remote URL must use HTTPS: {url}")
        request = urllib.request.Request(url, headers={"User-Agent": user_agent})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                if urllib.parse.urlparse(response.geturl()).scheme != "https":
                    fail(f"request redirected to a non-HTTPS URL: {url}")
                value = response.read(MAXIMUM_ASSET_BYTES + 1)
        except urllib.error.HTTPError as error:
            fail(f"request failed with status {error.code}: {url}")
        except urllib.error.URLError as error:
            fail(f"request failed: {url}: {error.reason}")
        if len(value) > MAXIMUM_ASSET_BYTES:
            fail(f"remote response exceeds {MAXIMUM_ASSET_BYTES} bytes: {url}")
        return value

    return fetch


def normalize_tag(value: str) -> str:
    tag = value if value.startswith("v") else f"v{value}"
    if TAG_PATTERN.fullmatch(tag) is None:
        fail(f"not a runtime release tag: {value}")
    return tag


def latest_tag(fetch: Fetch, include_prerelease: bool) -> str:
    """Return the newest published release; skip drafts and, by default, prereleases."""
    releases = json.loads(fetch(RELEASES_API))
    if not isinstance(releases, list):
        fail("GitHub returned an invalid release list")
    published = [
        release
        for release in releases
        if isinstance(release, dict)
        and not release.get("draft")
        and (include_prerelease or not release.get("prerelease"))
        and isinstance(release.get("tag_name"), str)
        and TAG_PATTERN.fullmatch(release["tag_name"])
        and isinstance(release.get("published_at"), str)
    ]
    if not published:
        hint = (
            ""
            if include_prerelease
            else "; pass --include-prerelease to accept a prerelease"
        )
        fail(f"no published runtime release found{hint}")
    return max(published, key=lambda release: release["published_at"])["tag_name"]


def asset_names(tag: str) -> tuple[str, str]:
    stem = f"Arknights-MacOS-Runtime-{tag}"
    return f"{stem}.tar.gz", f"{stem}-source.tar.gz"


def asset_url(tag: str, name: str) -> str:
    return f"{REPOSITORY_URL}/releases/download/{tag}/{name}"


def _checksum(fetch: Fetch, tag: str, name: str, expected: Mapping[str, Any]) -> str:
    line = fetch(asset_url(tag, f"{name}.sha256")).decode("utf-8").split()
    digest = expected.get("sha256")
    if expected.get("name") != name:
        fail(f"provenance.json names {expected.get('name')!r}, expected {name!r}")
    if len(line) != 2 or line[1].lstrip("*") != name:
        fail(f"{name}.sha256 does not describe {name}")
    if SHA256_PATTERN.fullmatch(line[0]) is None or line[0] != digest:
        fail(f"{name}.sha256 ({line[0]}) differs from provenance.json ({digest})")
    return line[0]


def fetch_provenance(fetch: Fetch, tag: str) -> dict[str, Any]:
    """Download `provenance.json` and prove that it agrees with the checksum files."""
    provenance = json.loads(fetch(asset_url(tag, "provenance.json")))
    if not isinstance(provenance, dict) or provenance.get("releaseTag") != tag:
        fail(f"provenance.json does not describe {tag}")
    archive, source = asset_names(tag)
    _checksum(fetch, tag, archive, provenance.get("runtimeArchive") or {})
    _checksum(fetch, tag, source, provenance.get("correspondingSourceArchive") or {})
    return provenance


def check_interface(layout: RuntimeLayout, provenance: Mapping[str, Any]) -> None:
    """Fail when the release interface differs from the interface in `runtime.json`."""
    wine, dxmt = layout.archive_wine_directory, layout.archive_dxmt_directory
    published = provenance["runtimeLock"]["contents"]["interface"]
    expected = {
        "wineDirectory": str(wine),
        "dxmtDirectory": str(dxmt),
        "runtimeCapabilities": str(layout.capability_manifest_path),
        "executables": sorted(
            str(wine / path) for path in (*layout.executables, layout.launcher.path)
        ),
        "requiredFiles": sorted(
            [str(wine / path) for path in (*layout.required_files, layout.mac_driver)]
            + [
                str(dxmt / architecture / library)
                for architecture, _ in layout.dxmt.destinations
                for library in layout.dxmt.libraries
            ]
        ),
    }
    actual = {
        **published,
        "executables": sorted(published["executables"]),
        "requiredFiles": sorted(published["requiredFiles"]),
    }
    drift = [key for key in expected if expected[key] != actual.get(key)]
    if drift:
        fail(
            "the release interface differs from runtime.json interface ("
            + ", ".join(drift)
            + "); update the interface by hand and review the Swift runtime code"
        )


def _repository(value: str) -> str:
    return value.removesuffix(".git")


def updated_manifest(
    manifest: Mapping[str, Any],
    tag: str,
    provenance: Mapping[str, Any],
    moltenvk_version: str | None = None,
) -> dict[str, Any]:
    """Return `manifest` with every release-derived field taken from `provenance`."""
    lock = provenance["runtimeLock"]["contents"]
    sources, base = lock["sources"], lock["baseProvenance"]
    archive, source = asset_names(tag)
    for commit in (
        provenance["sourceCommit"],
        sources["wine"]["commit"],
        sources["dxmt"]["commit"],
        base["moltenvk"]["commit"],
        lock["build"]["nixpkgs"]["commit"],
        lock["baseArtifact"]["recipe"]["commit"],
    ):
        if COMMIT_PATTERN.fullmatch(commit) is None:
            fail(f"provenance.json has an invalid Git commit: {commit!r}")
    result = json.loads(json.dumps(manifest))
    previous = result["provenance"]
    moltenvk_changed = previous["moltenvkCommit"] != base["moltenvk"]["commit"]
    if moltenvk_changed and moltenvk_version is None:
        fail(
            "the MoltenVK commit changed and provenance.json has no MoltenVK version; "
            "pass --moltenvk-version"
        )
    result["runtime"] = {
        "name": f"Arknights macOS Runtime {tag.removeprefix('v')}",
        "url": asset_url(tag, archive),
        "sha256": provenance["runtimeArchive"]["sha256"],
    }
    result["buildRecipe"] = {
        "url": asset_url(tag, source),
        "sha256": provenance["correspondingSourceArchive"]["sha256"],
    }
    result["components"] = {
        "wine": sources["wine"]["version"],
        "dxmt": sources["dxmt"]["version"],
        "moltenvk": moltenvk_version or result["components"]["moltenvk"],
    }
    previous.update(
        buildRepository=REPOSITORY_URL,
        buildCommit=provenance["sourceCommit"],
        wineRepository=_repository(sources["wine"]["repository"]),
        wineCommit=sources["wine"]["commit"],
        dxmtRepository=_repository(sources["dxmt"]["repository"]),
        dxmtCommit=sources["dxmt"]["commit"],
        moltenvkRepository=_repository(base["moltenvk"]["repository"]),
        moltenvkCommit=base["moltenvk"]["commit"],
        nixpkgsRepository=_repository(lock["build"]["nixpkgs"]["repository"]),
        nixpkgsCommit=lock["build"]["nixpkgs"]["commit"],
        baseRecipeRepository=_repository(lock["baseArtifact"]["recipe"]["repository"]),
        baseRecipeCommit=lock["baseArtifact"]["recipe"]["commit"],
        baseArchiveUrl=lock["baseArtifact"]["url"],
        baseArchiveSha256=lock["baseArtifact"]["sha256"],
    )
    return result


def format_manifest(manifest: Mapping[str, Any]) -> str:
    """Serialize like Prettier: two spaces, short string arrays on one line."""
    return _dump(manifest, 0, 0, True) + "\n"


def _dump(value: Any, indent: int, column: int, last: bool) -> str:
    if isinstance(value, dict):
        pad = " " * (indent + 2)
        items = list(value.items())
        lines = []
        for position, (key, item) in enumerate(items):
            head = f"{json.dumps(key)}: "
            body = _dump(
                item,
                indent + 2,
                indent + 2 + len(head),
                position == len(items) - 1,
            )
            lines.append(f"{pad}{head}{body}")
        return "{\n" + ",\n".join(lines) + "\n" + " " * indent + "}"
    if isinstance(value, list):
        inline = (
            "["
            + ", ".join(json.dumps(item, ensure_ascii=False) for item in value)
            + "]"
        )
        if column + len(inline) + (0 if last else 1) <= PRETTIER_WIDTH:
            return inline
        pad = " " * (indent + 2)
        items = ",\n".join(
            f"{pad}{json.dumps(item, ensure_ascii=False)}" for item in value
        )
        return "[\n" + items + "\n" + " " * indent + "]"
    return json.dumps(value, ensure_ascii=False)


def _slug(repository: str) -> str:
    return urllib.parse.urlparse(repository).path.strip("/").removesuffix(".git")


def render_components_block(
    manifest: Mapping[str, Any], components: tuple[Component, ...]
) -> str:
    """Render the runtime components table of the third-party notices."""
    provenance = manifest["provenance"]
    release = runtime_release(manifest)
    lines = [
        "| Component | Version or revision | License | Exact provenance source |",
        "| --- | --- | --- | --- |",
    ]
    for key, label, prefix in COMPONENT_ROWS:
        spdx = next((c.spdx for c in components if c.runtime_component == key), None)
        if spdx is None:
            fail(
                f"docs/legal/licenses/index.json has no entry for runtimeComponent {key}"
            )
        commit, repository = provenance[f"{key}Commit"], provenance[f"{key}Repository"]
        lines.append(
            f"| {label} | {prefix}{manifest['components'][key]}, `{commit}` "
            f"| {spdx} and bundled third-party terms "
            f"| [{_slug(repository)} commit]({tree_url(repository, commit)}) |"
        )
    libraries = next((c for c in components if c.runtime_release), None)
    if libraries is None:
        fail("docs/legal/licenses/index.json has no entry with runtimeRelease")
    nixpkgs = provenance["nixpkgsCommit"]
    lines.append(
        f"| Nix libraries | {', '.join(libraries.libraries)} | {libraries.spdx} "
        f"| [Runtime {release.tag}]({release.tree}), Nixpkgs `{nixpkgs}` |"
    )
    return "\n".join(lines) + "\n"


def render_build_block(manifest: Mapping[str, Any]) -> str:
    """Render the build-provenance paragraph and table of the third-party notices."""
    provenance = manifest["provenance"]
    release = runtime_release(manifest)
    base = re.fullmatch(
        r"(?P<repository>https://github\.com/[^/]+/(?P<name>[^/]+))/releases/download/"
        r"(?P<tag>[^/]+)/[^/]+",
        provenance["baseArchiveUrl"],
    )
    if base is None:
        fail("provenance.baseArchiveUrl must be a GitHub release asset URL")
    recipe, recipe_commit = (
        provenance["baseRecipeRepository"],
        provenance["baseRecipeCommit"],
    )
    recipe_name = _slug(recipe).split("/")[-1]
    nixpkgs = provenance["nixpkgsRepository"], provenance["nixpkgsCommit"]
    rows = (
        (
            f"| Runtime build | Arknights macOS Runtime {release.tag} "
            f"| [Runtime {release.tag} tag]({release.tree}), [release]({release.page}) |"
        ),
        (
            f"| {base['name']} base libraries | {base['tag']}, "
            f"`{provenance['baseArchiveSha256']}` archive SHA-256 "
            f"| [{base['name']} {base['tag']} release]"
            f"({base['repository']}/releases/tag/{base['tag']}) |"
        ),
        (
            f"| {recipe_name} base recipe | `{recipe_commit}` "
            f"| [{recipe_name} commit]({tree_url(recipe, recipe_commit)}) |"
        ),
        f"| Nixpkgs | `{nixpkgs[1]}` | [Nixpkgs commit]({tree_url(*nixpkgs)}) |",
    )
    return (
        f"The {release.tag} runtime was built from the release tag and exact inputs "
        "below. The base archive and Nixpkgs revision are build inputs, not "
        "independently selected runtime components. They remain part of the release's "
        "corresponding-source record.\n\n"
        "| Build input | Version or revision | Exact provenance source |\n"
        "| --- | --- | --- |\n" + "\n".join(rows) + "\n"
    )


def render_documents(root: Path) -> dict[Path, str]:
    """Return the documents with up-to-date `runtime` blocks."""
    problems: list[str] = []
    components = load_client_components(root, problems)
    if problems:
        fail("\n".join(problems))
    manifest = read_json(root / RUNTIME_CONFIG)
    blocks = {
        NOTICES_DOCUMENT: {
            "components": render_components_block(manifest, components),
            "build": render_build_block(manifest),
        }
    }
    return {
        path: apply_blocks(
            (root / path).read_text(encoding="utf-8"), values, True, BLOCK_NAMESPACE
        )
        for path, values in blocks.items()
    }


def manifest_problems(manifest: Mapping[str, Any]) -> list[str]:
    """Compare the release-derived fields with the tag in the archive URL (offline)."""
    release = runtime_release(manifest)
    archive, source = asset_names(release.tag)
    expected = {
        "runtime.name": (
            manifest["runtime"]["name"],
            f"Arknights macOS Runtime {release.version}",
        ),
        "runtime.url": (manifest["runtime"]["url"], asset_url(release.tag, archive)),
        "buildRecipe.url": (
            manifest["buildRecipe"]["url"],
            asset_url(release.tag, source),
        ),
        "provenance.buildRepository": (
            manifest["provenance"]["buildRepository"],
            REPOSITORY_URL,
        ),
    }
    return [
        f"runtime.json: {key} is {actual!r}, the tag {release.tag} implies {wanted!r}"
        for key, (actual, wanted) in expected.items()
        if actual != wanted
    ]


def check(root: Path) -> None:
    """Fail when `runtime.json` or a generated `runtime` block is stale; no network."""
    manifest = read_json(root / RUNTIME_CONFIG)
    problems = manifest_problems(manifest)
    if not problems:
        problems.extend(
            f"{path}: runtime blocks are stale; run scripts/update_runtime.py"
            for path, text in render_documents(root).items()
            if (root / path).read_text(encoding="utf-8") != text
        )
    if problems:
        fail("\n".join(problems))


def update(
    root: Path,
    tag: str,
    fetch: Fetch,
    moltenvk_version: str | None = None,
) -> list[Path]:
    """Pin `tag` and rewrite `runtime.json` and the `runtime` blocks; return changes."""
    target = root / RUNTIME_CONFIG
    original = target.read_text(encoding="utf-8")
    provenance = fetch_provenance(fetch, tag)
    current = load_runtime_config(target)
    manifest = current.raw
    check_interface(current.layout, provenance)
    text = format_manifest(
        updated_manifest(manifest, tag, provenance, moltenvk_version)
    )
    changed: list[Path] = []
    if text != original:
        target.write_text(text, encoding="utf-8")
        changed.append(RUNTIME_CONFIG)
    try:
        load_runtime_config(target)
        documents = render_documents(root)
    except BaseException:
        target.write_text(original, encoding="utf-8")
        raise
    for path, document in documents.items():
        if (root / path).read_text(encoding="utf-8") != document:
            (root / path).write_text(document, encoding="utf-8")
            changed.append(path)
    return changed
