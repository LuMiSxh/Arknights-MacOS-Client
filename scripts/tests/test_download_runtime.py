# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import hashlib
import json
import shutil
import subprocess
import tarfile
from pathlib import Path, PurePosixPath

import download_runtime
import pytest
from lib.common import PROJECT_DIR
from runtime_config import RuntimeLayout, load_runtime_config


def digest(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


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


def write_runtime_archive(
    archive: Path,
    root: Path,
    layout: RuntimeLayout,
    *,
    manifest: bytes | None,
    manifest_symlink: bool = False,
) -> None:
    libraries = root / "Libraries"
    wine = libraries / layout.archive_wine_directory
    wine.mkdir(parents=True)
    for relative in (*layout.executables, *layout.required_files, layout.mac_driver):
        path = wine / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
    for relative in layout.executables:
        (wine / relative).chmod(0o755)
    launcher = wine / layout.launcher.path
    launcher.parent.mkdir(parents=True, exist_ok=True)
    launcher.symlink_to(layout.launcher.target)

    dxmt = libraries / layout.archive_dxmt_directory
    for architecture, _ in layout.dxmt.destinations:
        for library in layout.dxmt.libraries:
            path = dxmt / architecture / library
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
    if manifest is not None or manifest_symlink:
        manifest_path = libraries / layout.capability_manifest_path
        if manifest_symlink:
            manifest_path.symlink_to("Wine/bin/wine64")
        else:
            manifest_path.write_bytes(manifest or b"")

    with tarfile.open(archive, "w:gz") as contents:
        contents.add(libraries, arcname="Libraries")


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

    download_runtime.download(URL, output, digest(b"prefixsuffix"), "fixture-agent")

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

    download_runtime.download(URL, output, digest(b"runtime"), "fixture-agent")

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


@pytest.mark.parametrize("sidecar", ["present", "missing", "symlink"])
def test_prepare_runtime_preserves_only_regular_capability_sidecar(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    layout: RuntimeLayout,
    sidecar: str,
) -> None:
    archive = tmp_path / "fixture.tar.gz"
    manifest = json.dumps(
        {
            "schemaVersion": 1,
            "capabilities": {
                "dxmtMaximumFrameLatency": {
                    "minimum": 0,
                    "maximum": 3,
                    "defaultValue": 3,
                },
                "hardwareCursor": True,
            },
        }
    ).encode()
    write_runtime_archive(
        archive,
        tmp_path / "source",
        layout,
        manifest=manifest,
        manifest_symlink=sidecar == "symlink",
    )
    if sidecar == "missing":
        # Recreate without a sidecar to model the verified legacy 0.6.0 archive.
        write_runtime_archive(
            archive,
            tmp_path / "legacy-source",
            layout,
            manifest=None,
        )

    def use_fixture_archive(
        url: str, output: Path, checksum: str, user_agent: str
    ) -> None:
        shutil.copyfile(archive, output)

    monkeypatch.setattr(download_runtime, "BUILD_DIR", tmp_path / "build")
    monkeypatch.setattr(download_runtime, "download", use_fixture_archive)

    if sidecar == "symlink":
        with pytest.raises(RuntimeError, match="capability manifest"):
            download_runtime.prepare_runtime(
                "https://example.invalid/runtime", "a" * 64, layout, "test"
            )
        return

    prepared = download_runtime.prepare_runtime(
        "https://example.invalid/runtime", "a" * 64, layout, "test"
    )
    manifest_path = prepared / layout.capability_manifest_path
    assert manifest_path.is_file() is (sidecar == "present")
    if sidecar == "present":
        assert manifest_path.read_bytes() == manifest
        assert not manifest_path.is_symlink()


def test_accepts_complete_runtime_layout(tmp_path: Path, layout: RuntimeLayout) -> None:
    create_runtime(tmp_path, layout)

    assert download_runtime.runtime_is_valid(tmp_path, layout)


def test_accepts_executable_symlink_within_runtime(
    tmp_path: Path, layout: RuntimeLayout
) -> None:
    create_runtime(tmp_path, layout)
    executable = tmp_path / layout.executables[0]
    target = executable.with_name("internal-executable")
    executable.replace(target)
    executable.symlink_to(target.name)

    assert download_runtime.runtime_is_valid(tmp_path, layout)


@pytest.mark.parametrize(
    "mutation", ("wrong-link", "executable-directory", "file-link", "outside-root")
)
def test_rejects_invalid_runtime_layout(
    tmp_path: Path, layout: RuntimeLayout, mutation: str
) -> None:
    runtime = tmp_path / "runtime" if mutation == "outside-root" else tmp_path
    create_runtime(runtime, layout)
    if mutation == "wrong-link":
        launcher = runtime / layout.launcher.path
        launcher.unlink()
        launcher.symlink_to("wrong")
    elif mutation == "executable-directory":
        executable = runtime / layout.executables[0]
        executable.unlink()
        executable.mkdir()
    elif mutation == "file-link":
        required = runtime / layout.required_regular_files[0]
        target = required.with_name("real-file")
        required.replace(target)
        required.symlink_to(target.name)
    else:
        outside = tmp_path / "outside"
        executable = runtime / layout.executables[0]
        escaped_parent = executable.parent
        outside_parent = outside / escaped_parent.relative_to(runtime)
        outside_parent.parent.mkdir(parents=True, exist_ok=True)
        escaped_parent.replace(outside_parent)
        escaped_parent.symlink_to(outside_parent)
    assert not download_runtime.runtime_is_valid(runtime, layout)


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
