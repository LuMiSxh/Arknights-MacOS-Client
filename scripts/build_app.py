#!/usr/bin/env -S uv run --locked --no-dev --group packaging
# SPDX-License-Identifier: MPL-2.0

"""Build and ad-hoc sign the native application bundle."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
import struct
import tempfile
from pathlib import Path

from build_compatibility import build as build_compatibility
from lib.common import (
    BUILD_DIR,
    DIST_DIR,
    PROJECT_DIR,
    fail,
    output,
    remove_path,
    require_commands,
    require_directory,
    require_file,
    run,
    run_main,
)
from lib.console import info, spinner, success
from lib.patch_wine_runtime import patch_file
from lib.project_config import ProjectConfiguration, load_project_configuration
from localization import prepare_localization
from runtime_config import (
    RuntimeConfiguration,
    load_runtime_config,
    runtime_is_valid,
)

LEGAL_FILES = {
    "docs/legal/third-party-notices.md": "THIRD_PARTY_NOTICES.md",
    "LICENSE": "LICENSE",
    "CHANGELOG.md": "CHANGELOG.md",
    "runtime.json": "RUNTIME.json",
    "docs/legal/source-code.md": "SOURCE_CODE.md",
}
REQUIRED_LICENSES = (
    "apache-2.0.txt",
    "fdk-aac.txt",
    "gpl-2.0.txt",
    "gpl-3.0.txt",
    "lgpl-2.1.txt",
    "lgpl-3.0.txt",
    "mit-dxmt.txt",
)


def copy_file(source: Path, destination: Path, mode: int = 0o644) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    destination.chmod(mode)


def copy_resource(source: Path, destination: Path) -> None:
    if source.is_dir():
        shutil.copytree(source, destination)
    elif source.is_file():
        copy_file(source, destination)
    else:
        fail(f"required resource not found: {source}")


def app_resources(configuration: ProjectConfiguration) -> tuple[tuple[Path, Path], ...]:
    project = configuration.project_directory
    icon_file = configuration.product.icon_file
    icon_filename = icon_file if Path(icon_file).suffix else f"{icon_file}.icns"
    entries = [
        (project / "Resources" / icon_filename, Path(icon_filename)),
        (project / "Resources/Assets.car", Path("Assets.car")),
        *(
            (
                project / f"Resources/{language}.lproj/InfoPlist.strings",
                Path(f"{language}.lproj/InfoPlist.strings"),
            )
            for language in configuration.product.localizations
        ),
        *(
            (source, Path(source.name))
            for source in configuration.copied_resource_source_paths
        ),
    ]
    destinations = [destination for _, destination in entries]
    if len(destinations) != len(set(destinations)):
        fail("application resources contain duplicate destinations")
    return tuple(entries)


def copy_swift_localizations(
    binary_dir: Path,
    resources: Path,
    configuration: ProjectConfiguration,
) -> None:
    source = require_directory(binary_dir / configuration.swift_resource_bundle_name)
    localizations = sorted(source.glob("*.lproj/*.strings"))
    if not localizations:
        fail("Swift resource bundle does not contain localizations")
    discovered = {path.parent.name.removesuffix(".lproj") for path in localizations}
    expected = set(configuration.product.localizations)
    if discovered != expected:
        fail(
            "Swift resource bundle localizations do not match CFBundleLocalizations "
            f"(found {sorted(discovered)}, expected {sorted(expected)})"
        )
    for localization in localizations:
        copy_file(localization, resources / localization.relative_to(source))


def copy_compatibility_helpers(source: Path, destination: Path) -> tuple[Path, ...]:
    files = sorted(path for path in source.rglob("*") if path.is_file())
    if not files:
        fail("compatibility build produced no artifacts")
    copied = []
    for artifact in files:
        packaged = destination / artifact.relative_to(source)
        copy_file(artifact, packaged)
        copied.append(packaged)
    return tuple(copied)


def copy_runtime(source: Path, destination: Path) -> None:
    # The callback needs a stable source root to identify the top-level exclusions.
    def ignore(directory: str, names: list[str]) -> set[str]:
        relative = Path(directory).relative_to(source)
        ignored = {name for name in names if name.endswith(".wine-original")}
        if relative == Path("."):
            ignored.add("include")
        if relative == Path("share"):
            ignored.add("man")
        if relative == Path("share/wine"):
            ignored.add("mono")
        return ignored

    shutil.copytree(source, destination, symlinks=True, ignore=ignore)


# Mach-O fat header layout (all fields big-endian on disk).
_FAT_MAGIC = 0xCAFEBABE
_FAT_MAGIC_64 = 0xCAFEBABF
_CPU_TYPE_X86_64 = 0x01000007
_CPU_TYPE_ARM64 = 0x0100000C


def _fat_cpu_types(path: Path) -> set[int]:
    # Reads only the fat header instead of shelling out to `lipo -archs`, since
    # most runtime files (fonts, configs, thin binaries) aren't fat Mach-O at
    # all and don't deserve a subprocess spawn just to find that out.
    with path.open("rb") as handle:
        header = handle.read(8)
        if len(header) < 8:
            return set()
        magic, count = struct.unpack(">II", header)
        if magic == _FAT_MAGIC:
            entry_size, entry_format = 20, ">ii"
        elif magic == _FAT_MAGIC_64:
            entry_size, entry_format = 32, ">ii"
        else:
            return set()
        body = handle.read(count * entry_size)
    return {
        struct.unpack_from(entry_format, body, index * entry_size)[0]
        for index in range(count)
        if len(body) >= (index + 1) * entry_size
    }


def thin_universal_files(runtime: Path) -> int:
    count = 0
    for path in runtime.rglob("*"):
        if not path.is_file() or path.is_symlink():
            continue
        cpu_types = _fat_cpu_types(path)
        if not {_CPU_TYPE_X86_64, _CPU_TYPE_ARM64} <= cpu_types:
            continue
        temporary = path.with_name(f"{path.name}.x86_64")
        mode = stat.S_IMODE(path.stat().st_mode)
        run(["lipo", path, "-thin", "x86_64", "-output", temporary])
        temporary.chmod(mode)
        temporary.replace(path)
        count += 1
    return count


def validate_inputs(
    runtime: Path | None,
    configuration: ProjectConfiguration,
    runtime_configuration: RuntimeConfiguration,
) -> None:
    require_commands(("codesign", "lipo", "plutil", "swift"))
    project = configuration.project_directory
    require_file(project / "Resources/Info.plist")
    for source, _ in app_resources(configuration):
        if not source.exists():
            fail(f"required resource not found: {source}")
    for relative in LEGAL_FILES:
        require_file(project / relative)
    licenses = require_directory(project / "docs/legal/licenses")
    for name in REQUIRED_LICENSES:
        require_file(licenses / name)
    if runtime is not None:
        require_directory(runtime)
        if not runtime_is_valid(runtime, runtime_configuration.layout):
            fail("runtime directory does not satisfy runtime.json interface")


def embed_runtime(
    runtime: Path,
    resources: Path,
    runtime_configuration: RuntimeConfiguration,
) -> None:
    layout = runtime_configuration.layout
    destination = resources / "Runtime"
    with spinner("Embedding the Wine + DXMT runtime"):
        copy_runtime(runtime, destination)
    with spinner("Removing unused arm64 slices from the x86-64 runtime"):
        count = thin_universal_files(destination)
    if count:
        info(f"Thinned {count} universal runtime files")

    driver = destination / layout.mac_driver
    require_file(driver)
    info("Applying the native Command-Q integration patch")
    patch_file(driver)
    run(["codesign", "--force", "--sign", "-", "--timestamp=none", driver])
    launcher = destination / layout.launcher.path
    remove_path(launcher)
    launcher.symlink_to(layout.launcher.target)
    if not runtime_is_valid(destination, layout):
        fail("packaged runtime does not satisfy runtime.json interface")


def build(
    runtime: Path | None,
    configuration: str = "release",
    project_configuration: ProjectConfiguration | None = None,
) -> Path:
    project_configuration = project_configuration or load_project_configuration()
    prepare_localization(configuration=project_configuration)
    project = project_configuration.project_directory
    runtime_configuration = load_runtime_config(project / "runtime.json")
    runtime = runtime.resolve() if runtime is not None else None
    validate_inputs(runtime, project_configuration, runtime_configuration)
    architectures = project_configuration.product.architecture_priority
    architecture_arguments = [
        argument
        for architecture in architectures
        for argument in ("--arch", architecture)
    ]
    info(f"Building the {configuration} executable for {', '.join(architectures)}")
    run(
        ["swift", "build", "--configuration", configuration, *architecture_arguments],
        cwd=project,
    )
    binary_dir = Path(
        output(
            [
                "swift",
                "build",
                "--configuration",
                configuration,
                *architecture_arguments,
                "--show-bin-path",
            ],
            cwd=project,
        )
    )
    binary = binary_dir / project_configuration.product.executable_name
    if not os.access(binary, os.X_OK):
        fail(f"{configuration} executable not found: {binary}")

    dist = project / DIST_DIR.relative_to(PROJECT_DIR)
    app_bundle = dist / project_configuration.app_bundle_name
    dist.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".app-build.", dir=dist) as name:
        staged_app = Path(name) / project_configuration.app_bundle_name
        macos = staged_app / "Contents/MacOS"
        resources = staged_app / "Contents/Resources"
        macos.mkdir(parents=True)
        resources.mkdir(parents=True)
        copy_file(binary, macos / project_configuration.product.executable_name, 0o755)
        copy_swift_localizations(binary_dir, resources, project_configuration)
        copy_file(project / "Resources/Info.plist", staged_app / "Contents/Info.plist")
        for source, destination in app_resources(project_configuration):
            copy_resource(source, resources / destination)

        helper_root = project / BUILD_DIR.relative_to(PROJECT_DIR) / "helpers"
        remove_path(helper_root)
        info("Building the game compatibility components")
        build_compatibility(helper_root)
        compatibility = resources / "Compatibility"
        helpers = copy_compatibility_helpers(helper_root, compatibility)
        for helper in (path for path in helpers if path.suffix == ".dylib"):
            run(
                [
                    "codesign",
                    "--force",
                    "--sign",
                    "-",
                    "--timestamp=none",
                    helper,
                ]
            )
        run(["plutil", "-lint", staged_app / "Contents/Info.plist"], capture=True)

        if runtime is not None:
            embed_runtime(runtime, resources, runtime_configuration)
        for source, destination in LEGAL_FILES.items():
            copy_file(project / source, resources / destination)
        licenses = resources / "ThirdPartyLicenses"
        license_files = sorted((project / "docs/legal/licenses").glob("*.txt"))
        if not license_files:
            fail("no third-party license files found")
        for license_file in license_files:
            copy_file(license_file, licenses / license_file.name)

        info("Ad-hoc signing the application bundle")
        run(["codesign", "--force", "--sign", "-", "--timestamp=none", staged_app])
        run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", staged_app])
        remove_path(app_bundle)
        staged_app.replace(app_bundle)
    success(f"Built {app_bundle.relative_to(project)}")
    return app_bundle


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--runtime", type=Path)
    parser.add_argument(
        "--configuration", choices=("debug", "release"), default="release"
    )
    arguments = parser.parse_args()
    build(arguments.runtime, arguments.configuration)


if __name__ == "__main__":
    run_main(main)
