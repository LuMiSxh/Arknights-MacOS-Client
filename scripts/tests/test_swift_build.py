# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import os
import subprocess
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


def test_just_preview_builds_before_launching(tmp_path) -> None:
    fake_uv = tmp_path / "fake-uv"
    fake_uv.write_text(
        """#!/bin/sh
printf '%s\\n' "$*" >> "$PREVIEW_TEST_LOG"
case "$*" in
  *scripts/swift_build.py*--show-bin-path*) printf '%s\\n' "$PREVIEW_TEST_BIN" ;;
  *scripts/project_config.py*executable-name*) printf '%s\\n' PreviewBinary ;;
esac
""",
        encoding="utf-8",
    )
    fake_uv.chmod(0o755)
    binary_dir = tmp_path / "bin"
    binary_dir.mkdir()
    binary = binary_dir / "PreviewBinary"
    binary.write_text(
        '#!/bin/sh\nprintf \'launch %s\\n\' "$*" >> "$PREVIEW_TEST_LOG"\n',
        encoding="utf-8",
    )
    binary.chmod(0o755)
    log = tmp_path / "preview.log"
    environment = os.environ | {
        "PREVIEW_TEST_BIN": str(binary_dir),
        "PREVIEW_TEST_LOG": str(log),
    }

    subprocess.run(
        ["just", "--set", "uv", str(fake_uv), "preview"],
        cwd=PROJECT_DIR,
        env=environment,
        check=True,
    )

    commands = log.read_text(encoding="utf-8").splitlines()
    builds = [command for command in commands if "scripts/swift_build.py" in command]
    assert len(builds) == 2
    assert "--show-bin-path" not in builds[0]
    assert "--sdk macosx27.0" in builds[0]
    assert "--show-bin-path" in builds[1]
    assert commands[-1] == "launch --developer-preview"


def test_just_release_build_uses_the_sdk_aware_builder() -> None:
    justfile = (PROJECT_DIR / "justfile").read_text(encoding="utf-8")

    assert "scripts/swift_build.py --configuration release" in justfile
    assert "swift run --skip-build" not in justfile
