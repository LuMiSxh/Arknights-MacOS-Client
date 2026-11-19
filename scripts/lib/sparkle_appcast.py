# SPDX-License-Identifier: MPL-2.0

"""Read and annotate the Sparkle appcast that the release workflow publishes."""

import re
import xml.etree.ElementTree as ET
from pathlib import Path

from lib.common import fail

SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
SPARKLE_VERSION_TAG = f"{{{SPARKLE_NAMESPACE}}}version"
INFORMATIONAL_UPDATE_TAG = f"{{{SPARKLE_NAMESPACE}}}informationalUpdate"
BELOW_VERSION_TAG = f"{{{SPARKLE_NAMESPACE}}}belowVersion"
DELTAS_TAG = f"{{{SPARKLE_NAMESPACE}}}deltas"
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


def newest_item(root: ET.Element) -> ET.Element:
    """Return the item with the highest `sparkle:version`."""
    items = root.findall("./channel/item")
    if not items:
        fail("Sparkle appcast has no item")
    return max(items, key=item_build_version)


def annotate_update_gate(root: ET.Element, minimum_build: int, info_link: str) -> None:
    """Make the newest item informational for clients below `minimum_build`."""
    item = newest_item(root)
    for existing in item.findall(INFORMATIONAL_UPDATE_TAG):
        item.remove(existing)
    informational = ET.SubElement(item, INFORMATIONAL_UPDATE_TAG)
    ET.SubElement(informational, BELOW_VERSION_TAG).text = str(minimum_build)
    link = item.find("link")
    if link is None:
        link = ET.SubElement(item, "link")
    link.text = info_link


def serialize(root: ET.Element) -> bytes:
    """Serialize the feed without a stale trailing signature block."""
    return (XML_DECLARATION + ET.tostring(root, encoding="unicode") + "\n").encode()


def validate_update_gate(root: ET.Element, minimum_build: int) -> None:
    """Fail when the newest item lacks the informational gate or its link."""
    item = newest_item(root)
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
            "the newest Sparkle item must set informationalUpdate "
            f"belowVersion {minimum_build}"
        )
    link = item.find("link")
    if link is None or not (link.text or "").strip():
        fail("the newest Sparkle informational item needs an info link")


def validate_appcast_gate(path: Path, minimum_build: int) -> None:
    """Validate the on-disk feed that the release publishes."""
    try:
        content = path.read_text(encoding="utf-8")
    except OSError as error:
        fail(f"could not read the Sparkle appcast: {error}")
    validate_update_gate(parse(content, "release"), minimum_build)
