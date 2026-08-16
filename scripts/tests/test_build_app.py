# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import build_app


class AppBundleTests(unittest.TestCase):
    def test_runtime_copy_excludes_development_payloads(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            (source / "include").mkdir(parents=True)
            (source / "share/man").mkdir(parents=True)
            (source / "share/wine/mono").mkdir(parents=True)
            (source / "bin").mkdir(parents=True)
            (source / "include/header.h").write_text("header", encoding="utf-8")
            (source / "share/man/wine.1").write_text("manual", encoding="utf-8")
            (source / "share/wine/mono/runtime").write_text("mono", encoding="utf-8")
            (source / "bin/wine64").write_text("wine", encoding="utf-8")
            (source / "bin/backup.wine-original").write_text("backup", encoding="utf-8")

            destination = root / "destination"
            build_app.copy_runtime(source, destination)

            self.assertTrue((destination / "bin/wine64").is_file())
            self.assertFalse((destination / "include").exists())
            self.assertFalse((destination / "share/man").exists())
            self.assertFalse((destination / "share/wine/mono").exists())
            self.assertFalse((destination / "bin/backup.wine-original").exists())


if __name__ == "__main__":
    unittest.main()
