#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Download, verify, and prepare the runtime pinned in runtime.json."""

from __future__ import annotations

import argparse
import hashlib
import os
import shutil
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

from common import BUILD_DIR, PROJECT_DIR, fail, info, remove_path, run_main, success
from extract_runtime import extract
from runtime_config import read_config, validate_config

RUNTIME_COMMANDS = ("bin/wine64", "bin/wineserver")
DXMT_LIBRARIES = ("d3d10core.dll", "d3d11.dll", "dxgi.dll", "winemetal.dll")


def runtime_is_valid(directory: Path) -> bool:
    if not all(os.access(directory / command, os.X_OK) for command in RUNTIME_COMMANDS):
        return False
    if not (directory / "lib/wine/x86_64-windows/winemetal.dll").exists():
        return False
    if not all(
        (directory / "DXMT" / architecture / library).is_file()
        for architecture in ("x64", "x32")
        for library in DXMT_LIBRARIES
    ):
        return False
    launcher = directory / "bin/Arknights"
    return launcher.is_symlink() and launcher.readlink() == Path("wine64")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, output: Path, expected_sha256: str) -> None:
    if output.is_file() and sha256(output) == expected_sha256:
        info("Using the verified runtime archive from the local cache")
        return

    partial = output.with_suffix(output.suffix + ".part")
    partial.unlink(missing_ok=True)
    request = urllib.request.Request(
        url, headers={"User-Agent": "Arknights-Client-Build"}
    )
    info("Downloading the pinned Wine + DXMT runtime")
    try:
        with (
            urllib.request.urlopen(request, timeout=60) as response,
            partial.open("wb") as file,
        ):
            if not response.geturl().startswith("https://"):
                fail("runtime download redirected to a non-HTTPS URL")
            total = int(response.headers.get("Content-Length", "0"))
            received = 0
            last_update = 0.0
            while chunk := response.read(1024 * 1024):
                file.write(chunk)
                received += len(chunk)
                now = time.monotonic()
                if sys.stderr.isatty() and now - last_update >= 0.2:
                    if total:
                        percentage = min(received / total * 100, 100)
                        message = (
                            f"\r  {percentage:5.1f}%  {received / 1_048_576:,.0f} MiB"
                        )
                    else:
                        message = f"\r  {received / 1_048_576:,.0f} MiB"
                    print(message, end="", file=sys.stderr, flush=True)
                    last_update = now
        if sys.stderr.isatty():
            print(file=sys.stderr)
    except (OSError, urllib.error.URLError) as error:
        partial.unlink(missing_ok=True)
        fail(f"unable to download the runtime: {error}")

    actual_sha256 = sha256(partial)
    if actual_sha256 != expected_sha256:
        partial.unlink(missing_ok=True)
        fail(
            "downloaded runtime failed SHA-256 verification "
            f"(expected {expected_sha256}, got {actual_sha256})"
        )
    partial.replace(output)


def prepare_runtime(url: str, checksum: str) -> Path:
    destination = BUILD_DIR / "runtime"
    revision_file = destination / ".arknights-runtime-archive-sha256"
    if (
        revision_file.is_file()
        and revision_file.read_text(encoding="utf-8").strip() == checksum
        and runtime_is_valid(destination)
    ):
        info("The prepared runtime is already current")
        return destination

    cache_dir = BUILD_DIR / "runtime-downloads"
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive = cache_dir / f"{checksum}.tar.gz"
    download(url, archive, checksum)

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".runtime-download.", dir=BUILD_DIR
    ) as name:
        staging = Path(name)
        info("Extracting the verified runtime")
        libraries = extract(archive, staging / "runtime-archive")
        wine = libraries / "Wine"
        dxmt = libraries / "DXMT"
        if not wine.is_dir() or not dxmt.is_dir():
            fail("runtime archive does not contain Wine and DXMT")

        runtime = staging / "runtime"
        wine.replace(runtime)
        shutil.move(dxmt, runtime / "DXMT")
        (runtime / "bin/Arknights").symlink_to("wine64")
        if not runtime_is_valid(runtime):
            fail("runtime archive is incomplete")
        (runtime / ".arknights-runtime-archive-sha256").write_text(
            f"{checksum}\n", encoding="utf-8"
        )
        remove_path(destination)
        runtime.replace(destination)
    success("Runtime is ready")
    return destination


def main() -> None:
    config_path = PROJECT_DIR / "runtime.json"
    validate_config(config_path)
    config = read_config(config_path)
    runtime = config["runtime"]

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=runtime["url"])
    parser.add_argument("--sha256", default=runtime["sha256"])
    arguments = parser.parse_args()
    if not arguments.url.startswith("https://"):
        fail("runtime URL must use HTTPS")
    if len(arguments.sha256) != 64 or any(
        character not in "0123456789abcdefABCDEF" for character in arguments.sha256
    ):
        fail("runtime checksum must be a 64-character SHA-256 value")
    print(prepare_runtime(arguments.url, arguments.sha256.lower()))


if __name__ == "__main__":
    run_main(main)
