# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
import subprocess
from collections.abc import Callable
from pathlib import Path

import pytest
import sparkle_deltas

REPOSITORY = "owner/repo"
UPDATE_NAME = "Example.Client.tar.xz"
# `fetch` derives legacy names from the real project's asset stem.
LEGACY_UPDATE_NAME = "Arknights.Client.zip"
NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def release(
    version: str, published: str, asset: str = UPDATE_NAME, **overrides: object
) -> dict[str, object]:
    return {
        "tag_name": f"v{version}",
        "published_at": published,
        "draft": False,
        "prerelease": False,
        "assets": [{"name": asset}],
        **overrides,
    }


def test_selects_newest_published_archives_excluding_current_and_unpublished() -> None:
    releases = [
        release("0.5.0", "2026-05-01T00:00:00Z"),
        release("0.4.0", "2026-04-01T00:00:00Z", draft=True),
        release("0.3.0", "2026-03-01T00:00:00Z", prerelease=True),
        release("0.2.0", "2026-02-01T00:00:00Z"),
        release("0.1.5", "2026-01-15T00:00:00Z", asset="Other.dmg"),
        release("0.1.0", "2026-01-01T00:00:00Z"),
        release("0.6.0", "2026-06-01T00:00:00Z"),
    ]

    sources = sparkle_deltas.select_sources(
        releases,
        current_version="0.6.0",
        stem="Example.Client",
        update_name=UPDATE_NAME,
        count=2,
    )

    assert sources == [
        ("0.5.0", "v0.5.0", UPDATE_NAME),
        ("0.2.0", "v0.2.0", UPDATE_NAME),
    ]


def fetch(
    destination: Path,
    monkeypatch: pytest.MonkeyPatch,
    releases: list[object],
    download: Callable[[list[str]], None],
) -> None:
    def fake_gh(command, **_):
        if command[1] == "api":
            return subprocess.CompletedProcess(command, 0, json.dumps(releases), "")
        download(command)
        return subprocess.CompletedProcess(command, 0, "", "")

    monkeypatch.setattr(sparkle_deltas, "run", fake_gh)
    sparkle_deltas.fetch(
        sparkle_deltas.argparse.Namespace(
            repository=REPOSITORY,
            current_version="0.7.0",
            update_name=UPDATE_NAME,
            destination=destination,
            count=3,
        )
    )


def test_download_failure_skips_deltas_without_failing_the_release(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    def fail_download(command: list[str]) -> None:
        raise sparkle_deltas.ScriptError("download failed with status 500")

    releases = [release("0.5.0", "2026-05-01T00:00:00Z")]
    fetch(tmp_path, monkeypatch, releases, fail_download)

    assert not list(tmp_path.iterdir())
    assert "Skipping deltas from 0.5.0" in capsys.readouterr().err


def test_fetch_keeps_each_sources_archive_format(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    def write_download(command: list[str]) -> None:
        Path(command[command.index("--output") + 1]).write_bytes(b"archive")

    releases = [
        release("0.5.0", "2026-05-01T00:00:00Z", asset=LEGACY_UPDATE_NAME),
        release("0.6.0", "2026-06-01T00:00:00Z"),
    ]
    fetch(tmp_path, monkeypatch, releases, write_download)

    names = sorted(path.name for path in tmp_path.iterdir())
    assert names[0].endswith(".0.5.0.zip")
    assert names[1].endswith(".0.6.0.tar.xz")


def appcast_with_delta(directory: Path) -> Path:
    appcast = directory / "appcast.xml"
    appcast.write_text(
        f'<rss xmlns:sparkle="{NAMESPACE}"><channel><item>'
        f'<enclosure url="https://h/v42/{UPDATE_NAME}" />'
        "<sparkle:deltas>"
        '<enclosure url="https://h/v42/Example%20Client42-41.delta" />'
        "</sparkle:deltas></item></channel></rss>\n"
        "<!-- sparkle-signatures:\nedSignature: old\nlength: 1\n-->\n"
    )
    (directory / "Example Client42-41.delta").write_bytes(b"delta")
    return appcast


def test_finalize_renames_deltas_rewrites_urls_and_resigns(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[tuple[list[object], dict[str, object]]] = []

    def fake_run(command, **kwargs):
        calls.append((command, kwargs))
        return subprocess.CompletedProcess(command, 0, stdout=b"", stderr=b"")

    monkeypatch.setattr(sparkle_deltas.subprocess, "run", fake_run)
    appcast = appcast_with_delta(tmp_path)
    output = tmp_path / "dist"

    published = sparkle_deltas.finalize_deltas(
        tmp_path, appcast, output, Path("/tools/sign_update"), "SECRET"
    )

    assert [path.name for path in published] == ["Example.Client42-41.delta"]
    assert (output / "Example.Client42-41.delta").read_bytes() == b"delta"
    assert b"Example.Client42-41.delta" in appcast.read_bytes()
    assert b"%20" not in appcast.read_bytes()
    command, kwargs = calls[0]
    assert command == [
        Path("/tools/sign_update"),
        "--ed-key-file",
        "-",
        "--disable-signing-warning",
        appcast,
    ]
    assert kwargs["input"] == b"SECRET"


def test_finalize_without_deltas_leaves_appcast_untouched(tmp_path: Path) -> None:
    appcast = tmp_path / "appcast.xml"
    appcast.write_text(
        '<rss><channel><item><enclosure url="u"/></item></channel></rss>'
    )
    before = appcast.read_bytes()

    published = sparkle_deltas.finalize_deltas(
        tmp_path, appcast, tmp_path / "out", Path("x"), ""
    )

    assert published == []
    assert appcast.read_bytes() == before


def test_finalize_fails_without_key_or_when_sign_update_fails(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    appcast = appcast_with_delta(tmp_path)
    output = tmp_path / "out"
    with pytest.raises(RuntimeError, match="PRIVATE_KEY is required"):
        sparkle_deltas.finalize_deltas(tmp_path, appcast, output, Path("x"), "")

    monkeypatch.setattr(
        sparkle_deltas.subprocess,
        "run",
        lambda command, **kwargs: subprocess.CompletedProcess(
            command, 1, stdout=b"ERROR! bad key", stderr=b""
        ),
    )
    with pytest.raises(RuntimeError, match="bad key"):
        sparkle_deltas.finalize_deltas(tmp_path, appcast, output, Path("x"), "K")
