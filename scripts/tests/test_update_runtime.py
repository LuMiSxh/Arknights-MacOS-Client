# SPDX-License-Identifier: MPL-2.0

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
NEW_SOURCE_COMMIT = "2" * 40
NEW_WINE_COMMIT = "1" * 40
LANES = ("x86", "arm")
ARCHIVE_DIGESTS = {"x86": "a" * 64, "arm": "c" * 64}
ARCHIVE_SIZES = {"x86": 123_456, "arm": 234_567}
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


def release_interface(architecture: str) -> dict[str, Any]:
    """Render one lane interface in the archive layout that provenance.json uses."""
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


def release_fragment(
    tag: str, architecture: str, moltenvk_commit: str = "4" * 40
) -> dict[str, Any]:
    """One lane fragment of a schema 2 release, with the interface of runtime.json."""
    interface = release_interface(architecture)
    archive, source = runtime_update.asset_names(tag, architecture)
    # Like the runtime's resolved lock view: features sit beside the interface.
    features = interface.pop("features")
    contents: dict[str, Any] = {"interface": interface, "features": features}
    if architecture == "x86":
        contents["baseArtifact"] = {
            "url": "https://github.com/dappermint/Whisky/releases/download/v4.7.3/Libraries.tar.gz",
            "sha256": "e" * 64,
        }
        contents["baseProvenance"] = {
            "moltenvk": {
                "commit": moltenvk_commit,
                "repository": "https://github.com/KhronosGroup/MoltenVK.git",
            }
        }
    return {
        "target": runtime_update.LANE_TARGETS[architecture],
        "arch": runtime_update.RELEASE_ARCHITECTURES[architecture],
        "version": tag.removeprefix("v"),
        "buildCommit": NEW_SOURCE_COMMIT,
        "runtimeLock": {"contents": contents},
        "wine": {
            "source": "built",
            "repository": "https://github.com/dappermint/winecx.git",
            "commit": NEW_WINE_COMMIT,
            "version": "11.18",
        },
        "dxmt": {
            "repository": "https://github.com/3Shain/dxmt.git",
            "commit": "5" * 40,
            "version": "0.81",
        },
        "runtimeArchive": {
            "name": archive,
            "sha256": ARCHIVE_DIGESTS[architecture],
            "sizeBytes": ARCHIVE_SIZES[architecture],
        },
        "correspondingSourceArchive": {"name": source, "sha256": "b" * 64},
    }


def release_provenance(
    tag: str = NEW_TAG, moltenvk_commit: str = "4" * 40
) -> dict[str, Any]:
    """A schema 2 provenance.json that carries one fragment per lane."""
    return {
        "schemaVersion": 2,
        "releaseTag": tag,
        "runtimes": [
            release_fragment(tag, architecture, moltenvk_commit)
            for architecture in LANES
        ],
    }


