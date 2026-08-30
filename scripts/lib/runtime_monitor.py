# SPDX-License-Identifier: MPL-2.0

"""Pure models, validation, and issue policy for runtime monitoring."""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol
from urllib.parse import urlparse

from lib.common import safe_relative_path

REPORT_SCHEMA_VERSION = 1
RUNTIME_TAG_PATTERN = re.compile(r"^v([0-9]+)\.([0-9]+)\.([0-9]+)$")
COMMIT_PATTERN = re.compile(r"^[0-9a-f]{40}$")
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")
SAFE_TEXT_PATTERN = re.compile(r"^[A-Za-z0-9 .,_:/()'&+\-]+$")
MONITOR_MARKER_PREFIX = "runtime-monitor:"


@dataclass(frozen=True)
class ReleaseAsset:
    name: str
    size: int
    digest: str | None
    url: str

    @classmethod
    def from_json(cls, value: object) -> ReleaseAsset:
        if not isinstance(value, dict):
            raise TypeError("release asset must be an object")
        name = _required_string(value, "name")
        size = value.get("size")
        if not isinstance(size, int) or isinstance(size, bool) or size < 0:
            raise ValueError("release asset size must be nonnegative")
        digest_value = value.get("digest")
        digest: str | None = None
        if digest_value is not None:
            if not isinstance(digest_value, str) or not digest_value.startswith(
                "sha256:"
            ):
                raise ValueError("release asset digest must use SHA-256")
            digest = digest_value.removeprefix("sha256:")
            if not SHA256_PATTERN.fullmatch(digest):
                raise ValueError("release asset digest must be lowercase SHA-256")
        url = _required_string(value, "browser_download_url")
        parsed_url = urlparse(url)
        if parsed_url.scheme != "https" or parsed_url.hostname != "github.com":
            raise ValueError("release asset URL must target github.com")
        return cls(name=name, size=size, digest=digest, url=url)


@dataclass(frozen=True)
class RuntimeRelease:
    tag: str
    version: tuple[int, int, int]
    body: str
    assets: tuple[ReleaseAsset, ...]

    @classmethod
    def from_json(cls, value: object, *, recipe: bool = False) -> RuntimeRelease:
        if not isinstance(value, dict):
            raise TypeError("release must be an object")
        if value.get("draft") is True:
            raise ValueError("draft release is not eligible")
        tag = _required_string(value, "tag_name")
        version_tag = tag.removeprefix("runtime-") if recipe else tag
        version = parse_runtime_version(version_tag)
        assets_value = value.get("assets")
        if not isinstance(assets_value, list):
            raise TypeError("release assets must be a list")
        assets = tuple(ReleaseAsset.from_json(asset) for asset in assets_value)
        if len({asset.name for asset in assets}) != len(assets):
            raise ValueError("release contains duplicate asset names")
        body = value.get("body") or ""
        if not isinstance(body, str):
            raise TypeError("release body must be text")
        return cls(tag=tag, version=version, body=body, assets=assets)

    def asset(self, name: str) -> ReleaseAsset | None:
        return next((asset for asset in self.assets if asset.name == name), None)


@dataclass(frozen=True)
class RecipeMetadata:
    build_commit: str
    archive_sha256: str
    pins: tuple[tuple[str, str], ...]


@dataclass(frozen=True)
class RuntimeCandidate:
    pinned_version: str
    version: str
    digest: str
    build_commit: str
    impact: str
    changed_pins: tuple[tuple[str, str, str], ...]
    change_areas: tuple[tuple[str, str], ...]
    commit_summaries: tuple[str, ...]
    changed_files: tuple[str, ...]

    @property
    def condition(self) -> str:
        value = f"{self.version}\0{self.digest}\0{self.build_commit}".encode()
        return hashlib.sha256(value).hexdigest()[:16]


@dataclass(frozen=True)
class RuntimeIncident:
    key: str
    summary: str


