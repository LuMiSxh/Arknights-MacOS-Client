# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest
from lib.runtime_monitor import (
    RuntimeCandidate,
    RuntimeIncident,
    RuntimeMonitorReport,
    RuntimeRelease,
    parse_recipe_metadata,
    report_value,
    select_latest_mirror_release,
)
from lib.runtime_probe import MIRROR_REPOSITORY, RuntimeProbe

PINNED_COMMIT = "a" * 40
CANDIDATE_COMMIT = "b" * 40
PINNED_DIGEST = "1" * 64
CANDIDATE_DIGEST = "2" * 64
SOURCE = b"fixture recipe source"


def test_selects_newest_numeric_runtime_with_required_asset() -> None:
    releases = [
        release_value("app-v2026.8.40", "9" * 64, include_archive=False),
        release_value("v4.5.9", "8" * 64),
        release_value("v4.5.125", CANDIDATE_DIGEST),
        release_value("v4.5.99", "7" * 64),
    ]

    selected = select_latest_mirror_release(releases)

    assert selected.tag == "v4.5.125"


def test_recipe_notes_expose_build_commit_and_component_pins() -> None:
    release = RuntimeRelease.from_json(
        recipe_release_value("4.5.125", CANDIDATE_DIGEST, CANDIDATE_COMMIT),
        recipe=True,
    )

    metadata = parse_recipe_metadata(release)

    assert metadata.build_commit == CANDIDATE_COMMIT
    assert metadata.archive_sha256 == CANDIDATE_DIGEST
    assert dict(metadata.pins)["winecx"] == CANDIDATE_COMMIT


def test_report_rejects_untrusted_or_non_newer_candidates() -> None:
    value = report_value(
        monitor_report(candidate=candidate("4.5.125", CANDIDATE_DIGEST))
    )
    candidate_value = value["candidate"]
    assert isinstance(candidate_value, dict)
    changed_pins = candidate_value["changedPins"]
    assert isinstance(changed_pins, list)
    changed_pins[0]["new"] = "<script>"

    with pytest.raises(ValueError, match="short safe text"):
        RuntimeMonitorReport.from_json(value)

    candidate_value["changedPins"][0]["new"] = CANDIDATE_COMMIT
    candidate_value["version"] = "4.5.100"
    with pytest.raises(ValueError, match="must be newer"):
        RuntimeMonitorReport.from_json(value)


def test_probe_builds_review_candidate_from_runtime_source_of_truth(
    tmp_path: Path,
) -> None:
    config = tmp_path / "runtime.json"
    config.write_text(json.dumps(runtime_config_value()), encoding="utf-8")
    notices = tmp_path / "notices.md"
    notices.write_text("| WineCX / Wine |", encoding="utf-8")
    report = RuntimeProbe(
        client=FakeUpstreamClient(), config_path=config, notices_path=notices
    ).run(environment={}, verify_archive=True)

    assert report.incidents == ()
    assert report.archive_verification == "passed"
    candidate = report.candidate
    assert candidate is not None
    assert candidate.version == "4.5.125"
    assert candidate.impact == "used-components"
    assert candidate.changed_pins == (
        ("WINECX_COMMIT", PINNED_COMMIT, CANDIDATE_COMMIT),
    )
    assert candidate.changed_files == (
        ".github/workflows/build.yml",
        "gptk-video/dxgishim.c",
    )
    assert dict(candidate.change_areas) == {
        "WineCX": "changed",
        "DXMT": "unchanged",
        "MoltenVK": "unchanged",
        "Nixpkgs": "unchanged",
        "Media stack": "unchanged",
        "Wine Gecko": "unchanged",
        "Build script": "changed",
        "Patches": "unchanged",
        "Packaging": "review",
        "GPTK video path": "changed",
    }