def release_fetch(
    tag: str = NEW_TAG,
    provenance: dict[str, Any] | None = None,
    mutate: Callable[[dict[str, str | bytes]], None] | None = None,
    listed_sizes: dict[str, int] | None = None,
) -> Callable[[str], bytes]:
    """Serve the release assets and metadata from memory; fail on any other URL."""
    provenance = provenance or release_provenance(tag)
    assets: dict[str, str | bytes] = {"provenance.json": json.dumps(provenance)}
    for fragment in provenance["runtimes"]:
        for key in ("runtimeArchive", "correspondingSourceArchive"):
            name = fragment[key]["name"]
            assets[f"{name}.sha256"] = f"{fragment[key]['sha256']}  {name}\n"
    if mutate:
        mutate(assets)
    if listed_sizes is None:
        listed_sizes = {
            fragment["runtimeArchive"]["name"]: fragment["runtimeArchive"]["sizeBytes"]
            for fragment in provenance["runtimes"]
        }
    metadata = {
        "assets": [{"name": name, "size": size} for name, size in listed_sizes.items()]
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


def test_update_pins_both_lanes_from_one_release(project: Path) -> None:
    changed = runtime_update.update(project, NEW_TAG, release_fetch())

    manifest = manifest_of(project)
    assert changed == [Path("runtime.json"), runtime_update.NOTICES_DOCUMENT]
    for architecture in LANES:
        archive, _ = runtime_update.asset_names(NEW_TAG, architecture)
        assert manifest["lanes"][architecture]["runtime"] == {
            "name": "Arknights macOS Runtime 99.0.0",
            "version": "99.0.0",
            "url": runtime_update.asset_url(NEW_TAG, archive),
            "sha256": ARCHIVE_DIGESTS[architecture],
            "sizeBytes": ARCHIVE_SIZES[architecture],
        }
    assert manifest["lanes"]["x86"]["components"]["wine"] == "11.18"
    assert manifest["lanes"]["x86"]["provenance"]["buildCommit"] == NEW_SOURCE_COMMIT
    assert manifest["lanes"]["x86"]["provenance"]["wineCommit"] == NEW_WINE_COMMIT
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


def test_update_leaves_the_interfaces_untouched(project: Path) -> None:
    def interfaces() -> dict[str, Any]:
        return {
            lane: manifest_of(project)["lanes"][lane]["interface"] for lane in LANES
        }

    before = interfaces()

    runtime_update.update(project, NEW_TAG, release_fetch())

    assert interfaces() == before


def test_update_seeds_an_empty_arm_lane_from_its_fragment(project: Path) -> None:
    manifest = manifest_of(project)
    manifest["lanes"]["arm"]["components"] = {}
    manifest["lanes"]["arm"]["provenance"] = {}
    (project / "runtime.json").write_text(json.dumps(manifest), encoding="utf-8")
    provenance = release_provenance()
    provenance["runtimes"][1]["wine"] = {
        "source": "external",
        "repository": "https://gitlab.winehq.org/wine/wine.git",
        "commit": "7b3fff76fa5178f6ce0141b2c776afa2a822f101",
        "version": "11.18",
        "externalBuild": {
            "repository": "https://github.com/riverfog7/wine-build-new",
            "commit": "3" * 40,
        },
    }

    runtime_update.update(
        project,
        NEW_TAG,
        release_fetch(provenance=provenance),
        architectures=("arm",),
    )

    lane = manifest_of(project)["lanes"]["arm"]
    assert lane["components"] == {"wine": "11.18", "dxmt": "0.81"}
    assert lane["provenance"]["wineRepository"] == "https://gitlab.winehq.org/wine/wine"
    assert lane["provenance"]["wineCommit"] == (
        "7b3fff76fa5178f6ce0141b2c776afa2a822f101"
    )
    assert lane["provenance"]["dxmtRepository"] == "https://github.com/3Shain/dxmt"
    assert lane["provenance"]["buildCommit"] == NEW_SOURCE_COMMIT
    assert lane["provenance"]["externalBuildRepository"] == (
        "https://github.com/riverfog7/wine-build-new"
    )
    assert lane["provenance"]["externalBuildCommit"] == "3" * 40
    runtime_update.check(project)


@pytest.mark.parametrize("architecture", LANES)
def test_update_needs_a_fragment_for_each_lane(
    project: Path, architecture: str
) -> None:
    before = (project / "runtime.json").read_text(encoding="utf-8")
    provenance = release_provenance()
    provenance["runtimes"] = [
        fragment
        for fragment in provenance["runtimes"]
        if fragment["target"] != runtime_update.LANE_TARGETS[architecture]
    ]

    with pytest.raises(ScriptError, match=f"one {architecture} runtime"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))

    assert (project / "runtime.json").read_text(encoding="utf-8") == before


