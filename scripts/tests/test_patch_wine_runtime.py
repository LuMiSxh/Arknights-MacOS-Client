# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import pytest
from lib import patch_wine_runtime


def test_changes_only_the_quit_shortcut() -> None:
    source = (
        b"before"
        + patch_wine_runtime.OPTION_COMMAND_Q
        + b"middle"
        + patch_wine_runtime.OPTION_COMMAND_Q
        + b"after"
    )

    patched, changed = patch_wine_runtime.patch_quit_shortcut(source)

    assert changed
    assert patched.count(patch_wine_runtime.OPTION_COMMAND_Q) == 1
    assert patched.count(patch_wine_runtime.COMMAND_Q) == 1
    assert patched.startswith(b"before")
    assert patched.endswith(b"after")


def test_accepts_an_already_patched_driver() -> None:
    source = (
        patch_wine_runtime.OPTION_COMMAND_Q + b"middle" + patch_wine_runtime.COMMAND_Q
    )

    patched, changed = patch_wine_runtime.patch_quit_shortcut(source)

    assert not changed
    assert patched == source


def test_rejects_an_unknown_driver_layout() -> None:
    with pytest.raises(RuntimeError):
        patch_wine_runtime.patch_quit_shortcut(b"unknown")
