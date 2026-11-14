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