@dataclass(frozen=True)
class RuntimeMonitorReport:
    checked_at: str
    trigger: str
    run_id: str
    run_url: str
    pinned_version: str
    candidate: RuntimeCandidate | None
    incidents: tuple[RuntimeIncident, ...]
    archive_verification: str

    @classmethod
    def from_json(cls, value: object) -> RuntimeMonitorReport:
        if (
            not isinstance(value, dict)
            or value.get("schemaVersion") != REPORT_SCHEMA_VERSION
        ):
            raise ValueError("unsupported runtime monitor report schema")
        checked_at = _required_string(value, "checkedAt")
        try:
            datetime.fromisoformat(checked_at)
        except ValueError:
            raise ValueError("runtime report checkedAt must be ISO-8601") from None
        trigger = _required_string(value, "trigger")
        if trigger not in {"schedule", "workflow_dispatch", "local"}:
            raise ValueError("runtime report trigger is unsupported")
        run_url = _required_string(value, "runURL")
        parsed_url = urlparse(run_url)
        if run_url != "local" and (
            parsed_url.scheme != "https" or parsed_url.hostname != "github.com"
        ):
            raise ValueError("runtime report runURL must target github.com")
        incidents_value = value.get("incidents")
        if not isinstance(incidents_value, list):
            raise TypeError("runtime report incidents must be a list")
        incidents = tuple(_parse_incident(item) for item in incidents_value)
        if len(incidents) > 32:
            raise ValueError("runtime report contains too many incidents")
        if len({incident.key for incident in incidents}) != len(incidents):
            raise ValueError("runtime report contains duplicate incidents")
        archive_verification = _required_string(value, "archiveVerification")
        if archive_verification not in {"not-requested", "passed", "failed"}:
            raise ValueError("runtime report archiveVerification is unsupported")
        candidate_value = value.get("candidate")
        candidate = (
            None if candidate_value is None else _parse_candidate(candidate_value)
        )
        pinned_version = _validated_version(_required_string(value, "pinnedVersion"))
        if candidate is not None and parse_runtime_version(
            f"v{candidate.version}"
        ) <= parse_runtime_version(f"v{pinned_version}"):
            raise ValueError("runtime candidate must be newer than the pinned runtime")
        return cls(
            checked_at=checked_at,
            trigger=trigger,
            run_id=_required_string(value, "runID"),
            run_url=run_url,
            pinned_version=pinned_version,
            candidate=candidate,
            incidents=incidents,
            archive_verification=archive_verification,
        )


@dataclass(frozen=True)
class RuntimeMonitorIssue:
    number: int
    state: str
    body: str

    @property
    def key(self) -> str | None:
        return _marker_value(self.body, f"<!-- {MONITOR_MARKER_PREFIX}")

    @property
    def condition(self) -> str | None:
        return _marker_value(self.body, "<!-- monitor-condition:")


class RuntimeIssueStore(Protocol):
    def ensure_label(self) -> None: ...

    def list_issues(self) -> list[RuntimeMonitorIssue]: ...

    def create_issue(self, title: str, body: str) -> RuntimeMonitorIssue: ...

    def update_issue(
        self, number: int, *, body: str | None = None, state: str | None = None
    ) -> None: ...

    def add_comment(self, number: int, body: str) -> None: ...


class RuntimeAlertReconciler:
    def __init__(self, store: RuntimeIssueStore) -> None:
        self.store = store

    def reconcile(
        self, current: RuntimeMonitorReport, history: list[RuntimeMonitorReport]
    ) -> list[str]:
        issues: dict[str, RuntimeMonitorIssue] = {}
        for issue in self.store.list_issues():
            key = issue.key
            if key not in {"candidate", "availability"}:
                continue
            existing = issues.get(key)
            if existing is None or (issue.state == "open" and existing.state != "open"):
                issues[key] = issue
        actions: list[str] = []
        candidate_action = self._candidate(current, issues.get("candidate"))
        if candidate_action:
            actions.append(candidate_action)
        availability_action = self._availability(
            current, history, issues.get("availability")
        )
        if availability_action:
            actions.append(availability_action)
        return actions

    def _candidate(
        self, report: RuntimeMonitorReport, issue: RuntimeMonitorIssue | None
    ) -> str | None:
        candidate = report.candidate
        if candidate is None:
            return None
        body = candidate_issue_body(candidate, report)
        if issue is None:
            self.store.ensure_label()
            self.store.create_issue(
                "Review newer Wine runtime",
                body,
            )
            return "opened runtime candidate"
        if issue.condition == candidate.condition:
            if issue.state == "open":
                self.store.update_issue(issue.number, body=body)
            return None
        self.store.update_issue(issue.number, body=body, state="open")
        self.store.add_comment(
            issue.number,
            f"A newer runtime candidate is available: `{candidate.version}`.\n\n"
            f"Latest run: {report.run_url}",
        )
        return "updated runtime candidate"

    def _availability(
        self,
        report: RuntimeMonitorReport,
        history: list[RuntimeMonitorReport],
        issue: RuntimeMonitorIssue | None,
    ) -> str | None:
        if report.incidents:
            body, condition = availability_issue_body(report)
            if issue is None:
                self.store.ensure_label()
                self.store.create_issue("Runtime source availability incident", body)
                return "opened runtime availability incident"
            self.store.update_issue(issue.number, body=body, state="open")
            if issue.state == "closed":
                self.store.add_comment(
                    issue.number,
                    "The runtime availability incident occurred again.\n\n"
                    f"Latest run: {report.run_url}",
                )
                return "reopened runtime availability incident"
            if issue.condition != condition:
                self.store.add_comment(
                    issue.number,
                    "The observed runtime availability condition changed.\n\n"
                    f"Latest run: {report.run_url}",
                )
                return "updated runtime availability incident"
            return None
        if issue is None or issue.state != "open":
            return None
        scheduled = [item for item in history if item.trigger == "schedule"]
        if not scheduled or scheduled[0].incidents:
            return None
        self.store.add_comment(
            issue.number,
            "Runtime sources passed two consecutive scheduled checks and are considered recovered."
            f"\n\nLatest run: {report.run_url}",
        )
        self.store.update_issue(issue.number, state="closed")
        return "closed runtime availability incident"


