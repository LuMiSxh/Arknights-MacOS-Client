# SPDX-License-Identifier: MPL-2.0

"""Streaming installer for the Endfield split ZIP.

Parts download in order. After each part, every entry whose bytes are all present is
extracted, and a part is deleted once no unextracted entry overlaps it. Peak disk is the
installed size plus the parts that unextracted entries still span. When every entry
spans at most N parts, at most N parts are on disk at once (counting the one arriving).
"""

import bisect
import hashlib
import http.client
import json
import os
import re
import shutil
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import zipstream
from zipstream import CentralDirectory, Entry, ZipError

ALLOWED_HOSTS = frozenset({"launcher.gryphline.com", "beyond.hg-cdn.com"})
API_URL = "https://launcher.gryphline.com/api/proxy/batch_proxy"
APP_CODE = "YDUTE5gscDZ229CW"
CHANNEL = "6"
USER_AGENT = "EndfieldLab/0"
RANGE_BUDGET_BYTES = 64 * 1024 * 1024
HTTP_TIMEOUT_SECONDS = 30
RETRY_ATTEMPTS = 5
RETRY_BASE_SECONDS = 2.0
RETRY_MAX_SECONDS = 30.0
PROGRESS_INTERVAL_SECONDS = 1.0
READ_BYTES = 1024 * 1024
PEAK_PARTS = 2
MIB = 1024 * 1024
PART_NAME_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")
MD5_PATTERN = re.compile(r"^[0-9a-f]{32}$")

type PartProvider = Callable[["Part", Path], None]


class InstallError(Exception):
    """The install cannot continue."""


class TransientError(InstallError):
    """A download failed in a way that a retry can fix."""


@dataclass(frozen=True, slots=True)
class Part:
    name: str
    url: str
    md5: str
    size: int


@dataclass(frozen=True, slots=True)
class Manifest:
    version: str
    parts: list[Part]
    installed_size: int
    package_type: str
    files_url: str
    files_md5: str

    @property
    def download_size(self) -> int:
        return sum(part.size for part in self.parts)


def validate_url(url: str) -> str:
    """Allow only https URLs on the two known hosts, with no port or user info."""
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.netloc.lower() not in ALLOWED_HOSTS:
        raise InstallError(f"URL is not allowed: {url!r}")
    return url


class _CheckedRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        validate_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


_OPENER = urllib.request.build_opener(_CheckedRedirects)


def http_open(
    url: str, *, headers: dict[str, str] | None = None, body: bytes | None = None
):
    request = urllib.request.Request(
        validate_url(url),
        data=body,
        headers={"User-Agent": USER_AGENT} | (headers or {}),
    )
    return _OPENER.open(request, timeout=HTTP_TIMEOUT_SECONDS)


def with_retries[T](
    action: Callable[[], T], sleep: Callable[[float], None] = time.sleep
) -> T:
    for attempt in range(RETRY_ATTEMPTS):
        try:
            return action()
        except urllib.error.HTTPError as error:
            if error.code < 500 and error.code not in {408, 429}:
                raise InstallError(f"HTTP {error.code} from {error.url}") from error
            failure: Exception = error
        except (
            TransientError,
            urllib.error.URLError,
            http.client.HTTPException,
            ConnectionError,
            TimeoutError,
        ) as error:
            failure = error
        if attempt == RETRY_ATTEMPTS - 1:
            raise InstallError(
                f"gave up after {RETRY_ATTEMPTS} attempts: {failure}"
            ) from failure
        sleep(min(RETRY_MAX_SECONDS, RETRY_BASE_SECONDS * 2**attempt))
    raise AssertionError  # pragma: no cover


def _int(value: Any, what: str) -> int:
    try:
        number = int(value)
    except TypeError, ValueError:
        raise InstallError(f"manifest {what} is not a number: {value!r}") from None
    if number < 0:
        raise InstallError(f"manifest {what} is negative")
    return number


