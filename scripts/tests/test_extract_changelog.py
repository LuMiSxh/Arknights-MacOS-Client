# SPDX-License-Identifier: MPL-2.0

import pytest
from extract_changelog import extract


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
