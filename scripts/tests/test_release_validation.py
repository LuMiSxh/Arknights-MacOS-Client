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


def test_rejects_mismatched_info_plist_version(changelog: Path) -> None:
    write_metadata(changelog, changelog_version="0.2.0")

    with pytest.raises(RuntimeError, match="CFBundleShortVersionString"):
        validate_release("0.2.0", changelog, "0.1.0")


def test_rejects_missing_changelog_section(changelog: Path) -> None:
    write_metadata(changelog, changelog_version="0.1.0")

    with pytest.raises(RuntimeError, match="does not contain"):
        validate_release("0.2.0", changelog, "0.2.0")


def test_rejects_non_semantic_version(changelog: Path) -> None:
    write_metadata(changelog, changelog_version="0.2.0")

    with pytest.raises(RuntimeError, match="X.Y.Z"):
        validate_release("v0.2.0", changelog, "0.2.0")
