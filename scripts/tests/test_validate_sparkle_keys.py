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


def test_rejects_system_libressl_with_actionable_openssl_guidance(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        validate_sparkle_keys.subprocess,
        "run",
        lambda command, **kwargs: subprocess.CompletedProcess(
            command, 0, stdout="LibreSSL 3.3.6", stderr=""
        ),
    )

    with pytest.raises(RuntimeError, match="brew install openssl@3"):
        validate_sparkle_keys.derive_public_key(b"S" * 32, "openssl")


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
        "      <description><![CDATA[Release notes]]></description>\n"
        f'      <enclosure url="https://example.invalid/Example.Client.zip" length="1" '
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

    validate_sparkle_keys.validate_appcast(
        appcast, expected_update_name="Example.Client.zip"
    )


def test_cryptographically_verifies_appcast_and_update_artifact(
    tmp_path: Path,
) -> None:
    openssl = validate_sparkle_keys.require_openssl_ed25519()

    seed = b"S" * validate_sparkle_keys.PRIVATE_SEED_BYTES
    private_key = tmp_path / "private.der"
    private_key.write_bytes(validate_sparkle_keys.PKCS8_ED25519_PREFIX + seed)
    public_key = validate_sparkle_keys.derive_public_key(seed, openssl)
    update = tmp_path / "Example.Client.zip"
    update.write_bytes(b"verified update contents")

    def sign(path: Path) -> bytes:
        result = subprocess.run(
            [
                openssl,
                "pkeyutl",
                "-sign",
                "-rawin",
                "-inkey",
                str(private_key),
                "-keyform",
                "DER",
                "-in",
                str(path),
            ],
            capture_output=True,
            check=True,
        )
        return result.stdout

    enclosure_signature = sign(update)
    body = (
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">\n'
        "  <channel><item>\n"
        "    <description>Release notes</description>\n"
        f'    <enclosure url="https://example.invalid/{update.name}" length="{update.stat().st_size}" '
        f'type="application/octet-stream" sparkle:edSignature="{encoded(enclosure_signature)}" />\n'
        "  </item></channel>\n"
        "</rss>\n"
    ).encode()
    appcast = tmp_path / "appcast.xml"
    feed = tmp_path / "feed.xml"
    feed.write_bytes(body)
    appcast.write_bytes(
        body
        + (
            "<!-- sparkle-signatures:\n"
            f"edSignature: {encoded(sign(feed))}\n"
            f"length: {len(body)}\n"
            "-->\n"
        ).encode()
    )

    validate_sparkle_keys.validate_appcast(
        appcast,
        expected_update_name=update.name,
        update_file=update,
        public_key=encoded(public_key),
        openssl=openssl,
    )

    update.write_bytes(b"tampered update contents")
    with pytest.raises(RuntimeError, match="enclosure Ed25519 signature is invalid"):
        validate_sparkle_keys.validate_appcast(
            appcast,
            expected_update_name=update.name,
            update_file=update,
            public_key=encoded(public_key),
            openssl=openssl,
        )

    update.write_bytes(b"verified update contents")
    with pytest.raises(RuntimeError, match="appcast Ed25519 signature is invalid"):
        validate_sparkle_keys.validate_appcast(
            appcast,
            expected_update_name=update.name,
            update_file=update,
            public_key=encoded(b"W" * validate_sparkle_keys.PUBLIC_KEY_BYTES),
            openssl=openssl,
        )


def test_rejects_appcast_with_wrong_update_name(tmp_path: Path) -> None:
    appcast = tmp_path / "appcast.xml"
    enclosure_signature = encoded(b"E" * 64)
    content = (
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
        "<channel><item>"
        "<description>Release notes</description>"
        f'<enclosure url="https://example.invalid/Other.zip" length="1" '
        f'type="application/octet-stream" sparkle:edSignature="{enclosure_signature}" />'
        "</item></channel></rss>\n"
    ).encode()
    signing_block = (
        "<!-- sparkle-signatures:\n"
        f"edSignature: {encoded(b'S' * 64)}\n"
        f"length: {len(content)}\n"
        "-->\n"
    ).encode()
    appcast.write_bytes(content + signing_block)

    with pytest.raises(RuntimeError, match="does not match expected update asset"):
        validate_sparkle_keys.validate_appcast(
            appcast, expected_update_name="Example.Client.zip"
        )


def test_rejects_appcast_without_release_notes(tmp_path: Path) -> None:
    appcast = tmp_path / "appcast.xml"
    enclosure_signature = encoded(b"E" * 64)
    content = (
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
        "<channel><item>"
        f'<enclosure url="https://example.invalid/Example.Client.zip" length="1" '
        f'type="application/octet-stream" sparkle:edSignature="{enclosure_signature}" />'
        "</item></channel></rss>\n"
    ).encode()
    signing_block = (
        "<!-- sparkle-signatures:\n"
        f"edSignature: {encoded(b'S' * 64)}\n"
        f"length: {len(content)}\n"
        "-->\n"
    ).encode()
    appcast.write_bytes(content + signing_block)

    with pytest.raises(RuntimeError, match="contains no release notes"):
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
