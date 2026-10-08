# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import base64
import subprocess
from pathlib import Path

import pytest
import sparkle_deltas
import validate_sparkle_keys

REPOSITORY = "owner/repo"
PREFIX = f"https://github.com/{REPOSITORY}/releases/download"
UPDATE_NAME = "Example.Client.tar.xz"
# `fetch` derives legacy names from the real project's asset stem.
LEGACY_UPDATE_NAME = "Arknights.Client.zip"


def release(version: str, published: str, **overrides: object) -> dict[str, object]:
    return {
        "tag_name": f"v{version}",
        "published_at": published,
        "draft": False,
        "prerelease": False,
        "assets": [
            {
                "name": UPDATE_NAME,
                "browser_download_url": f"{PREFIX}/v{version}/{UPDATE_NAME}",
            }
        ],
        **overrides,
    }


def test_selects_newest_published_archives_excluding_current_drafts_and_foreign_urls() -> (
    None
):
    foreign = release("0.1.0", "2026-01-01T00:00:00Z")
    foreign["assets"] = [
        {"name": UPDATE_NAME, "browser_download_url": "https://evil.invalid/a.zip"}
    ]
    releases = [
        release("0.5.0", "2026-05-01T00:00:00Z"),
        release("0.4.0", "2026-04-01T00:00:00Z", draft=True),
        release("0.3.0", "2026-03-01T00:00:00Z", prerelease=True),
        release("0.2.0", "2026-02-01T00:00:00Z"),
        release("0.1.5", "2026-01-15T00:00:00Z"),
        foreign,
        release("0.6.0", "2026-06-01T00:00:00Z"),
    ]

    sources = sparkle_deltas.select_sources(
        releases,
        repository=REPOSITORY,
        current_version="0.6.0",
        update_names=sparkle_deltas.accepted_archive_names(
            releases, "Example.Client", UPDATE_NAME
        ),
        count=2,
    )

    assert [source.version for source in sources] == ["0.5.0", "0.2.0"]


def test_first_release_has_no_sources() -> None:
    releases = [release("0.1.0", "2026-01-01T00:00:00Z")]

    assert not sparkle_deltas.select_sources(
        releases,
        repository=REPOSITORY,
        current_version="0.1.0",
        update_names={"0.1.0": {UPDATE_NAME}},
        count=3,
    )


class FailingClient:
    def __init__(self, token: str | None = None) -> None:
        pass

    def releases(self, repository: str) -> list[object]:
        return [release("0.5.0", "2026-05-01T00:00:00Z")]

    def download_to_file(self, url: str, destination: Path, maximum: int) -> int:
        raise sparkle_deltas.ScriptError("download failed with status 500")


def test_download_failure_skips_deltas_without_failing_the_release(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]
) -> None:
    monkeypatch.setattr(sparkle_deltas, "GitHubClient", FailingClient)
    arguments = sparkle_deltas.argparse.Namespace(
        repository=REPOSITORY,
        current_version="0.6.0",
        update_name=UPDATE_NAME,
        destination=tmp_path,
        count=3,
    )

    sparkle_deltas.fetch(arguments)

    assert not list(tmp_path.iterdir())
    assert "Skipping deltas from 0.5.0" in capsys.readouterr().err


class MixedFormatClient:
    def __init__(self, token: str | None = None) -> None:
        pass

    def releases(self, repository: str) -> list[object]:
        legacy = release("0.5.0", "2026-05-01T00:00:00Z")
        legacy["assets"] = [
            {
                "name": LEGACY_UPDATE_NAME,
                "browser_download_url": f"{PREFIX}/v0.5.0/{LEGACY_UPDATE_NAME}",
            }
        ]
        return [legacy, release("0.6.0", "2026-06-01T00:00:00Z")]

    def download_to_file(self, url: str, destination: Path, maximum: int) -> int:
        destination.write_bytes(b"archive")
        return 7


