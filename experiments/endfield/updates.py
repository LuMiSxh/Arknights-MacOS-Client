# SPDX-License-Identifier: MPL-2.0

"""Read the installed game version and ask the launcher API for incremental updates.

Reuses the installer's HTTP, retry, and host allowlist. It downloads only the small
``v2_patch_info`` and ``v2_verify_files`` manifests, never a patch archive, and applies
nothing. See ``README.md#game-updates``.
"""

import json
import re
import shutil
import urllib.parse
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import gamecrypt
import installer

LATEST_URL = "https://launcher.gryphline.com/api/game/get_latest"
LAUNCHER_APP_CODE = "TiaytKBUIEdoEwRT"
CONFIG_FILE = "config.ini"
MD5_PATTERN = re.compile(r"^[0-9a-f]{32}$")


@dataclass(frozen=True, slots=True)
class Pack:
    url: str
    md5: str
    size: int


@dataclass(frozen=True, slots=True)
class Package:
    file_path: str
    game_files_md5: str
    total_size: int
    packs: tuple[Pack, ...]


@dataclass(frozen=True, slots=True)
class Patch:
    urls: tuple[str, ...]
    patch_info_url: str | None
    patch_info_md5: str | None
    patch_info_size: int | None
    verify_url: str | None
    verify_md5: str | None
    verify_size: int | None
    cd_key: str | None
    total_size: int


@dataclass(frozen=True, slots=True)
class Latest:
    version: str
    action: int
    state: int
    launcher_action: int
    package: Package | None
    patch: Patch | None
    pre_patch: Patch | None


@dataclass(frozen=True, slots=True)
class InstalledGame:
    version: str
    entry: str
    entry_md5: str
    appcode: str
    region: str
    channel: str
    sub_channel: str


def latest_url(version: str | None) -> str:
    query = {
        "appcode": installer.APP_CODE,
        "launcher_appcode": LAUNCHER_APP_CODE,
        "channel": installer.CHANNEL,
        "sub_channel": installer.CHANNEL,
        "launcher_sub_channel": installer.CHANNEL,
        "disk_type": "0",
        "patch_encrypt": "true",
    }
    if version:
        query["version"] = version
    return f"{LATEST_URL}?{urllib.parse.urlencode(query)}"


def _int(value: Any, what: str, *, default: int | None = None) -> int | None:
    if value in (None, ""):
        return default
    try:
        number = int(value)
    except TypeError, ValueError:
        raise installer.InstallError(f"{what} is not a number: {value!r}") from None
    if number < 0:
        raise installer.InstallError(f"{what} is negative")
    return number


def _url(value: Any, what: str) -> str | None:
    if not value:
        return None
    return installer.validate_url(str(value))


def _md5(value: Any, what: str) -> str | None:
    if not value:
        return None
    digest = str(value).lower()
    if not MD5_PATTERN.match(digest):
        raise installer.InstallError(f"{what} is not an MD5: {value!r}")
    return digest


def _patch_urls(raw: dict[str, Any]) -> tuple[str, ...]:
    candidates = [raw.get("url")]
    for entry in raw.get("patches") or []:
        candidates.append(entry.get("url") if isinstance(entry, dict) else entry)
    urls = (_url(candidate, "patch.url") for candidate in candidates)
    return tuple(url for url in urls if url)


def _parse_patch(raw: Any) -> Patch | None:
    if not isinstance(raw, dict):
        return None
    return Patch(
        urls=_patch_urls(raw),
        patch_info_url=_url(raw.get("v2_patch_info_url"), "v2_patch_info_url"),
        patch_info_md5=_md5(raw.get("v2_patch_info_md5"), "v2_patch_info_md5"),
        patch_info_size=_int(raw.get("v2_patch_info_size"), "v2_patch_info_size"),
        verify_url=_url(raw.get("v2_verify_files_url"), "v2_verify_files_url"),
        verify_md5=_md5(raw.get("v2_verify_files_md5"), "v2_verify_files_md5"),
        verify_size=_int(raw.get("v2_verify_files_size"), "v2_verify_files_size"),
        cd_key=str(raw["cd_key"]) if raw.get("cd_key") else None,
        total_size=_int(raw.get("total_size"), "patch.total_size", default=0) or 0,
    )


def _parse_package(raw: Any) -> Package | None:
    if not isinstance(raw, dict):
        return None
    packs = [
        Pack(
            url=_url(pack.get("url"), "pkg.packs.url") or "",
            md5=_md5(pack.get("md5"), "pkg.packs.md5") or "",
            size=_int(pack.get("package_size"), "pkg.packs.package_size", default=0)
            or 0,
        )
        for pack in raw.get("packs") or []
    ]
    return Package(
        file_path=_url(raw.get("file_path"), "pkg.file_path") or "",
        game_files_md5=_md5(raw.get("game_files_md5"), "pkg.game_files_md5") or "",
        total_size=_int(raw.get("total_size"), "pkg.total_size", default=0) or 0,
        packs=tuple(packs),
    )


