# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
import re
import shutil
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from conftest import runtime_manifest
from lib import generated_blocks, licenses, runtime_update
from lib.common import PROJECT_DIR, ScriptError

NEW_TAG = "v99.0.0"
ARM_TAG = "v99.0.0+arm"
NEW_WINE_COMMIT = "1" * 40
NEW_SOURCE_COMMIT = "2" * 40
FIXTURE_FILES = (
    Path("runtime.json"),
    licenses.CLIENT_INDEX,
    runtime_update.NOTICES_DOCUMENT,
)


def manifest_of(root: Path) -> dict[str, Any]:
    return json.loads((root / "runtime.json").read_text(encoding="utf-8"))


def current_tag(root: Path, architecture: str = "x86") -> str:
    url = manifest_of(root)["lanes"][architecture]["runtime"]["url"]
    return re.search(r"/download/(v[^/]+)/", url).group(1)


def release_interface(architecture: str = "x86") -> dict[str, Any]:
    """Render one release interface in the archive layout that provenance.json uses."""
    manifest = runtime_manifest()
    interface = manifest["lanes"][architecture]["interface"]
    wine = interface["archive"]["wineDirectory"]
    dxmt = interface["archive"]["dxmtDirectory"]
    return {
        "dxmtDirectory": dxmt,
        "executables": sorted(
            [
                f"{wine}/{path}"
                for path in (*interface["executables"], interface["launcher"]["path"])
            ]
        ),
        "requiredFiles": sorted(
            [
                f"{wine}/{path}"
                for path in (*interface["requiredFiles"], interface["macDriver"])
            ]
            + [
                f"{dxmt}/{target}/{library}"
                for target in interface["dxmt"]["destinations"]
                for library in interface["dxmt"]["libraries"]
            ]
        ),
        "features": interface["features"],
        "minimumMacOS": manifest["lanes"][architecture]["minimumMacOS"],
        "wineDirectory": wine,
    }


def release_provenance(
    tag: str, architecture: str = "x86", **overrides: str
) -> dict[str, Any]:
    """The provenance.json of a release that keeps the interface of runtime.json."""
    archive, source = runtime_update.asset_names(tag)
    interface = release_interface(architecture)
    sources = {
        "wine": {
            "commit": NEW_WINE_COMMIT,
            "repository": "https://github.com/dappermint/winecx.git",
            "version": "11.18",
        },
        "dxmt": {
            "commit": "5" * 40,
            "repository": "https://github.com/3Shain/dxmt.git",
            "version": "0.81",
        },
    }
    if architecture == "arm":
        sources["fex"] = {
            "commit": "7" * 40,
            "repository": "https://github.com/FEX-Emu/FEX.git",
            "version": "2610",
        }
    contents: dict[str, Any] = {
        "interface": interface,
        "sources": sources,
        "targets": {
            runtime_update.LANE_TARGETS[architecture]: {"interface": interface}
        },
    }
    if architecture == "x86":
        contents["baseProvenance"] = {
            "moltenvk": {
                "commit": overrides.get(
                    "moltenvk_commit",
                    "4" * 40,
                ),
                "repository": "https://github.com/KhronosGroup/MoltenVK.git",
            }
        }
    return {
        "releaseTag": tag,
        "runtimeArchive": {
            "name": archive,
            "sha256": "a" * 64,
            "sizeBytes": 123_456,
        },
        "correspondingSourceArchive": {"name": source, "sha256": "b" * 64},
        "sourceCommit": overrides.get("source_commit", NEW_SOURCE_COMMIT),
        "runtimeLock": {"contents": contents},
    }


def release_fetch(
    tag: str = NEW_TAG,
    provenance: dict[str, Any] | None = None,
    mutate: Callable[[dict[str, str | bytes]], None] | None = None,
) -> Callable[[str], bytes]:
    """Serve the release assets and metadata from memory; fail on any other URL."""
    provenance = provenance or release_provenance(tag)
    archive, source = runtime_update.asset_names(tag)
    assets: dict[str, str | bytes] = {
        "provenance.json": json.dumps(provenance),
        f"{archive}.sha256": f"{provenance['runtimeArchive']['sha256']}  {archive}\n",
        f"{source}.sha256": (
            f"{provenance['correspondingSourceArchive']['sha256']}  {source}\n"
        ),
    }
    if mutate:
        mutate(assets)
    metadata = {
        "assets": [
            {
                "name": archive,
                "size": provenance["runtimeArchive"].get("sizeBytes", 123_456),
            }
        ]
    }

    def fetch(url: str) -> bytes:
        if url == f"{runtime_update.RELEASE_API}{tag}":
            return json.dumps(metadata).encode()
        prefix = f"{runtime_update.REPOSITORY_URL}/releases/download/{tag}/"
        assert url.startswith(prefix), url
        value = assets[url.removeprefix(prefix)]
        return value.encode() if isinstance(value, str) else value

    return fetch


