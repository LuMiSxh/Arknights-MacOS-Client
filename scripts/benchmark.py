#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Sample CPU, GPU, and memory use of a running game for a fair comparison."""

from __future__ import annotations

import argparse
import csv
import json
import re
import statistics
import subprocess
import time
from collections.abc import Callable, Sequence
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from lib.common import BUILD_DIR, ScriptError, run_main
from lib.console import info, success, warning

DEFAULT_OUTPUT_ROOT = BUILD_DIR / "benchmarks"
DEFAULT_INTERVAL_SECONDS = 1.0
CASE_PATTERN = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*\Z")
TARGET_PATTERNS = {
    # Wine reports Windows paths as the process name, so the .exe patterns match a suffix.
    "arknights-client": (
        r"^Arknights$",
        r"Arknights\.exe$",
        r"^wine64",
        r"^wineserver$",
        r"PlatformProcess.*\.exe$",
        r"BLWebBrowser\.exe$",
        r"PCGamePlatform\.exe$",
    ),
    "playcover": (r"^arknights$", r"^Arknights$"),
}
GPU_KEYS = {
    "device": "Device Utilization %",
    "renderer": "Renderer Utilization %",
    "tiler": "Tiler Utilization %",
}
METRIC_LABELS = {
    "cpu_percent": "CPU, mean (% of one core)",
    "system_cpu_percent": "System CPU, mean (% of one core)",
    "background_cpu_percent": "Background CPU, mean (% of one core)",
    "background_process_count": "Background process count, mean",
    "resident_mib": "Resident memory, mean (MiB)",
    "process_count": "Process count, mean",
    "gpu_device_percent": "GPU device, mean (%)",
    "gpu_renderer_percent": "GPU renderer, mean (%)",
    "gpu_tiler_percent": "GPU tiler, mean (%)",
    "free_mib": "Free memory, mean (MiB)",
    "wired_mib": "Wired memory, mean (MiB)",
    "compressed_mib": "Compressed memory, mean (MiB)",
    "cpu_speed_limit": "CPU speed limit, mean (%)",
}
CSV_FIELDS = (
    "timestamp",
    "elapsed_seconds",
    "cpu_percent",
    "system_cpu_percent",
    "background_cpu_percent",
    "background_process_count",
    "resident_mib",
    "process_count",
    "gpu_device_percent",
    "gpu_renderer_percent",
    "gpu_tiler_percent",
    "free_mib",
    "wired_mib",
    "compressed_mib",
    "cpu_speed_limit",
    "power_source",
)


class BenchmarkError(ScriptError):
    """The requested benchmark cannot run or cannot be read."""


@dataclass(frozen=True, slots=True)
class ProcessRow:
    pid: int
    parent_pid: int
    resident_kib: int
    cpu_seconds: float
    command: str


def case_name(value: str) -> str:
    if value in {".", ".."} or CASE_PATTERN.fullmatch(value) is None:
        raise BenchmarkError("case must be a safe path component")
    return value


def parse_ps_time(value: str) -> float:
    try:
        days, _, clock = value.rpartition("-")
        parts = [float(part) for part in clock.split(":")]
        if len(parts) == 2:
            parts.insert(0, 0.0)
        if len(parts) != 3:
            raise ValueError
        return int(days or 0) * 86_400 + parts[0] * 3_600 + parts[1] * 60 + parts[2]
    except ValueError as error:
        raise BenchmarkError(f"invalid ps time: {value!r}") from error


def parse_process_table(text: str) -> list[ProcessRow]:
    rows: list[ProcessRow] = []
    for line in text.splitlines():
        fields = line.split(maxsplit=4)
        if len(fields) != 5:
            continue
        try:
            rows.append(
                ProcessRow(
                    int(fields[0]),
                    int(fields[1]),
                    int(fields[2]),
                    parse_ps_time(fields[3]),
                    fields[4],
                )
            )
        except BenchmarkError, ValueError:
            continue
    return rows


