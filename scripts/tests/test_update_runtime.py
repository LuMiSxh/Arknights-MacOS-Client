# SPDX-License-Identifier: MPL-2.0

import hashlib
import json
import re
import shutil
from collections.abc import Callable, Mapping
from pathlib import Path
from typing import Any

import pytest
from conftest import runtime_manifest
from lib import generated_blocks, licenses, runtime_update
from lib.common import PROJECT_DIR, ScriptError
from lib.project_config import RUNTIME_CONFIG

NEW_TAG = "v99.0.0"
RELEASE_URL = (
    f"https://github.com/LuMiSxh/Arknights-MacOS-Runtime/releases/download/{NEW_TAG}"
)
NEW_SOURCE_COMMIT = "2" * 40
NEW_WINE_COMMIT = "1" * 40
LANES = ("x86", "arm")
ARCHIVE_DIGESTS = {"x86": "a" * 64, "arm": "c" * 64}
ARCHIVE_SIZES = {"x86": 123_456, "arm": 234_567}
FIXTURE_FILES = (
    RUNTIME_CONFIG,
    licenses.CLIENT_INDEX,
    runtime_update.NOTICES_DOCUMENT,
)


def manifest_of(root: Path) -> dict[str, Any]:
    return json.loads((root / RUNTIME_CONFIG).read_text(encoding="utf-8"))


def current_tag(root: Path, architecture: str = "x86") -> str:
    url = manifest_of(root)["lanes"][architecture]["runtime"]["url"]
    return re.search(r"/download/(v[^/]+)/", url).group(1)


def release_manifest(lane: str) -> dict[str, Any]:
    """Return the runtime manifest that a release writes for one lane (manifest schema 1)."""
    architecture = runtime_update.RELEASE_ARCHITECTURES[lane]
    pinned = runtime_manifest()["lanes"][lane]
    provenance = {
        "buildRepository": "https://github.com/LuMiSxh/Arknights-MacOS-Runtime",
        "buildCommit": NEW_SOURCE_COMMIT,
        "wineRepository": "https://github.com/dappermint/winecx",
        "wineCommit": NEW_WINE_COMMIT,
        "dxmtRepository": "https://github.com/3Shain/dxmt",
        "dxmtCommit": "5" * 40,
    }
    deltas: list[dict[str, Any]] = []
    if lane == "x86":
        provenance |= {
            "moltenvkRepository": "https://github.com/KhronosGroup/MoltenVK",
            "moltenvkCommit": "4" * 40,
        }
    else:
        # Oldest first, as the release lists them; the pin sorts them newest first.
        deltas = [
            {
                "from": "0.7.0",
                "name": f"runtime-{architecture}-from-0.7.0.delta.tar.xz",
                "sha256": "d" * 64,
                "sizeBytes": 1_000,
            },
            {
                "from": "0.8.0",
                "name": f"runtime-{architecture}-from-0.8.0.delta.tar.xz",
                "sha256": "e" * 64,
                "sizeBytes": 2_000,
            },
        ]
    return {
        "schemaVersion": 1,
        "arch": architecture,
        "version": NEW_TAG.removeprefix("v"),
        "minimumMacOS": pinned["minimumMacOS"],
        "archive": {
            "name": f"runtime-{architecture}.tar.xz",
            "sha256": ARCHIVE_DIGESTS[lane],
            "sizeBytes": ARCHIVE_SIZES[lane],
        },
        "deltas": deltas,
        "interface": pinned["interface"],
        "components": {"wine": "11.18", "dxmt": "0.81"},
        "provenance": provenance,
    }


def release_assets(manifests: Mapping[str, Mapping[str, Any]]) -> dict[str, bytes]:
    """Return one release: each lane manifest and the `SHA256SUMS` that lists all assets."""
    assets: dict[str, bytes] = {}
    digests: dict[str, str] = {}
    for lane, manifest in manifests.items():
        body = json.dumps(manifest).encode("utf-8")
        name = f"runtime-{runtime_update.RELEASE_ARCHITECTURES[lane]}.json"
        assets[name] = body
        digests[name] = hashlib.sha256(body).hexdigest()
        for asset in (manifest["archive"], *manifest["deltas"]):
            digests[asset["name"]] = asset["sha256"]
    listing = "".join(f"{digests[name]}  {name}\n" for name in sorted(digests))
    assets[runtime_update.CHECKSUMS_ASSET] = listing.encode("utf-8")
    return assets


def release_fetch(
    manifests: Mapping[str, Mapping[str, Any]] | None = None,
    mutate: Callable[[dict[str, bytes]], None] | None = None,
) -> Callable[[str], bytes]:
    """Serve the release assets from memory; fail on any other URL."""
    if manifests is None:
        manifests = {lane: release_manifest(lane) for lane in LANES}
    assets = release_assets(manifests)
    if mutate is not None:
        mutate(assets)
    prefix = f"{RELEASE_URL}/"

    def fetch(url: str) -> bytes:
        assert url.startswith(prefix), url
        return assets[url.removeprefix(prefix)]

    return fetch


