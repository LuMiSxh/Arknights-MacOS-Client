# SPDX-License-Identifier: MPL-2.0

import io
import json
import random
import stat
import struct
import zipfile
from pathlib import Path

import installer
import pytest
import zipstream
from installer import InstallError, Part
from zipstream import Entry, ZipError

FIXTURE = Path(__file__).parent / "fixtures/get_latest_game.json"
PART_COUNT = 5


def build_zip64() -> tuple[bytes, dict[str, bytes]]:
    """A ZIP with ZIP64 local headers and a ZIP64 end record, like the game's."""
    rng = random.Random(1)  # noqa: S311
    files = {
        "Endfield_Data/a.bin": (rng.randbytes(1500), zipfile.ZIP_STORED),
        "Endfield_Data/sub/dir/b.bin": (b"endfield " * 400, zipfile.ZIP_DEFLATED),
        "c.txt": (rng.randbytes(1800), zipfile.ZIP_DEFLATED),
        "d.bin": (rng.randbytes(2200), zipfile.ZIP_STORED),
        "Endfield_Data/sub/e.bin": (rng.randbytes(1900), zipfile.ZIP_STORED),
    }
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.mkdir("Endfield_Data/sub/dir")
        for name, (data, method) in files.items():
            info = zipfile.ZipInfo(name)
            info.compress_type = method
            with archive.open(info, "w", force_zip64=True) as output:
                output.write(data)
    blob = buffer.getvalue()
    # Python only writes a ZIP64 end record when sizes demand it, so add one by hand.
    eocd_at = len(blob) - 22
    count, size, offset = struct.unpack_from("<HII", blob, eocd_at + 10)
    record = struct.pack(
        zipstream.ZIP64_EOCD_FORMAT,
        struct.pack("<I", zipstream.ZIP64_EOCD_SIGNATURE),
        44, 45, 45, 0, 0, count, count, size, offset,
    )  # fmt: skip
    locator = struct.pack(
        zipstream.ZIP64_LOCATOR_FORMAT,
        struct.pack("<I", zipstream.ZIP64_LOCATOR_SIGNATURE),
        0, eocd_at, 1,
    )  # fmt: skip
    end = struct.pack(
        zipstream.EOCD_FORMAT,
        struct.pack("<I", zipstream.EOCD_SIGNATURE),
        0, 0, 0xFFFF, 0xFFFF, 0xFFFFFFFF, 0xFFFFFFFF, 0,
    )  # fmt: skip
    return blob[:eocd_at] + record + locator + end, {
        name: data for name, (data, _) in files.items()
    }


