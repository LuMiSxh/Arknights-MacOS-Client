# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import plistlib
import struct
from dataclasses import replace
from pathlib import Path

import build_app
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

    assert resources[configuration.project_directory / "docs/help/errors"] == Path(
        "SupportArticles"
    )
    for source in configuration.copied_resource_source_paths:
        assert resources[source] == Path(source.name)
    for language in configuration.product.localizations:
        source = (
            configuration.project_directory
            / f"Resources/{language}.lproj/InfoPlist.strings"
        )
        assert resources[source] == Path(f"{language}.lproj/InfoPlist.strings")


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


def test_bundle_retains_tracked_sparkle_key(tmp_path: Path) -> None:
    source = tmp_path / "Info.plist"
    destination = tmp_path / "app/Contents/Info.plist"
    public_key = "A" * 43 + "="
    source.write_bytes(
        plistlib.dumps(
            {
                "CFBundleIdentifier": "com.example.client",
                "SUPublicEDKey": public_key,
            }
        )
    )

    build_app.configure_info_plist(source, destination)

    metadata = plistlib.loads(destination.read_bytes())
    assert metadata["SUPublicEDKey"] == public_key


def test_bundle_rejects_malformed_sparkle_key(tmp_path: Path) -> None:
    source = tmp_path / "Info.plist"
    destination = tmp_path / "app/Contents/Info.plist"
    source.write_bytes(
        plistlib.dumps(
            {"CFBundleIdentifier": "com.example.client", "SUPublicEDKey": "invalid"}
        )
    )

    with pytest.raises(RuntimeError, match="SUPublicEDKey"):
        build_app.configure_info_plist(source, destination)


def test_sparkle_framework_copy_preserves_symlinks(tmp_path: Path) -> None:
    source = tmp_path / "source/Sparkle.framework"
    (source / "Versions/B").mkdir(parents=True)
    (source / "Versions/B/Sparkle").write_bytes(b"framework")
    (source / "Versions/Current").symlink_to("B")
    (source / "Sparkle").symlink_to("Versions/Current/Sparkle")
    destination = tmp_path / "destination/Sparkle.framework"

    build_app.copy_sparkle_framework(source, destination)

    assert (destination / "Versions/Current").is_symlink()
    assert (destination / "Sparkle").is_symlink()
    assert (destination / "Sparkle").read_bytes() == b"framework"


def test_sparkle_framework_version_comes_from_package_metadata(
    tmp_path: Path, configuration: ProjectConfiguration
) -> None:
    changed = replace(
        configuration,
        package=replace(
            configuration.package,
            exact_dependency_versions=(("sparkle", "9.8.7"),),
        ),
    )
    framework = tmp_path / "bin/Sparkle.framework/Versions/A"
    (framework / "XPCServices/Downloader.xpc").mkdir(parents=True)
    (framework / "XPCServices/Installer.xpc").mkdir()
    (framework / "Updater.app").mkdir()
    (framework / "Sparkle").write_bytes(b"framework")
    (framework / "Resources").mkdir()
    (framework / "Resources/Info.plist").write_bytes(
        plistlib.dumps({"CFBundleShortVersionString": "9.8.7"})
    )
    (framework.parent / "Current").symlink_to("A")

    discovered = build_app.sparkle_framework(tmp_path / "bin", changed)

    assert discovered == tmp_path / "bin/Sparkle.framework"
