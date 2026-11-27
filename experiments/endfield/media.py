# SPDX-License-Identifier: MPL-2.0

"""Fetch the home-screen background that the official launcher shows.

The launcher's web UI sends a get_main_bg_image request to batch_proxy. It loops
main_bg_image.video_url and shows main_bg_image.url, a still WebP, when there is no video
or the video fails. This module mirrors that request and writes both files to
<lab>/media. The downloads are untrusted data: they are written, never opened or run.
"""

import json
import urllib.parse
from dataclasses import dataclass
from pathlib import Path
from typing import IO, Any

from installer import (
    APP_CODE,
    CHANNEL,
    MD5_PATTERN,
    MIB,
    PART_NAME_PATTERN,
    READ_BYTES,
    InstallError,
    TransientError,
    file_md5,
    http_open,
    validate_url,
    with_retries,
    write_json,
)

BATCH_URL = "https://launcher.gryphline.com/api/proxy/web/batch_proxy"
LANGUAGE = "en-us"
MEDIA_DIRECTORY = "media"
MAX_MEDIA_BYTES = 256 * MIB


class MediaError(InstallError):
    """The background response is not the shape the launcher sends, or a file is unsafe."""


@dataclass(frozen=True, slots=True)
class Asset:
    url: str
    name: str
    md5: str | None


@dataclass(frozen=True, slots=True)
class Background:
    data_version: str
    image: Asset | None
    video: Asset | None


def request_body() -> bytes:
    request = {
        "appcode": APP_CODE,
        "language": LANGUAGE,
        "channel": CHANNEL,
        "sub_channel": CHANNEL,
        "platform": "Windows",
        "source": "launcher",
    }
    return json.dumps(
        {
            "proxy_reqs": [
                {"kind": "get_main_bg_image", "get_main_bg_image_req": request}
            ]
        }
    ).encode()


def fetch_background() -> dict[str, Any]:
    body = request_body()

    def attempt() -> dict[str, Any]:
        with http_open(
            BATCH_URL, headers={"Content-Type": "application/json"}, body=body
        ) as response:
            return json.load(response)

    return with_retries(attempt)


def parse_background(document: dict[str, Any]) -> Background:
    """Parse a batch_proxy response. Validate every URL and file name."""
    try:
        response = next(
            rsp["get_main_bg_image_rsp"]
            for rsp in document["proxy_rsps"]
            if rsp["kind"] == "get_main_bg_image"
        )
    except (KeyError, TypeError, StopIteration) as error:
        raise MediaError(f"unexpected background shape: {error!r}") from error
    main = response.get("main_bg_image") or {}
    image = asset(main.get("url"), main.get("md5"))
    video = asset(main.get("video_url"), None)
    if image is None and video is None:
        raise MediaError("background response has neither an image nor a video")
    return Background(str(response.get("data_version", "")), image, video)


def asset(url: object, md5: object) -> Asset | None:
    if not url:
        return None
    checked = validate_url(str(url))
    name = Path(urllib.parse.urlsplit(checked).path).name
    if not PART_NAME_PATTERN.match(name):
        raise MediaError(f"unsafe file name: {name!r}")
    digest = str(md5).lower() if md5 else None
    if digest is not None and not MD5_PATTERN.match(digest):
        raise MediaError(f"invalid MD5 for {name}")
    return Asset(checked, name, digest)


def copy_capped(source: IO[bytes], destination: IO[bytes]) -> None:
    written = 0
    while block := source.read(READ_BYTES):
        written += len(block)
        if written > MAX_MEDIA_BYTES:
            raise MediaError(f"media is larger than {MAX_MEDIA_BYTES} bytes")
        destination.write(block)


def download(item: Asset, directory: Path) -> Path:
    """Stream one file through a .part file, verify its MD5 when known, then rename."""
    final = directory / item.name
    partial = directory / f"{item.name}.part"

    def attempt() -> None:
        with http_open(item.url) as response:
            if response.status != 200:
                raise TransientError(f"unexpected status {response.status}")
            with partial.open("wb") as output:
                copy_capped(response, output)
        if item.md5 is not None and file_md5(partial) != item.md5:
            partial.unlink()
            raise TransientError(f"MD5 mismatch for {item.name}")
        partial.replace(final)

    with_retries(attempt)
    return final


def run(lab: Path) -> None:
    directory = lab / MEDIA_DIRECTORY
    document = fetch_background()
    background = parse_background(document)
    directory.mkdir(parents=True, exist_ok=True)
    write_json(directory / "main_bg_image.json", document)
    print(f"data_version: {background.data_version or '(none)'}")
    for kind, item in (("image", background.image), ("video", background.video)):
        if item is None:
            print(f"{kind}: not provided")
            continue
        path = download(item, directory)
        print(f"{kind}: {item.url}")
        print(f"  file: {path} ({path.stat().st_size} bytes)")
        print(f"  md5: {file_md5(path)} (expected {item.md5 or 'not provided'})")
