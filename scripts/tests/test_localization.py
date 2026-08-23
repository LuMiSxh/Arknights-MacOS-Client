# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import localization
from lib.common import ScriptError


class LocalizationSynchronizationTests(unittest.TestCase):
    def test_generated_symbols_use_the_packaged_app_resource_bundle(self) -> None:
        generated = (
            "#if SWIFT_PACKAGE\n"
            "private nonisolated let resourceBundle = Foundation.Bundle.module\n"
            "#endif\n"
        )

        result = localization.use_app_resource_bundle(generated)

        self.assertIn("AppResourceBundle.bundle", result)
        self.assertNotIn("Foundation.Bundle.module", result)

    def test_rejects_catalog_keys_without_shipping_translations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            catalog = Path(directory) / "Localizable.xcstrings"
            catalog.write_text(
                json.dumps(
                    {
                        "sourceLanguage": "en",
                        "strings": {
                            "home.settings": {
                                "comment": "Settings button",
                                "localizations": {
                                    "en": {
                                        "stringUnit": {
                                            "state": "translated",
                                            "value": "Settings",
                                        }
                                    }
                                },
                            }
                        },
                    }
                ),
                encoding="utf-8",
            )

            with self.assertRaisesRegex(ScriptError, "missing language: de"):
                localization.validate_catalog(catalog)

    def test_writes_missing_generated_file(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "generated"
            destination = root / "nested/output"
            source.write_text("localized", encoding="utf-8")

            localization.synchronize_file(source, destination, write=True)

            self.assertEqual(destination.read_text(encoding="utf-8"), "localized")

    def test_rejects_stale_generated_file_in_check_mode(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "generated"
            destination = localization.PROJECT_DIR / ".build/test-stale-localization"
            source.write_text("new", encoding="utf-8")
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text("old", encoding="utf-8")
            self.addCleanup(destination.unlink, missing_ok=True)

            with self.assertRaisesRegex(
                ScriptError, "generated localization file is stale"
            ):
                localization.synchronize_file(source, destination, write=False)

    def test_removes_obsolete_generated_files_in_format_mode(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            current = root / "current"
            obsolete = root / "obsolete"
            current.touch()
            obsolete.touch()

            localization.remove_stale_files({current, obsolete}, {current}, write=True)

            self.assertTrue(current.exists())
            self.assertFalse(obsolete.exists())


if __name__ == "__main__":
    unittest.main()
