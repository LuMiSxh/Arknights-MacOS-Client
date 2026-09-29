# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import hashlib
import json
import shutil
import tarfile
import urllib.error
import urllib.request
from pathlib import Path, PurePosixPath
from typing import Self

import download_runtime
import pytest
from lib.common import PROJECT_DIR
from runtime_config import RuntimeLayout, load_runtime_config


class Response:
    def __init__(
        self,
        chunks: list[bytes | Exception],
        *,
        headers: dict[str, str] | None = None,
        status: int = 200,
        url: str = "https://example.invalid/runtime.tar.gz",
    ) -> None:
        self.chunks, self.headers, self.status, self.url = (
            iter(chunks),
            headers or {},
            status,
            url,
        )

    def __enter__(self) -> Self:
        return self

    def __exit__(self, *args: object) -> None:
        pass

    def geturl(self) -> str:
        return self.url

    def read(self, size: int) -> bytes:
        value = next(self.chunks, b"")
        if isinstance(value, Exception):
            raise value
        return value


def download_paths(output: Path) -> tuple[Path, Path]:
    partial = output.with_suffix(output.suffix + ".part")
    return partial, Path(f"{partial}.json")


def metadata(path: Path, url: str, etag: str) -> None:
    path.write_text(json.dumps({"url": url, "etag": etag}), encoding="utf-8")


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


@pytest.mark.parametrize("content_length", ["unknown", "9" * 5_000])
def test_download_rejects_malformed_content_length(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, content_length: str
) -> None:
    output = tmp_path / "runtime.tar.gz"
    response = Response([b"runtime"], headers={"Content-Length": content_length})
    monkeypatch.setattr(urllib.request, "urlopen", lambda request, timeout: response)

    with pytest.raises(RuntimeError, match="Content-Length"):
        download_runtime.download(
            response.url, output, digest(b"runtime"), "fixture-agent"
        )


def test_download_enforces_archive_ceiling_while_streaming(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    partial, _ = download_paths(output)
    response = Response([b"12345678", b"overflow"])
    monkeypatch.setattr(
        download_runtime, "MAXIMUM_RUNTIME_ARCHIVE_BYTES", 10, raising=False
    )
    monkeypatch.setattr(urllib.request, "urlopen", lambda request, timeout: response)

    with pytest.raises(RuntimeError, match="size limit"):
        download_runtime.download(response.url, output, digest(b""), "fixture-agent")

    assert partial.read_bytes() == b"12345678"


def test_download_resumes_matching_partial_with_range_and_etag(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    partial, metadata_path = download_paths(output)
    complete = b"prefixsuffix"
    partial.write_bytes(b"prefix")
    metadata(metadata_path, "https://example.invalid/runtime.tar.gz", '"v1"')
    response = Response(
        [b"suffix"],
        status=206,
        headers={
            "Content-Length": "6",
            "Content-Range": "bytes 6-11/12",
            "ETag": '"v1"',
        },
    )
    requests: list[urllib.request.Request] = []

    def open_response(request: urllib.request.Request, timeout: int) -> Response:
        requests.append(request)
        return response

    monkeypatch.setattr(urllib.request, "urlopen", open_response)

    download_runtime.download(response.url, output, digest(complete), "fixture-agent")

    assert output.read_bytes() == complete
    assert requests[0].get_header("Range") == "bytes=6-"
    assert requests[0].get_header("If-range") == '"v1"'
    assert not partial.exists()
    assert not metadata_path.exists()


def test_download_preserves_partial_after_transient_failure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    output = tmp_path / "runtime.tar.gz"
    partial, metadata_path = download_paths(output)
    partial.write_bytes(b"prefix")
    metadata(metadata_path, "https://example.invalid/runtime.tar.gz", '"v1"')
    response = Response(
        [b"suffix", urllib.error.URLError("connection reset")],
        status=206,
        headers={
            "Content-Length": "12",
            "Content-Range": "bytes 6-17/18",
            "ETag": '"v1"',
        },
    )
    monkeypatch.setattr(urllib.request, "urlopen", lambda request, timeout: response)

    with pytest.raises(RuntimeError, match="unable to download"):
        download_runtime.download(response.url, output, digest(b""), "fixture-agent")

    assert partial.read_bytes() == b"prefixsuffix"
    assert metadata_path.is_file()


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