@pytest.mark.parametrize(("key", "value"), [("version", "98.0.0"), ("arch", "x86_64")])
def test_fragment_must_describe_its_lane_and_release(
    project: Path, key: str, value: str
) -> None:
    provenance = release_provenance()
    provenance["runtimes"][1][key] = value

    with pytest.raises(ScriptError, match="does not describe"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))


@pytest.mark.parametrize(
    ("key", "value"), [("releaseTag", "v0.7.0-rc2"), ("schemaVersion", 1)]
)
def test_provenance_of_another_release_or_schema_fails(
    project: Path, key: str, value: object
) -> None:
    provenance = release_provenance()
    provenance[key] = value

    with pytest.raises(ScriptError, match="is not schema 2"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))


def test_checksum_file_mismatch_fails_without_writing(project: Path) -> None:
    archive, _ = runtime_update.asset_names(NEW_TAG, "x86")
    before = (project / "runtime.json").read_text(encoding="utf-8")

    def corrupt(assets: dict[str, str | bytes]) -> None:
        assets[f"{archive}.sha256"] = f"{'f' * 64}  {archive}\n"

    with pytest.raises(ScriptError, match="differs from provenance.json"):
        runtime_update.update(project, NEW_TAG, release_fetch(mutate=corrupt))
    assert (project / "runtime.json").read_text(encoding="utf-8") == before


def test_checksum_file_for_another_asset_fails(project: Path) -> None:
    _, source = runtime_update.asset_names(NEW_TAG, "arm")

    def rename(assets: dict[str, str | bytes]) -> None:
        assets[f"{source}.sha256"] = f"{'b' * 64}  other.tar.gz\n"

    with pytest.raises(ScriptError, match="does not describe"):
        runtime_update.update(project, NEW_TAG, release_fetch(mutate=rename))


def test_listed_size_must_match_the_fragment(project: Path) -> None:
    listed = {runtime_update.asset_names(NEW_TAG, lane)[0]: 1 for lane in LANES}

    with pytest.raises(ScriptError, match="lists 1 bytes"):
        runtime_update.update(project, NEW_TAG, release_fetch(listed_sizes=listed))


def test_size_comes_from_the_release_when_the_fragment_has_none(project: Path) -> None:
    provenance = release_provenance()
    del provenance["runtimes"][0]["runtimeArchive"]["sizeBytes"]
    archive, _ = runtime_update.asset_names(NEW_TAG, "x86")

    runtime_update.update(
        project,
        NEW_TAG,
        release_fetch(provenance=provenance, listed_sizes={archive: 555}),
        architectures=("x86",),
    )

    assert manifest_of(project)["lanes"]["x86"]["runtime"]["sizeBytes"] == 555


@pytest.mark.parametrize("architecture", ["x86", "arm"])
def test_interface_drift_fails_without_writing(
    project: Path, architecture: str
) -> None:
    provenance = release_provenance()
    (fragment,) = [
        runtime
        for runtime in provenance["runtimes"]
        if runtime["target"] == runtime_update.LANE_TARGETS[architecture]
    ]
    fragment["runtimeLock"]["contents"]["interface"]["minimumMacOS"] = "27.0"
    before = (project / "runtime.json").read_text(encoding="utf-8")

    with pytest.raises(ScriptError, match="interface differs.*minimumMacOS"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))
    assert (project / "runtime.json").read_text(encoding="utf-8") == before


def test_changed_moltenvk_commit_needs_a_version(project: Path) -> None:
    provenance = release_provenance(moltenvk_commit="6" * 40)

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
    (project / "runtime.json").write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(ScriptError, match=r"arm runtime\.version"):
        runtime_update.check(project)


def test_check_detects_a_manifest_that_disagrees_with_its_name(project: Path) -> None:
    manifest = manifest_of(project)
    manifest["lanes"]["x86"]["runtime"]["name"] = "Arknights macOS Runtime 0.6.1"
    (project / "runtime.json").write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(ScriptError, match=r"x86 runtime\.name"):
        runtime_update.check(project)
