# SPDX-License-Identifier: MPL-2.0

import hashlib
import stat
import sys
from pathlib import Path

import appcast
import pytest
from lib import sparkle_appcast

KEY = "THROWAWAY-SEED"
NAMESPACE = sparkle_appcast.SPARKLE_NAMESPACE
MARKER = "<!-- sparkle-signatures:\n"

# Stands in for Sparkle's `sign_update`: a "signature" is sha256(key + feed text).
FAKE_SIGN_UPDATE = f"""#!{sys.executable}
import hashlib, sys
marker = {MARKER!r}
key = sys.stdin.read()
path = sys.argv[-1]
content = open(path).read()
text, _, tail = content.partition(marker)
digest = hashlib.sha256(key.encode() + text.encode()).hexdigest()
if "--verify" in sys.argv:
    sys.exit(0 if tail.split("edSignature: ")[1].split()[0] == digest else 1)
open(path, "w").write(text + marker + "edSignature: " + digest + "\\n-->\\n")
"""


def item(build: int, tag: str, channel: str | None) -> str:
    return (
        f"<item><sparkle:version>{build}</sparkle:version>"
        + (f"<sparkle:channel>{channel}</sparkle:channel>" if channel else "")
        + "<sparkle:informationalUpdate><sparkle:belowVersion>18</sparkle:belowVersion>"
        "</sparkle:informationalUpdate><link>https://example.com/info</link>"
        f'<enclosure url="https://h/releases/download/{tag}/App.tar.xz" '
        f'sparkle:edSignature="sig{build}" /></item>'
    )


def feed(*items: str) -> str:
    return f'<rss xmlns:sparkle="{NAMESPACE}"><channel>{"".join(items)}</channel></rss>'


CANONICAL = feed(
    item(28, "v1.0.2", None),
    item(30, "v1.0.3-rc.1", "canary"),
    item(31, "v1.0.3-rc.2", "canary"),
)


@pytest.fixture
def sign_update(tmp_path: Path) -> Path:
    path = tmp_path / "sign_update"
    path.write_text(FAKE_SIGN_UPDATE)
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


def run(monkeypatch: pytest.MonkeyPatch, *arguments: object) -> None:
    monkeypatch.setattr(sys, "argv", ["appcast.py", *map(str, arguments)])
    appcast.main()


def channels(path: Path) -> dict[int, str | None]:
    root = sparkle_appcast.parse(path.read_text(), "test")
    return {
        sparkle_appcast.item_build_version(entry): sparkle_appcast.item_channel(entry)
        for entry in root.findall("./channel/item")
    }


def assert_signed_with_the_key(path: Path) -> None:
    text, _, tail = path.read_text().partition(MARKER)
    expected = hashlib.sha256((KEY + text).encode()).hexdigest()
    assert tail.split("edSignature: ")[1].split()[0] == expected


def test_promote_signs_a_feed_with_only_the_tagged_item_changed(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, sign_update: Path
) -> None:
    monkeypatch.setenv("SPARKLE_ED25519_PRIVATE_KEY", KEY)
    source = tmp_path / "canonical.xml"
    source.write_text(CANONICAL)
    promoted = tmp_path / "promoted.xml"

    run(
        monkeypatch,
        *("promote", "--appcast", source, "--output", promoted),
        *("--sign-update", sign_update, "--tag", "v1.0.3-rc.2"),
    )

    assert channels(promoted) == {28: None, 30: "canary", 31: None}
    assert_signed_with_the_key(promoted)
    again = tmp_path / "again.xml"
    run(
        monkeypatch,
        *("promote", "--appcast", promoted, "--output", again),
        *("--sign-update", sign_update, "--tag", "v1.0.3-rc.2"),
    )
    assert channels(again) == {28: None, 30: "canary", 31: None}


def test_legacy_signs_a_feed_with_only_stable_items(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, sign_update: Path
) -> None:
    monkeypatch.setenv("SPARKLE_ED25519_PRIVATE_KEY", KEY)
    source = tmp_path / "canonical.xml"
    source.write_text(CANONICAL)
    legacy = tmp_path / "legacy.xml"

    run(
        monkeypatch,
        *("legacy", "--appcast", source, "--output", legacy),
        *("--sign-update", sign_update),
    )

    assert channels(legacy) == {28: None}
    assert_signed_with_the_key(legacy)


def test_signing_commands_require_the_key(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, sign_update: Path
) -> None:
    monkeypatch.delenv("SPARKLE_ED25519_PRIVATE_KEY", raising=False)
    source = tmp_path / "canonical.xml"
    source.write_text(CANONICAL)

    with pytest.raises(RuntimeError, match="PRIVATE_KEY is required"):
        run(
            monkeypatch,
            *("legacy", "--appcast", source, "--output", tmp_path / "out.xml"),
            *("--sign-update", sign_update),
        )


def test_merge_then_check_detects_a_rewritten_canonical_item(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    canonical = tmp_path / "canonical.xml"
    canonical.write_text(CANONICAL)
    generated = tmp_path / "generated.xml"
    generated.write_text(feed(item(32, "v1.0.4", None)))
    merged = tmp_path / "merged.xml"

    run(
        monkeypatch,
        *("merge", "--canonical", canonical, "--generated", generated),
        *("--output", merged, "--build", 32),
    )

    assert channels(merged) == {28: None, 30: "canary", 31: "canary", 32: None}
    run(monkeypatch, "check-preserved", "--canonical", canonical, "--appcast", merged)
    merged.write_text(merged.read_text().replace("sig30", "forged", 1))
    with pytest.raises(RuntimeError, match="canonical Sparkle item 30"):
        run(
            monkeypatch,
            *("check-preserved", "--canonical", canonical, "--appcast", merged),
        )


def test_check_preserved_detects_a_dropped_canonical_item(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    canonical = tmp_path / "canonical.xml"
    canonical.write_text(CANONICAL)
    shrunk = tmp_path / "shrunk.xml"
    shrunk.write_text(feed(item(28, "v1.0.2", None), item(32, "v1.0.4", None)))

    with pytest.raises(RuntimeError, match="canonical Sparkle item 30"):
        run(
            monkeypatch,
            *("check-preserved", "--canonical", canonical, "--appcast", shrunk),
        )