def parse_manifest(document: dict[str, Any]) -> Manifest:
    """Parse a batch_proxy response. Validate every URL."""
    try:
        latest = document["proxy_rsps"][0]["get_latest_game_rsp"]
        package = latest["pkg"]
        parts = [
            Part(
                name=Path(urllib.parse.urlsplit(pack["url"]).path).name,
                url=validate_url(pack["url"]),
                md5=str(pack["md5"]).lower(),
                size=_int(pack["package_size"], "package_size"),
            )
            for pack in package["packs"]
        ]
        version = str(latest["version"])
        manifest = Manifest(
            version=version,
            parts=parts,
            installed_size=_int(package["total_size"], "total_size"),
            package_type=str(package["package_type"]),
            files_url=validate_url(package["file_path"]),
            files_md5=str(package["game_files_md5"]),
        )
    except (KeyError, IndexError, TypeError) as error:
        raise InstallError(f"unexpected manifest shape: {error!r}") from error
    if not parts:
        raise InstallError("manifest has no parts")
    if not re.fullmatch(r"[0-9A-Za-z._-]+", version):
        raise InstallError(f"unsafe version: {version!r}")
    names = [part.name for part in parts]
    if len(set(names)) != len(names) or not all(map(PART_NAME_PATTERN.match, names)):
        raise InstallError("manifest part names are not unique file names")
    if not all(MD5_PATTERN.match(part.md5) for part in parts):
        raise InstallError("manifest has an invalid part MD5")
    return manifest


def fetch_manifest() -> dict[str, Any]:
    body = json.dumps(
        {
            "seq": "1",
            "proxy_reqs": [
                {
                    "kind": "get_latest_game",
                    "get_latest_game_req": {
                        "appcode": APP_CODE,
                        "channel": CHANNEL,
                        "sub_channel": CHANNEL,
                        "version": "",
                        "device_id": str(uuid.uuid4()),
                    },
                }
            ],
        }
    ).encode()

    def attempt() -> dict[str, Any]:
        with http_open(
            API_URL, headers={"Content-Type": "application/json"}, body=body
        ) as response:
            return json.load(response)

    return with_retries(attempt)


def part_offsets(parts: list[Part]) -> list[int]:
    offsets = [0]
    for part in parts:
        offsets.append(offsets[-1] + part.size)
    return offsets


def ranged_reader(parts: list[Part]) -> zipstream.Fetch:
    """Return fetch(start, end) that issues HTTP Range requests across parts."""
    offsets = part_offsets(parts)

    def fetch(start: int, end: int) -> bytes:
        chunks: list[bytes] = []
        while start < end:
            index = bisect.bisect_right(offsets, start) - 1
            if index >= len(parts):
                raise InstallError("range lies past the last part")
            stop = min(end, offsets[index + 1])
            first, last = start - offsets[index], stop - offsets[index] - 1

            def attempt(
                index: int = index, first: int = first, last: int = last
            ) -> bytes:
                with http_open(
                    parts[index].url, headers={"Range": f"bytes={first}-{last}"}
                ) as response:
                    if response.status != 206:
                        raise InstallError(
                            f"server ignored Range (status {response.status})"
                        )
                    return response.read()

            chunks.append(with_retries(attempt))
            start = stop
        return b"".join(chunks)

    return fetch


def _md5(path: Path) -> str:
    digest = hashlib.md5(usedforsecurity=False)
    with path.open("rb") as file:
        while block := file.read(READ_BYTES):
            digest.update(block)
    return digest.hexdigest()


def download_part(part: Part, directory: Path, report: Callable[[int], None]) -> None:
    """Download one part with Range resume, verify size and MD5, then rename atomically."""
    final = directory / part.name
    partial = directory / f"{part.name}.part"
    if final.is_file() and final.stat().st_size == part.size:
        return

    def attempt() -> None:
        have = partial.stat().st_size if partial.exists() else 0
        if have > part.size:
            partial.unlink()
            have = 0
        if have < part.size:
            headers = {"Range": f"bytes={have}-"} if have else {}
            try:
                response = http_open(part.url, headers=headers)
            except urllib.error.HTTPError as error:
                if error.code == 416:
                    partial.unlink(missing_ok=True)
                    raise TransientError("resume offset rejected") from error
                raise
            with response:
                if response.status == 206 and have:
                    mode = "ab"
                elif response.status == 200:
                    mode, have = "wb", 0
                else:
                    raise TransientError(f"unexpected status {response.status}")
                with partial.open(mode) as output:
                    while block := response.read(READ_BYTES):
                        output.write(block)
                        have += len(block)
                        report(have)
        if partial.stat().st_size != part.size or _md5(partial) != part.md5:
            partial.unlink()
            raise TransientError(f"size or MD5 mismatch for {part.name}")
        partial.replace(final)

    with_retries(attempt)


