# SPDX-License-Identifier: MPL-2.0

"""Read, edit, sign, and verify the Sparkle appcast that the release workflow publishes."""

import copy
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

from lib.common import fail

SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SPARKLE_VERSION_TAG = f"{{{SPARKLE_NAMESPACE}}}version"
INFORMATIONAL_UPDATE_TAG = f"{{{SPARKLE_NAMESPACE}}}informationalUpdate"
CRITICAL_UPDATE_TAG = f"{{{SPARKLE_NAMESPACE}}}criticalUpdate"
BELOW_VERSION_TAG = f"{{{SPARKLE_NAMESPACE}}}belowVersion"
DELTAS_TAG = f"{{{SPARKLE_NAMESPACE}}}deltas"
CHANNEL_TAG = f"{{{SPARKLE_NAMESPACE}}}channel"
ED_SIGNATURE_ATTRIBUTE = f"{{{SPARKLE_NAMESPACE}}}edSignature"
CANARY_CHANNEL = "canary"
XML_DECLARATION = '<?xml version="1.0" standalone="yes"?>\n'

ET.register_namespace("sparkle", SPARKLE_NAMESPACE)


def parse(content: str | bytes, label: str) -> ET.Element:
    """Parse an appcast feed."""
    try:
        return ET.fromstring(content)
    except ET.ParseError as error:
        fail(f"could not parse the {label} Sparkle appcast: {error}")


def item_build_version(item: ET.Element) -> int:
    """Return the numeric build that Sparkle orders an item by."""
    version = item.findtext(SPARKLE_VERSION_TAG)
    if version is None:
        enclosure = item.find("enclosure")
        version = enclosure.get(SPARKLE_VERSION_TAG) if enclosure is not None else None
    text = (version or "").strip()
    if re.fullmatch(r"[0-9]+", text) is None:
        fail(f"Sparkle appcast item has a non-numeric sparkle:version {text!r}")
    return int(text)


def item_channel(item: ET.Element) -> str | None:
    """Return the item's Sparkle channel; `None` is the stable channel."""
    return (item.findtext(CHANNEL_TAG) or "").strip() or None


def newest_item(root: ET.Element, channel: str | None) -> ET.Element:
    """Return the item with the highest `sparkle:version` in `channel`."""
    items = [
        item for item in root.findall("./channel/item") if item_channel(item) == channel
    ]
    if not items:
        fail(f"Sparkle appcast has no item in the {channel or 'stable'} channel")
    return max(items, key=item_build_version)


def new_item(root: ET.Element, build: int) -> ET.Element:
    """Return the item of `build`, which must be the newest of its own channel.

    A release edits and verifies only this item. Older items keep the bytes and
    enclosure signatures they were published with.
    """
    matches = [
        item
        for item in root.findall("./channel/item")
        if item_build_version(item) == build
    ]
    if len(matches) != 1:
        fail(f"Sparkle appcast must list build {build} exactly once")
    item = matches[0]
    channel = item_channel(item)
    if newest_item(root, channel) is not item:
        fail(f"build {build} is not the newest in the {channel or 'stable'} channel")
    return item


def item_for_tag(root: ET.Element, tag: str) -> ET.Element:
    """Return the item whose archive is a download of the release `tag`."""
    marker = f"/releases/download/{tag}/"
    for item in root.findall("./channel/item"):
        enclosure = item.find("enclosure")
        if enclosure is not None and marker in enclosure.get("url", ""):
            return item
    fail(f"Sparkle appcast has no item for release {tag}")


def promote_to_stable(root: ET.Element, tag: str) -> int:
    """Move the canary item of release `tag` to the stable channel; return its build.

    The enclosure and its signature stay as they are. The item must be, or become,
    the newest stable one, so promotion never offers a downgrade. An item that is
    already the newest stable one stays as it is, which makes a rerun safe.
    """
    item = item_for_tag(root, tag)
    channel = item_channel(item)
    if channel not in (None, CANARY_CHANNEL):
        fail(f"the appcast item of {tag} is in the unknown {channel!r} channel")
    for element in item.findall(CHANNEL_TAG):
        item.remove(element)
    build = item_build_version(item)
    new_item(root, build)
    return build


