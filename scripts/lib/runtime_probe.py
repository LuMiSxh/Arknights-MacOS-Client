# SPDX-License-Identifier: MPL-2.0

"""Read-only runtime candidate and pinned-source verification."""

from __future__ import annotations

import hashlib
import re
import urllib.parse
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Protocol

from runtime_config import MAXIMUM_RUNTIME_ARCHIVE_BYTES, load_runtime_config

from lib.common import ScriptError, fail, safe_relative_path
from lib.runtime_monitor import (
    COMMIT_PATTERN,
    RuntimeCandidate,
    RuntimeIncident,
    RuntimeMonitorReport,
    RuntimeRelease,
    parse_recipe_metadata,
    parse_recipe_pins,
    select_latest_mirror_release,
)

MIRROR_REPOSITORY = "dappermint/Whisky"
RECIPE_REPOSITORY = "dappermint/winecx-gptk"
MAXIMUM_SOURCE_ARCHIVE_BYTES = 32 * 1_024 * 1_024
REPOSITORY_PATTERN = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")
PINNED_RUNTIME_URL_PATTERN = re.compile(
    r"^https://github\.com/dappermint/Whisky/releases/download/v([0-9]+\.[0-9]+\.[0-9]+)/Libraries\.tar\.gz$"
)
COMPONENT_NOTICES = {
    "WINECX_COMMIT": ("WineCX / Wine",),
    "DXMT_VERSION": ("DXMT",),
    "MOLTENVK_VERSION": ("MoltenVK",),
    "NIXPKGS_REV": ("GStreamer", "FFmpeg"),
    "FAUDIO_VERSION": ("FAudio",),
}
USED_RUNTIME_PINS = {
    "WINECX_COMMIT",
    "NIXPKGS_REV",
    "MOLTENVK_VERSION",
    "FAUDIO_VERSION",
    "DXMT_VERSION",
    "MACOSX_DEPLOYMENT_TARGET",
}


class RuntimeUpstream(Protocol):
    def releases(self, repository: str) -> list[object]: ...

    def release(self, repository: str, tag: str) -> object: ...

    def commit(self, repository: str, revision: str) -> dict[str, Any]: ...

    def compare(self, repository: str, old: str, new: str) -> dict[str, Any]: ...

    def file_at(self, repository: str, path: str, commit: str) -> str: ...

    def download(self, url: str, maximum_bytes: int) -> bytes: ...

    def hash_download(self, url: str, maximum_bytes: int) -> str: ...


