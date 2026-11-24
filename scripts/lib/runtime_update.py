# SPDX-License-Identifier: MPL-2.0

"""Pin the Arknights macOS Runtime release and keep every mention current.

A release publishes one `provenance.json` with a fragment per lane, plus `.sha256` files
for the archives and deltas of each lane. `update` reads them over HTTPS, checks that they
agree, and rewrites the
runtime pins of the lanes in `runtime.json`. `render_documents` fills the generated
`runtime` blocks of the documents from `runtime.json` alone, so `check` runs offline. The
blocks use the marker syntax of the license generator: `<!-- runtime:begin NAME -->` and
`<!-- runtime:end NAME -->`.
"""

import json
import re
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable, Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from runtime_config import (
    COMMIT_PATTERN,
    MINIMUM_MACOS_PATTERN,
    RELEASE_VERSION_PATTERN,
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
from lib.project_config import RUNTIME_CONFIG

REPOSITORY = "LuMiSxh/Arknights-MacOS-Runtime"
REPOSITORY_URL = f"https://github.com/{REPOSITORY}"
RELEASES_API = f"https://api.github.com/repos/{REPOSITORY}/releases?per_page=100"
RELEASE_API = f"https://api.github.com/repos/{REPOSITORY}/releases/tags/"
NOTICES_DOCUMENT = Path("docs/legal/third-party-notices.md")
BLOCK_NAMESPACE = "runtime"
TAG_PATTERN = re.compile(r"^v[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.]+)?$")
MAXIMUM_ASSET_BYTES = 8 * 1_024 * 1_024
PRETTIER_WIDTH = 80
PROVENANCE_SCHEMA_VERSION = 2
# The archive name part and the provenance target of each lane of a release.
RELEASE_ARCHITECTURES = {"x86": "x86_64", "arm": "arm64"}
LANE_TARGETS = {"x86": "rosetta-x86_64", "arm": "native-arm64"}
# Wine and DXMT are the components a lane can carry; their sources are fields of the
# lane fragment. MoltenVK comes only from `runtimeLock.contents.baseProvenance`.
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


def asset_names(tag: str, architecture: str) -> tuple[str, str]:
    """Return the archive and source archive names of one lane of a release."""
    stem = f"Arknights-MacOS-Runtime-{tag}-{RELEASE_ARCHITECTURES[architecture]}"
    return f"{stem}.tar.xz", f"{stem}-source.tar.xz"


def delta_names(
    tag: str, architecture: str, listed_sizes: Mapping[str, int]
) -> list[tuple[str, str]]:
    """Return (from version, asset name) of each delta of one lane, newest source first.

    Deltas exist only for releases, so a prerelease tag has none. A delta counts only when
    its `.sha256` sidecar is listed too.
    """
    if RELEASE_VERSION_PATTERN.fullmatch(tag.removeprefix("v")) is None:
        return []
    pattern = re.compile(
        re.escape(f"Arknights-MacOS-Runtime-{tag}-from-v")
        + r"(?P<from>[0-9]+\.[0-9]+\.[0-9]+)-"
        + re.escape(RELEASE_ARCHITECTURES[architecture])
        + r"\.delta\.tar\.xz"
    )
    found = []
    for name in listed_sizes:
        match = pattern.fullmatch(name)
        if match is not None and f"{name}.sha256" in listed_sizes:
            found.append((match["from"], name))
    return sorted(
        found, key=lambda item: tuple(map(int, item[0].split("."))), reverse=True
    )


def _delta_pins(
    fetch: Fetch, tag: str, architecture: str, listed_sizes: Mapping[str, int]
) -> list[dict[str, Any]]:
    return [
        {
            "from": source,
            "url": asset_url(tag, name),
            "sha256": _sidecar_digest(fetch, tag, name),
            "sizeBytes": listed_sizes[name],
        }
        for source, name in delta_names(tag, architecture, listed_sizes)
    ]


def asset_url(tag: str, name: str) -> str:
    return f"{REPOSITORY_URL}/releases/download/{tag}/{name}"


def release_asset_sizes(fetch: Fetch, tag: str) -> dict[str, int]:
    """Read the asset sizes from the GitHub release metadata."""
    try:
        document = json.loads(fetch(f"{RELEASE_API}{tag}"))
    except json.JSONDecodeError:
        fail(f"GitHub returned invalid metadata for {tag}")
    if not isinstance(document, dict):
        fail(f"GitHub returned invalid metadata for {tag}")
    return {
        asset["name"]: asset["size"]
        for asset in document.get("assets") or []
        if isinstance(asset, dict)
        and isinstance(asset.get("name"), str)
        and isinstance(asset.get("size"), int)
        and asset["size"] > 0
    }


def _sidecar_digest(fetch: Fetch, tag: str, name: str) -> str:
    """Return the digest in the `.sha256` sidecar of one asset that must name it."""
    line = fetch(asset_url(tag, f"{name}.sha256")).decode("utf-8").split()
    if len(line) != 2 or line[1].lstrip("*") != name:
        fail(f"{name}.sha256 does not describe {name}")
    if SHA256_PATTERN.fullmatch(line[0]) is None:
        fail(f"{name}.sha256 does not contain a SHA-256 digest")
    return line[0]


def _checksum(fetch: Fetch, tag: str, name: str, expected: Mapping[str, Any]) -> str:
    checksum = _sidecar_digest(fetch, tag, name)
    digest = expected.get("sha256")
    if expected.get("name") != name:
        fail(f"provenance.json names {expected.get('name')!r}, expected {name!r}")
    if checksum != digest:
        fail(f"{name}.sha256 ({checksum}) differs from provenance.json ({digest})")
    return checksum


def fetch_provenance(fetch: Fetch, tag: str) -> dict[str, Any]:
    """Download the release `provenance.json` and check that it describes this tag."""
    provenance = json.loads(fetch(asset_url(tag, "provenance.json")))
    if (
        not isinstance(provenance, dict)
        or provenance.get("schemaVersion") != PROVENANCE_SCHEMA_VERSION
        or provenance.get("releaseTag") != tag
    ):
        fail(f"provenance.json is not schema {PROVENANCE_SCHEMA_VERSION} for {tag}")
    return provenance


@dataclass(frozen=True, slots=True)
class LaneRelease:
    """The runtime fragment and the verified assets of one lane of a release."""

    architecture: str
    fragment: Mapping[str, Any]
    archive: str
    sha256: str
    size_bytes: int
    deltas: list[dict[str, Any]]


def lane_fragment(
    provenance: Mapping[str, Any], tag: str, architecture: str
) -> Mapping[str, Any]:
    """Return the one runtime fragment of a lane; it must describe this release."""
    runtimes = provenance.get("runtimes")
    matches = [
        fragment
        for fragment in runtimes or []
        if isinstance(fragment, dict)
        and fragment.get("target") == LANE_TARGETS[architecture]
    ]
    if len(matches) != 1:
        fail(
            f"provenance.json needs one {architecture} runtime for {tag}, "
            f"found {len(matches)}"
        )
    fragment = matches[0]
    if fragment.get("arch") != RELEASE_ARCHITECTURES[architecture] or fragment.get(
        "version"
    ) != tag.removeprefix("v"):
        fail(f"the {architecture} runtime in provenance.json does not describe {tag}")
    return fragment


def fetch_lane(
    fetch: Fetch,
    tag: str,
    provenance: Mapping[str, Any],
    architecture: str,
    listed_sizes: Mapping[str, int],
) -> LaneRelease:
    """Verify the checksums and the size of one lane against its release assets."""
    fragment = lane_fragment(provenance, tag, architecture)
    archive, source = asset_names(tag, architecture)
    published = fragment.get("runtimeArchive") or {}
    digest = _checksum(fetch, tag, archive, published)
    _checksum(fetch, tag, source, fragment.get("correspondingSourceArchive") or {})
    size = published.get("sizeBytes")
    listed = listed_sizes.get(archive)
    if size is not None and listed is not None and size != listed:
        fail(
            f"the release lists {listed} bytes for {archive}; "
            f"provenance.json has {size}"
        )
    size = size if size is not None else listed
    if not isinstance(size, int) or isinstance(size, bool) or size < 1:
        fail(f"the runtime archive size of the {architecture} lane is unknown")
    deltas = _delta_pins(fetch, tag, architecture, listed_sizes)
    return LaneRelease(architecture, fragment, archive, digest, size, deltas)


def _published_interface(
    architecture: str, provenance: Mapping[str, Any]
) -> Mapping[str, Any]:
    """Return the release interface of one lane, with the lane's runtime features.

    The fragment's `runtimeLock.contents` is the lock already resolved for that lane.
    """
    lock = provenance.get("runtimeLock")
    contents = lock.get("contents") if isinstance(lock, dict) else None
    interface = contents.get("interface") if isinstance(contents, dict) else None
    if not isinstance(interface, dict):
        fail(f"provenance.json has no {architecture} runtime interface")
    features = contents.get("features")
    return (
        {**interface, "features": features} if isinstance(features, dict) else interface
    )


def check_interface(
    lane: RuntimeLaneConfiguration, provenance: Mapping[str, Any]
) -> None:
    """Fail when the release interface differs from the lane in `runtime.json`."""
    published = _published_interface(lane.name, provenance)
    layout = lane.layout
    dxmt = layout.dxmt.payload_directory
    expected: dict[str, Any] = {
        "features": layout.features.mapping(),
        "minimumMacOS": lane.minimum_macos,
        "executables": sorted(
            str(path) for path in (*layout.executables, layout.launcher.path)
        ),
        "requiredFiles": sorted(
            {str(path) for path in (*layout.required_files, layout.mac_driver)}
            | {
                str(dxmt / architecture / library)
                for architecture, _ in layout.dxmt.destinations
                for library in layout.dxmt.libraries
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


def _field(source: Mapping[str, Any], *keys: str) -> str | None:
    """Return the first non-empty string under one of `keys`."""
    for key in keys:
        value = source.get(key)
        if isinstance(value, str) and value:
            return value
    return None


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
    # `baseProvenance` describes the base archive; a lane built without one (the external
    # ARM64 tree) inherits the lock's top-level entry but does not ship that MoltenVK.
    base = (
        contents.get("baseProvenance")
        if isinstance(contents, dict) and contents.get("baseArtifact") is not None
        else None
    )
    previous = lane["provenance"]
    previous["buildRepository"] = REPOSITORY_URL
    if isinstance(provenance.get("buildCommit"), str):
        previous["buildCommit"] = _commit(provenance["buildCommit"], "build")
    wine = provenance.get("wine")
    external = wine.get("externalBuild") if isinstance(wine, dict) else None
    if isinstance(external, dict):
        repository = _field(external, "repository")
        commit = _field(external, "commit")
        if repository is not None:
            previous["externalBuildRepository"] = repository
        if commit is not None:
            previous["externalBuildCommit"] = _commit(commit, "external build")
    names = list(lane["components"]) or [
        name for name in RUNTIME_COMPONENTS if isinstance(provenance.get(name), dict)
    ]
    for name in names:
        source = provenance.get(name)
        if not isinstance(source, dict):
            continue
        version = _field(source, "version")
        if version is not None:
            lane["components"][name] = version
        repository = _field(source, "repository")
        commit = _field(source, "commit")
        if repository is None or commit is None:
            fail(f"provenance.json has no repository or commit for {name}")
        previous[f"{name}Repository"] = _repository(repository)
        previous[f"{name}Commit"] = _commit(commit, name)
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
    releases: Sequence[LaneRelease],
    moltenvk_version: str | None = None,
) -> dict[str, Any]:
    """Return `manifest` with each released lane pinned to the release."""
    result = json.loads(json.dumps(manifest))
    version = tag.removeprefix("v")
    for release in releases:
        lane = result["lanes"].get(release.architecture)
        if not isinstance(lane, dict):
            fail(f"runtime.json has no {release.architecture} lane")
        lane["runtime"] = {
            "name": f"Arknights macOS Runtime {version}",
            "version": version,
            "url": asset_url(tag, release.archive),
            "sha256": release.sha256,
            "sizeBytes": release.size_bytes,
            "deltas": release.deltas,
        }
        interface = _published_interface(release.architecture, release.fragment)
        minimum_macos = interface.get("minimumMacOS")
        if isinstance(minimum_macos, str) and MINIMUM_MACOS_PATTERN.fullmatch(
            minimum_macos
        ):
            lane["minimumMacOS"] = minimum_macos
        _update_provenance(lane, release.fragment, moltenvk_version)
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
        # Older pins name the asset without its lane; new pins add the architecture.
        name = match["name"]
        # v1.0.2-rc1 is the last `.tar.gz` pin; drop the legacy suffix with the next pin.
        if not name.startswith(f"Arknights-MacOS-Runtime-{tag}") or not name.endswith(
            (".tar.xz", ".tar.gz")
        ):
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
    provenance = fetch_provenance(fetch, tag)
    listed_sizes = release_asset_sizes(fetch, tag)
    releases = [
        fetch_lane(fetch, tag, provenance, architecture, listed_sizes)
        for architecture in architectures
    ]
    current = load_runtime_config(target)
    for release in releases:
        check_interface(current.lane(release.architecture), release.fragment)
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
