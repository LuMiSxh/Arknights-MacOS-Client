# SPDX-License-Identifier: MPL-2.0

from pathlib import Path

import pytest
from lib import sparkle_appcast

NAMESPACE = sparkle_appcast.SPARKLE_NAMESPACE
INFO_LINK = "https://github.com/owner/repo/releases/tag/v0.8.0"


def appcast() -> str:
    return f"""<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="{NAMESPACE}" version="2.0">
  <channel>
    <item>
      <title>0.5.2</title>
      <sparkle:version>16</sparkle:version>
      <enclosure url="https://example.com/old.tar.xz" />
    </item>
    <item>
      <title>0.8.0</title>
      <sparkle:version>30</sparkle:version>
      <enclosure url="https://example.com/new.tar.xz" />
    </item>
  </channel>
</rss>
"""


def below_versions(item) -> list[str]:
    return [
        (child.text or "").strip()
        for child in item.iter(sparkle_appcast.BELOW_VERSION_TAG)
    ]


def test_annotates_only_the_newest_item() -> None:
    root = sparkle_appcast.parse(appcast(), "test")

    sparkle_appcast.annotate_update_gate(root, 18, INFO_LINK)

    oldest, newest = root.findall("./channel/item")
    assert newest.findtext(sparkle_appcast.SPARKLE_VERSION_TAG) == "30"
    assert below_versions(newest) == ["18"]
    assert newest.findtext("link") == INFO_LINK
    assert oldest.find(sparkle_appcast.INFORMATIONAL_UPDATE_TAG) is None
    assert oldest.find("link") is None


def test_replaces_an_existing_gate_and_link() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    sparkle_appcast.annotate_update_gate(root, 18, INFO_LINK)

    sparkle_appcast.annotate_update_gate(root, 20, "https://example.com/other")

    newest = sparkle_appcast.newest_item(root)
    assert len(newest.findall(sparkle_appcast.INFORMATIONAL_UPDATE_TAG)) == 1
    assert below_versions(newest) == ["20"]
    assert newest.findtext("link") == "https://example.com/other"


def test_validation_requires_the_gate_and_a_link() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    with pytest.raises(RuntimeError, match="informationalUpdate"):
        sparkle_appcast.validate_update_gate(root, 18)

    sparkle_appcast.annotate_update_gate(root, 18, INFO_LINK)
    sparkle_appcast.validate_update_gate(root, 18)

    link = sparkle_appcast.newest_item(root).find("link")
    assert link is not None
    link.text = " "
    with pytest.raises(RuntimeError, match="info link"):
        sparkle_appcast.validate_update_gate(root, 18)


def test_validation_rejects_a_different_below_version() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    sparkle_appcast.annotate_update_gate(root, 17, INFO_LINK)

    with pytest.raises(RuntimeError, match="belowVersion 18"):
        sparkle_appcast.validate_update_gate(root, 18)


def test_serialize_round_trips_the_gate() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    sparkle_appcast.annotate_update_gate(root, 18, INFO_LINK)

    text = sparkle_appcast.serialize(root).decode()

    assert text.startswith('<?xml version="1.0" standalone="yes"?>')
    assert "<sparkle:belowVersion>18</sparkle:belowVersion>" in text
    sparkle_appcast.validate_update_gate(sparkle_appcast.parse(text, "test"), 18)


def test_file_validation_rejects_a_feed_without_the_gate(tmp_path: Path) -> None:
    appcast_path = tmp_path / "appcast.xml"
    appcast_path.write_text(appcast())

    with pytest.raises(RuntimeError, match="informationalUpdate"):
        sparkle_appcast.validate_appcast_gate(appcast_path, 18)
