# SPDX-License-Identifier: MPL-2.0

"""Pin the Arknights macOS Runtime release and keep every mention current.

A release publishes one `runtime-<arch>.json` manifest per lane and a `SHA256SUMS` file.
`update` reads them over HTTPS, checks them against `SHA256SUMS`, and rewrites the runtime
pins of the lanes in `runtime.json`. `render_documents` fills the generated
`runtime` blocks of the documents from `runtime.json` alone, so `check` runs offline. The
blocks use the marker syntax of the license generator: `<!-- runtime:begin NAME -->` and
`<!-- runtime:end NAME -->`.
"""

import hashlib
import json
import re
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Mapping, Sequence
from pathlib import Path
from typing import Any

from runtime_config import (
    RELEASE_VERSION_PATTERN,
    RUNTIME_ARCHITECTURES,
    SHA256_PATTERN,
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
from lib.project_config import RUNTIME_CONFIG

REPOSITORY = "LuMiSxh/Arknights-MacOS-Runtime"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
RELEASES_API = f"https://api.github.com/repos/{REPOSITORY}/releases?per_page=100"
NOTICES_DOCUMENT = Path("docs/legal/third-party-notices.md")
BLOCK_NAMESPACE = "runtime"
TAG_PATTERN = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?$")
MAXIMUM_ASSET_BYTES = 8 * 1_024 * 1_024
PRETTIER_WIDTH = 80
MANIFEST_SCHEMA_VERSION = 1
CHECKSUMS_ASSET = "SHA256SUMS"
# The architecture that names each lane's manifest and archive.
RELEASE_ARCHITECTURES = {"x86": "x86_64", "arm": "arm64"}
# The keys that a runtime manifest must have, and the keys of its archive and delta entries.
MANIFEST_KEYS = frozenset(
    {"minimumMacOS", "archive", "deltas", "interface", "components", "provenance"}
)
ASSET_KEYS = frozenset({"name", "sha256", "sizeBytes"})
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


def latest_tag(fetch: Fetch, include_prerelease: bool) -> str:
    """Return the newest published runtime release; skip drafts."""
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


def asset_url(tag: str, name: str) -> str:
    return f"{REPOSITORY_URL}/releases/download/{tag}/{name}"


def parse_checksums(text: bytes) -> dict[str, str]:
    """Return the digest that `SHA256SUMS` lists for each asset."""
    digests: dict[str, str] = {}
    for line in text.decode("utf-8").splitlines():
        digest, _, name = line.partition("  ")
        if SHA256_PATTERN.fullmatch(digest) is None or not name or name in digests:
            fail(f"SHA256SUMS has an invalid or repeated line: {line!r}")
        digests[name] = digest
    return digests


def _verify_listed(checksums: Mapping[str, str], name: str, digest: object) -> None:
    listed = checksums.get(name)
    if listed is None:
        fail(f"SHA256SUMS does not list {name}")
    if listed != digest:
        fail(f"SHA256SUMS lists {listed} for {name}, expected {digest}")


def fetch_lane(
    fetch: Fetch, tag: str, checksums: Mapping[str, str], lane: str
) -> dict[str, Any]:
    """Download the runtime manifest of one lane and check it and its assets.

    The manifest gives the archive and delta digests, so `SHA256SUMS` must list the same ones.
    """
    architecture = RELEASE_ARCHITECTURES[lane]
    name = f"runtime-{architecture}.json"
    raw = fetch(asset_url(tag, name))
    _verify_listed(checksums, name, hashlib.sha256(raw).hexdigest())
    try:
        manifest = json.loads(raw)
    except ValueError:
        fail(f"{name} is not valid JSON")
    if (
        not isinstance(manifest, dict)
        or manifest.get("schemaVersion") != MANIFEST_SCHEMA_VERSION
    ):
        fail(f"{name} is not runtime manifest schema {MANIFEST_SCHEMA_VERSION}")
    if manifest.get("arch") != architecture or manifest.get("version") != (
        tag.removeprefix("v")
    ):
        fail(f"{name} does not describe {architecture} {tag}")
    missing = sorted(MANIFEST_KEYS - set(manifest))
    if missing:
        fail(f"{name} lacks {', '.join(missing)}")
    archive = manifest["archive"]
    if (
        not isinstance(archive, dict)
        or set(archive) != ASSET_KEYS
        or archive["name"] != f"runtime-{architecture}.tar.xz"
    ):
        fail(f"{name} does not name the {architecture} archive")
    _verify_listed(checksums, archive["name"], archive["sha256"])
    if not isinstance(manifest["deltas"], list):
        fail(f"{name} has no delta list")
    for delta in manifest["deltas"]:
        if (
            not isinstance(delta, dict)
            or set(delta) != {*ASSET_KEYS, "from"}
            or not isinstance(delta["from"], str)
            or RELEASE_VERSION_PATTERN.fullmatch(delta["from"]) is None
            or delta["name"]
            != f"runtime-{architecture}-from-{delta['from']}.delta.tar.xz"
        ):
            fail(f"{name} has an invalid delta: {delta!r}")
        _verify_listed(checksums, delta["name"], delta["sha256"])
    return manifest


def updated_manifest(
    manifest: Mapping[str, Any],
    tag: str,
    releases: Mapping[str, Mapping[str, Any]],
    moltenvk_version: str | None = None,
) -> dict[str, Any]:
    """Return `manifest` with each released lane pinned to its runtime manifest.

    The release manifest has no MoltenVK version, so the pinned one stays unless its commit changes.
    """
    result = json.loads(json.dumps(manifest))
    version = tag.removeprefix("v")
    for architecture, release in releases.items():
        lane = result["lanes"].get(architecture)
        if not isinstance(lane, dict):
            fail(f"runtime.json has no {architecture} lane")
        provenance = release["provenance"]
        components = dict(release["components"])
        if "moltenvkCommit" in provenance:
            commit_changed = provenance["moltenvkCommit"] != lane["provenance"].get(
                "moltenvkCommit"
            )
            if commit_changed and moltenvk_version is None:
                fail(
                    "the MoltenVK commit changed and the release has no MoltenVK "
                    "version; pass --moltenvk-version"
                )
            components["moltenvk"] = moltenvk_version or lane["components"].get(
                "moltenvk"
            )
        archive = release["archive"]
        deltas = sorted(
            release["deltas"],
            key=lambda delta: tuple(map(int, delta["from"].split("."))),
            reverse=True,
        )
        lane["runtime"] = {
            "name": f"Arknights macOS Runtime {version}",
            "version": version,
            "url": asset_url(tag, archive["name"]),
            "sha256": archive["sha256"],
            "sizeBytes": archive["sizeBytes"],
            "deltas": [
                {
                    "from": delta["from"],
                    "url": asset_url(tag, delta["name"]),
                    "sha256": delta["sha256"],
                    "sizeBytes": delta["sizeBytes"],
                }
                for delta in deltas
            ],
        }
        lane["minimumMacOS"] = release["minimumMacOS"]
        lane["interface"] = release["interface"]
        lane["components"] = components
        lane["provenance"] = provenance
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
        expected = {
            "runtime.version": (runtime.get("version"), version),
            "runtime.name": (
                runtime.get("name"),
                f"Arknights macOS Runtime {version}",
            ),
        }
        problems.extend(
            f"runtime.json: {architecture} {key} is {actual!r}, the tag {tag} "
            f"implies {wanted!r}"
            for key, (actual, wanted) in expected.items()
            if actual != wanted
        )
        name = match["name"]
        if name != f"runtime-{RELEASE_ARCHITECTURES[architecture]}.tar.xz":
            problems.append(
                f"runtime.json: {architecture} runtime.url is not an archive of {tag}"
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
    architectures: Sequence[str] = tuple(RUNTIME_ARCHITECTURES),
) -> list[Path]:
    """Pin `tag` for the given lanes and rewrite `runtime.json` and the `runtime` blocks."""
    target = root / RUNTIME_CONFIG
    original = target.read_text(encoding="utf-8")
    for architecture in architectures:
        if architecture not in RUNTIME_ARCHITECTURES:
            fail(f"unknown runtime architecture: {architecture}")
    checksums = parse_checksums(fetch(asset_url(tag, CHECKSUMS_ASSET)))
    releases = {
        architecture: fetch_lane(fetch, tag, checksums, architecture)
        for architecture in architectures
    }
    current = load_runtime_config(target)
    text = format_manifest(
        updated_manifest(current.raw, tag, releases, moltenvk_version)
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