def split(blob: bytes) -> list[Part]:
    size = -(-len(blob) // PART_COUNT)
    return [
        Part(
            f"game.zip.{i + 1:03d}",
            "https://beyond.hg-cdn.com/x",
            "0" * 32,
            len(blob[i * size : (i + 1) * size]),
        )
        for i in range(PART_COUNT)
    ]


class StopInstallError(Exception):
    pass


def make_extractor(blob: bytes, parts: list[Part], lab: Path) -> installer.Extractor:
    directory = zipstream.read_central_directory(
        len(blob), lambda start, end: blob[start:end], budget=len(blob)
    )
    paths = installer.Paths(lab)
    paths.downloads.mkdir(parents=True, exist_ok=True)
    paths.game.mkdir(exist_ok=True)
    return installer.Extractor(
        parts, directory, paths.downloads, paths.game, paths.install_file("t")
    )


def test_streaming_extraction_resumes_and_frees_parts(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    blob, originals = build_zip64()
    parts = split(blob)
    offsets = installer.part_offsets(parts)
    extractor = make_extractor(blob, parts, tmp_path)
    spans = [max(s) - min(s) + 1 for s in extractor._span.values()]
    # Design bound: with every entry spanning at most N parts, at most N parts coexist.
    assert max(spans) == 2
    downloads = installer.Paths(tmp_path).downloads
    most_present = 0
    requested: list[int] = []
    extracted_names: list[str] = []
    real_extract = zipstream.extract_entry
    monkeypatch.setattr(
        zipstream,
        "extract_entry",
        lambda entry, *rest: (
            extracted_names.append(entry.name),
            real_extract(entry, *rest),
        )[1],
    )

    def provide(part: Part, directory: Path, *, stop_at: int | None) -> None:
        nonlocal most_present
        index = parts.index(part)
        if index == stop_at:
            raise StopInstallError
        requested.append(index)
        (directory / part.name).write_bytes(blob[offsets[index] : offsets[index + 1]])
        most_present = max(most_present, len(list(downloads.glob("game.zip.???"))))

    with pytest.raises(StopInstallError):
        extractor.run(lambda p, d: provide(p, d, stop_at=3), lambda _: None)
    assert requested == [0, 1, 2]
    assert installer.State.load(extractor.state_path).completed == {0, 1, 2}

    resumed = make_extractor(blob, parts, tmp_path)
    resumed.run(lambda p, d: provide(p, d, stop_at=None), lambda _: None)

    assert requested == [0, 1, 2, 3, 4]
    assert most_present <= 2
    assert not list(downloads.iterdir())
    assert resumed.state.deleted == set(range(PART_COUNT))
    game = installer.Paths(tmp_path).game
    assert {name: (game / name).read_bytes() for name in originals} == originals
    assert (game / "Endfield_Data/sub/dir").is_dir()
    files = [e.name for e in resumed.entries if not e.is_directory]
    assert sorted(extracted_names) == sorted(files)


def link_case(kind: str):
    def attempt(tmp: Path) -> None:
        game = tmp / "game"
        game.mkdir()
        outside = tmp / "outside"
        outside.mkdir()
        if kind == "entry":
            attributes = (stat.S_IFLNK | 0o777) << 16
            zipstream.check_entry(Entry("lnk", 0, 0, 0, 0, 0, 0, attributes))
        else:
            (game / "dir").symlink_to(outside)
            zipstream.resolve_destination(game, ["dir", "x"], directory=False)

    return attempt


REJECTED = {
    "dotdot": lambda _: zipstream.entry_parts("../x"),
    "absolute": lambda _: zipstream.entry_parts("/abs"),
    "drive": lambda _: zipstream.entry_parts("C:\\x"),
    "backslash dotdot": lambda _: zipstream.entry_parts("a\\..\\..\\b"),
    "empty component": lambda _: zipstream.entry_parts("a//b"),
    "dot component": lambda _: zipstream.entry_parts("a/./b"),
    "nul": lambda _: zipstream.entry_parts("a\0b"),
    "symlink entry": link_case("entry"),
    "symlinked directory": link_case("directory"),
    "http scheme": lambda _: installer.validate_url("http://beyond.hg-cdn.com/x"),
    "other host": lambda _: installer.validate_url("https://evil.example/x"),
    "explicit port": lambda _: installer.validate_url(
        "https://beyond.hg-cdn.com:8443/x"
    ),
    "user info": lambda _: installer.validate_url(
        "https://beyond.hg-cdn.com@evil.example/x"
    ),
    "redirect": lambda _: installer._CheckedRedirects().redirect_request(
        None, None, 302, "", {}, "https://evil.example/x"
    ),
}


@pytest.mark.parametrize("attempt", REJECTED.values(), ids=REJECTED.keys())
def test_unsafe_input_is_rejected(attempt, tmp_path: Path) -> None:
    with pytest.raises((ZipError, InstallError)):
        attempt(tmp_path)


def test_manifest_fixture_parses() -> None:
    manifest = installer.parse_manifest(json.loads(FIXTURE.read_text(encoding="utf-8")))
    assert manifest.version == "1.6.4"
    assert [part.name[-4:] for part in manifest.parts] == [".001", ".002", ".003"]
    assert {part.size for part in manifest.parts} == {1073741824}
    assert manifest.installed_size == 130924997432
    assert manifest.files_md5 == "2e359eebefa0f0035adc636fa1fe30e2"
    assert zipstream.entry_parts("a\\b/c.txt") == ["a", "b", "c.txt"]
