#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Summarize live reports and reconcile monitor-owned GitHub issues."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from lib.common import ScriptError, fail, run_main, success
from lib.contract_monitor import (
    ContractAlertReconciler,
    ContractReport,
    MonitorIssue,
    report_markdown,
)
from lib.github_client import GitHubClient
from lib.github_monitor import GitHubIssueStore, historical_reports

REPORT_ARTIFACT_NAME = "yostar-contract-report"
MAXIMUM_API_RESPONSE_BYTES = 4 * 1_024 * 1_024


def issue_from_json(value: dict[str, object]) -> MonitorIssue:
    return MonitorIssue(
        number=int(value["number"]),
        state=str(value["state"]),
        title=str(value["title"]),
        body=str(value.get("body") or ""),
    )


def load_report(path: Path) -> ContractReport:
    try:
        return ContractReport.from_json(json.loads(path.read_text()))
    except (OSError, TypeError, ValueError, json.JSONDecodeError) as error:
        raise ScriptError(f"invalid contract report at {path}: {error}") from None


def summarize(report_path: Path, output_path: Path | None) -> None:
    markdown = report_markdown(load_report(report_path))
    if output_path:
        with output_path.open("a") as output:
            output.write(markdown)
    else:
        print(markdown, end="")


def reconcile(report_path: Path) -> None:
    repository = os.environ.get("GITHUB_REPOSITORY") or fail(
        "GITHUB_REPOSITORY is required"
    )
    token = os.environ.get("GITHUB_TOKEN") or fail("GITHUB_TOKEN is required")
    run_id = os.environ.get("GITHUB_RUN_ID") or fail("GITHUB_RUN_ID is required")
    current = load_report(report_path)
    if current.trigger != "schedule":
        success("manual contract report does not mutate GitHub issues")
        return
    client = GitHubClient(token)
    store = GitHubIssueStore(
        client,
        repository,
        issue_factory=issue_from_json,
        label_color="B60205",
        label_description="Created and maintained by repository monitoring",
        maximum_api_bytes=MAXIMUM_API_RESPONSE_BYTES,
    )
    history = historical_reports(
        client,
        repository,
        run_id,
        artifact_name=REPORT_ARTIFACT_NAME,
        report_filename="contract-report.json",
        report_factory=ContractReport.from_json,
        limit=14,
        maximum_api_bytes=MAXIMUM_API_RESPONSE_BYTES,
    )
    actions = ContractAlertReconciler(store).reconcile(current, history)
    success(", ".join(actions) if actions else "contract alert state unchanged")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    summary_parser = commands.add_parser("summarize")
    summary_parser.add_argument("report", type=Path)
    summary_parser.add_argument("--output", type=Path)
    reconcile_parser = commands.add_parser("reconcile")
    reconcile_parser.add_argument("report", type=Path)
    arguments = parser.parse_args()
    if arguments.command == "summarize":
        summarize(arguments.report, arguments.output)
    else:
        reconcile(arguments.report)


if __name__ == "__main__":
    run_main(main)