def parse_latest(document: dict[str, Any]) -> Latest:
    """Parse a get_latest response. Validate every URL and MD5 it will use."""
    try:
        version = str(document["version"])
    except (KeyError, TypeError) as error:
        raise installer.InstallError(
            f"unexpected get_latest shape: {error!r}"
        ) from error
    return Latest(
        version=version,
        action=_int(document.get("action"), "action", default=0) or 0,
        state=_int(document.get("state"), "state", default=0) or 0,
        launcher_action=_int(
            document.get("launcher_action"), "launcher_action", default=0
        )
        or 0,
        package=_parse_package(document.get("pkg")),
        patch=_parse_patch(document.get("patch")),
        pre_patch=_parse_patch(document.get("pre_patch")),
    )


def fetch_latest(version: str | None) -> Latest:
    url = latest_url(version)

    def attempt() -> dict[str, Any]:
        with installer.http_open(
            url, headers={"Accept": "application/json"}
        ) as response:
            return json.load(response)

    return parse_latest(installer.with_retries(attempt))


def installed_game(game: Path) -> InstalledGame:
    path = game / CONFIG_FILE
    try:
        plain = gamecrypt.decrypt_config(path.read_bytes())
    except FileNotFoundError:
        raise installer.InstallError(f"no {CONFIG_FILE} in {game}") from None
    except ValueError as error:
        raise installer.InstallError(f"cannot decrypt {path}: {error}") from error
    fields = gamecrypt.parse_ini(plain.decode("utf-8", "replace")).get("Game", {})
    missing = [key for key in ("version", "entry", "entry_md5") if not fields.get(key)]
    if missing:
        raise installer.InstallError(
            f"{CONFIG_FILE} has no [Game] {', '.join(missing)}"
        )
    return InstalledGame(
        version=fields["version"],
        entry=fields["entry"],
        entry_md5=fields["entry_md5"],
        appcode=fields.get("appcode", ""),
        region=fields.get("region", ""),
        channel=fields.get("channel", ""),
        sub_channel=fields.get("sub_channel", ""),
    )


def older_version(version: str) -> str | None:
    """Decrement the patch component: ``1.7.2`` becomes ``1.7.1``."""
    parts = version.split(".")
    if len(parts) < 3 or not all(part.isdigit() for part in parts):
        return None
    if int(parts[-1]) == 0:
        return None
    return ".".join([*parts[:-1], str(int(parts[-1]) - 1)])


def download_verified(
    url: str, md5: str | None, size: int | None, directory: Path
) -> Path:
    """Download one manifest to ``<name>.part``, verify it, then rename it."""
    installer.validate_url(url)
    name = Path(urllib.parse.urlsplit(url).path).name
    if not installer.PART_NAME_PATTERN.match(name):
        raise installer.InstallError(f"unsafe download name: {name!r}")
    directory.mkdir(parents=True, exist_ok=True)
    final = directory / name
    if final.is_file() and (not md5 or installer.file_md5(final) == md5):
        return final
    partial = directory / f"{name}.part"

    def attempt() -> None:
        with installer.http_open(url) as response, partial.open("wb") as output:
            shutil.copyfileobj(response, output, installer.READ_BYTES)
        actual = partial.stat().st_size
        if size is not None and actual != size:
            partial.unlink()
            raise installer.TransientError(f"size mismatch for {name}")
        if md5 and installer.file_md5(partial) != md5:
            partial.unlink()
            raise installer.TransientError(f"MD5 mismatch for {name}")
        partial.replace(final)

    installer.with_retries(attempt)
    return final


def decrypt_verify_file(path: Path) -> bytes:
    try:
        return gamecrypt.decrypt_config(path.read_bytes())
    except ValueError as error:
        raise installer.InstallError(f"cannot decrypt {path}: {error}") from error


def summarize_verify(plain: bytes) -> dict[str, Any]:
    """Describe a decrypted verify list without assuming one exact schema."""
    text = plain.decode("utf-8", "replace").strip()
    try:
        records = json.loads(text)
    except json.JSONDecodeError:
        lines = [line for line in text.splitlines() if line.strip()]
        return {
            "format": "lines",
            "count": len(lines),
            "totalSize": None,
            "sample": lines[:3],
        }
    if isinstance(records, dict):
        for key in ("files", "list", "data"):
            if isinstance(records.get(key), list):
                records = records[key]
                break
    if not isinstance(records, list):
        return {
            "format": "json",
            "count": 1,
            "totalSize": None,
            "sample": [text[:200]],
        }
    sizes: list[int] = []
    sample: list[str] = []
    for entry in records:
        if isinstance(entry, dict):
            sizes.extend(
                value
                for key in ("size", "file_size", "bytes")
                if isinstance(value := entry.get(key), int)
            )
            sample.append(str(entry.get("path") or entry.get("name") or entry))
        else:
            sample.append(str(entry))
    return {
        "format": "json",
        "count": len(records),
        "totalSize": sum(sizes) if sizes else None,
        "sample": sample[:3],
    }