def select_processes(
    rows: Sequence[ProcessRow], patterns: Sequence[str]
) -> list[ProcessRow]:
    compiled = [re.compile(pattern, re.IGNORECASE) for pattern in patterns]
    by_pid = {row.pid: row for row in rows}
    children: dict[int, list[int]] = {}
    for row in rows:
        children.setdefault(row.parent_pid, []).append(row.pid)
    roots = {
        row.pid
        for row in rows
        if any(pattern.search(Path(row.command).name) for pattern in compiled)
    }
    selected: list[ProcessRow] = []
    seen: set[int] = set()
    stack = list(roots)
    while stack:
        pid = stack.pop()
        if pid in seen or pid not in by_pid:
            continue
        seen.add(pid)
        selected.append(by_pid[pid])
        stack.extend(children.get(pid, ()))
    return sorted(selected, key=lambda row: row.pid)


def cpu_seconds_delta(previous: dict[int, float], current: dict[int, float]) -> float:
    return sum(
        max(0.0, current[pid] - previous[pid])
        for pid in current.keys() & previous.keys()
    )


def parse_gpu_utilization(text: str) -> dict[str, int]:
    values: dict[str, int] = {}
    for name, key in GPU_KEYS.items():
        matches = [
            int(value) for value in re.findall(rf'"{re.escape(key)}"\s*=\s*(\d+)', text)
        ]
        if matches:
            values[name] = max(matches)
    return values


def parse_vm_stat(text: str) -> dict[str, float]:
    page_size_match = re.search(r"page size of (\d+) bytes", text)
    if page_size_match is None:
        return {}
    page_size = int(page_size_match.group(1))
    keys = {
        "free_mib": "Pages free",
        "wired_mib": "Pages wired down",
        "compressed_mib": "Pages occupied by compressor",
    }
    values: dict[str, float] = {}
    for name, key in keys.items():
        match = re.search(rf"^{re.escape(key)}:\s+(\d+)\.", text, re.MULTILINE)
        if match is not None:
            values[name] = int(match.group(1)) * page_size / 1_048_576
    return values


def parse_cpu_speed_limit(text: str) -> int | None:
    match = re.search(r"CPU_Speed_Limit\s*=\s*(\d+)", text)
    return int(match.group(1)) if match is not None else None


def parse_power_source(text: str) -> str | None:
    match = re.search(r"Now drawing from '([^']+)'", text)
    return match.group(1) if match is not None else None


def percentile(values: Sequence[float], fraction: float) -> float:
    if len(values) < 2:
        return values[0]
    return statistics.quantiles(values, n=100, method="inclusive")[int(fraction) - 1]


def summarize(samples: Sequence[dict[str, Any]]) -> dict[str, Any]:
    metrics: dict[str, dict[str, float | int]] = {}
    for metric in METRIC_LABELS:
        values = [
            float(sample[metric])
            for sample in samples
            if sample.get(metric) is not None
        ]
        if not values:
            continue
        metrics[metric] = {
            "count": len(values),
            "mean": statistics.fmean(values),
            "median": statistics.median(values),
            "p95": percentile(values, 95),
            "min": min(values),
            "max": max(values),
            "stdev": statistics.stdev(values) if len(values) > 1 else 0.0,
        }
    return {"sampleCount": len(samples), "metrics": metrics}


def _run(command: Sequence[str], *, required: bool = True) -> str:
    try:
        return subprocess.run(
            list(command), capture_output=True, check=True, text=True
        ).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        if required:
            raise BenchmarkError(
                f"command failed: {' '.join(command)}: {error}"
            ) from error
        return ""


def _try_run(command: Sequence[str]) -> str:
    return _run(command, required=False)


def machine_information(run: Callable[[Sequence[str]], str]) -> dict[str, Any]:
    return {
        "model": run(["sysctl", "-n", "hw.model"]).strip(),
        "chip": run(["sysctl", "-n", "machdep.cpu.brand_string"]).strip(),
        "logicalCores": int(run(["sysctl", "-n", "hw.ncpu"]).strip()),
        "memoryBytes": int(run(["sysctl", "-n", "hw.memsize"]).strip()),
        "macOSVersion": run(["sw_vers", "-productVersion"]).strip(),
        "macOSBuild": run(["sw_vers", "-buildVersion"]).strip(),
    }