@dataclass
class RuntimeProbe:
    client: RuntimeUpstream
    config_path: Path
    notices_path: Path

    def run(
        self, *, environment: dict[str, str], verify_archive: bool
    ) -> RuntimeMonitorReport:
        configuration = load_runtime_config(self.config_path)
        raw = configuration.raw
        runtime = _mapping(raw, "runtime")
        build_recipe = _mapping(raw, "buildRecipe")
        provenance = _mapping(raw, "provenance")
        runtime_url = _string(runtime, "url")
        version_match = PINNED_RUNTIME_URL_PATTERN.fullmatch(runtime_url)
        if version_match is None:
            fail("runtime URL does not identify a dappermint runtime version")
        pinned_version = version_match.group(1)
        pinned_digest = _string(runtime, "sha256")
        build_commit = _string(provenance, "buildCommit")
        incidents: list[RuntimeIncident] = []
        candidate: RuntimeCandidate | None = None
        archive_verification = "not-requested"

        try:
            self._verify_pinned_release(
                pinned_version, pinned_digest, build_commit, runtime_url
            )
        except (ScriptError, TypeError, ValueError) as error:
            incidents.append(incident("pinned-release", error))

        try:
            source = self.client.download(
                _string(build_recipe, "url"), MAXIMUM_SOURCE_ARCHIVE_BYTES
            )
            if hashlib.sha256(source).hexdigest() != _string(build_recipe, "sha256"):
                raise ValueError(
                    "pinned build recipe checksum differs from runtime.json"
                )
        except (ScriptError, TypeError, ValueError) as error:
            incidents.append(incident("build-recipe", error))

        incidents.extend(self._verify_source_commits(provenance))
        try:
            latest = select_latest_mirror_release(
                self.client.releases(MIRROR_REPOSITORY)
            )
            pinned_tuple = tuple(int(part) for part in pinned_version.split("."))
            if latest.version > pinned_tuple:
                candidate = self._candidate(
                    pinned_version=pinned_version,
                    pinned_digest=pinned_digest,
                    pinned_build_commit=build_commit,
                    mirror=latest,
                )
        except (ScriptError, TypeError, ValueError) as error:
            incidents.append(incident("candidate-discovery", error))

        if verify_archive:
            try:
                if (
                    self.client.hash_download(
                        runtime_url, MAXIMUM_RUNTIME_ARCHIVE_BYTES
                    )
                    != pinned_digest
                ):
                    raise ValueError(
                        "downloaded runtime checksum differs from runtime.json"
                    )
                archive_verification = "passed"
            except (ScriptError, ValueError) as error:
                archive_verification = "failed"
                incidents.append(incident("archive-checksum", error))

        return RuntimeMonitorReport(
            checked_at=datetime.now(UTC).isoformat().replace("+00:00", "Z"),
            trigger=environment.get("GITHUB_EVENT_NAME", "local"),
            run_id=environment.get("GITHUB_RUN_ID", "local"),
            run_url=_run_url(environment),
            pinned_version=pinned_version,
            candidate=candidate,
            incidents=tuple({item.key: item for item in incidents}.values()),
            archive_verification=archive_verification,
        )

    def _verify_pinned_release(
        self,
        version: str,
        digest: str,
        build_commit: str,
        runtime_url: str,
    ) -> None:
        mirror = self._release(MIRROR_REPOSITORY, f"v{version}")
        recipe = self._release(RECIPE_REPOSITORY, f"runtime-v{version}")
        metadata = parse_recipe_metadata(recipe)
        self._verify_release_pair(mirror, recipe, metadata)
        archive = required_asset(mirror, "Libraries.tar.gz")
        if archive.url != runtime_url or archive.digest != digest:
            raise ValueError("pinned mirror asset differs from runtime.json")
        if metadata.build_commit != build_commit:
            raise ValueError("pinned recipe commit differs from runtime.json")
        if self._resolved_commit(RECIPE_REPOSITORY, recipe.tag) != build_commit:
            raise ValueError("pinned recipe tag points at a different commit")

    def _candidate(
        self,
        *,
        pinned_version: str,
        pinned_digest: str,
        pinned_build_commit: str,
        mirror: RuntimeRelease,
    ) -> RuntimeCandidate:
        version = ".".join(str(part) for part in mirror.version)
        recipe = self._release(RECIPE_REPOSITORY, f"runtime-v{version}")
        metadata = parse_recipe_metadata(recipe)
        self._verify_release_pair(mirror, recipe, metadata)
        if (
            self._resolved_commit(RECIPE_REPOSITORY, recipe.tag)
            != metadata.build_commit
        ):
            raise ValueError("candidate recipe tag and build commit disagree")

        pinned_pins = parse_recipe_pins(self._recipe_workflow(pinned_build_commit))
        candidate_pins = parse_recipe_pins(self._recipe_workflow(metadata.build_commit))
        release_pins = dict(metadata.pins)
        expected_release_pins = {
            "winecx": candidate_pins["WINECX_COMMIT"],
            "dxvk": candidate_pins["DXVK_VERSION"],
            "dxmt": candidate_pins["DXMT_VERSION"],
            "moltenvk": candidate_pins["MOLTENVK_VERSION"],
        }
        if release_pins != expected_release_pins:
            raise ValueError("candidate release notes and recipe pins disagree")
        changed_pins = tuple(
            (name, pinned_pins[name], candidate_pins[name])
            for name in sorted(pinned_pins)
            if pinned_pins[name] != candidate_pins[name]
        )
        self._verify_notice_coverage(changed_pins)
        self._verify_candidate_sources(metadata.build_commit, changed_pins)
        summaries, changed_files = self._recipe_changes(
            pinned_build_commit, metadata.build_commit
        )
        pinned_gecko = self._gecko_version(pinned_pins["WINECX_COMMIT"])
        candidate_gecko = self._gecko_version(candidate_pins["WINECX_COMMIT"])
        change_areas = classify_change_areas(
            pinned_pins,
            candidate_pins,
            changed_files,
            wine_gecko_changed=pinned_gecko != candidate_gecko,
        )
        archive = required_asset(mirror, "Libraries.tar.gz")
        if archive.digest is None:
            raise ValueError("candidate archive digest is missing")
        changed_pin_names = {name for name, _, _ in changed_pins}
        if changed_pin_names & USED_RUNTIME_PINS:
            impact = "used-components"
        elif (
            archive.digest == pinned_digest
            and metadata.build_commit == pinned_build_commit
        ):
            impact = "metadata-only"
        else:
            impact = "optional-or-recipe-only"
        return RuntimeCandidate(
            pinned_version=pinned_version,
            version=version,
            digest=archive.digest,
            build_commit=metadata.build_commit,
            impact=impact,
            changed_pins=changed_pins,
            change_areas=change_areas,
            commit_summaries=summaries,
            changed_files=changed_files,
        )

    def _verify_release_pair(self, mirror, recipe, metadata) -> None:
        if mirror.version != recipe.version:
            raise ValueError("mirror and recipe versions disagree")
        expected_link = (
            f"https://github.com/{RECIPE_REPOSITORY}/releases/tag/{recipe.tag}"
        )
        if expected_link not in mirror.body:
            raise ValueError("mirror release does not link its recipe release")
        mirror_archive = required_asset(mirror, "Libraries.tar.gz")
        recipe_archive = required_asset(recipe, "Libraries.tar.gz")
        if (
            mirror_archive.digest is None
            or mirror_archive.digest != recipe_archive.digest
            or mirror_archive.digest != metadata.archive_sha256
        ):
            raise ValueError("mirror and recipe archive digests disagree")
        for release in (mirror, recipe):
            checksum = required_asset(release, "Libraries.tar.gz.sha256")
            contents = self.client.download(checksum.url, 1_024).decode("ascii")
            fields = contents.split()
            if not fields or fields[0] != metadata.archive_sha256:
                raise ValueError("published checksum file disagrees with asset digest")

    def _verify_source_commits(self, provenance) -> list[RuntimeIncident]:
        incidents: list[RuntimeIncident] = []
        for key, repository_url in sorted(provenance.items()):
            if not key.endswith("Repository") or not isinstance(repository_url, str):
                continue
            component = key.removesuffix("Repository")
            commit = provenance.get(f"{component}Commit")
            if not isinstance(commit, str):
                incidents.append(
                    RuntimeIncident(component, "provenance commit is missing")
                )
                continue
            try:
                repository = github_repository(repository_url)
                if repository is None:
                    self.client.download(
                        f"{repository_url.rstrip('/')}/-/commit/{commit}.patch",
                        4 * 1_024 * 1_024,
                    )
                elif self._resolved_commit(repository, commit) != commit:
                    raise ValueError("source revision resolved to a different commit")
            except (ScriptError, TypeError, ValueError) as error:
                incidents.append(incident(f"source-{component}", error))
        return incidents

    def _verify_notice_coverage(self, changed_pins) -> None:
        notices = self.notices_path.read_text(encoding="utf-8")
        for name, _, _ in changed_pins:
            for expected in COMPONENT_NOTICES.get(name, ()):
                if expected not in notices:
                    raise ValueError(f"third-party notices do not cover changed {name}")

    def _verify_candidate_sources(self, build_commit: str, changed_pins) -> None:
        self.client.download(
            f"https://github.com/{RECIPE_REPOSITORY}/archive/{build_commit}.tar.gz",
            MAXIMUM_SOURCE_ARCHIVE_BYTES,
        )
        revisions = {
            "WINECX_COMMIT": ("dappermint/winecx", lambda value: value),
            "NIXPKGS_REV": ("NixOS/nixpkgs", lambda value: value),
            "DXMT_VERSION": ("3Shain/dxmt", lambda value: f"v{value}"),
            "MOLTENVK_VERSION": ("KhronosGroup/MoltenVK", lambda value: f"v{value}"),
            "DXVK_VERSION": ("doitsujin/dxvk", lambda value: f"v{value}"),
        }
        for name, _, new in changed_pins:
            if source := revisions.get(name):
                repository, revision = source
                self._resolved_commit(repository, revision(new))

    def _recipe_changes(self, pinned: str, candidate: str):
        comparison = self.client.compare(RECIPE_REPOSITORY, pinned, candidate)
        if comparison.get("status") not in {"ahead", "identical"}:
            raise ValueError("candidate recipe is not descended from the pinned recipe")
        commits = comparison.get("commits")
        files = comparison.get("files")
        if not isinstance(commits, list) or not isinstance(files, list):
            raise TypeError("candidate comparison is incomplete")
        summaries: list[str] = []
        for item in commits[:20]:
            if not isinstance(item, dict) or not isinstance(item.get("commit"), dict):
                raise TypeError("candidate comparison contains invalid commit metadata")
            message = item["commit"].get("message")
            if not isinstance(message, str) or not message:
                raise ValueError(
                    "candidate comparison contains an empty commit message"
                )
            summaries.append(sanitize_summary(message))
        if not all(isinstance(item, dict) for item in files):
            raise TypeError("candidate comparison contains invalid file metadata")
        changed_files = tuple(
            safe_relative_path(
                _string(item, "filename"),
                "candidate comparison contains an unsafe file path",
            )
            for item in files[:50]
        )
        return tuple(summaries), changed_files

    def _release(self, repository: str, tag: str) -> RuntimeRelease:
        value = self.client.release(repository, tag)
        if isinstance(value, RuntimeRelease):
            return value
        return RuntimeRelease.from_json(value, recipe=repository == RECIPE_REPOSITORY)

    def _resolved_commit(self, repository: str, revision: str) -> str:
        value = self.client.commit(repository, revision)
        sha = value.get("sha")
        if not isinstance(sha, str) or COMMIT_PATTERN.fullmatch(sha) is None:
            raise ValueError("GitHub returned an invalid commit revision")
        return sha

    def _recipe_workflow(self, commit: str) -> str:
        return self.client.file_at(
            RECIPE_REPOSITORY, ".github/workflows/build.yml", commit
        )

    def _gecko_version(self, wine_commit: str) -> str:
        source = self.client.file_at(
            "dappermint/winecx", "dlls/appwiz.cpl/addons.c", wine_commit
        )
        match = re.search(
            r'^#define GECKO_VERSION "([0-9]+\.[0-9]+\.[0-9]+)"$',
            source,
            re.MULTILINE,
        )
        if match is None:
            raise ValueError("Wine source does not expose a recognized Gecko version")
        return match.group(1)