def parse_runtime_version(tag: str) -> tuple[int, int, int]:
    match = RUNTIME_TAG_PATTERN.fullmatch(tag)
    if match is None:
        raise ValueError("runtime tag must use vX.Y.Z")
    return tuple(int(component) for component in match.groups())  # type: ignore[return-value]


def select_latest_mirror_release(values: list[object]) -> RuntimeRelease:
    candidates: list[RuntimeRelease] = []
    for value in values:
        try:
            release = RuntimeRelease.from_json(value)
        except (TypeError, ValueError):
            continue
        if release.asset("Libraries.tar.gz") is not None:
            candidates.append(release)
    if not candidates:
        raise ValueError("no mirrored runtime release contains Libraries.tar.gz")
    return max(candidates, key=lambda release: release.version)


def parse_recipe_metadata(release: RuntimeRelease) -> RecipeMetadata:
    values = {
        name.lower(): value
        for name, value in re.findall(
            r"\|\s*([A-Za-z0-9]+)\s*\|\s*`?([0-9A-Za-z.]+)`?\s*\|",
            release.body,
        )
    }
    required = {"winecx", "dxvk", "dxmt", "moltenvk", "sha256"}
    if not required <= values.keys():
        raise ValueError("recipe release notes are missing component metadata")
    build_match = re.search(r"Built from ([0-9a-f]{40})\.", release.body)
    if build_match is None or not SHA256_PATTERN.fullmatch(values["sha256"]):
        raise ValueError("recipe release notes have invalid provenance")
    return RecipeMetadata(
        build_commit=build_match.group(1),
        archive_sha256=values["sha256"],
        pins=tuple(sorted((name, values[name]) for name in required - {"sha256"})),
    )


def parse_recipe_pins(workflow: str) -> dict[str, str]:
    names = (
        "WINECX_COMMIT",
        "NIXPKGS_REV",
        "MOLTENVK_VERSION",
        "FAUDIO_VERSION",
        "DXVK_VERSION",
        "DXMT_VERSION",
        "MACOSX_DEPLOYMENT_TARGET",
    )
    pins: dict[str, str] = {}
    for name in names:
        match = re.search(
            rf"^\s{{2}}{name}:\s*[\"']?([^\s\"']+)", workflow, re.MULTILINE
        )
        if match is None:
            raise ValueError(f"recipe workflow is missing {name}")
        pins[name] = _safe_text(match.group(1), f"recipe pin {name}")
    return pins


