# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import build_app
from lib.project_config import load_project_configuration


class AppBundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.configuration = load_project_configuration()

    def test_swift_localizations_are_copied_into_app_resources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            binary_dir = root / "bin"
            bundle = binary_dir / self.configuration.swift_resource_bundle_name
            for language in self.configuration.product.localizations:
                (bundle / f"{language}.lproj").mkdir(parents=True)
                (bundle / f"{language}.lproj/Localizable.strings").write_text(
                    '"home.settings" = "Settings";', encoding="utf-8"
                )
            resources = root / self.configuration.app_bundle_name / "Contents/Resources"

            build_app.copy_swift_localizations(
                binary_dir, resources, self.configuration
            )

            for language in self.configuration.product.localizations:
                self.assertTrue(
                    (resources / f"{language}.lproj/Localizable.strings").is_file()
                )
            self.assertFalse(
                (
                    root
                    / self.configuration.app_bundle_name
                    / self.configuration.swift_resource_bundle_name
                ).exists()
            )

    def test_package_copy_resources_are_bundled_automatically(self) -> None:
        resources = dict(build_app.app_resources(self.configuration))

        for source in self.configuration.copied_resource_source_paths:
            self.assertEqual(resources[source], Path(source.name))

    def test_resource_directories_are_copied_recursively(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "Configuration"
            (source / "nested").mkdir(parents=True)
            (source / "nested/value.json").write_text("{}", encoding="utf-8")
            destination = root / "App/Contents/Resources/Configuration"

            build_app.copy_resource(source, destination)

            self.assertEqual(
                (destination / "nested/value.json").read_text(encoding="utf-8"),
                "{}",
            )

    def test_main_bundle_localizations_are_bundled(self) -> None:
        resources = dict(build_app.app_resources(self.configuration))

        for language in self.configuration.product.localizations:
            source = (
                self.configuration.project_directory
                / f"Resources/{language}.lproj/InfoPlist.strings"
            )
            self.assertEqual(
                resources[source], Path(f"{language}.lproj/InfoPlist.strings")
            )

    def test_compatibility_artifacts_are_discovered_recursively(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "helpers"
            destination = root / "app/Compatibility"
            artifacts = (
                source / "NewComponent/Bridge.dylib",
                source / "NewComponent/Wrapper.exe",
            )
            for artifact in artifacts:
                artifact.parent.mkdir(parents=True, exist_ok=True)
                artifact.touch()

            copied = build_app.copy_compatibility_helpers(source, destination)

            self.assertEqual(
                copied,
                tuple(
                    destination / artifact.relative_to(source) for artifact in artifacts
                ),
            )

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
