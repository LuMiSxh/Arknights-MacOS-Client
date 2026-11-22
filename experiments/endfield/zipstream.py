# SPDX-License-Identifier: MPL-2.0

"""ZIP64 central directory parsing and streaming extraction over split parts.

The game ships as one ZIP cut into fixed-size parts. Offsets in the central directory
are global offsets into the concatenation of all parts.
"""

import bisect
import os
import re
import stat
import struct
import zlib
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from pathlib import Path

EOCD_SIGNATURE = 0x06054B50
EOCD_FORMAT = "<4s4H2IH"
ZIP64_LOCATOR_SIGNATURE = 0x07064B50
ZIP64_LOCATOR_FORMAT = "<4sIQI"
ZIP64_EOCD_SIGNATURE = 0x06064B50
ZIP64_EOCD_FORMAT = "<4sQHHIIQQQQ"
CENTRAL_SIGNATURE = 0x02014B50
CENTRAL_FORMAT = "<4s6H3I5H2I"
LOCAL_SIGNATURE = 0x04034B50
LOCAL_FORMAT = "<4s5H3I2H"
ZIP64_EXTRA_ID = 0x0001
MAX_32 = 0xFFFFFFFF
MAX_16 = 0xFFFF
FLAG_ENCRYPTED = 0x1
FLAG_DESCRIPTOR = 0x8
FLAG_UTF8 = 0x800
METHOD_STORE = 0
METHOD_DEFLATE = 8
TAIL_BYTES = 64 * 1024
CHUNK_BYTES = 1024 * 1024
DRIVE_PATTERN = re.compile(r"^[A-Za-z]:")

type Fetch = Callable[[int, int], bytes]


class ZipError(Exception):
    """The archive is malformed, unsupported, or unsafe."""


@dataclass(frozen=True, slots=True)
class Entry:
    name: str
    method: int
    flags: int
    crc: int
    compressed_size: int
    size: int
    offset: int
    attributes: int

    @property
    def is_directory(self) -> bool:
        return self.name.endswith("/")


@dataclass(frozen=True, slots=True)
class CentralDirectory:
    entries: list[Entry]
    offset: int


def entry_parts(name: str) -> list[str]:
    """Return the validated path components of an entry name, or raise ZipError."""
    if "\0" in name:
        raise ZipError(f"entry name has a NUL byte: {name!r}")
    normalized = name.replace("\\", "/")
    if normalized.startswith("/") or DRIVE_PATTERN.match(normalized):
        raise ZipError(f"entry path is absolute: {name!r}")
    parts = normalized.removesuffix("/").split("/")
    for part in parts:
        if part in {"", ".", ".."} or ":" in part:
            raise ZipError(f"entry path has an unsafe component: {name!r}")
    return parts


def check_entry(entry: Entry) -> list[str]:
    """Validate an entry's path and attributes. Return its path components."""
    if stat.S_ISLNK(entry.attributes >> 16):
        raise ZipError(f"entry is a symlink: {entry.name!r}")
    if entry.flags & FLAG_ENCRYPTED:
        raise ZipError(f"entry is encrypted: {entry.name!r}")
    if entry.method not in {METHOD_STORE, METHOD_DEFLATE}:
        raise ZipError(f"unsupported method {entry.method}: {entry.name!r}")
    return entry_parts(entry.name)


def resolve_destination(
    game_dir: Path, parts: Sequence[str], *, directory: bool
) -> Path:
    """Walk game_dir/parts without following symlinks, creating missing directories."""
    if stat.S_ISLNK(os.lstat(game_dir).st_mode):
        raise ZipError(f"game directory is a symlink: {game_dir}")
    current = game_dir
    for index, part in enumerate(parts):
        current = current / part
        must_be_directory = directory or index < len(parts) - 1
        try:
            mode = os.lstat(current).st_mode
        except FileNotFoundError:
            if must_be_directory:
                current.mkdir()
            continue
        if stat.S_ISLNK(mode):
            raise ZipError(f"path component is a symlink: {current}")
        if must_be_directory and not stat.S_ISDIR(mode):
            raise ZipError(f"path component is not a directory: {current}")
    return current


def _decode_name(raw: bytes, flags: int) -> str:
    if flags & FLAG_UTF8:
        return raw.decode("utf-8")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp437")