def candidate_issue_body(
    candidate: RuntimeCandidate, report: RuntimeMonitorReport
) -> str:
    changed = [
        f"- `{name}`: `{old}` -> `{new}`" for name, old, new in candidate.changed_pins
    ] or ["- No tracked component pin changed"]
    commits = [f"- {summary}" for summary in candidate.commit_summaries] or [
        "- No recipe commits reported"
    ]
    files = [f"- `{path}`" for path in candidate.changed_files] or [
        "- No changed files reported"
    ]
    return "\n".join(
        [
            f"<!-- {MONITOR_MARKER_PREFIX}candidate -->",
            f"<!-- monitor-condition:{candidate.condition} -->",
            "## Runtime candidate",
            "",
            f"A newer mirrored runtime is available: `{candidate.pinned_version}` -> `{candidate.version}`.",
            "",
            f"- Archive SHA-256: `{candidate.digest}`",
            f"- Recipe commit: `{candidate.build_commit}`",
            f"- Expected impact: `{candidate.impact}`",
            f"- Recipe release: https://github.com/dappermint/winecx-gptk/releases/tag/runtime-v{candidate.version}",
            f"- Mirror release: https://github.com/dappermint/Whisky/releases/tag/v{candidate.version}",
            "",
            "### Changed pins",
            "",
            *changed,
            "",
            "### Change areas",
            "",
            *[f"- {name}: `{status}`" for name, status in candidate.change_areas],
            "",
            "### Recipe commits",
            "",
            *commits,
            "",
            "### Changed recipe files",
            "",
            *files,
            "",
            "### Maintainer review",
            "",
            "- Inspect source and recipe changes.",
            "- Verify notices and corresponding-source coverage.",
            "- Hash the archive independently.",
            "- Test fresh and existing prefixes, login, media, display modes, MSYNC, ESYNC, and gameplay.",
            "- Update runtime.json only after manual approval.",
            "",
            f"Latest monitor run: {report.run_url}",
            "",
            "This issue is maintained automatically but requires a maintainer decision before closing.",
        ]
    )


def availability_issue_body(report: RuntimeMonitorReport) -> tuple[str, str]:
    incidents = sorted(report.incidents, key=lambda item: item.key)
    condition = hashlib.sha256(
        "\0".join(f"{item.key}:{item.summary}" for item in incidents).encode()
    ).hexdigest()[:16]
    lines = [f"- `{item.key}`: {item.summary}" for item in incidents]
    body = "\n".join(
        [
            f"<!-- {MONITOR_MARKER_PREFIX}availability -->",
            f"<!-- monitor-condition:{condition} -->",
            "## Runtime source availability incident",
            "",
            *lines,
            "",
            f"Latest monitor run: {report.run_url}",
            "",
            "This issue is maintained automatically. Remote response bodies are not included.",
        ]
    )
    return body, condition


def report_value(report: RuntimeMonitorReport) -> dict[str, object]:
    candidate: dict[str, object] | None = None
    if report.candidate:
        candidate = {
            "pinnedVersion": report.candidate.pinned_version,
            "version": report.candidate.version,
            "digest": report.candidate.digest,
            "buildCommit": report.candidate.build_commit,
            "impact": report.candidate.impact,
            "changedPins": [
                {"name": name, "old": old, "new": new}
                for name, old, new in report.candidate.changed_pins
            ],
            "changeAreas": [
                {"name": name, "status": status}
                for name, status in report.candidate.change_areas
            ],
            "commitSummaries": list(report.candidate.commit_summaries),
            "changedFiles": list(report.candidate.changed_files),
        }
    return {
        "schemaVersion": REPORT_SCHEMA_VERSION,
        "checkedAt": report.checked_at,
        "trigger": report.trigger,
        "runID": report.run_id,
        "runURL": report.run_url,
        "pinnedVersion": report.pinned_version,
        "candidate": candidate,
        "incidents": [
            {"key": incident.key, "summary": incident.summary}
            for incident in report.incidents
        ],
        "archiveVerification": report.archive_verification,
    }


def report_markdown(report: RuntimeMonitorReport) -> str:
    candidate = report.candidate.version if report.candidate else "none"
    lines = [
        "## Runtime monitor",
        "",
        f"- Checked: `{report.checked_at}`",
        f"- Pinned runtime: `{report.pinned_version}`",
        f"- Review candidate: `{candidate}`",
        f"- Full archive verification: `{report.archive_verification}`",
        f"- Availability incidents: `{len(report.incidents)}`",
    ]
    if report.candidate:
        lines.append(f"- Expected impact: `{report.candidate.impact}`")
        lines.extend(["", "### Changed pins", ""])
        lines.extend(
            f"- `{name}`: `{old}` -> `{new}`"
            for name, old, new in report.candidate.changed_pins
        )
        if not report.candidate.changed_pins:
            lines.append("- No tracked component pins changed")
        lines.extend(["", "### Change areas", ""])
        lines.extend(
            f"- {name}: `{status}`" for name, status in report.candidate.change_areas
        )
    if report.incidents:
        lines.extend(["", "### Incidents", ""])
        lines.extend(
            f"- `{incident.key}`: {incident.summary}" for incident in report.incidents
        )
    return "\n".join(lines) + "\n"


