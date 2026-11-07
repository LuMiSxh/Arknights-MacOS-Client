# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import plistlib
from dataclasses import replace
from pathlib import Path

import build_app
import pytest
from lib.project_config import ProjectConfiguration, load_project_configuration


@pytest.fixture(scope="module")
def configuration() -> ProjectConfiguration:
    return load_project_configuration()


def test_app_resources_follow_project_configuration(
    configuration: ProjectConfiguration,
) -> None:
    resources = dict(build_app.app_resources(configuration))

    assert resources[configuration.project_directory / "docs/help/errors"] == Path(
        "SupportArticles"
    )
    for source in configuration.copied_resource_source_paths:
        assert resources[source] == Path(source.name)


def test_app_resources_bundle_the_runtime_configuration(
    configuration: ProjectConfiguration,
) -> None:
    resources = dict(build_app.app_resources(configuration))

    assert resources[configuration.project_directory / "runtime.json"] == Path(
        "RUNTIME.json"
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