@pytest.fixture
def project(tmp_path: Path) -> Path:
    for relative in FIXTURE_FILES:
        (tmp_path / relative).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(PROJECT_DIR / relative, tmp_path / relative)
    (tmp_path / "runtime.json").write_text(
        json.dumps(runtime_manifest()), encoding="utf-8"
    )
    generated_blocks.write_documents(
        tmp_path, runtime_update.render_documents(tmp_path)
    )
    return tmp_path


def test_project_runtime_pin_is_current() -> None:
    runtime_update.check(PROJECT_DIR)


def test_update_rewrites_one_lane_and_keeps_the_other(project: Path) -> None:
    previous_tag = current_tag(project)
    arm_before = manifest_of(project)["lanes"]["arm"]
    changed = runtime_update.update(project, NEW_TAG, release_fetch())

    manifest = manifest_of(project)
    archive, _ = runtime_update.asset_names(NEW_TAG)
    base = f"{runtime_update.REPOSITORY_URL}/releases/download/{NEW_TAG}/"
    assert changed == [Path("runtime.json"), runtime_update.NOTICES_DOCUMENT]
    assert manifest["lanes"]["x86"]["runtime"] == {
        "name": "Arknights macOS Runtime 99.0.0",
        "version": "99.0.0",
        "url": base + archive,
        "sha256": "a" * 64,
        "sizeBytes": 123_456,
    }
    assert manifest["lanes"]["x86"]["components"]["wine"] == "11.18"
    assert manifest["lanes"]["x86"]["provenance"]["buildCommit"] == NEW_SOURCE_COMMIT
    assert manifest["lanes"]["x86"]["provenance"]["wineCommit"] == NEW_WINE_COMMIT
    assert manifest["lanes"]["arm"] == arm_before
    notices = (project / runtime_update.NOTICES_DOCUMENT).read_text(encoding="utf-8")
    assert NEW_TAG in notices
    assert f"[{previous_tag}](" not in notices
    runtime_update.check(project)


def test_update_leaves_the_interface_untouched(project: Path) -> None:
    before = manifest_of(project)["lanes"]["x86"]["interface"]

    runtime_update.update(project, NEW_TAG, release_fetch())

    assert manifest_of(project)["lanes"]["x86"]["interface"] == before


def test_update_pins_the_arm_lane_without_touching_x86(project: Path) -> None:
    x86_before = manifest_of(project)["lanes"]["x86"]
    arm_interface_before = manifest_of(project)["lanes"]["arm"]["interface"]
    changed = runtime_update.update(
        project,
        ARM_TAG,
        release_fetch(ARM_TAG, release_provenance(ARM_TAG, architecture="arm")),
        architecture="arm",
    )

    manifest = manifest_of(project)
    assert changed == [Path("runtime.json"), runtime_update.NOTICES_DOCUMENT]
    assert manifest["lanes"]["arm"]["runtime"]["version"] == "99.0.0+arm"
    assert manifest["lanes"]["arm"]["runtime"]["name"] == (
        "Arknights macOS Runtime 99.0.0+arm"
    )
    assert ARM_TAG in manifest["lanes"]["arm"]["runtime"]["url"]
    assert manifest["lanes"]["arm"]["interface"] == arm_interface_before
    assert manifest["lanes"]["x86"] == x86_before
    runtime_update.check(project)


def test_update_rejects_a_release_from_another_lane(project: Path) -> None:
    before = (project / "runtime.json").read_text(encoding="utf-8")

    with pytest.raises(ScriptError, match="not arm"):
        runtime_update.update(project, NEW_TAG, release_fetch(), architecture="arm")

    assert (project / "runtime.json").read_text(encoding="utf-8") == before


def test_check_detects_a_lane_that_disagrees_with_the_tag(project: Path) -> None:
    manifest = manifest_of(project)
    x86_url = manifest["lanes"]["x86"]["runtime"]["url"]
    manifest["lanes"]["arm"]["runtime"]["url"] = x86_url
    (project / "runtime.json").write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(ScriptError, match=r"arm runtime\.architecture"):
        runtime_update.check(project)