def required_asset(release: RuntimeRelease, name: str):
    asset = release.asset(name)
    if asset is None:
        raise ValueError(f"{release.tag} is missing {name}")
    return asset


def classify_change_areas(
    pinned,
    candidate,
    changed_files,
    *,
    wine_gecko_changed,
):
    def pin_status(name: str) -> str:
        return "changed" if pinned[name] != candidate[name] else "unchanged"

    nixpkgs_changed = pin_status("NIXPKGS_REV") == "changed"

    workflow_changed = ".github/workflows/build.yml" in changed_files
    return (
        ("WineCX", pin_status("WINECX_COMMIT")),
        ("DXMT", pin_status("DXMT_VERSION")),
        ("MoltenVK", pin_status("MOLTENVK_VERSION")),
        ("Nixpkgs", pin_status("NIXPKGS_REV")),
        ("Media stack", "review" if nixpkgs_changed else "unchanged"),
        ("Wine Gecko", "changed" if wine_gecko_changed else "unchanged"),
        ("Build script", "changed" if workflow_changed else "unchanged"),
        (
            "Patches",
            "changed"
            if any(path.startswith("patches/") for path in changed_files)
            else "unchanged",
        ),
        ("Packaging", "review" if workflow_changed else "unchanged"),
        (
            "GPTK video path",
            "changed"
            if any(path.startswith("gptk-video/") for path in changed_files)
            else "unchanged",
        ),
    )


