# SPDX-License-Identifier: MPL-2.0

import io
from unittest import mock

import pytest
from lib import http


class FakeResponse(io.BytesIO):
    def __init__(self, body: bytes, url: str) -> None:
        super().__init__(body)
        self.headers = {"Content-Type": "image/png; charset=binary"}
        self._url = url

    def geturl(self) -> str:
        return self._url


def get(url: str, *, max_bytes: int = 1024) -> http.Response:
    return http.fetch(url, user_agent="test", timeout=1, max_bytes=max_bytes)


def test_fetch_refuses_plain_http_before_connecting() -> None:
    with (
        mock.patch.object(http.urllib.request, "urlopen") as urlopen,
        pytest.raises(http.HttpError, match="HTTPS"),
    ):
        get("http://example.com/a.png")
    urlopen.assert_not_called()


def test_fetch_refuses_a_redirect_to_plain_http() -> None:
    response = FakeResponse(b"x", "http://example.com/a.png")
    with (
        mock.patch.object(http.urllib.request, "urlopen", return_value=response),
        pytest.raises(http.HttpError, match="non-HTTPS"),
    ):
        get("https://example.com/a.png")


def test_fetch_refuses_bodies_over_the_limit() -> None:
    response = FakeResponse(b"x" * 11, "https://example.com/a.png")
    with (
        mock.patch.object(http.urllib.request, "urlopen", return_value=response),
        pytest.raises(http.HttpError, match="exceeds 10 bytes"),
    ):
        get("https://example.com/a.png", max_bytes=10)


def test_fetch_returns_body_and_bare_content_type() -> None:
    response = FakeResponse(b"png", "https://example.com/a.png")
    with mock.patch.object(http.urllib.request, "urlopen", return_value=response):
        result = get("https://example.com/a.png")
    assert result == http.Response(b"png", "image/png")
