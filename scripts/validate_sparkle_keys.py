#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Check the Sparkle signing key against the app and verify the signed release files.

The private key must derive the `SUPublicEDKey` that ships in the app. Sparkle's
own `sign_update --verify` then checks the archive, every delta, and the appcast
feed, so this script never parses signatures itself.
"""

from __future__ import annotations

import argparse
import base64
import binascii
import hmac
import os
import plistlib
import re
import subprocess
from pathlib import Path
from urllib.parse import unquote, urlparse

from lib.common import fail, run_main
from lib.console import success

KEY_BYTES = 32
PKCS8_ED25519_PREFIX = bytes.fromhex("302e020100300506032b657004220420")
SPKI_ED25519_PREFIX = bytes.fromhex("302a300506032b6570032100")
OPENSSL_GUIDANCE = (
    "deriving the Sparkle public key needs OpenSSL 3 or newer; on macOS run "
    "`brew install openssl@3` and put its bin directory first in PATH"
)


def decode_key(value: str, label: str) -> bytes:
    try:
        key = base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as error:
        fail(f"{label} must be valid base64: {error}")
    if len(key) != KEY_BYTES:
        fail(f"{label} must decode to exactly {KEY_BYTES} bytes")
    return key


def derive_public_key(seed: bytes, openssl: str = "openssl") -> bytes:
    """Derive the Ed25519 public key from Sparkle's 32-byte seed."""
    try:
        result = subprocess.run(
            [openssl, "pkey", "-inform", "DER", "-pubout", "-outform", "DER"],
            input=PKCS8_ED25519_PREFIX + seed,
            capture_output=True,
            check=True,
        )
    except OSError, subprocess.CalledProcessError:
        fail(OPENSSL_GUIDANCE)
    if not result.stdout.startswith(SPKI_ED25519_PREFIX):
        fail("OpenSSL returned an unexpected Ed25519 public-key format")
    return result.stdout.removeprefix(SPKI_ED25519_PREFIX)


def validate_keys(public_key: str, private_key: str, openssl: str = "openssl") -> None:
    expected = decode_key(public_key, "SUPublicEDKey")
    seed = decode_key(private_key, "SPARKLE_ED25519_PRIVATE_KEY")
    if not hmac.compare_digest(expected, derive_public_key(seed, openssl)):
        fail("Sparkle public and private keys do not match")


def public_key_from_plist(path: Path) -> str:
    try:
        with path.open("rb") as file:
            public_key = plistlib.load(file).get("SUPublicEDKey")
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"could not read Sparkle application Info.plist: {error}")
    if not isinstance(public_key, str) or not public_key:
        fail("SUPublicEDKey is missing from the application Info.plist")
    return public_key


def appcast_enclosures(appcast: str) -> list[tuple[str, str]]:
    """Return `(file name, edSignature)` for every enclosure, deltas included."""
    enclosures = []
    for tag in re.findall(r"<enclosure\b[^>]*>", appcast):
        attributes = dict(re.findall(r'([\w:]+)="([^"]*)"', tag))
        name = Path(unquote(urlparse(attributes.get("url", "")).path)).name
        enclosures.append((name, attributes.get("sparkle:edSignature", "")))
    return enclosures


def verify(
    sign_update: Path, private_key: str, path: Path, signature: str | None = None
) -> None:
    """Run `sign_update --verify`; the feed carries its own signature."""
    command = [sign_update, "--verify", "--ed-key-file", "-", path]
    if signature is not None:
        command.append(signature)
    result = subprocess.run(
        command, input=private_key.encode(), capture_output=True, check=False
    )
    if result.returncode != 0:
        detail = (result.stdout + result.stderr).decode(errors="replace").strip()
        fail(f"Sparkle signature check failed for {path.name}: {detail}")


def verify_release(
    sign_update: Path,
    private_key: str,
    appcast: Path,
    update_file: Path,
    delta_directory: Path,
) -> None:
    """Verify the feed, then each enclosure against the archive or delta it names."""
    verify(sign_update, private_key, appcast)
    enclosures = appcast_enclosures(appcast.read_text(encoding="utf-8"))
    if not any(name == update_file.name for name, _ in enclosures):
        fail(f"Sparkle appcast has no enclosure for {update_file.name!r}")
    for name, signature in enclosures:
        path = update_file if name == update_file.name else delta_directory / name
        if not signature or not path.is_file():
            fail(f"Sparkle appcast enclosure {name!r} is unsigned or has no file")
        verify(sign_update, private_key, path, signature)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plist", type=Path, required=True)
    parser.add_argument("--sign-update", type=Path, help="Sparkle sign_update path")
    parser.add_argument("--appcast", type=Path)
    parser.add_argument("--update-file", type=Path)
    parser.add_argument("--delta-directory", type=Path)
    arguments = parser.parse_args()
    private_key = os.environ.get("SPARKLE_ED25519_PRIVATE_KEY", "")
    if not private_key:
        fail("SPARKLE_ED25519_PRIVATE_KEY is required")
    validate_keys(public_key_from_plist(arguments.plist), private_key)
    if arguments.appcast:
        if not (
            arguments.sign_update
            and arguments.update_file
            and arguments.delta_directory
        ):
            fail("--appcast needs --sign-update, --update-file, and --delta-directory")
        verify_release(
            arguments.sign_update,
            private_key,
            arguments.appcast,
            arguments.update_file,
            arguments.delta_directory,
        )
    success("Sparkle signing key and release signatures validated")


if __name__ == "__main__":
    run_main(main)