@pytest.fixture
def project(tmp_path: Path) -> Path:
    for relative in FIXTURE_FILES:
        (tmp_path / relative).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(PROJECT_DIR / relative, tmp_path / relative)
    (tmp_path / RUNTIME_CONFIG).write_text(
        json.dumps(runtime_manifest()), encoding="utf-8"
    )
    generated_blocks.write_documents(
        tmp_path, runtime_update.render_documents(tmp_path)
    )
    return tmp_path


def test_project_runtime_pin_is_current() -> None:
    runtime_update.check(PROJECT_DIR)


def test_update_pins_both_lanes_from_one_release(project: Path) -> None:
    changed = runtime_update.update(project, NEW_TAG, release_fetch())

    lanes = manifest_of(project)["lanes"]
    assert changed == [RUNTIME_CONFIG, runtime_update.NOTICES_DOCUMENT]
    assert lanes["x86"]["runtime"] == {
        "name": "Arknights macOS Runtime 99.0.0",
        "version": "99.0.0",
        "url": f"{RELEASE_URL}/runtime-x86_64.tar.xz",
        "sha256": "a" * 64,
        "sizeBytes": 123_456,
        "deltas": [],
    }
    assert lanes["arm"]["runtime"] == {
        "name": "Arknights macOS Runtime 99.0.0",
        "version": "99.0.0",
        "url": f"{RELEASE_URL}/runtime-arm64.tar.xz",
        "sha256": "c" * 64,
        "sizeBytes": 234_567,
        "deltas": [
            {
                "from": "0.8.0",
                "url": f"{RELEASE_URL}/runtime-arm64-from-0.8.0.delta.tar.xz",
                "sha256": "e" * 64,
                "sizeBytes": 2_000,
            },
            {
                "from": "0.7.0",
                "url": f"{RELEASE_URL}/runtime-arm64-from-0.7.0.delta.tar.xz",
                "sha256": "d" * 64,
                "sizeBytes": 1_000,
            },
        ],
    }
    assert lanes["x86"]["components"] == {
        "wine": "11.18",
        "dxmt": "0.81",
        "moltenvk": "1.4.2",
    }
    assert lanes["x86"]["provenance"] == release_manifest("x86")["provenance"]
    assert lanes["arm"]["interface"] == release_manifest("arm")["interface"]
    notices = (project / runtime_update.NOTICES_DOCUMENT).read_text(encoding="utf-8")
    assert f"releases/tag/{NEW_TAG}" in notices
    runtime_update.check(project)


@pytest.mark.parametrize("architecture", LANES)
def test_update_pins_one_lane_and_keeps_the_other(
    project: Path, architecture: str
) -> None:
    other = next(lane for lane in LANES if lane != architecture)
    other_before = manifest_of(project)["lanes"][other]

    runtime_update.update(
        project, NEW_TAG, release_fetch(), architectures=(architecture,)
    )

    manifest = manifest_of(project)
    assert manifest["lanes"][architecture]["runtime"]["version"] == "99.0.0"
    assert manifest["lanes"][other] == other_before
    runtime_update.check(project)


@pytest.mark.parametrize(
    ("key", "value", "message"),
    [
        ("version", "98.0.0", "does not describe"),
        ("arch", "x86_64", "does not describe"),
        ("schemaVersion", 2, "is not runtime manifest schema 1"),
    ],
)
def test_manifest_must_describe_its_lane_and_release(
    project: Path, key: str, value: object, message: str
) -> None:
    manifests = {lane: release_manifest(lane) for lane in LANES}
    manifests["arm"][key] = value

    with pytest.raises(ScriptError, match=message):
        runtime_update.update(project, NEW_TAG, release_fetch(manifests=manifests))


@pytest.mark.parametrize(
    ("name", "replacement", "message"),
    [
        pytest.param(
            "runtime-x86_64.json",
            f"{'f' * 64}  runtime-x86_64.json\n",
            "for runtime-x86_64.json",
            id="manifest-differs",
        ),
        pytest.param(
            "runtime-x86_64.tar.xz",
            f"{'f' * 64}  runtime-x86_64.tar.xz\n",
            "for runtime-x86_64.tar.xz",
            id="archive-differs",
        ),
        pytest.param(
            "runtime-x86_64.tar.xz",
            "",
            "does not list runtime-x86_64.tar.xz",
            id="archive-unlisted",
        ),
    ],
)
def test_sha256sums_must_list_the_manifest_and_its_archive(
    project: Path, name: str, replacement: str, message: str
) -> None:
    before = (project / RUNTIME_CONFIG).read_text(encoding="utf-8")

    def mutate(assets: dict[str, bytes]) -> None:
        text = assets["SHA256SUMS"].decode("utf-8")
        line = rf"^[0-9a-f]+  {re.escape(name)}\n"
        assets["SHA256SUMS"] = re.sub(
            line, replacement, text, flags=re.MULTILINE
        ).encode()

    with pytest.raises(ScriptError, match=re.escape(message)):
        runtime_update.update(project, NEW_TAG, release_fetch(mutate=mutate))
    assert (project / RUNTIME_CONFIG).read_text(encoding="utf-8") == before


