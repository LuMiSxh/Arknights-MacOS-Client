# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import hashlib
import io
import subprocess
import tarfile
from pathlib import Path, PurePosixPath

import download_runtime
import pytest
from runtime_config import (
    DXMTLayout,
    RuntimeFeatures,
    RuntimeLayout,
    RuntimeSymlink,
)


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def layout() -> RuntimeLayout:
    return RuntimeLayout(
        archive_wine_directory=PurePosixPath("Wine"),
        archive_dxmt_directory=PurePosixPath("DXMT"),
        features=RuntimeFeatures(True, True, True),
        executables=(PurePosixPath("bin/wine64"), PurePosixPath("bin/wineserver")),
        required_files=(
            PurePosixPath("lib/wine/aarch64-unix/winecoreaudio.so"),
            PurePosixPath("lib/wine/aarch64-windows/winemetal.dll"),
        ),
        mac_driver=PurePosixPath("lib/wine/aarch64-unix/winemac.so"),
        launcher=RuntimeSymlink(
            path=PurePosixPath("bin/Arknights"), target=PurePosixPath("wine64")
        ),
        dxmt=DXMTLayout(
            payload_directory=PurePosixPath("DXMT"),
            destinations=(("x64", "system32"),),
            libraries=("d3d10core.dll", "d3d11.dll", "dxgi.dll"),
        ),
    )


def create_runtime(runtime: Path) -> None:
    files = layout()
    for relative in files.required_paths:
        path = runtime / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
    for relative in files.executables:
        (runtime / relative).chmod(0o755)
    launcher = runtime / files.launcher.path
    launcher.parent.mkdir(parents=True, exist_ok=True)
    launcher.symlink_to(files.launcher.target)


URL = "https://example.invalid/runtime.tar.gz"


class FakeCurl:
    """Stand-in for the curl subprocess that appends `body` to the `.part` file."""

    def __init__(self, body: bytes, returncode: int = 0) -> None:
        self.body, self.returncode = body, returncode
        self.commands: list[list[str]] = []

    def __call__(self, command: list[str], **_: object) -> subprocess.CompletedProcess:
        self.commands.append(command)
        partial = Path(command[command.index("--output") + 1])
        with partial.open("ab") as file:
            file.write(self.body)
        return subprocess.CompletedProcess(command, self.returncode)