def _zip64_values(extra: bytes, needs: list[str]) -> dict[str, int]:
    position = 0
    while position + 4 <= len(extra):
        identifier, length = struct.unpack_from("<HH", extra, position)
        body = extra[position + 4 : position + 4 + length]
        position += 4 + length
        if identifier != ZIP64_EXTRA_ID:
            continue
        if len(body) < 8 * len(needs):
            raise ZipError("ZIP64 extra field is too short")
        values = struct.unpack_from(f"<{len(needs)}Q", body)
        return dict(zip(needs, values))
    if needs:
        raise ZipError("entry needs a ZIP64 extra field that is missing")
    return {}


def parse_central_directory(data: bytes) -> list[Entry]:
    entries: list[Entry] = []
    position = 0
    header_size = struct.calcsize(CENTRAL_FORMAT)
    while position < len(data):
        if position + header_size > len(data):
            raise ZipError("central directory is truncated")
        (
            signature,
            _made_by,
            _needed,
            flags,
            method,
            _time,
            _date,
            crc,
            compressed_size,
            size,
            name_length,
            extra_length,
            comment_length,
            _disk,
            _internal,
            attributes,
            offset,
        ) = struct.unpack_from(CENTRAL_FORMAT, data, position)
        if struct.unpack("<I", signature)[0] != CENTRAL_SIGNATURE:
            raise ZipError("bad central directory signature")
        position += header_size
        end = position + name_length + extra_length + comment_length
        if end > len(data):
            raise ZipError("central directory entry is truncated")
        name = _decode_name(data[position : position + name_length], flags)
        extra = data[position + name_length : position + name_length + extra_length]
        position = end
        needs = [
            field
            for field, value in (
                ("size", size),
                ("compressed_size", compressed_size),
                ("offset", offset),
            )
            if value == MAX_32
        ]
        resolved = {"size": size, "compressed_size": compressed_size, "offset": offset}
        resolved |= _zip64_values(extra, needs)
        entries.append(
            Entry(
                name=name,
                method=method,
                flags=flags,
                crc=crc,
                compressed_size=resolved["compressed_size"],
                size=resolved["size"],
                offset=resolved["offset"],
                attributes=attributes,
            )
        )
    return entries


def read_central_directory(
    total_size: int, fetch: Fetch, *, budget: int
) -> CentralDirectory:
    """Read the central directory from the end of a ZIP of total_size bytes.

    fetch(start, end) returns the bytes in [start, end). The sum of fetched bytes may
    not exceed budget.
    """
    spent = 0

    def ranged(start: int, end: int) -> bytes:
        nonlocal spent
        spent += end - start
        if spent > budget:
            raise ZipError(f"central directory needs more than {budget} ranged bytes")
        data = fetch(start, end)
        if len(data) != end - start:
            raise ZipError(f"short range read at {start}: got {len(data)} bytes")
        return data

    tail_start = max(0, total_size - TAIL_BYTES)
    tail = ranged(tail_start, total_size)
    eocd_at = tail.rfind(struct.pack("<I", EOCD_SIGNATURE))
    if eocd_at < 0:
        raise ZipError("no end of central directory record in the last 64 KiB")
    fields = struct.unpack_from(EOCD_FORMAT, tail, eocd_at)
    entry_count, directory_size, directory_offset = fields[4], fields[5], fields[6]
    locator_at = eocd_at - struct.calcsize(ZIP64_LOCATOR_FORMAT)
    if locator_at >= 0 and tail[locator_at : locator_at + 4] == struct.pack(
        "<I", ZIP64_LOCATOR_SIGNATURE
    ):
        record_offset = struct.unpack_from(ZIP64_LOCATOR_FORMAT, tail, locator_at)[2]
        size = struct.calcsize(ZIP64_EOCD_FORMAT)
        if record_offset >= tail_start:
            record = tail[
                record_offset - tail_start : record_offset - tail_start + size
            ]
        else:
            record = ranged(record_offset, record_offset + size)
        values = struct.unpack(ZIP64_EOCD_FORMAT, record)
        if struct.unpack("<I", values[0])[0] != ZIP64_EOCD_SIGNATURE:
            raise ZipError("bad ZIP64 end of central directory signature")
        entry_count, directory_size, directory_offset = values[7], values[8], values[9]
    elif MAX_32 in {directory_size, directory_offset} or entry_count == MAX_16:
        raise ZipError("ZIP64 values without a ZIP64 locator")
    if directory_offset + directory_size > total_size:
        raise ZipError("central directory lies outside the archive")
    if directory_size > budget:
        raise ZipError(
            f"central directory is {directory_size} bytes; budget is {budget}"
        )
    if directory_offset >= tail_start:
        start = directory_offset - tail_start
        data = tail[start : start + directory_size]
    else:
        data = ranged(directory_offset, directory_offset + directory_size)
    entries = parse_central_directory(data)
    if len(entries) != entry_count:
        raise ZipError(f"expected {entry_count} entries, parsed {len(entries)}")
    return CentralDirectory(entries=entries, offset=directory_offset)


