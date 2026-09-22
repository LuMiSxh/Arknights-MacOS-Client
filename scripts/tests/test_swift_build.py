# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

from types import SimpleNamespace

from lib import swift_build
from lib.common import PROJECT_DIR
from lib.project_config import ProjectConfiguration, load_project_configuration


def test_preview_build_records_active_sdk_separately_from_minimum() -> None:
    configuration: ProjectConfiguration = load_project_configuration()
    command = swift_build.swift_build_command(configuration, "debug", "27.0")

    assert command == (
        "xcrun",
        "--sdk",
        "macosx",
        "swift",
        "build",
        "--configuration",
        "debug",
        "--arch",
        "arm64",
        "-Xlinker",
        "-platform_version",
        "-Xlinker",
        "macos",
        "-Xlinker",
        "15.0",
        "-Xlinker",
        "27.0",
    )


def test_preview_build_selects_the_xcode_27_macos_sdk() -> None:
    configuration: ProjectConfiguration = load_project_configuration()
    command = swift_build.swift_build_command(
        configuration, "debug", "27.0", sdk_name="macosx27.0"
    )

    assert command[:4] == ("xcrun", "--sdk", "macosx27.0", "swift")


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


def test_just_build_recipes_use_the_sdk_aware_builder() -> None:
    justfile = (PROJECT_DIR / "justfile").read_text(encoding="utf-8")

    assert (
        "scripts/swift_build.py --configuration debug --sdk macosx27.0 --show-bin-path"
        in justfile
    )
    assert "scripts/swift_build.py --configuration release" in justfile
    assert "swift run --skip-build" not in justfile
