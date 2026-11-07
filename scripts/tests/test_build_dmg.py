# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import sys

import build_dmg
import pytest


@pytest.mark.parametrize("option", ["--runtime", "--runtime-architecture"])
def test_rejects_the_removed_runtime_options(
    monkeypatch: pytest.MonkeyPatch, option: str
) -> None:
    monkeypatch.setattr(sys, "argv", ["build_dmg.py", option, "value"])

    with pytest.raises(SystemExit) as error:
        build_dmg.main()

    assert error.value.code == 2
