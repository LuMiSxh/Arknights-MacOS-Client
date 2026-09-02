#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Download, verify, and prepare the runtime pinned in runtime.json."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

from lib.common import (
    BUILD_DIR,
    PROJECT_DIR,
    fail,
    remove_path,
    run_main,
)
from lib.console import Progress, info, spinner, success, warning
from lib.extract_runtime import extract
from lib.project_config import load_project_configuration
from runtime_config import (
    MAXIMUM_RUNTIME_ARCHIVE_BYTES,
    RuntimeLayout,
    load_runtime_config,
    runtime_is_valid,
)

CONTENT_RANGE_PATTERN = re.compile(r"^bytes ([0-9]+)-([0-9]+)/([0-9]+)$")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        while chunk := file.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def download(url: str, output: Path, expected_sha256: str, user_agent: str) -> None:
    if output.is_file() and sha256(output) == expected_sha256:
        info("Using the verified runtime archive from the local cache")
        return

    partial = output.with_suffix(output.suffix + ".part")
    metadata_path = Path(f"{partial}.json")
    offset, etag = _resume_state(partial, metadata_path, url)
    headers = {"User-Agent": user_agent}
    if offset:
        headers.update({"Range": f"bytes={offset}-", "If-Range": etag})
    request = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            redirected = urllib.parse.urlparse(response.geturl())
            if redirected.scheme != "https" or not redirected.hostname:
                fail("runtime download redirected to a non-HTTPS URL")
            status = getattr(response, "status", 200)
            response_etag = _strong_etag(response.headers.get("ETag"))
            if offset and status == 206:
                total = _validated_content_range(
                    response.headers.get("Content-Range"), offset
                )
                if response_etag != etag:
                    fail("runtime download resume ETag changed")
                mode = "ab"
            elif status == 200:
                offset = 0
                total = None
                mode = "wb"
            else:
                fail(f"runtime download returned unexpected HTTP status {status}")

            content_length = _content_length(response.headers.get("Content-Length"))
            if content_length is not None:
                if content_length > MAXIMUM_RUNTIME_ARCHIVE_BYTES - offset:
                    fail("runtime archive exceeds the download size limit")
                expected_total = offset + content_length
                if total is not None and expected_total != total:
                    fail("runtime download Content-Length and Content-Range disagree")
                total = expected_total
            if total is not None and total > MAXIMUM_RUNTIME_ARCHIVE_BYTES:
                fail("runtime archive exceeds the download size limit")

            if response_etag is None:
                metadata_path.unlink(missing_ok=True)
            else:
                metadata_path.write_text(
                    json.dumps({"url": url, "etag": response_etag}), encoding="utf-8"
                )
            received = offset
            progress = Progress(
                "Downloading the pinned Wine + DXMT runtime", total or 0
            )
            with partial.open(mode) as file:
                while chunk := response.read(1024 * 1024):
                    if len(chunk) > MAXIMUM_RUNTIME_ARCHIVE_BYTES - received:
                        fail("runtime archive exceeds the download size limit")
                    file.write(chunk)
                    received += len(chunk)
                    progress.update(received)
                file.flush()
                os.fsync(file.fileno())
            progress.finish()
    except (OSError, urllib.error.URLError) as download_error:
        fail(f"unable to download the runtime: {download_error}")

    actual_sha256 = sha256(partial)
    if actual_sha256 != expected_sha256:
        partial.unlink(missing_ok=True)
        metadata_path.unlink(missing_ok=True)
        fail(
            "downloaded runtime failed SHA-256 verification "
            f"(expected {expected_sha256}, got {actual_sha256})"
        )
    partial.replace(output)
    metadata_path.unlink(missing_ok=True)


def _resume_state(partial: Path, metadata_path: Path, url: str) -> tuple[int, str]:
    metadata: object = None
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
        etag = _strong_etag(
            metadata.get("etag") if isinstance(metadata, dict) else None
        )
    except (OSError, json.JSONDecodeError):
        etag = None
    if (
        isinstance(metadata, dict)
        and metadata.get("url") == url
        and etag is not None
        and partial.is_file()
        and not partial.is_symlink()
        and 0 < partial.stat().st_size <= MAXIMUM_RUNTIME_ARCHIVE_BYTES
    ):
        return partial.stat().st_size, etag
    partial.unlink(missing_ok=True)
    metadata_path.unlink(missing_ok=True)
    return 0, ""


def _strong_etag(value: object) -> str | None:
    if not isinstance(value, str) or len(value) < 2 or value.startswith("W/"):
        return None
    if (
        value[0] != '"'
        or value[-1] != '"'
        or any(ord(character) < 0x20 or character == '"' for character in value[1:-1])
    ):
        return None
    return value


def _content_length(value: object) -> int | None:
    if value is None:
        return None
    if (
        not isinstance(value, str)
        or len(value) > 20
        or not value.isascii()
        or not value.isdecimal()
    ):
        fail("runtime download returned an invalid Content-Length")
    return int(value)


def _validated_content_range(value: object, offset: int) -> int:
    match = CONTENT_RANGE_PATTERN.fullmatch(value) if isinstance(value, str) else None
    if match is None or any(len(component) > 20 for component in match.groups()):
        fail("runtime download returned an invalid Content-Range")
    start, end, total = (int(component) for component in match.groups())
    if start != offset or end < start or end >= total:
        fail("runtime download returned an invalid Content-Range")
    return total


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
