#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Build and ad-hoc sign the native Arknights Client application bundle."""

from __future__ import annotations

import argparse
import os
import shutil
import stat
import struct
import tempfile
from pathlib import Path

from lib.common import (
    BUILD_DIR,
    DIST_DIR,
    PROJECT_DIR,
    fail,
    info,
    output,
    remove_path,
    require_commands,
    require_directory,
    require_file,
    run,
    run_main,
    success,
)
from lib.console import spinner
from lib.patch_wine_runtime import patch_file
from runtime_config import validate_config

APP_NAME = "Arknights Client"
EXECUTABLE_NAME = "ArknightsClient"
APP_BUNDLE = DIST_DIR / f"{APP_NAME}.app"
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


def validate_inputs(runtime: Path | None) -> None:
    require_commands(("codesign", "lipo", "plutil", "swift", "uv"))
    for relative in (
        "Resources/Info.plist",
        "Resources/AppIcon.icns",
        "Resources/Assets.car",
        *LEGAL_FILES,
    ):
        require_file(PROJECT_DIR / relative)
    licenses = require_directory(PROJECT_DIR / "docs/legal/licenses")
    for name in REQUIRED_LICENSES:
        require_file(licenses / name)
    validate_config(PROJECT_DIR / "runtime.json")
    if runtime is not None:
        require_directory(runtime)


def embed_runtime(runtime: Path, resources: Path) -> None:
    for relative in ("bin/wine64", "bin/wineserver"):
        if not os.access(runtime / relative, os.X_OK):
            fail(f"runtime executable not found: {runtime / relative}")
    if not (runtime / "DXMT/x64").is_dir():
        fail(f"runtime DXMT payload not found: {runtime / 'DXMT/x64'}")

    destination = resources / "Runtime"
    with spinner("Embedding the Wine + DXMT runtime"):
        copy_runtime(runtime, destination)
    with spinner("Removing unused arm64 slices from the x86-64 runtime"):
        count = thin_universal_files(destination)
    if count:
        info(f"Thinned {count} universal runtime files")

    driver = destination / "lib/wine/x86_64-unix/winemac.so"
    require_file(driver)
    info("Applying the native Command-Q integration patch")
    patch_file(driver)
    run(["codesign", "--force", "--sign", "-", "--timestamp=none", driver])
    launcher = destination / "bin/Arknights"
    remove_path(launcher)
    launcher.symlink_to("wine64")


def build(runtime: Path | None, configuration: str = "release") -> Path:
    runtime = runtime.resolve() if runtime is not None else None
    validate_inputs(runtime)
    info(f"Building the Apple Silicon {configuration} executable")
    run(
        ["swift", "build", "--configuration", configuration, "--arch", "arm64"],
        cwd=PROJECT_DIR,
    )
    binary_dir = Path(
        output(
            [
                "swift",
                "build",
                "--configuration",
                configuration,
                "--arch",
                "arm64",
                "--show-bin-path",
            ],
            cwd=PROJECT_DIR,
        )
    )
    binary = binary_dir / EXECUTABLE_NAME
    if not os.access(binary, os.X_OK):
        fail(f"{configuration} executable not found: {binary}")

    DIST_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".app-build.", dir=DIST_DIR) as name:
        staged_app = Path(name) / f"{APP_NAME}.app"
        macos = staged_app / "Contents/MacOS"
        resources = staged_app / "Contents/Resources"
        macos.mkdir(parents=True)
        resources.mkdir(parents=True)
        copy_file(binary, macos / EXECUTABLE_NAME, 0o755)
        copy_file(
            PROJECT_DIR / "Resources/Info.plist", staged_app / "Contents/Info.plist"
        )
        copy_file(PROJECT_DIR / "Resources/AppIcon.icns", resources / "AppIcon.icns")
        copy_file(PROJECT_DIR / "Resources/Assets.car", resources / "Assets.car")

        helper_root = BUILD_DIR / "helpers"
        info("Building the game compatibility components")
        run(
            [
                "uv",
                "run",
                PROJECT_DIR / "scripts/build_compatibility.py",
                "--output",
                helper_root,
            ]
        )
        compatibility = resources / "Compatibility"
        compatibility_helpers = (
            ("Vuplex/Vuplex WebView.vuplex", "Vuplex/Vuplex WebView.vuplex"),
            ("Vuplex/userenv.dll", "Vuplex/userenv.dll"),
            (
                "PlatformProcess/PlatformProcess.exe",
                "PlatformProcess/PlatformProcess.exe",
            ),
            (
                "PlatformProcess/PlatformProcessWindowBridge.dylib",
                "PlatformProcess/PlatformProcessWindowBridge.dylib",
            ),
        )
        for source, destination in compatibility_helpers:
            copy_file(helper_root / source, compatibility / destination)
        run(
            [
                "codesign",
                "--force",
                "--sign",
                "-",
                "--timestamp=none",
                compatibility / "PlatformProcess/PlatformProcessWindowBridge.dylib",
            ]
        )
        run(["plutil", "-lint", staged_app / "Contents/Info.plist"], capture=True)

        if runtime is not None:
            embed_runtime(runtime, resources)
        for source, destination in LEGAL_FILES.items():
            copy_file(PROJECT_DIR / source, resources / destination)
        licenses = resources / "ThirdPartyLicenses"
        license_files = sorted((PROJECT_DIR / "docs/legal/licenses").glob("*.txt"))
        if not license_files:
            fail("no third-party license files found")
        for license_file in license_files:
            copy_file(license_file, licenses / license_file.name)

        info("Ad-hoc signing the application bundle")
        run(["codesign", "--force", "--sign", "-", "--timestamp=none", staged_app])
        run(["codesign", "--verify", "--deep", "--strict", "--verbose=2", staged_app])
        remove_path(APP_BUNDLE)
        staged_app.replace(APP_BUNDLE)
    success(f"Built {APP_BUNDLE.relative_to(PROJECT_DIR)}")
    return APP_BUNDLE


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
