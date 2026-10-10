# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
import shutil
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from lib import licenses, runtime_update
from lib.common import PROJECT_DIR, ScriptError

NEW_TAG = "v0.7.0-rc2"
NEW_WINE_COMMIT = "1" * 40
NEW_SOURCE_COMMIT = "2" * 40
FIXTURE_FILES = (
    Path("runtime.json"),
    licenses.CLIENT_INDEX,
    runtime_update.NOTICES_DOCUMENT,
)


def manifest_of(root: Path) -> dict[str, Any]:
    return json.loads((root / "runtime.json").read_text(encoding="utf-8"))


def release_provenance(tag: str, **overrides: str) -> dict[str, Any]:
    """The provenance.json of a release that keeps the interface of runtime.json."""
    archive, source = runtime_update.asset_names(tag)
    return {
        "releaseTag": tag,
        "runtimeArchive": {"name": archive, "sha256": "a" * 64},
        "correspondingSourceArchive": {"name": source, "sha256": "b" * 64},
        "sourceCommit": overrides.get("source_commit", NEW_SOURCE_COMMIT),
        "runtimeLock": {
            "contents": {
                "baseArtifact": {
                    "recipe": {
                        "commit": "3" * 40,
                        "repository": "https://github.com/dappermint/winecx-gptk.git",
                    },
                    "sha256": "c" * 64,
                    "url": "https://github.com/dappermint/Whisky/releases/download/v4.7.0/Libraries.tar.gz",
                },
                "baseProvenance": {
                    "moltenvk": {
                        "commit": overrides.get(
                            "moltenvk_commit",
                            "db66022459ffb663aa2b50f6b018bc2e124f5edf",
                        ),
                        "repository": "https://github.com/KhronosGroup/MoltenVK.git",
                    }
                },
                "build": {
                    "nixpkgs": {
                        "commit": "4" * 40,
                        "repository": "https://github.com/NixOS/nixpkgs.git",
                    }
                },
                "interface": {
                    "dxmtDirectory": "DXMT",
                    "executables": [
                        "Wine/bin/Arknights",
                        "Wine/bin/wine64",
                        "Wine/bin/wineserver",
                    ],
                    "requiredFiles": [
                        "Wine/lib/wine/x86_64-unix/winemac.so",
                        "Wine/lib/wine/x86_64-unix/winecoreaudio.so",
                        "Wine/lib/wine/x86_64-windows/winemetal.dll",
                        "DXMT/x64/d3d10core.dll",
                        "DXMT/x64/d3d11.dll",
                        "DXMT/x64/dxgi.dll",
                        "DXMT/x64/winemetal.dll",
                    ],
                    "runtimeCapabilities": "runtime-capabilities.json",
                    "wineDirectory": "Wine",
                },
                "sources": {
                    "dxmt": {
                        "commit": "5" * 40,
                        "repository": "https://github.com/3Shain/dxmt.git",
                        "version": "0.81",
                    },
                    "wine": {
                        "commit": NEW_WINE_COMMIT,
                        "repository": "https://github.com/dappermint/winecx.git",
                        "version": "11.18",
                    },
                },
            }
        },
    }


def release_fetch(
    tag: str = NEW_TAG,
    provenance: dict[str, Any] | None = None,
    mutate: Callable[[dict[str, str | bytes]], None] | None = None,
) -> Callable[[str], bytes]:
    """Serve the three release assets from memory; fail on any other URL."""
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

    def fetch(url: str) -> bytes:
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
    return tmp_path


def test_project_runtime_pin_is_current() -> None:
    runtime_update.check(PROJECT_DIR)


def test_manifest_formatting_round_trips() -> None:
    text = (PROJECT_DIR / "runtime.json").read_text(encoding="utf-8")

    assert runtime_update.format_manifest(json.loads(text)) == text


def test_update_rewrites_manifest_and_blocks(project: Path) -> None:
    changed = runtime_update.update(project, NEW_TAG, release_fetch())

    manifest = manifest_of(project)
    archive, source = runtime_update.asset_names(NEW_TAG)
    base = f"{runtime_update.REPOSITORY_URL}/releases/download/{NEW_TAG}/"
    assert changed == [
        Path("runtime.json"),
        runtime_update.NOTICES_DOCUMENT,
    ]
    assert manifest["runtime"] == {
        "name": "Arknights macOS Runtime 0.7.0-rc2",
        "url": base + archive,
        "sha256": "a" * 64,
    }
    assert manifest["buildRecipe"] == {"url": base + source, "sha256": "b" * 64}
    assert manifest["components"] == {
        "wine": "11.18",
        "dxmt": "0.81",
        "moltenvk": "1.4.2",
    }
    assert manifest["provenance"]["buildCommit"] == NEW_SOURCE_COMMIT
    assert manifest["provenance"]["wineCommit"] == NEW_WINE_COMMIT
    assert manifest["provenance"]["wineRepository"] == (
        "https://github.com/dappermint/winecx"
    )
    assert manifest["provenance"]["baseArchiveSha256"] == "c" * 64
    notices = (project / runtime_update.NOTICES_DOCUMENT).read_text(encoding="utf-8")
    assert NEW_TAG in notices
    assert "v0.7.0-rc1" not in notices
    assert f"Wine 11.18, `{NEW_WINE_COMMIT}`" in notices
    assert "Whisky base libraries | v4.7.0," in notices
    runtime_update.check(project)


