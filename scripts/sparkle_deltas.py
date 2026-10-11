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
import json
import os
import shutil
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import quote, unquote, urlparse

from lib.common import ScriptError, fail, run, run_main
from lib.console import info, success, warning
from lib.project_config import (
    SPARKLE_ARCHIVE_SUFFIXES,
    SPARKLE_DELTA_SOURCE_COUNT,
    github_asset_name,
    load_project_configuration,
    sparkle_archive_names,
)

DELTAS_TAG = "{http://www.andymatuschak.org/xml-namespaces/sparkle}deltas"


def select_sources(
    releases: list[dict],
    *,
    current_version: str,
    stem: str,
    update_name: str,
    count: int,
) -> list[tuple[str, str, str]]:
    """Return `(version, tag, asset)` for the newest published releases with an archive.

    The current release, drafts, and prereleases never count as sources.
    """
    published = sorted(
        (
            release
            for release in releases
            if not (release["draft"] or release["prerelease"])
            and release["tag_name"].removeprefix("v") != current_version
        ),
        key=lambda release: release["published_at"],
        reverse=True,
    )
    sources: list[tuple[str, str, str]] = []
    for release in published:
        version = release["tag_name"].removeprefix("v")
        accepted = {update_name, *sparkle_archive_names(stem, version)}
        asset = next(
            (a["name"] for a in release["assets"] if a["name"] in accepted), None
        )
        if asset is not None:
            sources.append((version, release["tag_name"], asset))
    return sources[:count]


def fetch(arguments: argparse.Namespace) -> None:
    """Download previous archives; every failure only costs deltas, never the release."""
    stem = load_project_configuration().release_asset_stem
    try:
        releases = json.loads(
            run(
                ["gh", "api", f"repos/{arguments.repository}/releases?per_page=100"],
                capture=True,
            ).stdout
        )
        sources = select_sources(
            releases,
            current_version=arguments.current_version,
            stem=stem,
            update_name=arguments.update_name,
            count=arguments.count,
        )
    except (ScriptError, ValueError, KeyError, TypeError) as error:
        warning(f"Skipping Sparkle deltas: could not list releases: {error}")
        return
    arguments.destination.mkdir(parents=True, exist_ok=True)
    fetched = 0
    for version, tag, asset in sources:
        # `generate_appcast` picks the extractor from the extension, so keep each
        # source's own format (older releases are zip, newer ones tar.xz).
        suffix = next(s for s in SPARKLE_ARCHIVE_SUFFIXES if asset.endswith(s))
        try:
            run(
                [
                    "gh",
                    "release",
                    "download",
                    tag,
                    "--repo",
                    arguments.repository,
                    "--pattern",
                    asset,
                    "--output",
                    arguments.destination / f"{stem}.{version}{suffix}",
                    "--clobber",
                ],
                capture=True,
            )
        except ScriptError as error:
            warning(f"Skipping deltas from {version}: {error}")
            continue
        fetched += 1
        info(f"Fetched {version} as a delta source.")
    if fetched < len(sources):
        warning(f"Fetched {fetched} of {len(sources)} delta sources.")
    elif not sources:
        info("No previous published release archives; the release has no deltas.")


def sign_appcast(sign_update: Path, private_key: str, appcast: Path) -> None:
    """Replace the feed's signature block with `sign_update`.

    `sign_update` strips the old trailing block itself. The key goes through
    standard input so it never appears in arguments.
    """
    result = subprocess.run(
        [sign_update, "--ed-key-file", "-", "--disable-signing-warning", appcast],
        input=private_key.encode(),
        capture_output=True,
        check=False,
    )
    if result.returncode != 0:
        fail(
            "sign_update could not sign the Sparkle appcast: "
            + result.stdout.decode(errors="replace").strip()
        )


def finalize_deltas(
    directory: Path, appcast: Path, output: Path, sign_update: Path, private_key: str
) -> list[Path]:
    """Publish referenced deltas under GitHub-safe names and refresh the feed signature."""
    content = appcast.read_bytes()
    try:
        root = ET.fromstring(content)
    except ET.ParseError as error:
        fail(f"could not parse generated Sparkle appcast: {error}")
    names = [
        Path(unquote(urlparse(enclosure.get("url", "")).path)).name
        for deltas in root.iter(DELTAS_TAG)
        for enclosure in deltas
    ]
    if not names:
        return []
    if not private_key:
        fail("SPARKLE_ED25519_PRIVATE_KEY is required to sign the delta appcast")
    output.mkdir(parents=True, exist_ok=True)
    published: list[Path] = []
    for name in names:
        if not name.endswith(".delta") or not (directory / name).is_file():
            fail(f"Sparkle appcast references a missing delta file: {name!r}")
        safe_name = github_asset_name(name)
        shutil.copyfile(directory / name, output / safe_name)
        published.append(output / safe_name)
        if safe_name != name:
            if quote(name).encode() not in content:
                fail(f"could not locate delta URL for {name!r} in the appcast")
            content = content.replace(quote(name).encode(), safe_name.encode())
    appcast.write_bytes(content)
    sign_appcast(sign_update, private_key, appcast)
    return published


def finalize(arguments: argparse.Namespace) -> None:
    published = finalize_deltas(
        arguments.directory,
        arguments.appcast,
        arguments.output,
        arguments.sign_update,
        os.environ.get("SPARKLE_ED25519_PRIVATE_KEY", ""),
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
    finalize_parser.add_argument("--sign-update", type=Path, required=True)
    finalize_parser.set_defaults(handler=finalize)
    arguments = parser.parse_args()
    arguments.handler(arguments)


if __name__ == "__main__":
    run_main(main)