def test_probe_records_mirror_recipe_disagreement_without_candidate(
    tmp_path: Path,
) -> None:
    config = tmp_path / "runtime.json"
    config.write_text(json.dumps(runtime_config_value()), encoding="utf-8")
    notices = tmp_path / "notices.md"
    notices.write_text("| WineCX / Wine |", encoding="utf-8")
    client = FakeUpstreamClient()
    client.candidate_recipe_digest = "3" * 64

    report = RuntimeProbe(client=client, config_path=config, notices_path=notices).run(
        environment={}, verify_archive=False
    )

    assert report.candidate is None
    assert {incident.key for incident in report.incidents} == {"candidate-discovery"}


def release_value(
    tag: str,
    digest: str,
    *,
    include_archive: bool = True,
) -> dict[str, object]:
    assets: list[dict[str, object]] = []
    if include_archive:
        assets.extend(asset_values(tag, digest, recipe=False))
    return {
        "tag_name": tag,
        "draft": False,
        "body": (
            "Wine runtime built by "
            f"[recipe](https://github.com/dappermint/winecx-gptk/releases/tag/runtime-{tag})."
        ),
        "assets": assets,
    }


def recipe_release_value(version: str, digest: str, commit: str) -> dict[str, object]:
    wine_commit = PINNED_COMMIT if version == "4.5.118" else CANDIDATE_COMMIT
    return {
        "tag_name": f"runtime-v{version}",
        "draft": False,
        "body": (
            "| | |\n|---|---|\n"
            f"| winecx | `{wine_commit}` |\n"
            "| dxvk | 1.10.3 |\n| dxmt | 0.80 |\n| moltenvk | 1.4.2 |\n"
            f"| sha256 | `{digest}` |\n\nBuilt from {commit}."
        ),
        "assets": asset_values(f"runtime-v{version}", digest, recipe=True),
    }


def asset_values(tag: str, digest: str, *, recipe: bool) -> list[dict[str, object]]:
    repository = "winecx-gptk" if recipe else "Whisky"
    prefix = f"https://github.com/dappermint/{repository}/releases/download/{tag}"
    return [
        {
            "name": "Libraries.tar.gz",
            "size": 460_000_000,
            "digest": f"sha256:{digest}",
            "browser_download_url": f"{prefix}/Libraries.tar.gz",
        },
        {
            "name": "Libraries.tar.gz.sha256",
            "size": 83,
            "digest": f"sha256:{'f' * 64}",
            "browser_download_url": f"{prefix}/Libraries.tar.gz.sha256",
        },
    ]


def runtime_config_value() -> dict[str, object]:
    components = {
        "wine": "11.15",
        "dxmt": "0.80",
        "gstreamer": "1.26.3",
        "ffmpeg": "7.1.1",
        "moltenvk": "1.4.2",
        "wineGecko": "2.47.4",
    }
    provenance: dict[str, str] = {
        "buildRepository": "https://github.com/dappermint/winecx-gptk",
        "buildCommit": PINNED_COMMIT,
    }
    for index, name in enumerate(components, start=2):
        provenance[f"{name}Repository"] = f"https://github.com/example/{name}"
        provenance[f"{name}Commit"] = f"{index:x}" * 40
    return {
        "schemaVersion": 2,
        "prefixRevision": 2,
        "runtime": {
            "name": "Fixture runtime",
            "url": "https://github.com/dappermint/Whisky/releases/download/v4.5.118/Libraries.tar.gz",
            "sha256": PINNED_DIGEST,
        },
        "buildRecipe": {
            "url": "https://github.com/dappermint/winecx-gptk/archive/"
            f"{PINNED_COMMIT}.tar.gz",
            "sha256": hashlib.sha256(SOURCE).hexdigest(),
        },
        "interface": {
            "archive": {"wineDirectory": "Wine", "dxmtDirectory": "DXMT"},
            "executables": ["bin/wine64", "bin/wineserver"],
            "requiredFiles": ["lib/wine/x86_64-windows/winemetal.dll"],
            "macDriver": "lib/wine/x86_64-unix/winemac.so",
            "launcher": {"path": "bin/Arknights", "target": "wine64"},
            "dxmt": {
                "payloadDirectory": "DXMT",
                "destinations": {"x64": "system32", "x32": "syswow64"},
                "libraries": [
                    "d3d10core.dll",
                    "d3d11.dll",
                    "dxgi.dll",
                    "winemetal.dll",
                ],
            },
        },
        "components": components,
        "provenance": provenance,
    }


