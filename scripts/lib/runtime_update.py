# SPDX-License-Identifier: MPL-2.0

"""Pin one lane of the Arknights macOS Runtime and keep every mention current.

A release publishes `provenance.json` and two `.sha256` files. `update` reads them over
HTTPS, checks that they agree, and rewrites the runtime pin of one lane in `runtime.json`.
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
    MINIMUM_MACOS_PATTERN,
    RUNTIME_ARCHITECTURES,
    SHA256_PATTERN,
    RuntimeLaneConfiguration,
    load_runtime_config,
)

from lib import generated_blocks
from lib.common import fail
from lib.http import HttpError
from lib.http import fetch as http_fetch
from lib.licenses import (
    Component,
    load_client_components,
    read_json,
    tree_url,
)

REPOSITORY = "LuMiSxh/Arknights-MacOS-Runtime"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
RELEASES_API = f"https://api.github.com/repos/{REPOSITORY}/releases?per_page=100"
RELEASE_API = f"https://api.github.com/repos/{REPOSITORY}/releases/tags/"
RUNTIME_CONFIG = Path("runtime.json")
NOTICES_DOCUMENT = Path("docs/legal/third-party-notices.md")
BLOCK_NAMESPACE = "runtime"
TAG_PATTERN = re.compile(
    r"^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
RUNTIME_ARCHITECTURE = "x86"
BUILD_METADATA = "+"
MAXIMUM_ASSET_BYTES = 8 * 1_024 * 1_024
PRETTIER_WIDTH = 80
LANE_TARGETS = {"x86": "rosetta-x86_64", "arm": "native-arm64"}
# Wine and DXMT are the components a lane can carry from `runtimeLock.contents.sources`;
# MoltenVK comes only from `baseProvenance`.
RUNTIME_COMPONENTS = ("wine", "dxmt")
ASSET_URL_PATTERN = re.compile(
    rf"^{re.escape(REPOSITORY_URL)}/releases/download/(?P<tag>[^/]+)/(?P<name>[^/]+)$"
)

Fetch = Callable[[str], bytes]


def https_fetcher(user_agent: str) -> Fetch:
    """Return a bounded HTTPS GET that follows redirects to HTTPS URLs only."""

    def fetch(url: str) -> bytes:
        try:
            return http_fetch(
                url,
                user_agent=user_agent,
                timeout=30,
                max_bytes=MAXIMUM_ASSET_BYTES,
            ).body
        except HttpError as error:
            fail(str(error))

    return fetch


def normalize_tag(value: str) -> str:
    tag = value if value.startswith("v") else f"v{value}"
    if TAG_PATTERN.fullmatch(tag) is None:
        fail(f"not a runtime release tag: {value}")
    return tag


def tag_architecture(tag: str) -> str:
    """Return the architecture of a release tag; older tags have no metadata."""
    return (
        tag.split(BUILD_METADATA, 1)[1]
        if BUILD_METADATA in tag
        else RUNTIME_ARCHITECTURE
    )


def latest_tag(
    fetch: Fetch,
    include_prerelease: bool,
    architecture: str = RUNTIME_ARCHITECTURE,
) -> str:
    """Return the newest published release for one architecture; skip drafts."""
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
        and tag_architecture(release["tag_name"]) == architecture
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


def release_asset_size(fetch: Fetch, tag: str, name: str) -> int:
    """Read the archive size from the GitHub release metadata."""
    try:
        document = json.loads(fetch(f"{RELEASE_API}{tag}"))
    except json.JSONDecodeError:
        fail(f"GitHub returned invalid metadata for {tag}")
    if not isinstance(document, dict):
        fail(f"GitHub returned invalid metadata for {tag}")
    for asset in document.get("assets") or []:
        if (
            isinstance(asset, dict)
            and asset.get("name") == name
            and isinstance(asset.get("size"), int)
            and asset["size"] > 0
        ):
            return asset["size"]
    fail(f"release {tag} has no size for {name}; pass --size")


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


def _published_interface(
    architecture: str, provenance: Mapping[str, Any]
) -> Mapping[str, Any] | None:
    """Return the release interface of one lane, or the usable part of it."""
    lock = provenance.get("runtimeLock")
    contents = lock.get("contents") if isinstance(lock, dict) else None
    if isinstance(contents, dict):
        targets = contents.get("targets")
        target = LANE_TARGETS[architecture]
        if isinstance(targets, dict):
            entry = targets.get(target)
            if isinstance(entry, dict) and isinstance(entry.get("interface"), dict):
                return entry["interface"]
        if architecture == "x86" and isinstance(contents.get("interface"), dict):
            return contents["interface"]
    if isinstance(provenance.get("interface"), dict):
        return provenance["interface"]
    if provenance.get("target") == LANE_TARGETS[architecture]:
        partial: dict[str, Any] = {}
        if isinstance(provenance.get("minimumMacOS"), str):
            partial["minimumMacOS"] = provenance["minimumMacOS"]
        if isinstance(provenance.get("features"), dict):
            partial["features"] = provenance["features"]
        return partial or None
    return None


def check_interface(
    lane: RuntimeLaneConfiguration, provenance: Mapping[str, Any]
) -> None:
    """Fail when the release interface differs from the lane in `runtime.json`."""
    published = _published_interface(lane.name, provenance)
    if published is None:
        return
    wine, dxmt = lane.layout.archive_wine_directory, lane.layout.archive_dxmt_directory
    expected: dict[str, Any] = {
        "wineDirectory": str(wine),
        "dxmtDirectory": str(dxmt),
        "features": lane.layout.features.mapping(),
        "minimumMacOS": lane.minimum_macos,
        "executables": sorted(
            str(wine / path)
            for path in (*lane.layout.executables, lane.layout.launcher.path)
        ),
        "requiredFiles": sorted(
            {
                str(wine / path)
                for path in (*lane.layout.required_files, lane.layout.mac_driver)
            }
            | {
                str(dxmt / architecture / library)
                for architecture, _ in lane.layout.dxmt.destinations
                for library in lane.layout.dxmt.libraries
            }
        ),
    }
    actual = dict(published)
    if "executables" in actual:
        actual["executables"] = sorted(actual["executables"])
    if "requiredFiles" in actual:
        actual["requiredFiles"] = sorted(actual["requiredFiles"])
    drift = [
        key for key in expected if key in actual and expected[key] != actual.get(key)
    ]
    if drift:
        fail(
            f"the release interface differs from the {lane.name} lane in runtime.json ("
            + ", ".join(drift)
            + "); update the interface by hand and review the Swift runtime code"
        )


def _repository(value: str) -> str:
    return value.removesuffix(".git")


def _commit(value: object, label: str) -> str:
    if not isinstance(value, str) or COMMIT_PATTERN.fullmatch(value) is None:
        fail(f"provenance.json has an invalid Git commit for {label}: {value!r}")
    return value


def _update_provenance(
    lane: Mapping[str, Any],
    provenance: Mapping[str, Any],
    moltenvk_version: str | None,
) -> None:
    """Update the component versions and sources that the release names."""
    lock = provenance.get("runtimeLock")
    contents = lock.get("contents") if isinstance(lock, dict) else None
    sources = contents.get("sources") if isinstance(contents, dict) else None
    base = contents.get("baseProvenance") if isinstance(contents, dict) else None
    previous = lane["provenance"]
    previous["buildRepository"] = REPOSITORY_URL
    if isinstance(provenance.get("sourceCommit"), str):
        previous["buildCommit"] = _commit(provenance["sourceCommit"], "build")
    external = provenance.get("externalBuild")
    if isinstance(external, dict):
        if isinstance(external.get("repository"), str):
            previous["externalBuildRepository"] = external["repository"]
        if isinstance(external.get("revision"), str):
            previous["externalBuildCommit"] = _commit(
                external["revision"], "external build"
            )
    if isinstance(sources, dict):
        names = list(lane["components"])
        if not names:
            names = [
                name
                for name in RUNTIME_COMPONENTS
                if isinstance(sources.get(name), dict)
            ]
        for name in names:
            source = sources.get(name)
            if not isinstance(source, dict):
                continue
            lane["components"][name] = str(source["version"])
            previous[f"{name}Repository"] = _repository(str(source["repository"]))
            previous[f"{name}Commit"] = _commit(source["commit"], name)
    moltenvk = base.get("moltenvk") if isinstance(base, dict) else None
    if isinstance(moltenvk, dict):
        commit = _commit(moltenvk["commit"], "moltenvk")
        if previous.get("moltenvkCommit") != commit and moltenvk_version is None:
            fail(
                "the MoltenVK commit changed and provenance.json has no MoltenVK "
                "version; pass --moltenvk-version"
            )
        if moltenvk_version is not None:
            lane["components"]["moltenvk"] = moltenvk_version
        previous["moltenvkRepository"] = _repository(str(moltenvk["repository"]))
        previous["moltenvkCommit"] = commit


def updated_manifest(
    manifest: Mapping[str, Any],
    tag: str,
    provenance: Mapping[str, Any],
    architecture: str = RUNTIME_ARCHITECTURE,
    moltenvk_version: str | None = None,
    sha256: str | None = None,
    size_bytes: int | None = None,
) -> dict[str, Any]:
    """Return `manifest` with one lane pinned to the release."""
    result = json.loads(json.dumps(manifest))
    lane = result["lanes"].get(architecture)
    if not isinstance(lane, dict):
        fail(f"runtime.json has no {architecture} lane")
    version = tag.removeprefix("v")
    archive, _ = asset_names(tag)
    published = provenance.get("runtimeArchive") or {}
    published_sha256 = published.get("sha256")
    if (
        not isinstance(published_sha256, str)
        or SHA256_PATTERN.fullmatch(published_sha256) is None
    ):
        fail("provenance.json has an invalid runtime archive checksum")
    if sha256 is not None and sha256 != published_sha256:
        fail("the provided SHA-256 differs from provenance.json")
    digest = sha256 or published_sha256
    published_size = published.get("sizeBytes")
    if (
        size_bytes is not None
        and isinstance(published_size, int)
        and size_bytes != published_size
    ):
        fail("the provided size differs from provenance.json")
    size = size_bytes if size_bytes is not None else published_size
    if not isinstance(size, int) or isinstance(size, bool) or size < 1:
        fail("the runtime archive size is unknown; pass --size")
    lane["runtime"] = {
        "name": f"Arknights macOS Runtime {version}",
        "version": version,
        "url": asset_url(tag, archive),
        "sha256": digest,
        "sizeBytes": size,
    }
    interface = _published_interface(architecture, provenance)
    minimum_macos = (
        interface.get("minimumMacOS") if interface is not None else None
    ) or provenance.get("minimumMacOS")
    if isinstance(minimum_macos, str) and MINIMUM_MACOS_PATTERN.fullmatch(
        minimum_macos
    ):
        lane["minimumMacOS"] = minimum_macos
    _update_provenance(lane, provenance, moltenvk_version)
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


def _release_page(manifest: Mapping[str, Any], architecture: str) -> str:
    url = manifest["lanes"][architecture]["runtime"]["url"]
    match = ASSET_URL_PATTERN.fullmatch(url)
    if match is None:
        fail(f"cannot derive the runtime release from {url}")
    return f"{REPOSITORY_URL}/releases/tag/{match['tag']}"


def render_components_block(
    manifest: Mapping[str, Any], components: tuple[Component, ...]
) -> str:
    """Render the per-runtime component table of the third-party notices."""
    lines = [
        "| Runtime | Component | Version or revision | License | Exact provenance source |",
        "| --- | --- | --- | --- | --- |",
    ]
    for architecture in RUNTIME_ARCHITECTURES:
        lane = manifest.get("lanes", {}).get(architecture)
        if not isinstance(lane, dict):
            continue
        provenance = lane["provenance"]
        for key, version in lane["components"].items():
            entry = next(
                (
                    component
                    for component in components
                    if component.runtime_component == key
                ),
                None,
            )
            if entry is None:
                fail(
                    "docs/legal/licenses/index.json has no entry for runtimeComponent "
                    f"{key}"
                )
            commit = provenance.get(f"{key}Commit")
            repository = provenance.get(f"{key}Repository")
            if not isinstance(commit, str) or not isinstance(repository, str):
                fail(f"runtime.json {architecture} provenance has no source for {key}")
            lines.append(
                f"| {architecture} | {entry.name} | {version}, `{commit}` "
                f"| {entry.spdx} | [{_slug(repository)} commit]"
                f"({tree_url(repository, commit)}) |"
            )
    return "\n".join(lines) + "\n"


def render_build_block(manifest: Mapping[str, Any]) -> str:
    """Render the pinned runtime archive table of the third-party notices."""
    lines = [
        "| Runtime | Release | Archive SHA-256 | Archive size |",
        "| --- | --- | --- | --- |",
    ]
    for architecture in RUNTIME_ARCHITECTURES:
        lane = manifest.get("lanes", {}).get(architecture)
        if not isinstance(lane, dict):
            continue
        runtime = lane["runtime"]
        if not runtime["url"]:
            lines.append(f"| {architecture} | Not pinned yet | | |")
            continue
        tag = runtime["url"].split("/releases/download/", 1)[1].split("/", 1)[0]
        lines.append(
            f"| {architecture} | [{tag}]({_release_page(manifest, architecture)}) "
            f"| `{runtime['sha256']}` | {runtime['sizeBytes']} bytes |"
        )
    return (
        "The client pins one runtime archive per architecture. The launcher downloads "
        "the archive for the architecture that you choose; the app bundle does not "
        "contain a runtime. Each archive carries its own build provenance, license "
        "texts, and notices. The client does not generate a runtime closure inventory."
        "\n\n" + "\n".join(lines) + "\n"
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
    return generated_blocks.render_documents(root, blocks, BLOCK_NAMESPACE)


def manifest_problems(manifest: Mapping[str, Any]) -> list[str]:
    """Compare each lane pin with the tag in its archive URL (offline)."""
    problems: list[str] = []
    for architecture in RUNTIME_ARCHITECTURES:
        lane = manifest.get("lanes", {}).get(architecture)
        if not isinstance(lane, dict):
            continue
        runtime = lane.get("runtime")
        if not isinstance(runtime, dict):
            problems.append(f"runtime.json: {architecture} lane has no runtime pin")
            continue
        url = runtime.get("url")
        if not url:
            if runtime.get("sha256") or runtime.get("sizeBytes"):
                problems.append(
                    f"runtime.json: {architecture} runtime pin must be complete or empty"
                )
            continue
        match = ASSET_URL_PATTERN.fullmatch(url) if isinstance(url, str) else None
        if match is None:
            problems.append(
                f"runtime.json: {architecture} runtime.url is not a release asset"
            )
            continue
        tag = match["tag"]
        version = tag.removeprefix("v")
        archive, _ = asset_names(tag)
        expected = {
            "runtime.version": (runtime.get("version"), version),
            "runtime.name": (
                runtime.get("name"),
                f"Arknights macOS Runtime {version}",
            ),
            "runtime.url": (url, asset_url(tag, archive)),
            "runtime.architecture": (tag_architecture(tag), architecture),
        }
        problems.extend(
            f"runtime.json: {architecture} {key} is {actual!r}, the tag {tag} "
            f"implies {wanted!r}"
            for key, (actual, wanted) in expected.items()
            if actual != wanted
        )
        size = runtime.get("sizeBytes")
        if not isinstance(size, int) or isinstance(size, bool) or size < 1:
            problems.append(
                f"runtime.json: {architecture} runtime.sizeBytes is invalid"
            )
        checksum = runtime.get("sha256")
        if not isinstance(checksum, str) or SHA256_PATTERN.fullmatch(checksum) is None:
            problems.append(f"runtime.json: {architecture} runtime.sha256 is invalid")
    if "buildRecipe" in manifest:
        problems.append("runtime.json: remove the top-level buildRecipe")
    if "armInterface" in manifest:
        problems.append("runtime.json: remove armInterface and use lanes.arm")
    return problems


def check(root: Path) -> None:
    """Fail when `runtime.json` or a generated `runtime` block is stale; no network."""
    load_runtime_config(root / RUNTIME_CONFIG)
    manifest = read_json(root / RUNTIME_CONFIG)
    problems = manifest_problems(manifest)
    if not problems:
        problems.extend(
            f"{path}: runtime blocks are stale; run scripts/update_runtime.py"
            for path in generated_blocks.stale_documents(root, render_documents(root))
        )
    if problems:
        fail("\n".join(problems))


def update(
    root: Path,
    tag: str,
    fetch: Fetch,
    moltenvk_version: str | None = None,
    *,
    architecture: str = RUNTIME_ARCHITECTURE,
    sha256: str | None = None,
    size_bytes: int | None = None,
) -> list[Path]:
    """Pin `tag` for one lane and rewrite `runtime.json` and the `runtime` blocks."""
    target = root / RUNTIME_CONFIG
    original = target.read_text(encoding="utf-8")
    if architecture not in RUNTIME_ARCHITECTURES:
        fail(f"unknown runtime architecture: {architecture}")
    if tag_architecture(tag) != architecture:
        fail(
            f"release {tag} is for {tag_architecture(tag)}, not {architecture}; "
            "pass the matching --architecture"
        )
    provenance = fetch_provenance(fetch, tag)
    current = load_runtime_config(target)
    lane = current.lane(architecture)
    check_interface(lane, provenance)
    archive, _ = asset_names(tag)
    published_size = (provenance.get("runtimeArchive") or {}).get("sizeBytes")
    if size_bytes is not None:
        size = size_bytes
    elif isinstance(published_size, int) and not isinstance(published_size, bool):
        size = published_size
    else:
        size = release_asset_size(fetch, tag, archive)
    text = format_manifest(
        updated_manifest(
            current.raw,
            tag,
            provenance,
            architecture,
            moltenvk_version,
            sha256,
            size,
        )
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
    return [*changed, *generated_blocks.write_documents(root, documents)]
