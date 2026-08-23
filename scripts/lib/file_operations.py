# SPDX-License-Identifier: MPL-2.0

"""Shared file-copy operations for packaging scripts."""

from __future__ import annotations

import shutil
from pathlib import Path

from lib.common import fail


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
