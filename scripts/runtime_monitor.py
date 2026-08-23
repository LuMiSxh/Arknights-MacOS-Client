#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Inspect pinned runtime provenance and reconcile monitor-owned issues."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from lib.common import PROJECT_DIR, ScriptError, fail, run_main, success
from lib.github_client import GitHubClient
from lib.github_monitor import GitHubIssueStore, historical_reports
from lib.runtime_monitor import (
    RuntimeAlertReconciler,
    RuntimeMonitorIssue,
    RuntimeMonitorReport,
    report_markdown,
    report_value,
)
from lib.runtime_probe import RuntimeProbe

REPORT_ARTIFACT_NAME = "runtime-monitor-report"


def issue_from_json(value: dict[str, object]) -> RuntimeMonitorIssue:
    return RuntimeMonitorIssue(
        number=int(value["number"]),
        state=str(value["state"]),
        body=str(value.get("body") or ""),
    )


def load_report(path: Path) -> RuntimeMonitorReport:
    try:
        return RuntimeMonitorReport.from_json(json.loads(path.read_text()))
    except (OSError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise ScriptError(f"invalid runtime monitor report: {error}") from None


def probe(config: Path, output: Path, verify_archive: bool) -> None:
    client = GitHubClient(os.environ.get("GITHUB_TOKEN"))
    report = RuntimeProbe(
        client=client,
        config_path=config,
        notices_path=PROJECT_DIR / "docs/legal/third-party-notices.md",
    ).run(environment=dict(os.environ), verify_archive=verify_archive)
    output.write_text(json.dumps(report_value(report), indent=2, sort_keys=True) + "\n")
    if report.incidents:
        fail(f"runtime monitor found {len(report.incidents)} availability incident(s)")


def summarize(report_path: Path, output: Path | None) -> None:
    markdown = report_markdown(load_report(report_path))
    if output:
        with output.open("a") as stream:
            stream.write(markdown)
    else:
        print(markdown, end="")


def reconcile(report_path: Path) -> None:
    repository = os.environ.get("GITHUB_REPOSITORY") or fail(
        "GITHUB_REPOSITORY is required"
    )
    token = os.environ.get("GITHUB_TOKEN") or fail("GITHUB_TOKEN is required")
    run_id = os.environ.get("GITHUB_RUN_ID") or fail("GITHUB_RUN_ID is required")
    report = load_report(report_path)
    if report.trigger != "schedule":
        success("manual runtime report does not mutate GitHub issues")
        return
    client = GitHubClient(token)
    store = GitHubIssueStore(
        client,
        repository,
        issue_factory=issue_from_json,
        label_color="6E7781",
        label_description="Created and maintained by repository automation",
    )
    history = historical_reports(
        client,
        repository,
        run_id,
        artifact_name=REPORT_ARTIFACT_NAME,
        report_filename="runtime-monitor-report.json",
        report_factory=RuntimeMonitorReport.from_json,
        limit=4,
    )
    actions = RuntimeAlertReconciler(store).reconcile(report, history)
    success(", ".join(actions) if actions else "runtime alert state unchanged")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    probe_parser = commands.add_parser("probe")
    probe_parser.add_argument("config", type=Path)
    probe_parser.add_argument("--output", type=Path, required=True)
    probe_parser.add_argument("--verify-archive", action="store_true")
    summary_parser = commands.add_parser("summarize")
    summary_parser.add_argument("report", type=Path)
    summary_parser.add_argument("--output", type=Path)
    reconcile_parser = commands.add_parser("reconcile")
    reconcile_parser.add_argument("report", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "probe":
        probe(arguments.config, arguments.output, arguments.verify_archive)
    elif arguments.command == "summarize":
        summarize(arguments.report, arguments.output)
    else:
        reconcile(arguments.report)


if __name__ == "__main__":
    run_main(main)
