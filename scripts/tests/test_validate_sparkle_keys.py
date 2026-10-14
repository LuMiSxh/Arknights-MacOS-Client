# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import base64
import hashlib
import plistlib
import stat
import sys
from pathlib import Path

import pytest
import validate_sparkle_keys as sparkle

SEED = base64.b64encode(b"S" * 32).decode()
PUBLIC = base64.b64encode(b"P" * 32).decode()
UPDATE = "Example.Client.tar.xz"
DELTA = "Example.Client42-41.delta"
MARKER = "<!-- sparkle-signatures:\n"

# Stands in for Sparkle's `sign_update --verify`: a "signature" is sha256(key + bytes).
FAKE_SIGN_UPDATE = f"""#!{sys.executable}
import hashlib, sys
key = sys.stdin.read()
path, *signature = sys.argv[4:]
data = open(path, "rb").read()
if not signature:
    text, _, tail = data.decode().partition({MARKER!r})
    signature, data = [tail.split("edSignature: ")[1].split()[0]], text.encode()
sys.exit(0 if hashlib.sha256(key.encode() + data).hexdigest() == signature[0] else 1)
"""
FAKE_OPENSSL = f"""#!{sys.executable}
import sys
sys.stdout.buffer.write(bytes.fromhex({sparkle.SPKI_ED25519_PREFIX.hex()!r}) + b"P" * 32)
"""


def script(path: Path, body: str) -> Path:
    path.write_text(body)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


def signature(data: bytes, key: str = SEED) -> str:
    return hashlib.sha256(key.encode() + data).hexdigest()


def test_accepts_matching_key_pair_and_rejects_another(tmp_path: Path) -> None:
    openssl = str(script(tmp_path / "openssl", FAKE_OPENSSL))

    sparkle.validate_keys(PUBLIC, SEED, openssl)
    with pytest.raises(RuntimeError, match="do not match"):
        sparkle.validate_keys(base64.b64encode(b"Q" * 32).decode(), SEED, openssl)


def test_missing_openssl_gives_install_guidance(tmp_path: Path) -> None:
    with pytest.raises(RuntimeError, match="brew install openssl@3"):
        sparkle.derive_public_key(b"S" * 32, str(tmp_path / "missing"))


@pytest.mark.parametrize(
    "value", [" " + PUBLIC, "not base64!", base64.b64encode(b"P" * 31).decode()]
)
def test_rejects_invalid_key_encodings(value: str) -> None:
    with pytest.raises(RuntimeError, match="SUPublicEDKey"):
        sparkle.validate_keys(value, SEED)


def test_reads_public_key_from_info_plist(tmp_path: Path) -> None:
    plist = tmp_path / "Info.plist"
    plist.write_bytes(plistlib.dumps({"SUPublicEDKey": PUBLIC}))
    assert sparkle.public_key_from_plist(plist) == PUBLIC

    plist.write_bytes(plistlib.dumps({}))
    with pytest.raises(RuntimeError, match="missing"):
        sparkle.public_key_from_plist(plist)


def release(directory: Path) -> tuple[Path, Path, Path]:
    """Write a signed archive, one delta, and the appcast that lists both."""
    update = directory / UPDATE
    update.write_bytes(b"full archive")
    (directory / DELTA).write_bytes(b"delta")
    feed = (
        '<rss xmlns:sparkle="s"><channel><item>'
        f'<enclosure url="https://h/v42/{UPDATE}" '
        f'sparkle:edSignature="{signature(b"full archive")}" />'
        "<sparkle:deltas>"
        f'<enclosure url="https://h/v42/{DELTA}" sparkle:deltaFrom="41" '
        f'sparkle:edSignature="{signature(b"delta")}" />'
        "</sparkle:deltas></item></channel></rss>\n"
    )
    appcast = directory / "appcast.xml"
    appcast.write_text(f"{feed}{MARKER}edSignature: {signature(feed.encode())}\n-->\n")
    return script(directory / "sign_update", FAKE_SIGN_UPDATE), appcast, update


def test_verifies_feed_archive_and_deltas(tmp_path: Path) -> None:
    sign_update, appcast, update = release(tmp_path)

    sparkle.verify_release(sign_update, SEED, appcast, update, tmp_path)

    (tmp_path / DELTA).write_bytes(b"tampered")
    with pytest.raises(RuntimeError, match=DELTA):
        sparkle.verify_release(sign_update, SEED, appcast, update, tmp_path)


def test_rejects_wrong_key_or_tampered_feed(tmp_path: Path) -> None:
    sign_update, appcast, update = release(tmp_path)

    with pytest.raises(RuntimeError, match="appcast.xml"):
        sparkle.verify_release(sign_update, "other", appcast, update, tmp_path)
    appcast.write_text(appcast.read_text().replace("v42", "v43", 1))
    with pytest.raises(RuntimeError, match="appcast.xml"):
        sparkle.verify_release(sign_update, SEED, appcast, update, tmp_path)


def test_rejects_missing_archive_enclosure_or_delta_file(tmp_path: Path) -> None:
    sign_update, appcast, update = release(tmp_path)

    with pytest.raises(RuntimeError, match="no enclosure"):
        sparkle.verify_release(
            sign_update, SEED, appcast, tmp_path / "Other.tar.xz", tmp_path
        )
    (tmp_path / DELTA).unlink()
    with pytest.raises(RuntimeError, match="unsigned or has no file"):
        sparkle.verify_release(sign_update, SEED, appcast, update, tmp_path)