def test_update_leaves_the_interface_untouched(project: Path) -> None:
    before = manifest_of(project)["interface"]

    runtime_update.update(project, NEW_TAG, release_fetch())

    assert manifest_of(project)["interface"] == before


def test_second_update_changes_nothing(project: Path) -> None:
    runtime_update.update(project, NEW_TAG, release_fetch())
    snapshot = {
        path: (project / path).read_text(encoding="utf-8") for path in FIXTURE_FILES
    }

    assert runtime_update.update(project, NEW_TAG, release_fetch()) == []
    assert snapshot == {
        path: (project / path).read_text(encoding="utf-8") for path in FIXTURE_FILES
    }


def test_repinning_the_current_release_is_a_no_op(project: Path) -> None:
    manifest = manifest_of(project)
    provenance = release_provenance("v0.7.0-rc1")
    lock = provenance["runtimeLock"]["contents"]
    provenance["runtimeArchive"]["sha256"] = manifest["runtime"]["sha256"]
    provenance["correspondingSourceArchive"]["sha256"] = manifest["buildRecipe"][
        "sha256"
    ]
    provenance["sourceCommit"] = manifest["provenance"]["buildCommit"]
    for key, name in (("wine", "wine"), ("dxmt", "dxmt")):
        lock["sources"][key] = {
            "commit": manifest["provenance"][f"{name}Commit"],
            "repository": manifest["provenance"][f"{name}Repository"] + ".git",
            "version": manifest["components"][name],
        }
    lock["build"]["nixpkgs"]["commit"] = manifest["provenance"]["nixpkgsCommit"]
    lock["baseArtifact"] = {
        "recipe": {
            "commit": manifest["provenance"]["baseRecipeCommit"],
            "repository": manifest["provenance"]["baseRecipeRepository"] + ".git",
        },
        "sha256": manifest["provenance"]["baseArchiveSha256"],
        "url": manifest["provenance"]["baseArchiveUrl"],
    }

    changed = runtime_update.update(
        project, "v0.7.0-rc1", release_fetch("v0.7.0-rc1", provenance)
    )

    assert changed == []
    assert manifest_of(project) == manifest


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
    provenance["releaseTag"] = "v0.7.0-rc3"

    with pytest.raises(ScriptError, match="does not describe"):
        runtime_update.update(project, NEW_TAG, release_fetch(provenance=provenance))


@pytest.mark.parametrize(
    ("key", "value"),
    [
        ("executables", ["Wine/bin/wine64"]),
        ("requiredFiles", ["Wine/lib/wine/x86_64-unix/winemac.so"]),
        ("wineDirectory", "Libraries"),
        ("runtimeCapabilities", "other.json"),
    ],
)
def test_interface_drift_fails_without_writing(
    project: Path, key: str, value: object
) -> None:
    provenance = release_provenance(NEW_TAG)
    provenance["runtimeLock"]["contents"]["interface"][key] = value
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
    assert manifest_of(project)["components"]["moltenvk"] == "1.4.3"


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


def test_latest_without_a_candidate_names_the_flag() -> None:
    fetch = releases_fetch(
        [release_entry("v0.7.0-rc1", "2026-04-01T00:00:00Z", prerelease=True)]
    )

    with pytest.raises(ScriptError, match="--include-prerelease"):
        runtime_update.latest_tag(fetch, include_prerelease=False)


@pytest.mark.parametrize(
    ("value", "tag"), [("0.7.0-rc2", "v0.7.0-rc2"), ("v0.7.0", "v0.7.0")]
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
        notices.read_text(encoding="utf-8").replace("Wine 11.17", "Wine 11.16"),
        encoding="utf-8",
    )

    with pytest.raises(ScriptError, match="runtime blocks are stale"):
        runtime_update.check(project)


def test_check_detects_a_manifest_that_disagrees_with_its_tag(project: Path) -> None:
    manifest = manifest_of(project)
    manifest["runtime"]["name"] = "Arknights macOS Runtime 0.6.1"
    (project / "runtime.json").write_text(json.dumps(manifest), encoding="utf-8")

    with pytest.raises(ScriptError, match=r"runtime\.name"):
        runtime_update.check(project)


def test_license_blocks_ignore_runtime_markers_and_follow_the_pin(
    project: Path,
) -> None:
    components = licenses.load_client_components(project, [])
    libraries = next(c for c in components if c.runtime_release)
    assert libraries.name == "Libraries of runtime 0.7.0-rc1"

    runtime_update.update(project, NEW_TAG, release_fetch())

    components = licenses.load_client_components(project, [])
    libraries = next(c for c in components if c.runtime_release)
    assert libraries.name == "Libraries of runtime 0.7.0-rc2"
    assert libraries.source.endswith(f"/tree/{NEW_TAG}")
    text = "<!-- runtime:begin build -->\nold\n<!-- runtime:end build -->\n"
    assert licenses.apply_blocks(text, {}, True) == text