def test_changed_moltenvk_commit_needs_a_version(project: Path) -> None:
    manifests = {lane: release_manifest(lane) for lane in LANES}
    manifests["x86"]["provenance"]["moltenvkCommit"] = "6" * 40

    with pytest.raises(ScriptError, match="--moltenvk-version"):
        runtime_update.update(project, NEW_TAG, release_fetch(manifests=manifests))

    runtime_update.update(project, NEW_TAG, release_fetch(manifests=manifests), "1.4.3")
    assert manifest_of(project)["lanes"]["x86"]["components"]["moltenvk"] == "1.4.3"


def releases_fetch(releases: list[dict[str, object]]) -> Callable[[str], bytes]:
    def fetch(url: str) -> bytes:
        assert url == runtime_update.RELEASES_API
        return json.dumps(releases).encode()

    return fetch


def release_entry(tag: str, published: str, **flags: bool) -> dict[str, object]:
    return {"tag_name": tag, "published_at": published, **flags}


def test_latest_skips_drafts_and_prereleases_by_default() -> None:
    fetch = releases_fetch(
        [
            release_entry("v0.8.0", "2026-05-01T00:00:00Z", draft=True),
            release_entry("v0.7.0-rc2", "2026-04-01T00:00:00Z", prerelease=True),
            release_entry("v0.6.1", "2026-03-01T00:00:00Z"),
            release_entry("v0.6.0", "2026-02-01T00:00:00Z"),
            release_entry("nightly", "2026-06-01T00:00:00Z"),
        ]
    )

    assert runtime_update.latest_tag(fetch, include_prerelease=False) == "v0.6.1"
    assert runtime_update.latest_tag(fetch, include_prerelease=True) == "v0.7.0-rc2"


def test_latest_selects_the_newest_release_for_both_lanes() -> None:
    fetch = releases_fetch(
        [
            release_entry("v1.0.0-rc2", "2026-05-01T00:00:00Z", prerelease=True),
            release_entry("v0.9.0", "2026-04-01T00:00:00Z"),
        ]
    )

    assert runtime_update.latest_tag(fetch, include_prerelease=True) == "v1.0.0-rc2"
    assert runtime_update.latest_tag(fetch, include_prerelease=False) == "v0.9.0"


def test_latest_without_a_candidate_names_the_flag() -> None:
    fetch = releases_fetch(
        [release_entry("v0.7.0-rc1", "2026-04-01T00:00:00Z", prerelease=True)]
    )

    with pytest.raises(ScriptError, match="--include-prerelease"):
        runtime_update.latest_tag(fetch, include_prerelease=False)


@pytest.mark.parametrize(
    ("value", "tag"),
    [
        ("0.7.0-rc2", "v0.7.0-rc2"),
        ("v0.7.0", "v0.7.0"),
        ("1.0.0-rc1", "v1.0.0-rc1"),
    ],
)
def test_normalize_tag(value: str, tag: str) -> None:
    assert runtime_update.normalize_tag(value) == tag


def test_normalize_tag_rejects_other_values() -> None:
    with pytest.raises(ScriptError, match="not a runtime release tag"):
        runtime_update.normalize_tag("../latest")


def test_check_detects_a_stale_block(project: Path) -> None:
    runtime_update.check(project)
    notices = project / runtime_update.NOTICES_DOCUMENT
    notices.write_text(
        notices.read_text(encoding="utf-8").replace(current_tag(project), "v0.0.0"),
        encoding="utf-8",
    )

    with pytest.raises(ScriptError, match="runtime blocks are stale"):
        runtime_update.check(project)


def test_check_detects_a_lane_that_names_another_release(project: Path) -> None:
    manifest = manifest_of(project)
    url = manifest["lanes"]["arm"]["runtime"]["url"]
    manifest["lanes"]["arm"]["runtime"]["url"] = url.replace("/v0.8.0/", "/v0.7.0/")
    (project / RUNTIME_CONFIG).write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(ScriptError, match=r"arm runtime\.version"):
        runtime_update.check(project)


def test_check_detects_a_manifest_that_disagrees_with_its_name(project: Path) -> None:
    manifest = manifest_of(project)
    manifest["lanes"]["x86"]["runtime"]["name"] = "Arknights macOS Runtime 0.6.1"
    (project / RUNTIME_CONFIG).write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(ScriptError, match=r"x86 runtime\.name"):
        runtime_update.check(project)
