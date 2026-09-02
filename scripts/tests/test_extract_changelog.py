# SPDX-License-Identifier: MPL-2.0

import pytest
from extract_changelog import extract


def test_extracts_only_requested_release_body() -> None:
    changelog = """# Changelog

## [0.2.0] - 2026-08-16

### Added

- Native update prompt.

## [0.1.0]

- Initial release.
"""

    assert extract(changelog, "0.2.0") == "### Added\n\n- Native update prompt."


def test_rejects_missing_version() -> None:
    with pytest.raises(RuntimeError):
        extract("# Changelog\n", "0.2.0")


def test_extracts_undated_section_starting_with_a_list() -> None:
    changelog = "# Changelog\n\n## [0.2.0]\n\n- Release notes.\n"

    assert extract(changelog, "0.2.0") == "- Release notes."
