# SPDX-License-Identifier: MPL-2.0

from pathlib import Path

import pytest
from release_validation import validate_release


@pytest.fixture
def changelog(tmp_path: Path) -> Path:
    return tmp_path / "CHANGELOG.md"


def write_metadata(changelog: Path, *, changelog_version: str) -> None:
    changelog.write_text(
        f"# Changelog\n\n## [{changelog_version}]\n\n- Release notes.\n",
        encoding="utf-8",
    )


def test_accepts_matching_release_metadata(changelog: Path) -> None:
    write_metadata(changelog, changelog_version="0.2.0")

    notes = validate_release("0.2.0", changelog, "0.2.0")

    assert notes == "- Release notes."


@pytest.mark.parametrize(
    ("release_version", "changelog_version", "plist_version", "message"),
    [
        ("0.2.0", "0.2.0", "0.1.0", "CFBundleShortVersionString"),
        ("0.2.0", "0.1.0", "0.2.0", "does not contain"),
        ("v0.2.0", "0.2.0", "0.2.0", "X.Y.Z"),
    ],
    ids=("plist-version", "missing-changelog-section", "version-format"),
)
def test_rejects_invalid_release_metadata(
    changelog: Path,
    release_version: str,
    changelog_version: str,
    plist_version: str,
    message: str,
) -> None:
    write_metadata(changelog, changelog_version=changelog_version)

    with pytest.raises(RuntimeError, match=message):
        validate_release(release_version, changelog, plist_version)