class FakeUpstreamClient:
    def __init__(self) -> None:
        self.candidate_recipe_digest = CANDIDATE_DIGEST

    def releases(self, repository: str) -> list[object]:
        assert repository == MIRROR_REPOSITORY
        return [
            release_value("v4.5.118", PINNED_DIGEST),
            release_value("v4.5.125", CANDIDATE_DIGEST),
        ]

    def release(self, repository: str, tag: str) -> RuntimeRelease:
        version = tag.removeprefix("runtime-v").removeprefix("v")
        if repository == MIRROR_REPOSITORY:
            digest = PINNED_DIGEST if version == "4.5.118" else CANDIDATE_DIGEST
            value = release_value(f"v{version}", digest)
            return RuntimeRelease.from_json(value)
        digest = PINNED_DIGEST if version == "4.5.118" else self.candidate_recipe_digest
        commit = PINNED_COMMIT if version == "4.5.118" else CANDIDATE_COMMIT
        return RuntimeRelease.from_json(
            recipe_release_value(version, digest, commit), recipe=True
        )

    def download(self, url: str, maximum_bytes: int) -> bytes:
        if url.endswith(".sha256"):
            digest = PINNED_DIGEST if "4.5.118" in url else self.candidate_recipe_digest
            return f"{digest}  Libraries.tar.gz\n".encode()
        return SOURCE

    def commit(self, repository: str, revision: str) -> dict[str, object]:
        if revision == "runtime-v4.5.118":
            return {"sha": PINNED_COMMIT}
        if revision == "runtime-v4.5.125":
            return {"sha": CANDIDATE_COMMIT}
        return {"sha": revision}

    def file_at(self, repository: str, path: str, commit: str) -> str:
        if path == ".github/workflows/build.yml":
            wine = PINNED_COMMIT if commit == PINNED_COMMIT else CANDIDATE_COMMIT
            return workflow_fixture(wine)
        return '#define GECKO_VERSION "2.47.4"\n'

    def compare(self, repository: str, old: str, new: str) -> dict[str, object]:
        return {
            "status": "ahead",
            "commits": [{"commit": {"message": "chore: bump winecx"}}],
            "files": [
                {"filename": ".github/workflows/build.yml"},
                {"filename": "gptk-video/dxgishim.c"},
            ],
        }

    def hash_download(self, url: str, maximum_bytes: int) -> str:
        return PINNED_DIGEST


def workflow_fixture(wine_commit: str) -> str:
    return f"""env:
  WINECX_COMMIT: {wine_commit}
  NIXPKGS_REV: {"d" * 40}
  MOLTENVK_VERSION: "1.4.2"
  FAUDIO_VERSION: "26.08"
  DXVK_VERSION: "1.10.3"
  DXMT_VERSION: "0.80"
  MACOSX_DEPLOYMENT_TARGET: "26.0"
"""


def candidate(version: str, digest: str) -> RuntimeCandidate:
    return RuntimeCandidate(
        pinned_version="4.5.118",
        version=version,
        digest=digest,
        build_commit=CANDIDATE_COMMIT,
        impact="used-components",
        changed_pins=(("WINECX_COMMIT", PINNED_COMMIT, CANDIDATE_COMMIT),),
        change_areas=(("WineCX", "changed"),),
        commit_summaries=("chore: bump winecx",),
        changed_files=(".github/workflows/build.yml",),
    )


def monitor_report(
    *,
    run: int = 1,
    candidate: RuntimeCandidate | None = None,
    incidents: tuple[RuntimeIncident, ...] = (),
) -> RuntimeMonitorReport:
    return RuntimeMonitorReport(
        checked_at=f"2026-08-{run:02d}T05:23:00Z",
        trigger="schedule",
        run_id=str(run),
        run_url=f"https://github.com/example/repo/actions/runs/{run}",
        pinned_version="4.5.118",
        candidate=candidate,
        incidents=incidents,
        archive_verification="not-requested",
    )
