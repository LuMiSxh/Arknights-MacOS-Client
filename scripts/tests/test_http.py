# SPDX-License-Identifier: MPL-2.0

import io
import urllib.request
from unittest import mock

import pytest
from lib import http


class FakeResponse(io.BytesIO):
    def __init__(self, body: bytes) -> None:
        super().__init__(body)
        self.headers = {"Content-Type": "image/png; charset=binary"}


def get(url: str, *, max_bytes: int = 1024) -> http.Response:
    return http.fetch(url, user_agent="test", timeout=1, max_bytes=max_bytes)


def opener_for(response: FakeResponse) -> mock.Mock:
    return mock.Mock(open=mock.Mock(return_value=response))


def test_fetch_refuses_plain_http_before_connecting() -> None:
    with (
        mock.patch.object(http.urllib.request, "build_opener") as build_opener,
        pytest.raises(http.HttpError, match="HTTPS"),
    ):
        get("http://example.com/a.png")
    build_opener.assert_not_called()


def test_redirect_handler_refuses_a_non_https_target() -> None:
    request = urllib.request.Request("https://example.com/a.png")
    with pytest.raises(http.HttpError, match="non-HTTPS"):
        http.HttpsOnlyRedirectHandler().redirect_request(
            request, None, 302, "Found", {}, "http://example.com/a.png"
        )


def test_redirect_handler_follows_an_https_target() -> None:
    request = urllib.request.Request("https://example.com/a.png")
    redirected = http.HttpsOnlyRedirectHandler().redirect_request(
        request, None, 302, "Found", {}, "https://example.com/b.png"
    )
    assert redirected.full_url == "https://example.com/b.png"


def test_fetch_uses_the_https_only_opener() -> None:
    response = FakeResponse(b"png")
    with mock.patch.object(
        http.urllib.request, "build_opener", return_value=opener_for(response)
    ) as build_opener:
        get("https://example.com/a.png")
    assert isinstance(build_opener.call_args.args[0], http.HttpsOnlyRedirectHandler)


def test_fetch_refuses_bodies_over_the_limit() -> None:
    response = FakeResponse(b"x" * 11)
    with (
        mock.patch.object(
            http.urllib.request, "build_opener", return_value=opener_for(response)
        ),
        pytest.raises(http.HttpError, match="exceeds 10 bytes"),
    ):
        get("https://example.com/a.png", max_bytes=10)


def test_fetch_returns_body_and_bare_content_type() -> None:
    response = FakeResponse(b"png")
    with mock.patch.object(
        http.urllib.request, "build_opener", return_value=opener_for(response)
    ):
        result = get("https://example.com/a.png")
    assert result == http.Response(b"png", "image/png")
