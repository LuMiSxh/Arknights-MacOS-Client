#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Regenerate the layered app icon, README preview, and fallback assets."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path

from lib.common import (
    BUILD_DIR,
    PROJECT_DIR,
    fail,
    info,
    remove_path,
    require_command,
    require_directory,
    require_file,
    run,
    run_main,
    success,
    warning,
)

DEFAULT_ICON_COMPOSER = Path(
    "/Applications/Icon Composer.app/Contents/Executables/ictool"
)


def icon_composer() -> Path:
    discovered = shutil.which("ictool")
    if discovered:
        return Path(discovered)
    if DEFAULT_ICON_COMPOSER.is_file():
        return DEFAULT_ICON_COMPOSER
    fail("Icon Composer command not found; install Icon Composer or add ictool to PATH")


def compile_arguments(source: Path, destination: Path) -> list[str | Path]:
    return [
        "actool",
        source,
        "--compile",
        destination,
        "--output-partial-info-plist",
        destination / "Info.plist",
        "--app-icon",
        "AppIcon",
        "--enable-on-demand-resources",
        "NO",
        "--development-region",
        "en",
        "--target-device",
        "mac",
        "--minimum-deployment-target",
        "26.0",
        "--platform",
        "macosx",
        "--notices",
        "--warnings",
        "--errors",
        "--output-format",
        "human-readable-text",
    ]


def generate() -> None:
    require_command("actool")
    require_command("sips")
    composer = icon_composer()
    source = require_directory(PROJECT_DIR / "Resources/AppIcon.icon")

    rendered = BUILD_DIR / "AppIcon.png"
    preview = PROJECT_DIR / "Resources/AppIcon.png"
    catalog = BUILD_DIR / "AppIcon.xcassets"
    iconset = catalog / "AppIcon.appiconset"
    compiled = BUILD_DIR / "AppIcon.compiled"
    dynamic = BUILD_DIR / "AppIcon.dynamic"
    output_icns = PROJECT_DIR / "Resources/AppIcon.icns"
    output_assets = PROJECT_DIR / "Resources/Assets.car"
    for path in (catalog, compiled, dynamic):
        remove_path(path)
    for path in (iconset, compiled, dynamic):
        path.mkdir(parents=True)

    info("Rendering the Icon Composer source")
    run(
        [
            composer,
            source,
            "--export-image",
            "--output-file",
            rendered,
            "--platform",
            "macOS",
            "--rendition",
            "Default",
            "--width",
            "1024",
            "--height",
            "1024",
            "--scale",
            "1",
        ]
    )
    run(
        ["sips", "--resampleHeightWidth", "512", "512", rendered, "--out", preview],
        capture=True,
    )

    info("Compiling the native layered icon")
    result = subprocess.run(
        [str(value) for value in compile_arguments(source, dynamic)],
        text=True,
        capture_output=True,
        check=False,
    )
    (dynamic / "actool.log").write_text(result.stdout + result.stderr, encoding="utf-8")
    if (
        result.returncode == 0
        and (dynamic / "AppIcon.icns").is_file()
        and (dynamic / "Assets.car").is_file()
    ):
        shutil.copyfile(dynamic / "AppIcon.icns", output_icns)
        shutil.copyfile(dynamic / "Assets.car", output_assets)
        success("Built the native layered app icon")
        return

    warning("Native .icon compilation is unavailable; using the asset-catalog fallback")
    require_command("magick")
    contents = require_file(PROJECT_DIR / "Resources/AppIconAssetContents.json")
    shutil.copyfile(contents, iconset / "Contents.json")
    for size in (16, 32, 128, 256, 512):
        for scale, pixels in ((1, size), (2, size * 2)):
            suffix = "" if scale == 1 else "@2x"
            output = iconset / f"icon_{size}x{size}{suffix}.png"
            run(["magick", rendered, "-resize", f"{pixels}x{pixels}", output])
    run(compile_arguments(catalog, compiled))
    shutil.copyfile(require_file(compiled / "AppIcon.icns"), output_icns)
    shutil.copyfile(require_file(compiled / "Assets.car"), output_assets)
    success("Built the asset-catalog app icon fallback")


def main() -> None:
    generate()


if __name__ == "__main__":
    run_main(main)
