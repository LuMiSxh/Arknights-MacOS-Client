# SPDX-License-Identifier: MPL-2.0

"""The GitHub release and asset shape that the release scripts read."""

from typing import TypedDict


class ReleaseAsset(TypedDict):
    name: str
    download_count: int


class GitHubRelease(TypedDict, total=False):
    tag_name: str
    draft: bool
    prerelease: bool
    published_at: str
    assets: list[ReleaseAsset]