def test_fetch_keeps_each_sources_archive_format(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(sparkle_deltas, "GitHubClient", MixedFormatClient)
    arguments = sparkle_deltas.argparse.Namespace(
        repository=REPOSITORY,
        current_version="0.7.0",
        update_name=UPDATE_NAME,
        destination=tmp_path,
        count=3,
    )

    sparkle_deltas.fetch(arguments)

    names = sorted(path.name for path in tmp_path.iterdir())
    assert [name.rpartition(".")[2] for name in names] == ["zip", "xz"]
    assert names[0].endswith(".0.5.0.zip")
    assert names[1].endswith(".0.6.0.tar.xz")


def test_finalize_renames_deltas_rewrites_urls_and_resigns(tmp_path: Path) -> None:
    openssl = validate_sparkle_keys.require_openssl_ed25519()
    seed = b"S" * validate_sparkle_keys.PRIVATE_SEED_BYTES
    public_key = validate_sparkle_keys.derive_public_key(seed, openssl)

    def encoded(value: bytes) -> str:
        return base64.b64encode(value).decode("ascii")

    update = tmp_path / UPDATE_NAME
    update.write_bytes(b"full archive")
    delta = tmp_path / "Example Client42-41.delta"
    delta.write_bytes(b"delta contents")

    def signature_for(path: Path) -> str:
        key = tmp_path / "key.der"
        key.write_bytes(validate_sparkle_keys.PKCS8_ED25519_PREFIX + seed)
        result = subprocess.run(
            [
                openssl,
                "pkeyutl",
                "-sign",
                "-rawin",
                "-inkey",
                str(key),
                "-keyform",
                "DER",
                "-in",
                str(path),
            ],
            capture_output=True,
            check=True,
        )
        return encoded(result.stdout)

    def fake_sign_update(appcast: Path) -> None:
        """Stand in for sign_update: append a signing block over the current bytes."""
        content = appcast.read_bytes()
        feed = tmp_path / "feed-to-sign.xml"
        feed.write_bytes(content)
        appcast.write_bytes(
            content
            + (
                "<!-- sparkle-signatures:\n"
                f"edSignature: {signature_for(feed)}\n"
                f"length: {len(content)}\n"
                "-->\n"
            ).encode()
        )

    content = (
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
        "<channel><item><description>Notes</description>"
        f'<enclosure url="{PREFIX}/v42/{UPDATE_NAME}" length="{update.stat().st_size}" '
        f'sparkle:edSignature="{signature_for(update)}" />'
        "<sparkle:deltas>"
        f'<enclosure url="{PREFIX}/v42/Example%20Client42-41.delta" '
        f'sparkle:deltaFrom="41" length="{delta.stat().st_size}" '
        f'sparkle:edSignature="{signature_for(delta)}" />'
        "</sparkle:deltas></item></channel></rss>\n"
    ).encode()
    appcast = tmp_path / "appcast.xml"
    appcast.write_bytes(content)
    fake_sign_update(appcast)
    output = tmp_path / "dist"

    published = sparkle_deltas.finalize_deltas(
        tmp_path, appcast, output, fake_sign_update
    )

    assert [path.name for path in published] == ["Example.Client42-41.delta"]
    assert b"Example.Client42-41.delta" in appcast.read_bytes()
    assert b"%20" not in appcast.read_bytes()
    validate_sparkle_keys.validate_appcast(
        appcast,
        UPDATE_NAME,
        update_file=update,
        public_key=encoded(public_key),
        openssl=openssl,
        delta_directory=output,
    )

    (output / "Example.Client42-41.delta").write_bytes(b"tampered delta!")
    with pytest.raises(RuntimeError, match="length does not match"):
        validate_sparkle_keys.validate_appcast(
            appcast,
            UPDATE_NAME,
            update_file=update,
            public_key=encoded(public_key),
            openssl=openssl,
            delta_directory=output,
        )
    (output / "Example.Client42-41.delta").write_bytes(b"tampered delta")
    with pytest.raises(RuntimeError, match="delta Ed25519 signature is invalid"):
        validate_sparkle_keys.validate_appcast(
            appcast,
            UPDATE_NAME,
            update_file=update,
            public_key=encoded(public_key),
            openssl=openssl,
            delta_directory=output,
        )


def test_finalize_without_deltas_leaves_appcast_untouched(tmp_path: Path) -> None:
    content = b'<rss xmlns:sparkle="x"><channel><item><enclosure url="u"/></item></channel></rss>\n'
    appcast = tmp_path / "appcast.xml"
    signed = (
        content
        + f"<!-- sparkle-signatures:\nedSignature: {base64.b64encode(b'S' * 64).decode()}\nlength: {len(content)}\n-->\n".encode()
    )
    appcast.write_bytes(signed)

    assert (
        sparkle_deltas.finalize_deltas(tmp_path, appcast, tmp_path / "out", None) == []
    )
    assert appcast.read_bytes() == signed


def test_validator_rejects_delta_that_github_would_rename() -> None:
    delta = validate_sparkle_keys.ET.fromstring(
        f'<enclosure xmlns:sparkle="{validate_sparkle_keys.SPARKLE_NAMESPACE}" '
        f'url="{PREFIX}/v42/Example%20Client42-41.delta" sparkle:deltaFrom="41" />'
    )
    archive = validate_sparkle_keys.ET.fromstring(
        f'<enclosure url="{PREFIX}/v42/{UPDATE_NAME}" />'
    )

    with pytest.raises(RuntimeError, match="renamed by GitHub"):
        validate_sparkle_keys.validate_delta_enclosures(
            [delta], [archive], None, None, None
        )


def test_sign_update_receives_the_key_on_stdin_only(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    calls: list[tuple[list[str], dict[str, object]]] = []

    def fake_run(command: list[str], **kwargs: object) -> subprocess.CompletedProcess:
        calls.append((command, kwargs))
        return subprocess.CompletedProcess(command, 0, stdout=b"", stderr=b"")

    monkeypatch.setattr(sparkle_deltas.subprocess, "run", fake_run)
    appcast = tmp_path / "appcast.xml"

    sparkle_deltas.sign_feed_with_sparkle("SECRET", Path("/tools/sign_update"))(appcast)

    command, kwargs = calls[0]
    assert command == [
        "/tools/sign_update",
        "--ed-key-file",
        "-",
        "--disable-signing-warning",
        str(appcast),
    ]
    assert kwargs["input"] == b"SECRET"
    assert "SECRET" not in " ".join(command)


def test_sign_update_failure_fails_the_release(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.setattr(
        sparkle_deltas.subprocess,
        "run",
        lambda command, **kwargs: subprocess.CompletedProcess(
            command, 1, stdout=b"ERROR! bad key", stderr=b""
        ),
    )

    with pytest.raises(RuntimeError, match="bad key"):
        sparkle_deltas.sign_feed_with_sparkle("K", Path("sign_update"))(
            tmp_path / "appcast.xml"
        )
