#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Validate the Sparkle Ed25519 public/private key pair without exposing secrets."""

from __future__ import annotations

import argparse
import base64
import binascii
import hmac
import os
import plistlib
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from lib.common import fail, require_command, run_main
from lib.console import success

PUBLIC_KEY_BYTES = 32
PRIVATE_SEED_BYTES = 32
PKCS8_ED25519_PREFIX = bytes.fromhex("302e020100300506032b657004220420")
SPKI_ED25519_PREFIX = bytes.fromhex("302a300506032b6570032100")
SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SPARKLE_FEED_SIGNATURE_PREFIX = b"<!-- sparkle-signatures:\n"
SPARKLE_FEED_SIGNATURE_SUFFIX = b"-->"


def decode_base64(value: str, label: str) -> bytes:
    if any(character.isspace() for character in value):
        fail(f"{label} must not contain whitespace")
    try:
        return base64.b64decode(value, validate=True)
    except (ValueError, binascii.Error) as error:
        fail(f"{label} must be valid base64: {error}")


def derive_public_key(seed: bytes, openssl: str | None = None) -> bytes:
    """Derive an Ed25519 public key from Sparkle's 32-byte seed using OpenSSL."""
    command = [
        openssl or require_command("openssl"),
        "pkey",
        "-inform",
        "DER",
        "-pubout",
        "-outform",
        "DER",
    ]
    try:
        result = subprocess.run(
            command,
            input=PKCS8_ED25519_PREFIX + seed,
            capture_output=True,
            check=True,
        )
    except FileNotFoundError:
        fail("required command not found: openssl")
    except subprocess.CalledProcessError:
        fail("OpenSSL could not derive the Sparkle Ed25519 public key")

    public_key = result.stdout
    if not public_key.startswith(SPKI_ED25519_PREFIX):
        fail("OpenSSL returned an unexpected Ed25519 public-key format")
    public_key = public_key[len(SPKI_ED25519_PREFIX) :]
    if len(public_key) != PUBLIC_KEY_BYTES:
        fail("OpenSSL returned an unexpected Ed25519 public-key length")
    return public_key


def public_key_for_secret(secret: bytes, openssl: str | None = None) -> bytes:
    if len(secret) == PRIVATE_SEED_BYTES:
        return derive_public_key(secret, openssl)
    fail("SPARKLE_ED25519_PRIVATE_KEY must decode to exactly 32 bytes")


def validate_keys(
    public_key: str, private_key: str, openssl: str | None = None
) -> None:
    expected = decode_base64(public_key, "SUPublicEDKey")
    if len(expected) != PUBLIC_KEY_BYTES:
        fail("SUPublicEDKey must decode to 32 bytes")
    secret = decode_base64(private_key, "SPARKLE_ED25519_PRIVATE_KEY")
    derived = public_key_for_secret(secret, openssl)
    if not hmac.compare_digest(expected, derived):
        fail("Sparkle public and private keys do not match")


def public_key_from_plist(path: Path) -> str:
    try:
        with path.open("rb") as file:
            metadata = plistlib.load(file)
    except (OSError, plistlib.InvalidFileException) as error:
        fail(f"could not read Sparkle application Info.plist: {error}")
    public_key = metadata.get("SUPublicEDKey")
    if not isinstance(public_key, str) or not public_key:
        fail("SUPublicEDKey is missing from the application Info.plist")
    return public_key


def validate_feed_signature(data: bytes) -> None:
    """Validate Sparkle 2.9.6's trailing appcast signing comment."""
    prefix_index = data.rfind(SPARKLE_FEED_SIGNATURE_PREFIX)
    if prefix_index < 0:
        fail("generated Sparkle appcast is missing its sparkle-signatures block")
    content_start = prefix_index + len(SPARKLE_FEED_SIGNATURE_PREFIX)
    suffix_index = data.find(SPARKLE_FEED_SIGNATURE_SUFFIX, content_start)
    if suffix_index < 0:
        fail("generated Sparkle appcast has an unterminated sparkle-signatures block")
    try:
        signing_block = data[content_start:suffix_index].decode("utf-8")
    except UnicodeDecodeError as error:
        fail(f"generated Sparkle appcast has invalid signing metadata: {error}")

    fields = {
        key: value.strip()
        for key, separator, value in (
            line.partition(":") for line in signing_block.splitlines()
        )
        if separator
    }
    signature = fields.get("edSignature", "")
    if not signature:
        fail("generated Sparkle appcast has an empty feed Ed25519 signature")
    try:
        decoded_signature = base64.b64decode(signature, validate=True)
    except (ValueError, binascii.Error) as error:
        fail(f"generated Sparkle appcast feed signature must be valid base64: {error}")
    if len(decoded_signature) != 64:
        fail("generated Sparkle appcast feed signature must decode to 64 bytes")
    try:
        content_length = int(fields.get("length", ""))
    except ValueError:
        fail("generated Sparkle appcast signing block has an invalid content length")
    if content_length != prefix_index:
        fail("generated Sparkle appcast signing block has an incorrect content length")


def validate_appcast(path: Path) -> None:
    """Reject generated appcasts without Sparkle feed or enclosure signatures."""
    try:
        data = path.read_bytes()
    except OSError as error:
        fail(f"could not read generated Sparkle appcast: {error}")
    validate_feed_signature(data)
    try:
        root = ET.fromstring(data)
    except ET.ParseError as error:
        fail(f"could not parse generated Sparkle appcast: {error}")

    enclosures = [
        element
        for element in root.iter()
        if isinstance(element.tag, str)
        and element.tag.rsplit("}", 1)[-1] == "enclosure"
    ]
    if not enclosures:
        fail("generated Sparkle appcast contains no update enclosures")
    signature_attribute = f"{{{SPARKLE_NAMESPACE}}}edSignature"
    if any(
        not enclosure.get(signature_attribute, "").strip() for enclosure in enclosures
    ):
        fail("every Sparkle appcast enclosure must contain an Ed25519 signature")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--plist",
        type=Path,
        required=True,
        help="application Info.plist containing the tracked Sparkle public key",
    )
    parser.add_argument(
        "--appcast",
        type=Path,
        help="also require every generated appcast enclosure to be signed",
    )
    arguments = parser.parse_args()
    public_key = public_key_from_plist(arguments.plist)
    private_key = os.environ.get("SPARKLE_ED25519_PRIVATE_KEY", "")
    if not private_key:
        fail("SPARKLE_ED25519_PRIVATE_KEY is required")
    validate_keys(public_key, private_key)
    if arguments.appcast:
        validate_appcast(arguments.appcast)
    success("Sparkle Ed25519 key pair validated")


if __name__ == "__main__":
    run_main(main)
