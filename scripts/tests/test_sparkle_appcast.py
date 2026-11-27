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

    sparkle_appcast.annotate_update_gate(root, 30, 18, INFO_LINK)

    oldest, newest = root.findall("./channel/item")
    assert newest.findtext(sparkle_appcast.SPARKLE_VERSION_TAG) == "30"
    assert below_versions(newest) == ["18"]
    assert newest.findtext("link") == INFO_LINK
    assert oldest.find(sparkle_appcast.INFORMATIONAL_UPDATE_TAG) is None
    assert oldest.find("link") is None


def test_replaces_an_existing_gate_and_link() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    sparkle_appcast.annotate_update_gate(root, 30, 18, INFO_LINK)

    sparkle_appcast.annotate_update_gate(root, 30, 20, "https://example.com/other")

    newest = sparkle_appcast.newest_item(root, None)
    assert len(newest.findall(sparkle_appcast.INFORMATIONAL_UPDATE_TAG)) == 1
    assert below_versions(newest) == ["20"]
    assert newest.findtext("link") == "https://example.com/other"


def test_validation_requires_the_gate_and_a_link() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    with pytest.raises(RuntimeError, match="informationalUpdate"):
        sparkle_appcast.validate_update_gate(root, 30, 18)

    sparkle_appcast.annotate_update_gate(root, 30, 18, INFO_LINK)
    sparkle_appcast.validate_update_gate(root, 30, 18)

    link = sparkle_appcast.newest_item(root, None).find("link")
    assert link is not None
    link.text = " "
    with pytest.raises(RuntimeError, match="info link"):
        sparkle_appcast.validate_update_gate(root, 30, 18)


def test_validation_rejects_a_different_below_version() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    sparkle_appcast.annotate_update_gate(root, 30, 17, INFO_LINK)

    with pytest.raises(RuntimeError, match="belowVersion 18"):
        sparkle_appcast.validate_update_gate(root, 30, 18)


def test_serialize_round_trips_the_gate() -> None:
    root = sparkle_appcast.parse(appcast(), "test")
    sparkle_appcast.annotate_update_gate(root, 30, 18, INFO_LINK)

    text = sparkle_appcast.serialize(root).decode()

    assert text.startswith('<?xml version="1.0" standalone="yes"?>')
    assert "<sparkle:belowVersion>18</sparkle:belowVersion>" in text
    sparkle_appcast.validate_update_gate(sparkle_appcast.parse(text, "test"), 30, 18)


def test_critical_marks_only_the_newest_item() -> None:
    root = sparkle_appcast.parse(appcast(), "test")

    sparkle_appcast.annotate_critical_update(root, 30)

    assert sparkle_appcast.serialize(root).decode() == (
        '<?xml version="1.0" standalone="yes"?>\n'
        '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">\n'
        "  <channel>\n"
        "    <item>\n"
        "      <title>0.5.2</title>\n"
        "      <sparkle:version>16</sparkle:version>\n"
        '      <enclosure url="https://example.com/old.tar.xz" />\n'
        "    </item>\n"
        "    <item>\n"
        "      <title>0.8.0</title>\n"
        "      <sparkle:version>30</sparkle:version>\n"
        '      <enclosure url="https://example.com/new.tar.xz" />\n'
        "    <sparkle:criticalUpdate /></item>\n"
        "  </channel>\n"
        "</rss>\n"
    )


def test_file_validation_rejects_a_feed_without_the_gate(tmp_path: Path) -> None:
    appcast_path = tmp_path / "appcast.xml"
    appcast_path.write_text(appcast())

    with pytest.raises(RuntimeError, match="informationalUpdate"):
        sparkle_appcast.validate_appcast_gate(appcast_path, 30, 18)


def canonical_feed() -> str:
    """Stable 28, a published canary 30, and the new canary 31 on top."""

    def item(build: int, tag: str, channel: bool) -> str:
        return (
            f"<item><sparkle:version>{build}</sparkle:version>"
            + ("<sparkle:channel>canary</sparkle:channel>" if channel else "")
            + f'<enclosure url="https://h/releases/download/{tag}/App.tar.xz" '
            f'sparkle:edSignature="sig{build}" /></item>'
        )

    return (
        f'<rss xmlns:sparkle="{NAMESPACE}"><channel>'
        + item(28, "v1.0.2", False)
        + item(30, "v1.0.3-rc.1", True)
        + item(31, "v1.0.3-rc.2", True)
        + "</channel></rss>"
    )


def test_gate_and_critical_apply_to_the_new_item_of_its_channel() -> None:
    root = sparkle_appcast.parse(canonical_feed(), "test")

    sparkle_appcast.annotate_update_gate(root, 31, 18, INFO_LINK)
    sparkle_appcast.annotate_critical_update(root, 31)

    gated = [
        sparkle_appcast.item_build_version(item)
        for item in root.findall("./channel/item")
        if item.find(sparkle_appcast.INFORMATIONAL_UPDATE_TAG) is not None
        or item.find(sparkle_appcast.CRITICAL_UPDATE_TAG) is not None
    ]
    assert gated == [31]
    # Stable 28 is still the newest stable item although canary 31 is newer overall.
    sparkle_appcast.annotate_critical_update(root, 28)
    with pytest.raises(RuntimeError, match="not the newest in the canary channel"):
        sparkle_appcast.annotate_update_gate(root, 30, 18, INFO_LINK)
    with pytest.raises(RuntimeError, match="exactly once"):
        sparkle_appcast.annotate_critical_update(root, 99)


def test_promote_moves_only_the_tagged_canary_item_to_stable() -> None:
    root = sparkle_appcast.parse(canonical_feed(), "test")

    build = sparkle_appcast.promote_to_stable(root, "v1.0.3-rc.2")

    assert build == 31
    channels = {
        sparkle_appcast.item_build_version(item): sparkle_appcast.item_channel(item)
        for item in root.findall("./channel/item")
    }
    assert channels == {28: None, 30: "canary", 31: None}
    promoted = sparkle_appcast.item_for_tag(root, "v1.0.3-rc.2")
    enclosure = promoted.find("enclosure")
    assert enclosure is not None
    assert enclosure.get(sparkle_appcast.ED_SIGNATURE_ATTRIBUTE) == "sig31"


@pytest.mark.parametrize(
    ("tag", "message"),
    [
        ("v1.0.2", "not the newest in the stable channel"),
        ("v1.0.3-rc.1", "not the newest in the stable channel"),
        ("v9.9.9", "no item for release v9.9.9"),
    ],
    ids=("older-stable", "older-canary", "unknown-tag"),
)
def test_promote_rejects_downgrades_and_unknown_tags(tag: str, message: str) -> None:
    root = sparkle_appcast.parse(canonical_feed(), "test")
    sparkle_appcast.promote_to_stable(root, "v1.0.3-rc.2")

    with pytest.raises(RuntimeError, match=message):
        sparkle_appcast.promote_to_stable(root, tag)


def test_legacy_feed_keeps_only_stable_items() -> None:
    root = sparkle_appcast.parse(canonical_feed(), "test")

    sparkle_appcast.keep_stable_items(root)

    assert [
        sparkle_appcast.item_build_version(item)
        for item in root.findall("./channel/item")
    ] == [28]