def _parse_incident(value: object) -> RuntimeIncident:
    if not isinstance(value, dict):
        raise TypeError("runtime incident must be an object")
    key = _safe_text(_required_string(value, "key"), "incident key")
    summary = _safe_text(_required_string(value, "summary"), "incident summary")
    return RuntimeIncident(key=key, summary=summary)


def _parse_candidate(value: object) -> RuntimeCandidate:
    if not isinstance(value, dict):
        raise TypeError("runtime candidate must be an object")
    changed_pins_value = value.get("changedPins")
    change_areas_value = value.get("changeAreas")
    commits_value = value.get("commitSummaries")
    files_value = value.get("changedFiles")
    if not isinstance(changed_pins_value, list):
        raise TypeError("candidate changedPins must be a list")
    if not isinstance(change_areas_value, list):
        raise TypeError("candidate changeAreas must be a list")
    if not isinstance(commits_value, list) or not isinstance(files_value, list):
        raise TypeError("candidate change summaries must be lists")
    if (
        len(changed_pins_value) > 16
        or len(change_areas_value) > 16
        or len(commits_value) > 20
        or len(files_value) > 50
    ):
        raise ValueError("candidate change summary exceeds its item limit")
    changed_pins: list[tuple[str, str, str]] = []
    for item in changed_pins_value:
        if not isinstance(item, dict):
            raise TypeError("candidate changed pin must be an object")
        changed_pins.append(
            (
                _safe_text(_required_string(item, "name"), "pin name"),
                _safe_text(_required_string(item, "old"), "old pin"),
                _safe_text(_required_string(item, "new"), "new pin"),
            )
        )
    if len({item[0] for item in changed_pins}) != len(changed_pins):
        raise ValueError("candidate contains duplicate changed pins")
    change_areas: list[tuple[str, str]] = []
    for item in change_areas_value:
        if not isinstance(item, dict):
            raise TypeError("candidate change area must be an object")
        status = _required_string(item, "status")
        if status not in {"changed", "unchanged", "review"}:
            raise ValueError("candidate change area status is unsupported")
        change_areas.append(
            (_safe_text(_required_string(item, "name"), "change area"), status)
        )
    if len({item[0] for item in change_areas}) != len(change_areas):
        raise ValueError("candidate contains duplicate change areas")
    return RuntimeCandidate(
        pinned_version=_validated_version(_required_string(value, "pinnedVersion")),
        version=_validated_version(_required_string(value, "version")),
        digest=_validated_sha256(_required_string(value, "digest")),
        build_commit=_validated_commit(_required_string(value, "buildCommit")),
        impact=_validated_impact(_required_string(value, "impact")),
        changed_pins=tuple(changed_pins),
        change_areas=tuple(change_areas),
        commit_summaries=tuple(
            _safe_text(item, "commit summary") for item in commits_value
        ),
        changed_files=tuple(
            safe_relative_path(item, "changed file must be a safe relative path")
            for item in files_value
        ),
    )


def _required_string(value: dict[object, object], key: str) -> str:
    result = value.get(key)
    if not isinstance(result, str) or not result:
        raise ValueError(f"runtime monitor {key} must be non-empty text")
    return result


def _safe_text(value: object, name: str) -> str:
    if (
        not isinstance(value, str)
        or len(value) > 240
        or SAFE_TEXT_PATTERN.fullmatch(value) is None
    ):
        raise ValueError(f"{name} must be short safe text")
    return value


def _validated_version(value: str) -> str:
    parse_runtime_version(f"v{value}")
    return value


def _validated_sha256(value: str) -> str:
    if SHA256_PATTERN.fullmatch(value) is None:
        raise ValueError("runtime digest must be lowercase SHA-256")
    return value


def _validated_commit(value: str) -> str:
    if COMMIT_PATTERN.fullmatch(value) is None:
        raise ValueError("runtime build commit must be lowercase Git commit")
    return value


def _validated_impact(value: str) -> str:
    if value not in {"used-components", "optional-or-recipe-only", "metadata-only"}:
        raise ValueError("runtime candidate impact is unsupported")
    return value


def _marker_value(body: str, prefix: str) -> str | None:
    for line in body.splitlines():
        if line.startswith(prefix) and line.endswith(" -->"):
            return line.removeprefix(prefix).removesuffix(" -->")
    return None
