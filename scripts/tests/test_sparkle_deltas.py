# SPDX-License-Identifier: MPL-2.0

import json
import subprocess
import xml.etree.ElementTree as ET
from collections.abc import Callable
from pathlib import Path

import pytest
import sparkle_deltas
from lib import sparkle_appcast

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
        "<sparkle:version>42</sparkle:version>"
        f'<enclosure url="https://h/v42/{UPDATE_NAME}" />'
        "<sparkle:deltas>"
        '<enclosure url="https://h/v42/Example%20Client42-41.delta" />'
        "</sparkle:deltas></item></channel></rss>\n"
        "<!-- sparkle-signatures:\nedSignature: old\nlength: 1\n-->\n"
    )
    (directory / "Example Client42-41.delta").write_bytes(b"delta")
    return appcast


def appcast_without_delta(directory: Path) -> Path:
    appcast = directory / "appcast.xml"
    appcast.write_text(
        f'<rss xmlns:sparkle="{NAMESPACE}"><channel>'
        "<item><sparkle:version>16</sparkle:version>"
        '<enclosure url="https://h/v0.5.2/old.tar.xz" /></item>'
        "<item><sparkle:version>30</sparkle:version>"
        '<enclosure url="https://h/v0.8.0/new.tar.xz" /></item>'
        "</channel></rss>\n"
    )
    return appcast


def test_finalize_annotates_the_newest_item_and_signs_without_deltas(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[tuple[list[object], dict[str, object]]] = []

    def fake_run(command, **kwargs):
        calls.append((command, kwargs))
        return subprocess.CompletedProcess(command, 0, stdout=b"", stderr=b"")

    monkeypatch.setattr(sparkle_appcast.subprocess, "run", fake_run)
    appcast = appcast_without_delta(tmp_path)
    info_link = "https://github.com/owner/repo/releases/tag/v0.8.0"

    published = sparkle_deltas.finalize_deltas(
        tmp_path,
        appcast,
        tmp_path / "dist",
        Path("/tools/sign_update"),
        "SECRET",
        build=30,
        minimum_build=18,
        info_link=info_link,
    )

    assert published == []
    text = appcast.read_text()
    assert "<sparkle:belowVersion>18</sparkle:belowVersion>" in text
    assert info_link in text
    root = ET.fromstring(text)
    oldest, newest = root.findall("./channel/item")
    below = newest.find(
        f"{{{NAMESPACE}}}informationalUpdate/{{{NAMESPACE}}}belowVersion"
    )
    assert below is not None
    assert below.text == "18"
    assert oldest.find(f"{{{NAMESPACE}}}informationalUpdate") is None
    command, kwargs = calls[0]
    assert command == [
        Path("/tools/sign_update"),
        "--ed-key-file",
        "-",
        "--disable-signing-warning",
        appcast,
    ]
    assert kwargs["input"] == b"SECRET"


def test_finalize_signs_a_feed_without_deltas_or_gate(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[list[object]] = []

    def fake_run(command, **kwargs):
        calls.append(command)
        return subprocess.CompletedProcess(command, 0, stdout=b"", stderr=b"")

    monkeypatch.setattr(sparkle_appcast.subprocess, "run", fake_run)
    appcast = appcast_without_delta(tmp_path)

    published = sparkle_deltas.finalize_deltas(
        tmp_path,
        appcast,
        tmp_path / "dist",
        Path("/tools/sign_update"),
        "SECRET",
        build=30,
    )

    assert published == []
    assert calls[0][-1] == appcast


def test_finalize_requires_an_info_link_for_the_gate(tmp_path: Path) -> None:
    appcast = appcast_without_delta(tmp_path)
    with pytest.raises(RuntimeError, match="information link"):
        sparkle_deltas.finalize_deltas(
            tmp_path,
            appcast,
            tmp_path / "dist",
            Path("x"),
            "K",
            build=30,
            minimum_build=18,
        )


def test_finalize_renames_deltas_rewrites_urls_and_resigns(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[tuple[list[object], dict[str, object]]] = []

    def fake_run(command, **kwargs):
        calls.append((command, kwargs))
        return subprocess.CompletedProcess(command, 0, stdout=b"", stderr=b"")

    monkeypatch.setattr(sparkle_appcast.subprocess, "run", fake_run)
    appcast = appcast_with_delta(tmp_path)
    output = tmp_path / "dist"

    published = sparkle_deltas.finalize_deltas(
        tmp_path, appcast, output, Path("/tools/sign_update"), "SECRET", build=42
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
        sparkle_deltas.finalize_deltas(
            tmp_path, appcast, output, Path("x"), "", build=42
        )

    monkeypatch.setattr(
        sparkle_appcast.subprocess,
        "run",
        lambda command, **kwargs: subprocess.CompletedProcess(
            command, 1, stdout=b"ERROR! bad key", stderr=b""
        ),
    )
    with pytest.raises(RuntimeError, match="bad key"):
        sparkle_deltas.finalize_deltas(
            tmp_path, appcast, output, Path("x"), "K", build=42
        )


def test_finalize_ignores_deltas_of_older_items(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        sparkle_appcast.subprocess,
        "run",
        lambda command, **kwargs: subprocess.CompletedProcess(command, 0, b"", b""),
    )
    appcast = appcast_with_delta(tmp_path)
    older = (
        "<item><sparkle:version>40</sparkle:version>"
        '<enclosure url="https://h/v40/Old.tar.xz" />'
        "<sparkle:deltas>"
        '<enclosure url="https://h/v40/Old39-38.delta" />'
        "</sparkle:deltas></item>"
    )
    appcast.write_text(appcast.read_text().replace("<item>", older + "<item>", 1))

    published = sparkle_deltas.finalize_deltas(
        tmp_path,
        appcast,
        tmp_path / "dist",
        Path("/tools/sign_update"),
        "SECRET",
        build=42,
    )

    assert [path.name for path in published] == ["Example.Client42-41.delta"]
    assert b"Old39-38.delta" in appcast.read_bytes()