def github_repository(url: str) -> str | None:
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or not parsed.hostname:
        raise ValueError("source repository URL must use HTTPS")
    if parsed.hostname != "github.com":
        return None
    repository = parsed.path.strip("/").removesuffix(".git")
    if REPOSITORY_PATTERN.fullmatch(repository) is None:
        raise ValueError("source GitHub repository path is invalid")
    return repository


def incident(key: str, error: Exception) -> RuntimeIncident:
    return RuntimeIncident(key=sanitize_key(key), summary=sanitize_summary(str(error)))


def sanitize_key(value: str) -> str:
    sanitized = re.sub(r"[^A-Za-z0-9-]", "-", value)[:80].strip("-")
    return sanitized or "unknown"


def sanitize_summary(value: str) -> str:
    first_line = value.splitlines()[0] if value else "unexpected monitor failure"
    sanitized = re.sub(r"[^A-Za-z0-9 .,_:/()'&+\-]", "", first_line)
    return sanitized[:240].strip() or "unexpected monitor failure"


def _mapping(value: dict[str, Any], key: str) -> dict[str, Any]:
    result = value.get(key)
    if not isinstance(result, dict):
        raise TypeError(f"runtime configuration {key} must be an object")
    return result


def _string(value: dict[str, Any], key: str) -> str:
    result = value.get(key)
    if not isinstance(result, str) or not result:
        raise ValueError(f"{key} must be non-empty text")
    return result


def _run_url(environment: dict[str, str]) -> str:
    server = environment.get("GITHUB_SERVER_URL")
    repository = environment.get("GITHUB_REPOSITORY")
    run_id = environment.get("GITHUB_RUN_ID")
    if not server or not repository or not run_id:
        return "local"
    return f"{server}/{repository}/actions/runs/{run_id}"