@dataclass(slots=True)
class State:
    completed: set[int]
    deleted: set[int]
    extracted: set[int]

    @classmethod
    def load(cls, path: Path) -> State:
        if not path.is_file():
            return cls(set(), set(), set())
        data = json.loads(path.read_text(encoding="utf-8"))
        return cls(set(data["completed"]), set(data["deleted"]), set(data["extracted"]))

    def save(self, path: Path) -> None:
        document = {
            "completed": sorted(self.completed),
            "deleted": sorted(self.deleted),
            "extracted": sorted(self.extracted),
        }
        write_json(path, document)


def write_json(path: Path, document: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(document, separators=(",", ":")), encoding="utf-8")
    temporary.replace(path)


class Extractor:
    """Extract entries and delete parts as the download advances."""

    def __init__(
        self,
        parts: list[Part],
        directory: CentralDirectory,
        downloads: Path,
        game: Path,
        state_path: Path,
    ) -> None:
        self.parts = parts
        self.downloads = downloads
        self.game = game
        self.state_path = state_path
        self.state = State.load(state_path)
        self.entries = directory.entries
        self._offsets = part_offsets(parts)
        # Each entry owns the bytes up to the next entry, a safe superset of its extent.
        order = sorted(range(len(self.entries)), key=lambda i: self.entries[i].offset)
        self._span: dict[int, tuple[int, int]] = {}
        for position, index in enumerate(order):
            start = self.entries[index].offset
            end = (
                self.entries[order[position + 1]].offset
                if position + 1 < len(order)
                else directory.offset
            )
            self._span[index] = (
                self._part_of(start),
                self._part_of(max(start, end - 1)),
            )
        self._order = order
        self._paths = [zipstream.check_entry(entry) for entry in self.entries]
        self._reader = zipstream.VirtualReader(
            [part.size for part in parts], lambda i: downloads / parts[i].name
        )

    def _part_of(self, offset: int) -> int:
        index = bisect.bisect_right(self._offsets, offset) - 1
        if not 0 <= index < len(self.parts):
            raise InstallError(f"offset {offset} lies outside the parts")
        return index

    @property
    def present(self) -> set[int]:
        return self.state.completed - self.state.deleted

    def mark_complete(self, index: int) -> None:
        self.state.completed.add(index)
        self.state.save(self.state_path)

    def extract_ready(self) -> int:
        """Extract every entry whose parts are all present. Return how many."""
        present = self.present
        count = 0
        for index in self._order:
            if index in self.state.extracted:
                continue
            first, last = self._span[index]
            if not all(part in present for part in range(first, last + 1)):
                continue
            entry = self.entries[index]
            destination = zipstream.resolve_destination(
                self.game, self._paths[index], directory=entry.is_directory
            )
            if not entry.is_directory:
                zipstream.extract_entry(entry, self._reader, destination)
            self.state.extracted.add(index)
            count += 1
        self.state.save(self.state_path)
        return count

    def delete_finished(self) -> list[int]:
        """Delete present parts that no unextracted entry overlaps."""
        needed: set[int] = set()
        for index, (first, last) in self._span.items():
            if index not in self.state.extracted:
                needed.update(range(first, last + 1))
        removed = sorted(self.present - needed)
        for part in removed:
            (self.downloads / self.parts[part].name).unlink(missing_ok=True)
            self.state.deleted.add(part)
        if removed:
            self.state.save(self.state_path)
        return removed

    def run(self, provide: PartProvider, log: Callable[[str], None] = print) -> None:
        self.extract_ready()
        self.delete_finished()
        for index, part in enumerate(self.parts):
            if index in self.state.deleted:
                continue
            path = self.downloads / part.name
            if not (index in self.state.completed and path.is_file()):
                self.state.completed.discard(index)
                provide(part, self.downloads)
                self.mark_complete(index)
            extracted = self.extract_ready()
            removed = self.delete_finished()
            log(
                f"part {index + 1}/{len(self.parts)} {part.name}: "
                f"extracted {extracted} entries, deleted {len(removed)} parts"
            )
        remaining = len(self.entries) - len(self.state.extracted)
        if remaining:
            raise InstallError(f"{remaining} entries were not extracted")


@dataclass(frozen=True, slots=True)
class Paths:
    lab: Path

    @property
    def state(self) -> Path:
        return self.lab / "state"

    @property
    def downloads(self) -> Path:
        return self.lab / "downloads"

    @property
    def game(self) -> Path:
        return self.lab / "game"

    def plan_file(self, version: str) -> Path:
        return self.state / f"plan-{version}.json"

    def install_file(self, version: str) -> Path:
        return self.state / f"install-{version}.json"


