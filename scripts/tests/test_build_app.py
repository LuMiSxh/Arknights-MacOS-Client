# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import build_app


class AppBundleTests(unittest.TestCase):
    def test_game_icon_background_is_bundled(self) -> None:
        resource = (
            "Sources/ArknightsClient/Resources/OperatorIconFrame.svg",
            "OperatorIconFrame.svg",
        )

        self.assertIn(resource, build_app.APP_RESOURCES)

    def test_game_icon_bridge_is_bundled_and_signed(self) -> None:
        helper = ("GameIcon/GameIconBridge.dylib", "GameIcon/GameIconBridge.dylib")

        self.assertIn(helper, build_app.COMPATIBILITY_HELPERS)
        self.assertIn(helper[1], build_app.SIGNED_COMPATIBILITY_HELPERS)

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


class FatCpuTypesTests(unittest.TestCase):
    def test_detects_universal_x86_64_and_arm64(self) -> None:
        header = struct.pack(">II", build_app._FAT_MAGIC, 2)
        arches = struct.pack(
            ">iiIII", build_app._CPU_TYPE_X86_64, 0, 0x1000, 0x100, 12
        ) + struct.pack(">iiIII", build_app._CPU_TYPE_ARM64, 0, 0x2000, 0x100, 14)
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "universal"
            path.write_bytes(header + arches)
            self.assertEqual(
                build_app._fat_cpu_types(path),
                {build_app._CPU_TYPE_X86_64, build_app._CPU_TYPE_ARM64},
            )

    def test_ignores_non_mach_o_files(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "plain.txt"
            path.write_text("not a binary", encoding="utf-8")
            self.assertEqual(build_app._fat_cpu_types(path), set())


if __name__ == "__main__":
    unittest.main()
