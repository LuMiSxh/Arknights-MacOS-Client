# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1]))

import build_dmg
import generate_icon
import project_config as project_config_command
from lib.project_config import PackageMetadata, ProductMetadata, ProjectConfiguration


def configuration(root: Path) -> ProjectConfiguration:
    product = ProductMetadata(
        display_name="Renamed Client",
        bundle_name="Renamed Client",
        executable_name="RenamedExecutable",
        bundle_identifier="example.renamed",
        marketing_version="9.8.7",
        icon_name="RenamedIcon",
        icon_file="RenamedIcon",
        development_region="fr",
        localizations=("fr", "en"),
        minimum_macos_version="16.0",
        architecture_priority=("arm64",),
    )
    package = PackageMetadata(
        name="RenamedPackage",
        default_localization="fr",
        macos_version="16.0",
        executable_product_name="RenamedExecutable",
        executable_target_name="RenamedTarget",
        target_path=Path("Sources/RenamedTarget"),
        excluded_paths=(),
        copy_resource_paths=(),
        processed_resource_paths=(
            Path("Resources/fr.lproj"),
            Path("Resources/en.lproj"),
        ),
    )
    return ProjectConfiguration(root, product, package)


class DerivedPackagingTests(unittest.TestCase):
    def test_dmg_arguments_follow_product_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = configuration(Path(directory))
            arguments = build_dmg.dmgbuild_arguments(
                Path("dist/Renamed Client.app"),
                Path("dist/Renamed Client.dmg"),
                config,
            )

            self.assertIn("app_name=Renamed Client.app", arguments)
            self.assertIn("Renamed Client", arguments)

    def test_icon_arguments_follow_product_and_package_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = configuration(Path(directory))
            arguments = generate_icon.compile_arguments(
                Path("RenamedIcon.icon"), Path("output"), config
            )

            self.assertEqual(
                arguments[arguments.index("--app-icon") + 1], "RenamedIcon"
            )
            self.assertEqual(
                arguments[arguments.index("--development-region") + 1], "fr"
            )
            self.assertEqual(
                arguments[arguments.index("--minimum-deployment-target") + 1],
                "16.0",
            )

    def test_command_fields_are_derived_from_configuration(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            config = configuration(Path(directory))

            self.assertEqual(
                project_config_command.read_field(config, "app-bundle-name"),
                "Renamed Client.app",
            )
            self.assertEqual(
                project_config_command.read_field(config, "dmg-name"),
                "Renamed Client.dmg",
            )
            self.assertEqual(
                project_config_command.read_field(
                    config, "swift-architecture-arguments"
                ),
                "--arch arm64",
            )


if __name__ == "__main__":
    unittest.main()
