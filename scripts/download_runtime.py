#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Download and prepare the runtime pinned for one architecture."""

from __future__ import annotations

import argparse
import hashlib
import shutil
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
from lib.console import info, success, warning
from lib.extract_runtime import extract
from lib.licenses import stage_runtime_legal
from lib.project_config import load_project_configuration
from runtime_config import (
    MAXIMUM_RUNTIME_ARCHIVE_BYTES,
    PREPARED_REVISION_FILE,
    RUNTIME_ARCHITECTURES,
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


def download(
    url: str,
    output: Path,
    expected_sha256: str,
    user_agent: str,
    expected_size: int | None = None,
) -> None:
    """Fetch `url` with a resumable curl transfer, verify it, and rename it into place."""
    if (
        output.is_file()
        and sha256(output) == expected_sha256
        and (expected_size is None or output.stat().st_size == expected_size)
    ):
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
    info("Downloading the pinned runtime")
    try:
        result = subprocess.run(command, check=False)
    except OSError as error:
        fail(f"unable to run curl: {error}")
    if result.returncode != 0:
        # Keep the .part file so the next run resumes it.
        fail(f"unable to download the runtime: curl exited with {result.returncode}")

    actual_size = partial.stat().st_size
    if actual_size > MAXIMUM_RUNTIME_ARCHIVE_BYTES:
        partial.unlink()
        fail("runtime archive exceeds the download size limit")
    if expected_size is not None and actual_size != expected_size:
        partial.unlink()
        fail(
            "downloaded runtime failed size verification "
            f"(expected {expected_size} bytes, got {actual_size})"
        )
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
    size_bytes: int,
    layout: RuntimeLayout,
    architecture: str,
    user_agent: str,
) -> Path:
    destination = BUILD_DIR / f"runtime-{architecture}"
    revision_file = destination / PREPARED_REVISION_FILE
    if (
        revision_file.is_file()
        and revision_file.read_text(encoding="utf-8").strip() == checksum
        and runtime_is_valid(destination, layout)
    ):
        info(f"The prepared {architecture} runtime is already current")
        return destination

    cache_dir = BUILD_DIR / "runtime-downloads"
    cache_dir.mkdir(parents=True, exist_ok=True)
    archive = cache_dir / f"{checksum}.tar.gz"
    download(url, archive, checksum, user_agent, size_bytes)

    BUILD_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(
        prefix=".runtime-download.", dir=BUILD_DIR
    ) as name:
        staging = Path(name)
        info("Extracting the verified runtime")
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
        if not stage_runtime_legal(libraries.parent, runtime):
            warning("Runtime archive has no Licenses/ directory")
        launcher = runtime / layout.launcher.path
        launcher.parent.mkdir(parents=True, exist_ok=True)
        if not launcher.exists() and not launcher.is_symlink():
            warning("Runtime archive is missing the launcher alias; adding it")
            launcher.symlink_to(layout.launcher.target)
        if not runtime_is_valid(runtime, layout):
            fail(f"runtime archive does not satisfy the {architecture} interface")
        (runtime / PREPARED_REVISION_FILE).write_text(f"{checksum}\n", encoding="utf-8")
        remove_path(destination)
        runtime.replace(destination)
    success(f"The {architecture} runtime is ready")
    return destination


def main() -> None:
    project_configuration = load_project_configuration()
    config = load_runtime_config(PROJECT_DIR / "runtime.json")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--architecture",
        required=True,
        choices=tuple(RUNTIME_ARCHITECTURES),
        help="runtime lane to download",
    )
    arguments = parser.parse_args()
    lane = config.lane(arguments.architecture)
    if not lane.runtime.is_available:
        fail(f"the {lane.name} runtime has no published pin yet")
    print(
        prepare_runtime(
            lane.runtime.url,
            lane.runtime.sha256,
            lane.runtime.size_bytes,
            lane.layout,
            lane.name,
            f"{project_configuration.product.bundle_identifier}.build",
        )
    )


if __name__ == "__main__":
    run_main(main)
