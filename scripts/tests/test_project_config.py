# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import plistlib
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

from lib.common import ScriptError
from lib.project_config import load_project_configuration


class ProjectConfigurationTests(unittest.TestCase):
    def plist(
        self, *, languages: list[str] | None = None, executable: str = "Client"
    ) -> dict[str, object]:
        return {
            "CFBundleDisplayName": "Example Client",
            "CFBundleName": "Example Client",
            "CFBundleExecutable": executable,
            "CFBundleIdentifier": "example.client",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleIconName": "AppIcon",
            "CFBundleIconFile": "AppIcon",
            "CFBundleDevelopmentRegion": "en",
            "CFBundleLocalizations": languages or ["en", "de"],
            "LSMinimumSystemVersion": "15.0",
            "LSArchitecturePriority": ["arm64"],
        }

    def dump(
        self,
        *,
        languages: list[str] | None = None,
        name: str = "Client",
        resources: list[dict[str, object]] | None = None,
    ) -> dict[str, object]:
        languages = languages or ["en", "de"]
        return {
            "name": name,
            "defaultLocalization": "en",
            "platforms": [{"platformName": "macos", "version": "15.0"}],
            "products": [{"name": name, "type": {"executable": {}}, "targets": [name]}],
            "targets": [
                {
                    "name": name,
                    "type": "executable",
                    "path": f"Sources/{name}",
                    "resources": resources
                    or [
                        {"path": "Resources/Icon.png", "rule": {"copy": {}}},
                        *(
                            {
                                "path": f"Resources/{language}.lproj",
                                "rule": {"process": {}},
                            }
                            for language in languages
                        ),
                    ],
                }
            ],
        }

    def load(self, plist: dict[str, object], dump: dict[str, object]):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            info = root / "Resources/Info.plist"
            info.parent.mkdir()
            with info.open("wb") as file:
                plistlib.dump(plist, file)
            return load_project_configuration(root, dump)

    def test_derives_paths_from_manifest_and_plist(self) -> None:
        configuration = self.load(self.plist(), self.dump())

        self.assertEqual(configuration.app_bundle_name, "Example Client.app")
        self.assertEqual(configuration.dmg_name, "Example Client.dmg")
        self.assertEqual(
            configuration.target_directory,
            configuration.project_directory / "Sources/Client",
        )
        self.assertEqual(
            configuration.resource_directory,
            configuration.target_directory / "Resources",
        )
        self.assertEqual(
            configuration.swift_resource_bundle_name, "Client_Client.bundle"
        )
        self.assertEqual(
            configuration.copied_resource_source_paths,
            (configuration.target_directory / "Resources/Icon.png",),
        )

    def test_renames_languages_and_resources_are_derived_automatically(self) -> None:
        languages = ["en", "de", "ja"]
        resources = [
            {"path": "Assets/Brand.png", "rule": {"copy": {}}},
            *(
                {"path": f"Assets/{language}.lproj", "rule": {"process": {}}}
                for language in languages
            ),
        ]
        configuration = self.load(
            self.plist(languages=languages, executable="Renamed"),
            self.dump(languages=languages, name="Renamed", resources=resources),
        )

        self.assertEqual(
            configuration.swift_resource_bundle_name, "Renamed_Renamed.bundle"
        )
        self.assertEqual(
            configuration.package.processed_resource_paths,
            tuple(Path(f"Assets/{language}.lproj") for language in languages),
        )
        self.assertEqual(
            configuration.copied_resource_source_paths,
            (configuration.target_directory / "Assets/Brand.png",),
        )

    def test_rejects_cross_source_mismatches(self) -> None:
        cases = [
            (self.plist(executable="Other"), self.dump()),
            (self.plist(languages=["en", "fr"]), self.dump()),
            ({**self.plist(), "CFBundleIconFile": "OtherIcon"}, self.dump()),
            (self.plist(), {**self.dump(), "defaultLocalization": "de"}),
            (
                self.plist(),
                {
                    **self.dump(),
                    "platforms": [{"platformName": "macos", "version": "14.0"}],
                },
            ),
        ]
        for plist, dump in cases:
            with self.subTest(plist=plist, dump=dump), self.assertRaises(ScriptError):
                self.load(plist, dump)

    def test_rejects_duplicate_languages_architectures_and_unsafe_paths(self) -> None:
        for plist, dump in (
            (self.plist(languages=["en", "en"]), self.dump()),
            (
                {**self.plist(), "LSArchitecturePriority": ["arm64", "arm64"]},
                self.dump(),
            ),
            (
                self.plist(),
                {
                    **self.dump(),
                    "targets": [{**self.dump()["targets"][0], "path": "../Client"}],
                },
            ),
        ):
            with self.subTest(plist=plist, dump=dump), self.assertRaises(ScriptError):
                self.load(plist, dump)

    def test_rejects_unsafe_architecture_arguments(self) -> None:
        with self.assertRaisesRegex(ScriptError, "Swift architecture names"):
            self.load(
                {**self.plist(), "LSArchitecturePriority": ["arm64 --verbose"]},
                self.dump(),
            )


if __name__ == "__main__":
    unittest.main()