def test_download_runs_hardened_resumable_curl_and_renames(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    partial = tmp_path / "runtime.tar.gz.part"
    partial.write_bytes(b"prefix")
    curl = FakeCurl(b"suffix")
    monkeypatch.setattr(subprocess, "run", curl)

    download_runtime.download(
        URL, output, digest(b"prefixsuffix"), "fixture-agent", len(b"prefixsuffix")
    )

    command = curl.commands[0]
    assert command[0] == "curl"
    assert command[-1] == URL
    for flag in ("--fail", "--location"):
        assert flag in command
    assert command[command.index("--proto") + 1] == "=https"
    assert command[command.index("--proto-redir") + 1] == "=https"
    assert command[command.index("--continue-at") + 1] == "-"
    assert command[command.index("--user-agent") + 1] == "fixture-agent"
    assert output.read_bytes() == b"prefixsuffix"
    assert not partial.exists()


def test_download_skips_curl_for_verified_cache(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    output.write_bytes(b"runtime")
    curl = FakeCurl(b"")
    monkeypatch.setattr(subprocess, "run", curl)

    download_runtime.download(URL, output, digest(b"runtime"), "fixture-agent", 7)

    assert curl.commands == []


def test_download_rejects_checksum_mismatch_and_removes_partial(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    monkeypatch.setattr(subprocess, "run", FakeCurl(b"tampered"))

    with pytest.raises(RuntimeError, match="SHA-256"):
        download_runtime.download(URL, output, digest(b"runtime"), "fixture-agent")

    assert not output.exists()
    assert not (tmp_path / "runtime.tar.gz.part").exists()


def test_download_rejects_a_wrong_size_and_removes_partial(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    body = b"runtime"
    monkeypatch.setattr(subprocess, "run", FakeCurl(body))

    with pytest.raises(RuntimeError, match="size verification"):
        download_runtime.download(
            URL, output, digest(body), "fixture-agent", len(body) + 1
        )

    assert not output.exists()
    assert not (tmp_path / "runtime.tar.gz.part").exists()


def test_download_enforces_archive_ceiling(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    monkeypatch.setattr(download_runtime, "MAXIMUM_RUNTIME_ARCHIVE_BYTES", 10)
    monkeypatch.setattr(subprocess, "run", FakeCurl(b"x" * 11))

    with pytest.raises(RuntimeError, match="size limit"):
        download_runtime.download(URL, output, digest(b"x" * 11), "fixture-agent")

    assert not output.exists()
    assert not (tmp_path / "runtime.tar.gz.part").exists()


def test_download_preserves_partial_after_curl_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    partial = tmp_path / "runtime.tar.gz.part"
    monkeypatch.setattr(subprocess, "run", FakeCurl(b"prefix", returncode=18))

    with pytest.raises(RuntimeError, match="unable to download"):
        download_runtime.download(URL, output, digest(b""), "fixture-agent")

    assert partial.read_bytes() == b"prefix"
    assert not output.exists()


def test_accepts_complete_runtime_layout(tmp_path: Path) -> None:
    create_runtime(tmp_path)

    assert download_runtime.runtime_is_valid(tmp_path, layout())


def test_accepts_executable_symlink_within_runtime(tmp_path: Path) -> None:
    files = layout()
    create_runtime(tmp_path)
    executable = tmp_path / files.executables[0]
    target = executable.with_name("internal-executable")
    executable.replace(target)
    executable.symlink_to(target.name)

    assert download_runtime.runtime_is_valid(tmp_path, files)


@pytest.mark.parametrize(
    "mutation", ("wrong-link", "executable-directory", "file-link", "outside-root")
)
def test_rejects_invalid_runtime_layout(tmp_path: Path, mutation: str) -> None:
    files = layout()
    runtime = tmp_path / "runtime" if mutation == "outside-root" else tmp_path
    create_runtime(runtime)
    if mutation == "wrong-link":
        launcher = runtime / files.launcher.path
        launcher.unlink()
        launcher.symlink_to("wrong")
    elif mutation == "executable-directory":
        executable = runtime / files.executables[0]
        executable.unlink()
        executable.mkdir()
    elif mutation == "file-link":
        required = runtime / files.required_regular_files[0]
        target = required.with_name("real-file")
        required.replace(target)
        required.symlink_to(target.name)
    else:
        outside = tmp_path / "outside"
        executable = runtime / files.executables[0]
        escaped_parent = executable.parent
        outside_parent = outside / escaped_parent.relative_to(runtime)
        outside_parent.parent.mkdir(parents=True, exist_ok=True)
        escaped_parent.replace(outside_parent)
        escaped_parent.symlink_to(outside_parent)
    assert not download_runtime.runtime_is_valid(runtime, files)


@pytest.mark.parametrize("missing", layout().required_paths, ids=str)
def test_rejects_every_missing_declared_runtime_path(
    tmp_path: Path, missing: PurePosixPath
) -> None:
    create_runtime(tmp_path)
    (tmp_path / missing).unlink()

    assert not download_runtime.runtime_is_valid(tmp_path, layout())


def archive_bytes() -> bytes:
    files = layout()
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode="w:gz") as archive:
        for relative in files.required_paths:
            if relative == files.launcher.path or relative.is_relative_to(
                files.dxmt.payload_directory
            ):
                continue
            data = b"#!/bin/sh\n" if relative in files.executables else b""
            info = tarfile.TarInfo(f"Libraries/Wine/{relative}")
            info.size = len(data)
            info.mode = 0o755 if relative in files.executables else 0o644
            archive.addfile(info, io.BytesIO(data))
        launcher = tarfile.TarInfo(f"Libraries/Wine/{files.launcher.path}")
        launcher.type = tarfile.SYMTYPE
        launcher.linkname = str(files.launcher.target)
        archive.addfile(launcher)
        for library in files.dxmt.libraries:
            data = b""
            info = tarfile.TarInfo(f"Libraries/DXMT/x64/{library}")
            info.size = 0
            archive.addfile(info, io.BytesIO(data))
        notice = b"notice"
        info = tarfile.TarInfo("NOTICE.md")
        info.size = len(notice)
        archive.addfile(info, io.BytesIO(notice))
        license_text = b"MIT"
        info = tarfile.TarInfo("Licenses/index.json")
        info.size = len(license_text)
        archive.addfile(info, io.BytesIO(license_text))
    return buffer.getvalue()


def test_prepare_runtime_selects_the_lane_directory(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    payload = archive_bytes()
    monkeypatch.setattr(download_runtime, "BUILD_DIR", tmp_path / ".build")
    monkeypatch.setattr(subprocess, "run", FakeCurl(payload))
    other = tmp_path / ".build/runtime-x86"
    other.mkdir(parents=True)
    (other / "keep").write_text("untouched", encoding="utf-8")

    destination = download_runtime.prepare_runtime(
        URL,
        digest(payload),
        len(payload),
        layout(),
        "arm",
        "fixture-agent",
    )

    assert destination == tmp_path / ".build/runtime-arm"
    assert (destination / "bin/wine64").is_file()
    assert (destination / "DXMT/x64/dxgi.dll").is_file()
    assert (destination / "Licenses/index.json").is_file()
    assert (destination / "NOTICE.md").is_file()
    assert (destination / download_runtime.PREPARED_REVISION_FILE).read_text(
        encoding="utf-8"
    ).strip() == digest(payload)
    assert (other / "keep").read_text(encoding="utf-8") == "untouched"
