# SPDX-License-Identifier: MPL-2.0

import plistlib
import tempfile
import unittest
from pathlib import Path

from release_validation import validate_release


class ReleaseValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary_directory.name)
        self.changelog = self.root / "CHANGELOG.md"
        self.info_plist = self.root / "Info.plist"

    def tearDown(self) -> None:
        self.temporary_directory.cleanup()

    def write_metadata(self, *, changelog_version: str, plist_version: str) -> None:
        self.changelog.write_text(
            f"# Changelog\n\n## [{changelog_version}]\n\n- Release notes.\n",
            encoding="utf-8",
        )
        with self.info_plist.open("wb") as file:
            plistlib.dump({"CFBundleShortVersionString": plist_version}, file)

    def test_accepts_matching_release_metadata(self) -> None:
        self.write_metadata(changelog_version="0.2.0", plist_version="0.2.0")

        notes = validate_release("0.2.0", self.changelog, self.info_plist)

        self.assertEqual(notes, "- Release notes.")

    def test_rejects_mismatched_info_plist_version(self) -> None:
        self.write_metadata(changelog_version="0.2.0", plist_version="0.1.0")

        with self.assertRaisesRegex(RuntimeError, "CFBundleShortVersionString"):
            validate_release("0.2.0", self.changelog, self.info_plist)

    def test_rejects_missing_changelog_section(self) -> None:
        self.write_metadata(changelog_version="0.1.0", plist_version="0.2.0")

        with self.assertRaisesRegex(RuntimeError, "does not contain"):
            validate_release("0.2.0", self.changelog, self.info_plist)

    def test_rejects_non_semantic_version(self) -> None:
        self.write_metadata(changelog_version="0.2.0", plist_version="0.2.0")

        with self.assertRaisesRegex(RuntimeError, "X.Y.Z"):
            validate_release("v0.2.0", self.changelog, self.info_plist)


if __name__ == "__main__":
    unittest.main()