class VirtualReader:
    """Random reads over the present part files of one split archive."""

    def __init__(self, sizes: Sequence[int], path_of: Callable[[int], Path]) -> None:
        self._offsets = [0]
        for size in sizes:
            self._offsets.append(self._offsets[-1] + size)
        self._path_of = path_of

    def read_at(self, offset: int, length: int) -> bytes:
        chunks: list[bytes] = []
        end = offset + length
        index = bisect.bisect_right(self._offsets, offset) - 1
        while offset < end:
            if index >= len(self._offsets) - 1:
                raise ZipError("read past the end of the archive")
            local = offset - self._offsets[index]
            take = min(end, self._offsets[index + 1]) - offset
            with self._path_of(index).open("rb") as file:
                file.seek(local)
                data = file.read(take)
            if len(data) != take:
                raise ZipError(f"part {index} is shorter than expected")
            chunks.append(data)
            offset += take
            index += 1
        return b"".join(chunks)


def extract_entry(entry: Entry, reader: VirtualReader, destination: Path) -> None:
    """Stream one validated entry to destination.part, verify it, and rename it."""
    header_size = struct.calcsize(LOCAL_FORMAT)
    header = struct.unpack(LOCAL_FORMAT, reader.read_at(entry.offset, header_size))
    if struct.unpack("<I", header[0])[0] != LOCAL_SIGNATURE:
        raise ZipError(f"bad local header signature: {entry.name!r}")
    _, _, flags, method, _, _, crc, compressed_size, size, name_length, extra_length = (
        header
    )
    if method != entry.method:
        raise ZipError(f"local method differs from the directory: {entry.name!r}")
    if not flags & FLAG_DESCRIPTOR:
        # With a data descriptor the local sizes are zero; the directory is authoritative.
        local = (crc, compressed_size, size)
        if any(
            value not in {directory, MAX_32}
            for value, directory in zip(
                local, (entry.crc, entry.compressed_size, entry.size)
            )
        ):
            raise ZipError(f"local header differs from the directory: {entry.name!r}")
    data_start = entry.offset + header_size + name_length + extra_length
    partial = destination.with_name(destination.name + ".part")
    descriptor = os.open(
        partial, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o644
    )
    inflater = zlib.decompressobj(-15) if entry.method == METHOD_DEFLATE else None
    checksum = 0
    written = 0
    with os.fdopen(descriptor, "wb") as output:
        consumed = 0
        while consumed < entry.compressed_size:
            take = min(CHUNK_BYTES, entry.compressed_size - consumed)
            block = reader.read_at(data_start + consumed, take)
            consumed += take
            if inflater is not None:
                block = inflater.decompress(block, entry.size - written + 1)
                if inflater.unconsumed_tail:
                    raise ZipError(f"entry inflates past its size: {entry.name!r}")
            written += len(block)
            if written > entry.size:
                raise ZipError(f"entry is larger than its size: {entry.name!r}")
            checksum = zlib.crc32(block, checksum)
            output.write(block)
        if inflater is not None:
            tail = inflater.flush()
            written += len(tail)
            checksum = zlib.crc32(tail, checksum)
            output.write(tail)
            if not inflater.eof:
                raise ZipError(f"deflate stream is incomplete: {entry.name!r}")
    if written != entry.size or checksum != entry.crc:
        partial.unlink()
        raise ZipError(f"size or CRC32 mismatch: {entry.name!r}")
    partial.replace(destination)
