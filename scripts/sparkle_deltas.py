#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Prepare and publish Sparkle binary delta updates for a release.

`fetch` downloads the update archives of recent published releases so Sparkle's
`generate_appcast` can build deltas from them. `finalize` renames the generated
deltas to the names GitHub stores, rewrites their appcast URLs, and signs the
feed again, because the feed signature covers those URLs.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import xml.etree.ElementTree as ET
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

from lib.common import PROJECT_DIR, ScriptError, fail, run_main
from lib.console import info, success, warning
from lib.github_client import GitHubClient
from lib.project_config import (
    SPARKLE_ARCHIVE_SUFFIXES,
    SPARKLE_DELTA_SOURCE_COUNT,
    github_asset_name,
    load_project_configuration,
    sparkle_archive_names,
)
from validate_sparkle_keys import SPARKLE_NAMESPACE, validate_feed_signature

MAXIMUM_ARCHIVE_BYTES = 1_024 * 1_024 * 1_024


@dataclass(frozen=True)
class DeltaSource:
    """A published update archive that deltas can be generated from."""

    version: str
    url: str


def select_sources(
    releases: list[object],
    *,
    repository: str,
    current_version: str,
    update_names: dict[str, set[str]],
    count: int,
) -> list[DeltaSource]:
    """Pick the newest published releases (excluding the current one) with an archive.

    `update_names` maps a release version to the asset names its archive may use.
    """
    candidates: list[tuple[str, str, DeltaSource]] = []
    download_prefix = f"https://github.com/{repository}/releases/download/"
    for release in releases:
        if not isinstance(release, dict):
            continue
        if release.get("draft") or release.get("prerelease"):
            continue
        tag = release.get("tag_name")
        published = release.get("published_at")
        assets = release.get("assets")
        if not (
            isinstance(tag, str)
            and isinstance(published, str)
            and isinstance(assets, list)
        ):
            continue
        version = tag.removeprefix("v")
        if version == current_version:
            continue
        accepted = update_names[version]
        for asset in assets:
            if not isinstance(asset, dict) or asset.get("name") not in accepted:
                continue
            url = asset.get("browser_download_url")
            if isinstance(url, str) and url.startswith(download_prefix):
                candidates.append((published, version, DeltaSource(version, url)))
                break
    candidates.sort(key=lambda candidate: candidate[0], reverse=True)
    return [source for _, _, source in candidates[:count]]


def accepted_archive_names(releases: list[object], stem: str, update_name: str):
    """Map each release version to its legitimate update archive names."""
    names: dict[str, set[str]] = {}
    for release in releases:
        if isinstance(release, dict) and isinstance(release.get("tag_name"), str):
            version = release["tag_name"].removeprefix("v")
            names[version] = {update_name, *sparkle_archive_names(stem, version)}
    return names


def fetch(arguments: argparse.Namespace) -> None:
    """Download previous archives; every failure only costs deltas, never the release."""
    configuration = load_project_configuration()
    client = GitHubClient(os.environ.get("GH_TOKEN") or None)
    try:
        releases = client.releases(arguments.repository)
    except (ScriptError, ValueError) as error:
        warning(f"Skipping Sparkle deltas: could not list releases: {error}")
        return
    sources = select_sources(
        releases,
        repository=arguments.repository,
        current_version=arguments.current_version,
        update_names=accepted_archive_names(
            releases, configuration.release_asset_stem, arguments.update_name
        ),
        count=arguments.count,
    )
    if not sources:
        info("No previous published release archives; the release has no deltas.")
        return
    arguments.destination.mkdir(parents=True, exist_ok=True)
    fetched = 0
    for source in sources:
        # `generate_appcast` picks the extractor from the extension, so keep each
        # source's own format (older releases are zip, newer ones tar.xz).
        suffix = next(
            (
                suffix
                for suffix in SPARKLE_ARCHIVE_SUFFIXES
                if urlparse(source.url).path.endswith(suffix)
            ),
            ".zip",
        )
        destination = (
            arguments.destination
            / f"{configuration.release_asset_stem}.{source.version}{suffix}"
        )
        try:
            client.download_to_file(source.url, destination, MAXIMUM_ARCHIVE_BYTES)
        except ScriptError as error:
            warning(f"Skipping deltas from {source.version}: {error}")
            continue
        fetched += 1
        info(f"Fetched {source.version} as a delta source.")
    if fetched < len(sources):
        warning(f"Fetched {fetched} of {len(sources)} delta sources.")


