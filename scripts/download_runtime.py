#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Download, verify, and prepare the runtime pinned in runtime.json."""

from __future__ import annotations

import argparse
import hashlib
import shutil
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

from lib.common import (
    BUILD_DIR,
    PROJECT_DIR,
    fail,
    remove_path,
    run_main,
)
from lib.console import info, spinner, success, warning
from lib.extract_runtime import extract
from lib.licenses import stage_runtime_legal
from lib.project_config import load_project_configuration
from runtime_config import (
    MAXIMUM_RUNTIME_ARCHIVE_BYTES,
    RuntimeLayout,
    load_runtime_config,
    runtime_is_valid,
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, output: Path, expected_sha256: str, user_agent: str) -> None:
    """Fetch `url` with a resumable curl transfer, verify it, and rename it into place."""
    if output.is_file() and sha256(output) == expected_sha256:
        info("Using the verified runtime archive from the local cache")
        return

    partial = output.with_suffix(output.suffix + ".part")
    command = [
        "curl",
        "--fail",
        "--location",
        "--proto",
        "=https",
        "--proto-redir",
        "=https",
        "--max-filesize",
        str(MAXIMUM_RUNTIME_ARCHIVE_BYTES),
        "--user-agent",
        user_agent,
        "--continue-at",
        "-",
        "--output",
        str(partial),
        *(["--progress-bar"] if sys.stderr.isatty() else ["--silent", "--show-error"]),
        url,
    ]
    info("Downloading the pinned Wine + DXMT runtime")
    try:
        result = subprocess.run(command, check=False)
    except OSError as error:
        fail(f"unable to run curl: {error}")
    if result.returncode != 0:
        # Keep the .part file so the next run resumes it.
        fail(f"unable to download the runtime: curl exited with {result.returncode}")

    if partial.stat().st_size > MAXIMUM_RUNTIME_ARCHIVE_BYTES:
        partial.unlink()
        fail("runtime archive exceeds the download size limit")
    actual_sha256 = sha256(partial)
    if actual_sha256 != expected_sha256:
        partial.unlink()
        fail(
            "downloaded runtime failed SHA-256 verification "
            f"(expected {expected_sha256}, got {actual_sha256})"
        )
    partial.replace(output)


def prepare_runtime(
    url: str,
    checksum: str,
    layout: RuntimeLayout,
    user_agent: str,
) -> Path:
    destination = BUILD_DIR / "runtime"
    revision_file = destination / ".arknights-runtime-archive-sha256"
    if (
        revision_file.is_file()
        and revision_file.read_text(encoding="utf-8").strip() == checksum
        and runtime_is_valid(destination, layout)
    ):
        info("The prepared runtime is already current")
        return destination

    cache_dir = BUILD_DIR / "runtime-downloads"
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive = cache_dir / f"{checksum}.tar.gz"
    download(url, archive, checksum, user_agent)

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".runtime-download.", dir=BUILD_DIR
    ) as name:
        staging = Path(name)
        with spinner("Extracting the verified runtime"):
            libraries = extract(archive, staging / "runtime-archive")
        wine = libraries / layout.archive_wine_directory
        dxmt = libraries / layout.archive_dxmt_directory
        if not wine.is_dir() or not dxmt.is_dir():
            fail("runtime archive does not contain Wine and DXMT")

        runtime = staging / "runtime"
        wine.replace(runtime)
        dxmt_destination = runtime / layout.dxmt.payload_directory
        dxmt_destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(dxmt, dxmt_destination)
        capability_manifest = libraries / layout.capability_manifest_path
        try:
            manifest_status = capability_manifest.lstat()
        except FileNotFoundError:
            manifest_status = None
        except OSError as error:
            fail(f"unable to inspect runtime capability manifest: {error}")
        if manifest_status is not None:
            if (
                not stat.S_ISREG(manifest_status.st_mode)
                or manifest_status.st_nlink != 1
            ):
                fail("runtime capability manifest must be a regular, unlinked file")
            capability_manifest.replace(runtime / layout.capability_manifest_path)
        if not stage_runtime_legal(libraries.parent, runtime):
            warning("Runtime archive has no Licenses/ directory")
        launcher = runtime / layout.launcher.path
        launcher.parent.mkdir(parents=True, exist_ok=True)
        if not launcher.exists() and not launcher.is_symlink():
            warning("Runtime archive is missing the launcher alias; adding it")
            launcher.symlink_to(layout.launcher.target)
        if not runtime_is_valid(runtime, layout):
            fail("runtime archive is incomplete")
        (runtime / ".arknights-runtime-archive-sha256").write_text(
            f"{checksum}\n", encoding="utf-8"
        )
        remove_path(destination)
        runtime.replace(destination)
    success("Runtime is ready")
    return destination


def main() -> None:
    project_configuration = load_project_configuration()
    config_path = PROJECT_DIR / "runtime.json"
    config = load_runtime_config(config_path)

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--url", default=config.runtime_url)
    parser.add_argument("--sha256", default=config.runtime_sha256)
    arguments = parser.parse_args()
    if not arguments.url.startswith("https://"):
        fail("runtime URL must use HTTPS")
    if len(arguments.sha256) != 64 or any(
        character not in "0123456789abcdefABCDEF" for character in arguments.sha256
    ):
        fail("runtime checksum must be a 64-character SHA-256 value")
    print(
        prepare_runtime(
            arguments.url,
            arguments.sha256.lower(),
            config.layout,
            f"{project_configuration.product.bundle_identifier}.build",
        )
    )


if __name__ == "__main__":
    run_main(main)
