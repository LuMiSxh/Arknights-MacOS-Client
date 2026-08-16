# SPDX-License-Identifier: MPL-2.0

import unittest

from extract_changelog import extract


class ExtractChangelogTests(unittest.TestCase):
    def test_extracts_only_requested_release_body(self) -> None:
        changelog = """# Changelog

## [0.2.0] - 2026-08-16

### Added

- Native update prompt.

## [0.1.0]

- Initial release.
"""

        self.assertEqual(
            extract(changelog, "0.2.0"),
            "### Added\n\n- Native update prompt.",
        )

    def test_rejects_missing_version(self) -> None:
        with self.assertRaises(RuntimeError):
            extract("# Changelog\n", "0.2.0")


if __name__ == "__main__":
    unittest.main()