def delta_enclosures(root: ET.Element) -> list[ET.Element]:
    return [
        enclosure
        for deltas in root.iter(f"{{{SPARKLE_NAMESPACE}}}deltas")
        for enclosure in deltas
        if enclosure.tag == "enclosure"
    ]


def find_sign_update() -> Path:
    """Locate Sparkle's `sign_update` the way the release workflow finds `generate_appcast`."""
    root = PROJECT_DIR / ".build" / "artifacts" / "sparkle"
    for candidate in sorted(root.glob("**/Sparkle/bin/sign_update")):
        if candidate.is_file() and os.access(candidate, os.X_OK):
            return candidate
    fail("Sparkle sign_update tool not found.")


def sign_feed_with_sparkle(
    private_key: str, sign_update: Path
) -> Callable[[Path], None]:
    """Return a signer that replaces a feed's signature block via `sign_update`.

    `sign_update` strips the existing trailing block itself and re-signs the remaining
    bytes; the signing warning `generate_appcast` embedded is already present, so none
    is added. The key goes through standard input so it never appears in arguments.
    """

    def sign(appcast: Path) -> None:
        result = subprocess.run(
            [
                str(sign_update),
                "--ed-key-file",
                "-",
                "--disable-signing-warning",
                str(appcast),
            ],
            input=private_key.encode(),
            capture_output=True,
            check=False,
        )
        if result.returncode != 0:
            fail(
                "sign_update could not sign the Sparkle appcast: "
                + result.stdout.decode(errors="replace").strip()
            )

    return sign


def finalize_deltas(
    directory: Path,
    appcast: Path,
    output: Path,
    sign: Callable[[Path], None] | None,
) -> list[Path]:
    """Publish referenced deltas under GitHub-safe names and refresh the feed signature."""
    data = appcast.read_bytes()
    content, _ = validate_feed_signature(data)
    try:
        root = ET.fromstring(content)
    except ET.ParseError as error:
        fail(f"could not parse generated Sparkle appcast: {error}")
    renames: dict[str, str] = {}
    for enclosure in delta_enclosures(root):
        name = Path(unquote(urlparse(enclosure.get("url", "")).path)).name
        if not name.endswith(".delta") or not (directory / name).is_file():
            fail(f"Sparkle appcast references a missing delta file: {name!r}")
        renames[name] = github_asset_name(name)
    if not renames:
        return []
    if sign is None:
        fail("SPARKLE_ED25519_PRIVATE_KEY is required to sign the delta appcast")
    output.mkdir(parents=True, exist_ok=True)
    published: list[Path] = []
    for name, safe_name in renames.items():
        shutil.copyfile(directory / name, output / safe_name)
        published.append(output / safe_name)
        if safe_name != name:
            old_reference = quote(name).encode()
            if old_reference not in content:
                fail(f"could not locate delta URL for {name!r} in the appcast")
            content = content.replace(old_reference, safe_name.encode())
    appcast.write_bytes(content)
    sign(appcast)
    return published


def finalize(arguments: argparse.Namespace) -> None:
    private_key = os.environ.get("SPARKLE_ED25519_PRIVATE_KEY", "")
    sign = (
        sign_feed_with_sparkle(private_key, arguments.sign_update or find_sign_update())
        if private_key
        else None
    )
    published = finalize_deltas(
        arguments.directory, arguments.appcast, arguments.output, sign
    )
    if published:
        success(f"Published {len(published)} Sparkle delta update(s)")
    else:
        warning(
            "No Sparkle delta updates were generated; users will download the full archive."
        )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    fetch_parser = commands.add_parser("fetch", help="download delta source archives")
    fetch_parser.add_argument("--repository", required=True)
    fetch_parser.add_argument("--current-version", required=True)
    fetch_parser.add_argument("--update-name", required=True)
    fetch_parser.add_argument("--destination", type=Path, required=True)
    fetch_parser.add_argument("--count", type=int, default=SPARKLE_DELTA_SOURCE_COUNT)
    fetch_parser.set_defaults(handler=fetch)
    finalize_parser = commands.add_parser(
        "finalize", help="rename deltas, rewrite their URLs, and re-sign the appcast"
    )
    finalize_parser.add_argument("--directory", type=Path, required=True)
    finalize_parser.add_argument("--appcast", type=Path, required=True)
    finalize_parser.add_argument("--output", type=Path, required=True)
    finalize_parser.add_argument(
        "--sign-update", type=Path, help="Sparkle sign_update path"
    )
    finalize_parser.set_defaults(handler=finalize)
    arguments = parser.parse_args()
    arguments.handler(arguments)


if __name__ == "__main__":
    run_main(main)
