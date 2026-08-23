# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import struct
from dataclasses import replace
from pathlib import Path

import build_app
import build_dmg
import generate_icon
import project_config as project_config_command
import pytest
from lib.project_config import ProjectConfiguration, load_project_configuration


@pytest.fixture(scope="module")
def configuration() -> ProjectConfiguration:
    return load_project_configuration()


def test_swift_localizations_are_copied_into_app_resources(
    tmp_path: Path, configuration: ProjectConfiguration
) -> None:
    binary_dir = tmp_path / "bin"
    bundle = binary_dir / configuration.swift_resource_bundle_name
    for language in configuration.product.localizations:
        (bundle / f"{language}.lproj").mkdir(parents=True)
        (bundle / f"{language}.lproj/Localizable.strings").write_text(
            '"home.settings" = "Settings";', encoding="utf-8"
        )
    resources = tmp_path / configuration.app_bundle_name / "Contents/Resources"

    build_app.copy_swift_localizations(binary_dir, resources, configuration)

    for language in configuration.product.localizations:
        assert (resources / f"{language}.lproj/Localizable.strings").is_file()
    assert not (
        tmp_path
        / configuration.app_bundle_name
        / configuration.swift_resource_bundle_name
    ).exists()


def test_app_resources_follow_project_configuration(
    configuration: ProjectConfiguration,
) -> None:
    resources = dict(build_app.app_resources(configuration))

    for source in configuration.copied_resource_source_paths:
        assert resources[source] == Path(source.name)
    for language in configuration.product.localizations:
        source = (
            configuration.project_directory
            / f"Resources/{language}.lproj/InfoPlist.strings"
        )
        assert resources[source] == Path(f"{language}.lproj/InfoPlist.strings")


def test_packaging_commands_follow_changed_project_metadata(
    tmp_path: Path, configuration: ProjectConfiguration
) -> None:
    changed = replace(
        configuration,
        product=replace(
            configuration.product,
            display_name="Renamed Client",
            icon_name="RenamedIcon",
            development_region="fr",
        ),
        package=replace(configuration.package, macos_version="16.0"),
    )

    dmg_arguments = build_dmg.dmgbuild_arguments(
        tmp_path / "Renamed Client.app", tmp_path / "Renamed Client.dmg", changed
    )
    icon_arguments = generate_icon.compile_arguments(
        tmp_path / "RenamedIcon.icon", tmp_path / "compiled", changed
    )

    assert "app_name=Renamed Client.app" in dmg_arguments
    assert project_config_command.FIELDS["dmg-name"](changed) == "Renamed Client.dmg"
    assert icon_arguments[icon_arguments.index("--app-icon") + 1] == "RenamedIcon"
    assert icon_arguments[icon_arguments.index("--development-region") + 1] == "fr"
    assert (
        icon_arguments[icon_arguments.index("--minimum-deployment-target") + 1]
        == "16.0"
    )


def test_compatibility_artifacts_are_discovered_recursively(tmp_path: Path) -> None:
    source = tmp_path / "helpers"
    destination = tmp_path / "app/Compatibility"
    artifacts = (
        source / "NewComponent/Bridge.dylib",
        source / "NewComponent/Wrapper.exe",
    )
    for artifact in artifacts:
        artifact.parent.mkdir(parents=True, exist_ok=True)
        artifact.touch()

    copied = build_app.copy_compatibility_helpers(source, destination)

    assert copied == tuple(
        destination / artifact.relative_to(source) for artifact in artifacts
    )


def test_runtime_copy_excludes_development_payloads(tmp_path: Path) -> None:
    source = tmp_path / "source"
    (source / "include").mkdir(parents=True)
    (source / "share/man").mkdir(parents=True)
    (source / "share/wine/mono").mkdir(parents=True)
    (source / "bin").mkdir(parents=True)
    (source / "include/header.h").write_text("header", encoding="utf-8")
    (source / "share/man/wine.1").write_text("manual", encoding="utf-8")
    (source / "share/wine/mono/runtime").write_text("mono", encoding="utf-8")
    (source / "bin/wine64").write_text("wine", encoding="utf-8")
    (source / "bin/backup.wine-original").write_text("backup", encoding="utf-8")

    destination = tmp_path / "destination"
    build_app.copy_runtime(source, destination)

    assert (destination / "bin/wine64").is_file()
    assert not (destination / "include").exists()
    assert not (destination / "share/man").exists()
    assert not (destination / "share/wine/mono").exists()
    assert not (destination / "bin/backup.wine-original").exists()


def test_detects_universal_x86_64_and_arm64(tmp_path: Path) -> None:
    header = struct.pack(">II", build_app._FAT_MAGIC, 2)
    arches = struct.pack(
        ">iiIII", build_app._CPU_TYPE_X86_64, 0, 0x1000, 0x100, 12
    ) + struct.pack(">iiIII", build_app._CPU_TYPE_ARM64, 0, 0x2000, 0x100, 14)
    path = tmp_path / "universal"
    path.write_bytes(header + arches)

    assert build_app._fat_cpu_types(path) == {
        build_app._CPU_TYPE_X86_64,
        build_app._CPU_TYPE_ARM64,
    }


def test_ignores_non_mach_o_files(tmp_path: Path) -> None:
    path = tmp_path / "plain.txt"
    path.write_text("not a binary", encoding="utf-8")

    assert build_app._fat_cpu_types(path) == set()
