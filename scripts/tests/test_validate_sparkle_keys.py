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


@pytest.mark.parametrize(
    ("public_key", "private_key", "message"),
    [
        (
            encoded(b"P" * 32),
            encoded(b"S" * 96),
            "exactly 32 bytes",
        ),
        (
            encoded(b"P" * 31),
            encoded(b"S" * 32),
            "must decode to 32 bytes",
        ),
        (
            f" {encoded(b'P' * 32)}",
            encoded(b"S" * 32),
            "must not contain whitespace",
        ),
    ],
    ids=("legacy-private-key-format", "public-key-length", "public-key-whitespace"),
)
def test_rejects_invalid_key_encodings(
    public_key: str, private_key: str, message: str
) -> None:
    with pytest.raises(RuntimeError, match=message):
        validate_sparkle_keys.validate_keys(public_key, private_key)


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

    def signed_feed(content: bytes) -> bytes:
        feed.write_bytes(content)
        return (
            content
            + (
                "<!-- sparkle-signatures:\n"
                f"edSignature: {encoded(sign(feed))}\n"
                f"length: {len(content)}\n"
                "-->\n"
            ).encode()
        )

    appcast.write_bytes(signed_feed(body))

    validate_sparkle_keys.validate_appcast(
        appcast,
        expected_update_name=update.name,
        update_file=update,
        public_key=encoded(public_key),
        openssl=openssl,
    )

    incomplete_appcast = tmp_path / "signed-prefix-completed-after-comment.xml"
    incomplete_prefix = body.removesuffix(b"</rss>\n")
    incomplete_appcast.write_bytes(signed_feed(incomplete_prefix) + b"</rss>\n")
    with pytest.raises(RuntimeError, match="could not parse generated Sparkle appcast"):
        validate_sparkle_keys.validate_appcast(
            incomplete_appcast,
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


ENCLOSURE_SIGNATURE = encoded(b"E" * 64)
FEED_SIGNATURE = encoded(b"S" * 64)
VALID_APPCAST_ITEM = (
    "<description>Release notes</description>"
    '<enclosure url="https://example.invalid/Example.Client.zip" length="1" '
    f'type="application/octet-stream" sparkle:edSignature="{ENCLOSURE_SIGNATURE}" />'
)


@pytest.mark.parametrize(
    ("item", "feed_signature", "expected_update_name", "message"),
    [
        pytest.param(
            VALID_APPCAST_ITEM,
            None,
            None,
            "missing its sparkle-signatures block",
            id="unsigned-appcast",
        ),
        pytest.param(
            VALID_APPCAST_ITEM,
            "",
            None,
            "empty feed Ed25519 signature",
            id="empty-feed-signature",
        ),
        pytest.param(
            VALID_APPCAST_ITEM.replace(
                f' sparkle:edSignature="{ENCLOSURE_SIGNATURE}"', ""
            ),
            FEED_SIGNATURE,
            None,
            "every Sparkle appcast enclosure",
            id="unsigned-enclosure",
        ),
        pytest.param(
            VALID_APPCAST_ITEM.replace("Example.Client.zip", "Other.zip"),
            FEED_SIGNATURE,
            "Example.Client.zip",
            "does not match expected update asset",
            id="wrong-update-name",
        ),
        pytest.param(
            VALID_APPCAST_ITEM.removeprefix("<description>Release notes</description>"),
            FEED_SIGNATURE,
            None,
            "contains no release notes",
            id="missing-release-notes",
        ),
    ],
)
def test_rejects_invalid_appcasts(
    tmp_path: Path,
    item: str,
    feed_signature: str | None,
    expected_update_name: str | None,
    message: str,
) -> None:
    appcast = tmp_path / "appcast.xml"
    content = (
        '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">'
        f"<channel><item>{item}</item></channel></rss>\n"
    ).encode()
    signing_block = (
        b""
        if feed_signature is None
        else (
            "<!-- sparkle-signatures:\n"
            f"edSignature: {feed_signature}\n"
            f"length: {len(content)}\n"
            "-->\n"
        ).encode()
    )
    appcast.write_bytes(content + signing_block)

    with pytest.raises(RuntimeError, match=message):
        validate_sparkle_keys.validate_appcast(
            appcast, expected_update_name=expected_update_name
        )