def estimate_peak(manifest: Manifest, remaining_installed: int | None = None) -> int:
    installed = (
        manifest.installed_size if remaining_installed is None else remaining_installed
    )
    return installed + PEAK_PARTS * max(part.size for part in manifest.parts)


def _entry_row(entry: Entry) -> list[Any]:
    return [
        entry.name,
        entry.method,
        entry.flags,
        entry.crc,
        entry.compressed_size,
        entry.size,
        entry.offset,
        entry.attributes,
    ]


def load_plan(paths: Paths, manifest: Manifest) -> CentralDirectory | None:
    path = paths.plan_file(manifest.version)
    if not path.is_file():
        return None
    document = json.loads(path.read_text(encoding="utf-8"))
    signature = [[part.name, part.md5, part.size] for part in manifest.parts]
    if document.get("parts") != signature:
        return None
    return CentralDirectory(
        entries=[Entry(*row) for row in document["entries"]], offset=document["offset"]
    )


def make_plan(
    paths: Paths, document: dict[str, Any]
) -> tuple[Manifest, CentralDirectory]:
    """Parse the manifest, then reuse or read the central directory."""
    manifest = parse_manifest(document)
    directory = load_plan(paths, manifest)
    if directory is None:
        total = manifest.download_size
        try:
            directory = zipstream.read_central_directory(
                total, ranged_reader(manifest.parts), budget=RANGE_BUDGET_BYTES
            )
            for entry in directory.entries:
                zipstream.check_entry(entry)
        except ZipError as error:
            raise InstallError(str(error)) from error
        write_json(
            paths.plan_file(manifest.version),
            {
                "parts": [[part.name, part.md5, part.size] for part in manifest.parts],
                "offset": directory.offset,
                "entries": [_entry_row(entry) for entry in directory.entries],
            },
        )
    write_json(paths.state / f"manifest-{manifest.version}.json", document)
    return manifest, directory


def describe(manifest: Manifest, directory: CentralDirectory, free: int) -> list[str]:
    methods: dict[int, int] = {}
    for entry in directory.entries:
        methods[entry.method] = methods.get(entry.method, 0) + 1
    return [
        f"version: {manifest.version}",
        f"parts: {len(manifest.parts)}",
        f"download bytes: {manifest.download_size}",
        f"installed bytes: {manifest.installed_size}",
        f"entries: {len(directory.entries)}",
        f"compression methods: {dict(sorted(methods.items()))}",
        f"central directory offset: {directory.offset}",
        f"free disk: {free}",
        f"estimated peak disk: {estimate_peak(manifest)}",
    ]


class _Progress:
    def __init__(self, label: str, total: int) -> None:
        self.label, self.total = label, total
        self._last = 0.0

    def __call__(self, done: int) -> None:
        now = time.monotonic()
        if now - self._last >= PROGRESS_INTERVAL_SECONDS or done == self.total:
            self._last = now
            print(f"  {self.label}: {done // MIB}/{self.total // MIB} MiB")


def run(lab: Path, *, plan_only: bool, force: bool) -> None:
    paths = Paths(lab)
    lab.mkdir(parents=True, exist_ok=True)
    manifest, directory = make_plan(paths, fetch_manifest())
    free = shutil.disk_usage(lab).free
    for line in describe(manifest, directory, free):
        print(line)
    if plan_only:
        return
    state = State.load(paths.install_file(manifest.version))
    remaining = sum(
        entry.size
        for i, entry in enumerate(directory.entries)
        if i not in state.extracted
    )
    need = estimate_peak(manifest, remaining)
    if free < need and not force:
        raise InstallError(
            f"not enough free disk: need about {need} bytes, have {free} (use --force)"
        )
    paths.game.mkdir(parents=True, exist_ok=True)
    paths.downloads.mkdir(parents=True, exist_ok=True)
    total = len(manifest.parts)

    def provide(part: Part, directory_: Path) -> None:
        label = f"part {manifest.parts.index(part) + 1}/{total} {part.name}"
        print(f"downloading {label}")
        download_part(part, directory_, _Progress(label, part.size))

    try:
        Extractor(
            manifest.parts,
            directory,
            paths.downloads,
            paths.game,
            paths.install_file(manifest.version),
        ).run(provide)
    except ZipError as error:
        raise InstallError(str(error)) from error
    print(f"installed {manifest.version} into {paths.game}")
    if os.path.lexists(paths.downloads) and not any(paths.downloads.iterdir()):
        paths.downloads.rmdir()
