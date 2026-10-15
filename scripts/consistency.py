#!/usr/bin/env -S uv run --locked
# SPDX-License-Identifier: MPL-2.0

"""Check the bundled-resource registry, runtime.json, license inventory, and runtime pin."""

from __future__ import annotations

from lib.bundled_resources import registry_drift
from lib.common import PROJECT_DIR, fail, run_main
from lib.console import info, warning
from lib.licenses import check_all
from lib.project_config import load_project_configuration
from lib.runtime_update import check as check_runtime_pin
from runtime_config import load_runtime_config


def main() -> None:
    info("Checking the bundled resource registry")
    drift = registry_drift(load_project_configuration())
    if drift:
        fail(
            "Swift BundledResource and scripts/lib/bundled_resources.py differ:\n"
            + "\n".join(drift)
        )
    info("Checking runtime.json")
    load_runtime_config(PROJECT_DIR / "runtime.json")
    info("Checking the third-party license inventory")
    for message in check_all(PROJECT_DIR):
        warning(message)
    info("Checking the runtime pin and its generated blocks")
    check_runtime_pin(PROJECT_DIR)


if __name__ == "__main__":
    run_main(main)
