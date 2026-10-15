# SPDX-License-Identifier: MPL-2.0

from pathlib import Path

import pytest
from release import extract, validate_release


@pytest.mark.parametrize(
    ("changelog", "expected"),
    [
        (
            """# Changelog

## [0.2.0] - 2026-08-16

### Added

- Native update prompt.

## [0.1.0]

- Initial release.
""",
            "### Added\n\n- Native update prompt.",
        ),
        (
            "# Changelog\n\n## [0.2.0]\n\n- Release notes.\n",
            "- Release notes.",
        ),
    ],
    ids=["dated-release", "undated-list-section"],
)
def test_extracts_requested_release_body(changelog: str, expected: str) -> None:
    assert extract(changelog, "0.2.0") == expected


def test_rejects_missing_version() -> None:
    with pytest.raises(RuntimeError):
        extract("# Changelog\n", "0.2.0")


def write_changelog(path: Path, version: str) -> Path:
    path.write_text(
        f"# Changelog\n\n## [{version}]\n\n- Release notes.\n", encoding="utf-8"
    )
    return path


def test_accepts_matching_release_metadata(tmp_path: Path) -> None:
    changelog = write_changelog(tmp_path / "CHANGELOG.md", "0.2.0")

    assert validate_release("0.2.0", changelog, "0.2.0") == "- Release notes."


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
    tmp_path: Path,
    release_version: str,
    changelog_version: str,
    plist_version: str,
    message: str,
) -> None:
    changelog = write_changelog(tmp_path / "CHANGELOG.md", changelog_version)

    with pytest.raises(RuntimeError, match=message):
        validate_release(release_version, changelog, plist_version)
