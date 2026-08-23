# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from pathlib import Path, PurePosixPath

import download_runtime
import pytest
from lib.common import PROJECT_DIR
from runtime_config import RuntimeLayout, load_runtime_config


@pytest.fixture(scope="module")
def layout() -> RuntimeLayout:
    return load_runtime_config(PROJECT_DIR / "runtime.json").layout


def create_runtime(runtime: Path, layout: RuntimeLayout) -> None:
    for relative in layout.required_paths:
        path = runtime / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
    for relative in layout.executables:
        (runtime / relative).chmod(0o755)
    launcher = runtime / layout.launcher.path
    launcher.parent.mkdir(parents=True, exist_ok=True)
    launcher.symlink_to(layout.launcher.target)


def test_accepts_complete_runtime_layout(tmp_path: Path, layout: RuntimeLayout) -> None:
    create_runtime(tmp_path, layout)

    assert download_runtime.runtime_is_valid(tmp_path, layout)


def test_rejects_wrong_launcher_link(tmp_path: Path, layout: RuntimeLayout) -> None:
    create_runtime(tmp_path, layout)
    launcher = tmp_path / layout.launcher.path
    launcher.unlink()
    launcher.symlink_to("wrong")

    assert not download_runtime.runtime_is_valid(tmp_path, layout)


def test_rejects_executable_directory(tmp_path: Path, layout: RuntimeLayout) -> None:
    create_runtime(tmp_path, layout)
    executable = tmp_path / layout.executables[0]
    executable.unlink()
    executable.mkdir()

    assert not download_runtime.runtime_is_valid(tmp_path, layout)


@pytest.mark.parametrize(
    "missing",
    load_runtime_config(PROJECT_DIR / "runtime.json").layout.required_paths,
    ids=str,
)
def test_rejects_every_missing_declared_runtime_path(
    tmp_path: Path, layout: RuntimeLayout, missing: PurePosixPath
) -> None:
    create_runtime(tmp_path, layout)
    (tmp_path / missing).unlink()

    assert not download_runtime.runtime_is_valid(tmp_path, layout)