def merge_new_item(
    canonical: ET.Element | None, generated: ET.Element, build: int
) -> ET.Element:
    """Return the canonical feed with the generated item of `build` appended.

    Existing items are never rewritten, and the feed never shrinks. Without a
    canonical feed, the generated one is the result.
    """
    item = new_item(generated, build)
    if canonical is None:
        return generated
    channel = canonical.find("channel")
    if channel is None:
        fail("canonical Sparkle appcast has no channel element")
    if any(item_build_version(other) == build for other in channel.findall("item")):
        fail(f"canonical Sparkle appcast already lists build {build}")
    channel.append(item)
    new_item(canonical, build)
    return canonical


def _item_form(item: ET.Element) -> bytes:
    """Serialize an item without the whitespace that follows it in its feed."""
    detached = copy.deepcopy(item)
    detached.tail = None
    return ET.tostring(detached)


def check_items_preserved(canonical: ET.Element, final: ET.Element) -> None:
    """Fail unless every canonical item is in `final` with identical content."""
    final_forms = {
        item_build_version(item): _item_form(item)
        for item in final.findall("./channel/item")
    }
    for item in canonical.findall("./channel/item"):
        build = item_build_version(item)
        if final_forms.get(build) != _item_form(item):
            fail(
                f"canonical Sparkle item {build} is missing or changed in the new feed"
            )


def keep_stable_items(root: ET.Element) -> None:
    """Drop every channel item, leaving the feed that launchers 1.0.2 and older read."""
    channel = root.find("channel")
    if channel is None:
        fail("Sparkle appcast has no channel element")
    for item in channel.findall("item"):
        if item_channel(item) is not None:
            channel.remove(item)
    if channel.find("item") is None:
        fail("Sparkle appcast has no stable item")


def annotate_update_gate(
    root: ET.Element, build: int, minimum_build: int, info_link: str
) -> None:
    """Make item `build` informational for clients below `minimum_build`."""
    item = new_item(root, build)
    for existing in item.findall(INFORMATIONAL_UPDATE_TAG):
        item.remove(existing)
    informational = ET.SubElement(item, INFORMATIONAL_UPDATE_TAG)
    ET.SubElement(informational, BELOW_VERSION_TAG).text = str(minimum_build)
    link = item.find("link")
    if link is None:
        link = ET.SubElement(item, "link")
    link.text = info_link


def annotate_critical_update(root: ET.Element, build: int) -> None:
    """Make item `build` critical, so Sparkle offers no way to postpone it."""
    item = new_item(root, build)
    if item.find(CRITICAL_UPDATE_TAG) is None:
        ET.SubElement(item, CRITICAL_UPDATE_TAG)


def serialize(root: ET.Element) -> bytes:
    """Serialize the feed without a stale trailing signature block."""
    return (XML_DECLARATION + ET.tostring(root, encoding="unicode") + "\n").encode()


def validate_update_gate(root: ET.Element, build: int, minimum_build: int) -> None:
    """Fail when item `build` lacks the informational gate or its link."""
    item = new_item(root, build)
    informational = item.find(INFORMATIONAL_UPDATE_TAG)
    below_versions = (
        []
        if informational is None
        else [
            (child.text or "").strip()
            for child in informational.findall(BELOW_VERSION_TAG)
        ]
    )
    if str(minimum_build) not in below_versions:
        fail(
            f"Sparkle item {build} must set informationalUpdate "
            f"belowVersion {minimum_build}"
        )
    link = item.find("link")
    if link is None or not (link.text or "").strip():
        fail(f"Sparkle informational item {build} needs an info link")


def validate_appcast_gate(path: Path, build: int, minimum_build: int) -> None:
    """Validate the gate of item `build` in the on-disk feed that the release publishes."""
    try:
        content = path.read_text(encoding="utf-8")
    except OSError as error:
        fail(f"could not read the Sparkle appcast: {error}")
    validate_update_gate(parse(content, "release"), build, minimum_build)


def sign_appcast(sign_update: Path, private_key: str, appcast: Path) -> None:
    """Replace the feed's signature block with `sign_update`.

    `sign_update` strips the old trailing block itself. The key goes through
    standard input so it never appears in arguments.
    """
    result = subprocess.run(
        [sign_update, "--ed-key-file", "-", "--disable-signing-warning", appcast],
        input=private_key.encode(),
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        fail(
            "sign_update could not sign the Sparkle appcast: "
            + result.stdout.decode(errors="replace").strip()
        )


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