def test_second_update_changes_nothing(project: Path) -> None:
    runtime_update.update(project, NEW_TAG, release_fetch())
    snapshot = {
        path: (project / path).read_text(encoding="utf-8") for path in FIXTURE_FILES
    }

    assert runtime_update.update(project, NEW_TAG, release_fetch()) == []
    assert snapshot == {
        path: (project / path).read_text(encoding="utf-8") for path in FIXTURE_FILES
    }


def test_update_writes_no_feed_or_client_version_fields(project: Path) -> None:
    runtime_update.update(project, NEW_TAG, release_fetch())

    text = (project / "runtime.json").read_text(encoding="utf-8")
    for forbidden in (
        "runtimeFeed",
        "feedUrl",
        "channel",
        "minimumClientVersion",
        "maximumClientVersion",
        "signature",
        "armInterface",
        "buildRecipe",
    ):
        assert forbidden not in text


def test_checksum_file_mismatch_fails_without_writing(project: Path) -> None:
    archive, _ = runtime_update.asset_names(NEW_TAG)
    before = (project / "runtime.json").read_text(encoding="utf-8")

    def corrupt(assets: dict[str, str | bytes]) -> None:
        assets[f"{archive}.sha256"] = f"{'e' * 64}  {archive}\n"

    with pytest.raises(ScriptError, match="differs from provenance.json"):
        runtime_update.update(project, NEW_TAG, release_fetch(mutate=corrupt))
    assert (project / "runtime.json").read_text(encoding="utf-8") == before


def test_checksum_file_for_another_asset_fails(project: Path) -> None:
    _, source = runtime_update.asset_names(NEW_TAG)

    def rename(assets: dict[str, str | bytes]) -> None:
        assets[f"{source}.sha256"] = f"{'b' * 64}  other.tar.gz\n"

    with pytest.raises(ScriptError, match="does not describe"):
        runtime_update.update(project, NEW_TAG, release_fetch(mutate=rename))


def test_provenance_for_another_tag_fails(project: Path) -> None:
    provenance = release_provenance(NEW_TAG)
    provenance["releaseTag"] = "v0.7.0-rc2"

    with pytest.raises(ScriptError, match="does not describe"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("executables", ["Wine/bin/wine64"]),
        ("requiredFiles", ["Wine/lib/wine/x86_64-unix/winemac.so"]),
        ("wineDirectory", "Libraries"),
        (
            "features",
            {
                "hardwareCursor": False,
                "metalFXSpatialUpscaling": True,
                "nativeFullscreenSpace": True,
            },
        ),
        ("minimumMacOS", "27.0"),
    ],
)
def test_interface_drift_fails_without_writing(
    project: Path, key: str, value: object
) -> None:
    provenance = release_provenance(NEW_TAG)
    interface = provenance["runtimeLock"]["contents"]["interface"]
    interface[key] = value
    provenance["runtimeLock"]["contents"]["targets"][
        runtime_update.LANE_TARGETS["x86"]
    ]["interface"] = interface
    before = (project / "runtime.json").read_text(encoding="utf-8")

    with pytest.raises(ScriptError, match=f"interface differs.*{key}"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))
    assert (project / "runtime.json").read_text(encoding="utf-8") == before


def test_changed_moltenvk_commit_needs_a_version(project: Path) -> None:
    provenance = release_provenance(NEW_TAG, moltenvk_commit="6" * 40)

    with pytest.raises(ScriptError, match="--moltenvk-version"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))

    runtime_update.update(
        project, NEW_TAG, release_fetch(provenance=provenance), "1.4.3"
    )
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


def test_latest_selects_only_the_requested_architecture() -> None:
    fetch = releases_fetch(
        [
            release_entry("v0.8.0+arm", "2026-05-01T00:00:00Z"),
            release_entry("v0.8.0+x86", "2026-04-01T00:00:00Z"),
            release_entry("v0.7.0", "2026-03-01T00:00:00Z"),
        ]
    )

    assert runtime_update.latest_tag(fetch, include_prerelease=False) == "v0.8.0+x86"
    assert (
        runtime_update.latest_tag(fetch, include_prerelease=False, architecture="arm")
        == "v0.8.0+arm"
    )


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
        ("0.8.0+x86", "v0.8.0+x86"),
        ("v0.8.0+arm", "v0.8.0+arm"),
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


def test_check_detects_a_manifest_that_disagrees_with_its_name(project: Path) -> None:
    manifest = manifest_of(project)
    manifest["lanes"]["x86"]["runtime"]["name"] = "Arknights macOS Runtime 0.6.1"
    (project / "runtime.json").write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(ScriptError, match=r"x86 runtime\.name"):
        runtime_update.check(project)
