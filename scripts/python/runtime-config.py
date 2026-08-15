# SPDX-License-Identifier: MPL-2.0

"""Read and validate the pinned runtime configuration."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

REQUIRED_STRING_KEYS = (
    "runtime.name",
    "runtime.url",
    "runtime.sha256",
    "buildRecipe.url",
    "buildRecipe.sha256",
    "components.wine",
    "components.dxmt",
    "components.gstreamer",
    "components.ffmpeg",
    "components.moltenvk",
    "components.wineGecko",
    "provenance.buildRepository",
    "provenance.buildCommit",
    "provenance.wineRepository",
    "provenance.wineCommit",
    "provenance.dxmtRepository",
    "provenance.dxmtCommit",
    "provenance.moltenvkRepository",
    "provenance.moltenvkCommit",
    "provenance.gstreamerRepository",
    "provenance.gstreamerCommit",
    "provenance.ffmpegRepository",
    "provenance.ffmpegCommit",
    "provenance.wineGeckoRepository",
    "provenance.wineGeckoCommit",
    "provenance.nixpkgsRepository",
    "provenance.nixpkgsCommit",
)
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")


def fail(message: str) -> None:
    raise SystemExit(f"error: {message}")


def read_config(config: Path) -> dict[str, Any]:
    try:
        value: Any = json.loads(config.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"unable to read {config}: {error}")
    if not isinstance(value, dict):
        fail("runtime configuration root must be an object")
    return value


def nested_value(config: dict[str, Any], key: str) -> Any:
    value: Any = config

    for component in key.split("."):
        if not isinstance(value, dict) or component not in value:
            fail(f"runtime configuration has no value for {key}")
        value = value[component]
    return value


def read_value(config: Path, key: str) -> str:
    value = nested_value(read_config(config), key)

    if not isinstance(value, (str, int, float, bool)):
        fail(f"runtime configuration value is not scalar: {key}")
    return str(value).lower() if isinstance(value, bool) else str(value)


def validate_config(config_path: Path) -> None:
    config = read_config(config_path)
    if nested_value(config, "schemaVersion") != 1:
        fail("runtime configuration schemaVersion must be 1")
    if (
        not isinstance(nested_value(config, "prefixRevision"), int)
        or nested_value(config, "prefixRevision") < 1
    ):
        fail("runtime configuration prefixRevision must be a positive integer")

    values: dict[str, str] = {}
    for key in REQUIRED_STRING_KEYS:
        value = nested_value(config, key)
        if not isinstance(value, str) or not value:
            fail(f"runtime configuration value must be a non-empty string: {key}")
        values[key] = value

    repository_keys = tuple(
        key for key in REQUIRED_STRING_KEYS if key.endswith("Repository")
    )
    for key in ("runtime.url", "buildRecipe.url", *repository_keys):
        if not values[key].startswith("https://"):
            fail(f"runtime configuration URL must use HTTPS: {key}")
    for key in ("runtime.sha256", "buildRecipe.sha256"):
        if not SHA256_PATTERN.fullmatch(values[key]):
            fail(f"runtime configuration checksum must be lowercase SHA-256: {key}")
    for key in (
        "provenance.buildCommit",
        "provenance.wineCommit",
        "provenance.dxmtCommit",
        "provenance.moltenvkCommit",
        "provenance.gstreamerCommit",
        "provenance.ffmpegCommit",
        "provenance.wineGeckoCommit",
        "provenance.nixpkgsCommit",
    ):
        if not COMMIT_PATTERN.fullmatch(values[key]):
            fail(f"runtime configuration commit must be a lowercase Git commit: {key}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--validate", action="store_true")
    parser.add_argument("config", type=Path)
    parser.add_argument("key", nargs="?")
    arguments = parser.parse_args()
    if arguments.validate:
        if arguments.key is not None:
            parser.error("a key cannot be used with --validate")
        validate_config(arguments.config)
        return
    if arguments.key is None:
        parser.error("a key is required unless --validate is used")
    print(read_value(arguments.config, arguments.key))


if __name__ == "__main__":
    main()
