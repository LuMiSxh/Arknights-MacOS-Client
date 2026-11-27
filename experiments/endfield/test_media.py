# SPDX-License-Identifier: MPL-2.0

"""Tests for parsing the get_main_bg_image response in media.py."""

import json
from pathlib import Path

import media
import pytest
from installer import InstallError

FIXTURE = Path(__file__).parent / "fixtures/get_main_bg_image.json"
IMAGE_URL = "https://gl-utils-public.hg-cdn.com/hg-utils/prod/eppcsuwqpaueijqk/YDUTE5gscDZ229CW/b7/c2/b7c23b1626958a976a6140fe27a3621b.webp"
IMAGE_MD5 = "b765ab5c1ea93c985fa12569e615fae5"
VIDEO_URL = "https://gl-utils-public.hg-cdn.com/hg-utils/prod/eppcsuwqpaueijqk/YDUTE5gscDZ229CW/1a/ac/1aaccbf685888149b299a1a854d68546.mp4"


def response_with(main: dict[str, object] | None) -> dict[str, object]:
    rsp = {"main_bg_image": main}
    return {"proxy_rsps": [{"kind": "get_main_bg_image", "get_main_bg_image_rsp": rsp}]}


def test_parse_background_reads_image_and_video() -> None:
    document = json.loads(FIXTURE.read_text(encoding="utf-8"))
    assert media.parse_background(document) == media.Background(
        data_version="",
        image=media.Asset(
            url=IMAGE_URL,
            name="b7c23b1626958a976a6140fe27a3621b.webp",
            md5=IMAGE_MD5,
        ),
        video=media.Asset(
            url=VIDEO_URL,
            name="1aaccbf685888149b299a1a854d68546.mp4",
            md5=None,
        ),
    )


def test_parse_background_without_video_keeps_the_still_image() -> None:
    background = media.parse_background(
        response_with({"url": IMAGE_URL, "md5": IMAGE_MD5, "video_url": ""})
    )
    assert background.video is None
    assert background.image == media.Asset(
        url=IMAGE_URL, name="b7c23b1626958a976a6140fe27a3621b.webp", md5=IMAGE_MD5
    )


REJECTED = {
    "no proxy response": {"proxy_rsps": []},
    "neither image nor video": response_with({"url": "", "video_url": ""}),
    "video on another host": response_with(
        {"url": IMAGE_URL, "md5": IMAGE_MD5, "video_url": "https://evil.example/a.mp4"}
    ),
    "malformed image MD5": response_with({"url": IMAGE_URL, "md5": "not-hex"}),
}


@pytest.mark.parametrize("document", REJECTED.values(), ids=REJECTED.keys())
def test_unexpected_background_is_rejected(document: dict[str, object]) -> None:
    with pytest.raises(InstallError):
        media.parse_background(document)
