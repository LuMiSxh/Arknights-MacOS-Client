# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import base64
import plistlib
import subprocess
from pathlib import Path

import pytest
import validate_sparkle_keys


def encoded(value: bytes) -> str:
    return base64.b64encode(value).decode("ascii")


def test_rejects_legacy_key_format() -> None:
    with pytest.raises(RuntimeError, match="exactly 32 bytes"):
        validate_sparkle_keys.validate_keys(encoded(b"P" * 32), encoded(b"S" * 96))


def test_rejects_mismatched_key_pair(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        validate_sparkle_keys,
        "derive_public_key",
        lambda seed, openssl=None: b"P" * 32,
    )

    with pytest.raises(RuntimeError, match="do not match"):
        validate_sparkle_keys.validate_keys(encoded(b"Q" * 32), encoded(b"S" * 32))


def test_derives_new_seed_using_native_key_format(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    public_key = b"P" * 32

    def fake_run(command, *, input, capture_output, check):
        assert command[1:] == [
            "pkey",
            "-inform",
            "DER",
            "-pubout",
            "-outform",
            "DER",
        ]
        assert input == validate_sparkle_keys.PKCS8_ED25519_PREFIX + b"S" * 32
        return subprocess.CompletedProcess(
            command,
            0,
            stdout=validate_sparkle_keys.SPKI_ED25519_PREFIX + public_key,
            stderr=b"",
        )

    monkeypatch.setattr(validate_sparkle_keys.subprocess, "run", fake_run)

    assert validate_sparkle_keys.derive_public_key(b"S" * 32, "openssl") == public_key


def test_rejects_invalid_public_key_length() -> None:
    with pytest.raises(RuntimeError, match="must decode to 32 bytes"):
        validate_sparkle_keys.validate_keys(encoded(b"P" * 31), encoded(b"S" * 32))


def test_rejects_public_key_whitespace() -> None:
    with pytest.raises(RuntimeError, match="must not contain whitespace"):
        validate_sparkle_keys.validate_keys(
            f" {encoded(b'P' * 32)}", encoded(b"S" * 32)
        )


def test_reads_public_key_from_tracked_info_plist(tmp_path: Path) -> None:
    public_key = encoded(b"P" * 32)
    path = tmp_path / "Info.plist"
    path.write_bytes(plistlib.dumps({"SUPublicEDKey": public_key}))

    assert validate_sparkle_keys.public_key_from_plist(path) == public_key


def test_accepts_signed_appcast(tmp_path: Path) -> None:
    appcast = tmp_path / "appcast.xml"
    enclosure_signature = encoded(b"E" * 64)
    content = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">\n'
        "  <channel>\n"
        "    <item>\n"
        f'      <enclosure url="https://example.invalid/update.zip" length="1" '
        f'type="application/octet-stream" sparkle:edSignature="{enclosure_signature}" />\n'
        "    </item>\n"
        "  </channel>\n"
        "</rss>\n"
    )
    content = content.encode()
    signing_block = (
        "<!-- sparkle-signatures:\n"
        f"edSignature: {encoded(b'S' * 64)}\n"
        f"length: {len(content)}\n"
        "-->\n"
    ).encode()
    appcast.write_bytes(content + signing_block)

    validate_sparkle_keys.validate_appcast(appcast)


def test_rejects_unsigned_appcast(tmp_path: Path) -> None:
    appcast = tmp_path / "appcast.xml"
    appcast.write_text(
        "<rss><channel><item><enclosure /></item></channel></rss>", encoding="utf-8"
    )

    with pytest.raises(RuntimeError, match="missing its sparkle-signatures block"):
        validate_sparkle_keys.validate_appcast(appcast)


def test_rejects_empty_feed_signature(tmp_path: Path) -> None:
    appcast = tmp_path / "appcast.xml"
    content = b"<rss><channel /></rss>\n"
    appcast.write_bytes(
        content
        + f"<!-- sparkle-signatures:\nedSignature: \nlength: {len(content)}\n-->\n".encode()
    )

    with pytest.raises(RuntimeError, match="empty feed Ed25519 signature"):
        validate_sparkle_keys.validate_appcast(appcast)


def test_rejects_unsigned_enclosure(tmp_path: Path) -> None:
    appcast = tmp_path / "appcast.xml"
    content = b"<rss><channel><item><enclosure /></item></channel></rss>\n"
    appcast.write_bytes(
        content
        + f"<!-- sparkle-signatures:\nedSignature: {encoded(b'S' * 64)}\nlength: {len(content)}\n-->\n".encode()
    )

    with pytest.raises(RuntimeError, match="every Sparkle appcast enclosure"):
        validate_sparkle_keys.validate_appcast(appcast)