def parse_display_information(text: str) -> dict[str, Any]:
    try:
        value: Any = json.loads(text)
    except json.JSONDecodeError:
        return {}
    if not isinstance(value, dict):
        return {}
    displays = value.get("SPDisplaysDataType")
    if not isinstance(displays, list):
        return {}
    for gpu in displays:
        if not isinstance(gpu, dict):
            continue
        for display in gpu.get("spdisplays_ndrvs", []):
            if not isinstance(display, dict):
                continue
            if display.get("spdisplays_main") != "spdisplays_yes":
                continue
            resolution = str(display.get("_spdisplays_resolution", ""))
            match = re.search(r"@\s*([\d.]+)Hz", resolution)
            return {
                "pixels": display.get("_spdisplays_pixels", ""),
                "points": resolution.split("@")[0].strip(),
                "refreshHz": float(match.group(1)) if match else None,
            }
    return {}


def parse_window_bounds(text: str) -> dict[str, int] | None:
    parts = [part.strip() for part in text.strip().split(",")]
    if len(parts) != 4:
        return None
    try:
        x, y, width, height = (int(part) for part in parts)
    except ValueError:
        return None
    return {"x": x, "y": y, "width": width, "height": height}


def foreground_app(run: Callable[[Sequence[str]], str]) -> str | None:
    output = run(
        [
            "osascript",
            "-e",
            'tell application "System Events" to get name of first application process whose frontmost is true',
        ]
    )
    return output.strip() or None


def window_information(
    run: Callable[[Sequence[str]], str], selected: Sequence[ProcessRow]
) -> dict[str, Any] | None:
    for row in selected:
        name = Path(row.command).name.replace('"', '\\"')
        bounds = parse_window_bounds(
            run(
                [
                    "osascript",
                    "-e",
                    f'tell application "System Events" to get {{position, size}} of window 1 of process "{name}"',
                ]
            )
        )
        if bounds:
            return {"process": Path(row.command).name, **bounds}
    return None


def _background_top(
    cpu_totals: dict[int, float],
    rss_totals: dict[int, float],
    names: dict[int, str],
    duration: float,
    sample_count: int,
) -> dict[str, list[dict[str, Any]]]:
    duration = max(duration, 1e-9)
    sample_count = max(sample_count, 1)
    cpu = sorted(
        (
            {
                "process": names[pid],
                "pid": pid,
                "meanCpuPercent": total / duration * 100,
            }
            for pid, total in cpu_totals.items()
        ),
        key=lambda item: item["meanCpuPercent"],
        reverse=True,
    )[:5]
    memory = sorted(
        (
            {
                "process": names[pid],
                "pid": pid,
                "meanResidentMiB": total / sample_count / 1024,
            }
            for pid, total in rss_totals.items()
        ),
        key=lambda item: item["meanResidentMiB"],
        reverse=True,
    )[:5]
    return {"topCpu": cpu, "topMemory": memory}


def _utc_timestamp(value: datetime) -> str:
    return value.astimezone(UTC).isoformat(timespec="seconds").replace("+00:00", "Z")


def _run_directory(output_root: Path, case: str, start: datetime) -> Path:
    output_root.mkdir(parents=True, exist_ok=True)
    stem = f"{case}-{start.astimezone(UTC):%Y%m%dT%H%M%SZ}"
    for sequence in range(1, 10_000):
        candidate = output_root / f"{stem}{'' if sequence == 1 else f'-{sequence}'}"
        try:
            candidate.mkdir()
        except FileExistsError:
            continue
        return candidate
    raise BenchmarkError("could not allocate a benchmark run directory")


