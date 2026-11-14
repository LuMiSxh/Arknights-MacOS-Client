# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from types import SimpleNamespace

from lib import swift_build
from lib.project_config import load_project_configuration


def test_swift_build_passes_active_sdk_to_swiftpm_and_linker(
    monkeypatch,
) -> None:
    configuration = load_project_configuration()
    captured: dict[str, object] = {}

    def fake_run(command, **kwargs):
        captured["command"] = command
        captured.update(kwargs)
        return SimpleNamespace(stdout="")

    monkeypatch.setattr(
        swift_build, "active_macos_sdk", lambda sdk_name: ("/SDK", "27.0")
    )
    monkeypatch.setattr(swift_build, "run", fake_run)

    swift_build.run_swift_build(configuration, "debug")

    assert captured["command"][-4:] == (
        "-Xlinker",
        "15.0",
        "-Xlinker",
        "27.0",
    )
    assert captured["environment"]["SDKROOT"] == "/SDK"
    assert captured["command"][:4] == ("xcrun", "--sdk", "macosx", "swift")