def sample(
    case: str,
    *,
    seconds: float,
    interval: float = DEFAULT_INTERVAL_SECONDS,
    target: str = "arknights-client",
    patterns: Sequence[str] = (),
    note: str = "",
    output_root: Path = DEFAULT_OUTPUT_ROOT,
    run: Callable[[Sequence[str]], str] = _run,
    optional_run: Callable[[Sequence[str]], str] = _try_run,
    clock: Callable[[], float] = time.monotonic,
    wait: Callable[[float], None] = time.sleep,
) -> Path:
    case = case_name(case)
    if seconds <= 0 or interval <= 0:
        raise BenchmarkError("seconds and interval must be greater than zero")
    if not patterns:
        patterns = TARGET_PATTERNS.get(target, ())
    if not patterns:
        raise BenchmarkError(f"target {target!r} has no process patterns; pass --match")
    sample_count = max(1, round(seconds / interval))
    started_at = datetime.now(UTC)
    start = clock()
    initial_rows = parse_process_table(
        run(["ps", "-axo", "pid=,ppid=,rss=,time=,comm="])
    )
    selected = select_processes(initial_rows, patterns)
    if not selected:
        raise BenchmarkError(
            "no matching process is running; start the game before you sample"
        )
    info(
        f"Sampling {len(selected)} process(es) for {seconds:g} s "
        f"at {interval:g} s intervals"
    )
    previous_all = {row.pid: row.cpu_seconds for row in initial_rows}
    display = parse_display_information(
        optional_run(["system_profiler", "SPDisplaysDataType", "-json"])
    )
    foreground_start = foreground_app(optional_run)
    window = window_information(optional_run, selected)
    background_cpu_totals: dict[int, float] = {}
    background_rss_totals: dict[int, float] = {}
    background_names: dict[int, str] = {}
    previous_time = start
    samples: list[dict[str, Any]] = []
    warned_empty = False
    for _ in range(sample_count):
        wait(interval)
        now = clock()
        rows = parse_process_table(run(["ps", "-axo", "pid=,ppid=,rss=,time=,comm="]))
        selected = select_processes(rows, patterns)
        if not selected and not warned_empty:
            warning("No matching process is running; the run may be invalid")
            warned_empty = True
        by_pid = {row.pid: row for row in rows}
        current_all = {row.pid: row.cpu_seconds for row in rows}
        selected_pids = {row.pid for row in selected}
        deltas = {
            pid: max(0.0, current_all[pid] - previous_all[pid])
            for pid in current_all.keys() & previous_all.keys()
        }
        system_cpu_seconds = sum(deltas.values())
        selected_cpu_seconds = sum(
            delta for pid, delta in deltas.items() if pid in selected_pids
        )
        background_cpu_seconds = max(0.0, system_cpu_seconds - selected_cpu_seconds)
        for pid, delta in deltas.items():
            if pid in selected_pids:
                continue
            background_cpu_totals[pid] = background_cpu_totals.get(pid, 0.0) + delta
            row = by_pid[pid]
            background_rss_totals[pid] = (
                background_rss_totals.get(pid, 0.0) + row.resident_kib
            )
            background_names[pid] = Path(row.command).name
        elapsed = now - previous_time
        gpu = parse_gpu_utilization(
            optional_run(["ioreg", "-r", "-d", "1", "-c", "IOAccelerator", "-w", "0"])
        )
        memory = parse_vm_stat(optional_run(["vm_stat"]))
        samples.append(
            {
                "timestamp": _utc_timestamp(datetime.now(UTC)),
                "elapsed_seconds": now - start,
                "cpu_percent": (
                    selected_cpu_seconds / elapsed * 100 if elapsed > 0 else None
                ),
                "system_cpu_percent": (
                    system_cpu_seconds / elapsed * 100 if elapsed > 0 else None
                ),
                "background_cpu_percent": (
                    background_cpu_seconds / elapsed * 100 if elapsed > 0 else None
                ),
                "background_process_count": len(current_all) - len(selected),
                "resident_mib": sum(row.resident_kib for row in selected) / 1024,
                "process_count": len(selected),
                "gpu_device_percent": gpu.get("device"),
                "gpu_renderer_percent": gpu.get("renderer"),
                "gpu_tiler_percent": gpu.get("tiler"),
                "free_mib": memory.get("free_mib"),
                "wired_mib": memory.get("wired_mib"),
                "compressed_mib": memory.get("compressed_mib"),
                "cpu_speed_limit": parse_cpu_speed_limit(
                    optional_run(["pmset", "-g", "therm"])
                ),
                "power_source": parse_power_source(
                    optional_run(["pmset", "-g", "batt"])
                ),
            }
        )
        previous_all = current_all
        previous_time = now
    ended_at = datetime.now(UTC)
    foreground_end = foreground_app(optional_run)
    background_top = _background_top(
        background_cpu_totals,
        background_rss_totals,
        background_names,
        previous_time - start,
        len(samples),
    )
    run_directory = _run_directory(output_root, case, started_at)
    with (run_directory / "samples.csv").open(
        "w", encoding="utf-8", newline=""
    ) as file:
        writer = csv.DictWriter(file, fieldnames=CSV_FIELDS)
        writer.writeheader()
        writer.writerows(
            {field: sample.get(field) for field in CSV_FIELDS} for sample in samples
        )
    summary = summarize(samples)
    summary["durationSeconds"] = previous_time - start
    (run_directory / "summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    manifest = {
        "schemaVersion": 1,
        "case": case,
        "note": note,
        "target": target,
        "patterns": list(patterns),
        "intervalSeconds": interval,
        "requestedDurationSeconds": seconds,
        "start": _utc_timestamp(started_at),
        "end": _utc_timestamp(ended_at),
        "machine": machine_information(run),
        "display": display,
        "window": window,
        "foregroundAtStart": foreground_start,
        "foregroundAtEnd": foreground_end,
        "backgroundTop": background_top,
        "samples": "samples.csv",
        "summary": "summary.json",
    }
    (run_directory / "manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    success(f"Benchmark run complete: {run_directory}")
    return run_directory


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value: Any = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise BenchmarkError(f"cannot read {path}: {error}") from error
    if not isinstance(value, dict):
        raise BenchmarkError(f"{path} does not contain a JSON object")
    return value


def _read_samples(path: Path) -> list[dict[str, Any]]:
    try:
        with path.open(encoding="utf-8", newline="") as file:
            rows: list[dict[str, Any]] = []
            for row in csv.DictReader(file):
                parsed: dict[str, Any] = {}
                for field in CSV_FIELDS:
                    value = row.get(field)
                    if value in (None, ""):
                        parsed[field] = None
                    elif field in {"timestamp", "power_source"}:
                        parsed[field] = value
                    elif field == "process_count":
                        parsed[field] = int(value)
                    else:
                        parsed[field] = float(value)
                rows.append(parsed)
            return rows
    except (OSError, ValueError) as error:
        raise BenchmarkError(f"cannot read {path}: {error}") from error


def _downsample(
    samples: Sequence[dict[str, Any]], maximum: int
) -> list[dict[str, Any]]:
    if maximum <= 0:
        raise BenchmarkError("max-samples must be greater than zero")
    if len(samples) <= maximum:
        return list(samples)
    stride = (len(samples) + maximum - 1) // maximum
    selected = list(samples[::stride])
    if selected[-1] is not samples[-1]:
        selected.append(samples[-1])
    return selected


def _read_run(
    path: Path, label: str, maximum_samples: int, slot: int | None = None
) -> dict[str, Any]:
    manifest = _load_json(path / "manifest.json")
    run = {
        "label": label
        or {
            "arknights-client": "Arknights Client",
            "playcover": "PlayCover",
        }.get(manifest.get("target"), manifest.get("case", "Run")),
        "target": manifest.get("target", ""),
        "case": manifest.get("case", ""),
        "note": manifest.get("note", ""),
        "machine": manifest.get("machine", {}),
        "summary": _load_json(path / "summary.json"),
        "samples": _downsample(_read_samples(path / "samples.csv"), maximum_samples),
    }
    if slot is not None:
        run["slot"] = slot
    return run


def _read_slots(slots: Sequence[int] | None, count: int) -> list[int | None]:
    """Return one palette slot per run. A run without a slot falls back to its position."""
    if not slots:
        return [None] * count
    if len(slots) != count:
        raise ScriptError(f"expected {count} color slots, got {len(slots)}")
    if len(set(slots)) != len(slots) or any(slot < 0 for slot in slots):
        raise ScriptError("color slots must be non-negative and unique")
    return list(slots)


def _parse_slots(value: str) -> list[int] | None:
    """Parse the `--slots` argument. An empty value keeps the positional fallback."""
    if not value.strip():
        return None
    try:
        return [int(part) for part in value.split(",")]
    except ValueError as error:
        raise ScriptError(
            f"--slots must be comma-separated integers: {value}"
        ) from error


def export(
    baseline: Path,
    candidate: Path,
    *,
    output: Path,
    title: str = "",
    baseline_label: str = "",
    candidate_label: str = "",
    extra: Path | None = None,
    extra_label: str = "",
    slots: Sequence[int] | None = None,
    maximum_samples: int = 600,
) -> Path:
    requested: list[tuple[Path, str]] = [
        (baseline, baseline_label),
        (candidate, candidate_label),
    ]
    if extra is not None:
        requested.append((extra, extra_label))
    runs = [
        _read_run(path, label, maximum_samples, slot)
        for (path, label), slot in zip(
            requested, _read_slots(slots, len(requested)), strict=True
        )
    ]
    dataset = {
        "schemaVersion": 1,
        "title": title or "Arknights Client vs PlayCover",
        "generatedAt": _utc_timestamp(datetime.now(UTC)),
        "machine": runs[0]["machine"] or runs[1]["machine"],
        "runs": runs,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(dataset, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    success(f"Chart dataset written: {output}")
    return output


def compare(baseline: Path, candidate: Path) -> str:
    def load(path: Path) -> dict[str, Any]:
        return _load_json(path / "summary.json" if path.is_dir() else path)

    def mean(metrics: dict[str, Any], name: str) -> float | None:
        value = metrics.get(name)
        if isinstance(value, dict) and isinstance(value.get("mean"), (int, float)):
            return float(value["mean"])
        return None

    baseline_metrics = load(baseline).get("metrics")
    candidate_metrics = load(candidate).get("metrics")
    if not isinstance(baseline_metrics, dict) or not isinstance(
        candidate_metrics, dict
    ):
        raise BenchmarkError("a summary file has no metrics object")
    lines = [
        "| Metric | Baseline | Candidate | Delta |",
        "| --- | ---: | ---: | ---: |",
    ]
    for metric, label in METRIC_LABELS.items():
        left = mean(baseline_metrics, metric)
        right = mean(candidate_metrics, metric)
        if left is None or right is None:
            continue
        delta = right - left
        percent = f"{delta / left * 100:+.1f}%" if left else "n/a"
        lines.append(
            f"| {label} | {left:.2f} | {right:.2f} | {delta:+.2f} ({percent}) |"
        )
    return "\n".join(lines)


def main(arguments: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    sample_parser = commands.add_parser("sample", help="record one run")
    sample_parser.add_argument("case")
    sample_parser.add_argument("--seconds", type=float, required=True)
    sample_parser.add_argument(
        "--interval", type=float, default=DEFAULT_INTERVAL_SECONDS
    )
    sample_parser.add_argument(
        "--target", choices=sorted(TARGET_PATTERNS), default="arknights-client"
    )
    sample_parser.add_argument("--match", action="append", default=[], metavar="REGEX")
    sample_parser.add_argument("--note", default="")
    sample_parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    compare_parser = commands.add_parser("compare", help="compare two runs")
    compare_parser.add_argument("baseline", type=Path)
    compare_parser.add_argument("candidate", type=Path)
    export_parser = commands.add_parser("export", help="write a website chart dataset")
    export_parser.add_argument("baseline", type=Path)
    export_parser.add_argument("candidate", type=Path)
    export_parser.add_argument("--output", type=Path, required=True)
    export_parser.add_argument("--title", default="")
    export_parser.add_argument("--baseline-label", default="")
    export_parser.add_argument("--candidate-label", default="")
    export_parser.add_argument("--extra", type=Path, default=None)
    export_parser.add_argument("--extra-label", default="")
    export_parser.add_argument(
        "--slots",
        default="",
        help="comma-separated palette slots, one per run in argument order",
    )
    export_parser.add_argument("--max-samples", type=int, default=600)
    parsed = parser.parse_args(arguments)
    if parsed.command == "sample":
        print(
            sample(
                parsed.case,
                seconds=parsed.seconds,
                interval=parsed.interval,
                target=parsed.target,
                patterns=parsed.match,
                note=parsed.note,
                output_root=parsed.output_root,
            )
        )
    elif parsed.command == "export":
        print(
            export(
                parsed.baseline,
                parsed.candidate,
                output=parsed.output,
                title=parsed.title,
                baseline_label=parsed.baseline_label,
                candidate_label=parsed.candidate_label,
                extra=parsed.extra,
                extra_label=parsed.extra_label,
                slots=_parse_slots(parsed.slots),
                maximum_samples=parsed.max_samples,
            )
        )
    else:
        print(compare(parsed.baseline, parsed.candidate))
    return 0


if __name__ == "__main__":
    run_main(main)
