# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
from pathlib import Path

import benchmark
import pytest


def test_parse_ps_time() -> None:
    assert benchmark.parse_ps_time("0:14.59") == pytest.approx(14.59)
    assert benchmark.parse_ps_time("1:02:03.50") == pytest.approx(3723.5)
    assert benchmark.parse_ps_time("2-03:04:05") == pytest.approx(183_845)


def test_parse_ps_time_rejects_unknown_format() -> None:
    with pytest.raises(benchmark.BenchmarkError):
        benchmark.parse_ps_time("nope")


def test_parse_process_table_keeps_paths_with_spaces() -> None:
    text = "  10   1  2048   0:01.50 /Applications/My Game.app/Arknights\n"
    assert benchmark.parse_process_table(text) == [
        benchmark.ProcessRow(
            pid=10,
            parent_pid=1,
            resident_kib=2048,
            cpu_seconds=1.5,
            command="/Applications/My Game.app/Arknights",
        )
    ]


def test_select_processes_includes_descendants() -> None:
    rows = [
        benchmark.ProcessRow(1, 0, 100, 0.0, "/sbin/launchd"),
        benchmark.ProcessRow(10, 1, 200, 1.0, "/Applications/Arknights"),
        benchmark.ProcessRow(11, 10, 300, 2.0, "/Applications/PlatformProcess.exe"),
        benchmark.ProcessRow(12, 1, 400, 3.0, "/usr/bin/other"),
    ]
    selected = benchmark.select_processes(rows, (r"^Arknights$",))
    assert [row.pid for row in selected] == [10, 11]


def test_client_patterns_match_wine_windows_paths() -> None:
    rows = [
        benchmark.ProcessRow(1, 0, 100, 0.0, "/sbin/launchd"),
        benchmark.ProcessRow(20, 1, 500, 5.0, "G:\\Arknights.exe"),
        benchmark.ProcessRow(
            21, 20, 100, 1.0, "G:\\PlatformProcess.original.helper.exe"
        ),
    ]
    selected = benchmark.select_processes(
        rows, benchmark.TARGET_PATTERNS["arknights-client"]
    )
    assert [row.pid for row in selected] == [20, 21]


def test_cpu_seconds_delta_ignores_new_and_missing_processes() -> None:
    previous = {10: 1.0, 11: 2.0}
    current = {10: 1.5, 11: 2.0, 12: 5.0}
    assert benchmark.cpu_seconds_delta(previous, current) == pytest.approx(0.5)


def test_parse_gpu_utilization_takes_the_highest_accelerator() -> None:
    text = '"Device Utilization %"=10 "Device Utilization %"=40'
    assert benchmark.parse_gpu_utilization(text) == {"device": 40}


def test_parse_vm_stat_converts_pages_to_mebibytes() -> None:
    text = """Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                               1000.
Pages wired down:                         4000.
Pages occupied by compressor:             500.
"""
    values = benchmark.parse_vm_stat(text)
    assert values["free_mib"] == pytest.approx(15.625)
    assert values["wired_mib"] == pytest.approx(62.5)
    assert values["compressed_mib"] == pytest.approx(7.8125)


def test_parse_vm_stat_without_page_size_returns_nothing() -> None:
    assert benchmark.parse_vm_stat("Pages free: 1000.") == {}


def test_summarize_skips_missing_values() -> None:
    summary = benchmark.summarize(
        [{"cpu_percent": None}, {"cpu_percent": 10.0}, {"cpu_percent": 20.0}]
    )
    metrics = summary["metrics"]["cpu_percent"]
    assert metrics["count"] == 2
    assert metrics["mean"] == pytest.approx(15.0)
    assert metrics["p95"] == pytest.approx(19.5)


def test_case_name_rejects_unsafe_components() -> None:
    assert benchmark.case_name("adverse-60s") == "adverse-60s"
    with pytest.raises(benchmark.BenchmarkError):
        benchmark.case_name("../escape")


def test_sample_writes_manifest_samples_and_summary(tmp_path: Path) -> None:
    ps_outputs = iter(
        [
            "10 1 2048 0:00.00 /Applications/Arknights\n99 1 1024 0:00.00 /Applications/Zed\n",
            "10 1 4096 0:01.00 /Applications/Arknights\n99 1 1024 0:00.50 /Applications/Zed\n",
            "10 1 4096 0:02.00 /Applications/Arknights\n99 1 1024 0:01.00 /Applications/Zed\n",
        ]
    )

    def run(command: list[str]) -> str:
        if command[0] == "ps":
            return next(ps_outputs)
        if command[0] == "sysctl":
            return {
                "hw.model": "Mac16,1\n",
                "machdep.cpu.brand_string": "Apple M4\n",
                "hw.ncpu": "10\n",
                "hw.memsize": "17179869184\n",
            }[command[-1]]
        if command[0] == "sw_vers":
            return "27.0.1\n" if command[-1] == "-productVersion" else "26A434\n"
        if command[0] == "ioreg":
            return '"Device Utilization %"=25'
        if command[0] == "vm_stat":
            return "page size of 16384 bytes\nPages free: 1000.\n"
        if command[0] == "pmset":
            return "CPU_Speed_Limit = 100\nNow drawing from 'AC Power'\n"
        if command[0] == "system_profiler":
            return json.dumps(
                {
                    "SPDisplaysDataType": [
                        {
                            "spdisplays_ndrvs": [
                                {
                                    "spdisplays_main": "spdisplays_yes",
                                    "_spdisplays_pixels": "6016 x 3384",
                                    "_spdisplays_resolution": "3008 x 1692 @ 120.00Hz",
                                }
                            ]
                        }
                    ]
                }
            )
        if command[0] == "osascript":
            if "frontmost" in command[-1]:
                return "zed\n"
            return "0, 30, 1504, 1564\n"
        raise AssertionError(command)

    times = iter([0.0, 1.0, 2.0])
    run_directory = benchmark.sample(
        "adverse",
        seconds=2,
        interval=1,
        patterns=(r"^Arknights$",),
        output_root=tmp_path,
        run=run,
        optional_run=run,
        clock=lambda: next(times),
        wait=lambda _: None,
    )

    manifest = json.loads((run_directory / "manifest.json").read_text())
    summary = json.loads((run_directory / "summary.json").read_text())
    assert manifest["machine"]["chip"] == "Apple M4"
    assert summary["sampleCount"] == 2
    assert summary["metrics"]["cpu_percent"]["mean"] == pytest.approx(100.0)
    assert summary["metrics"]["system_cpu_percent"]["mean"] == pytest.approx(150.0)
    assert summary["metrics"]["background_cpu_percent"]["mean"] == pytest.approx(50.0)
    assert summary["metrics"]["background_process_count"]["mean"] == pytest.approx(1.0)
    assert summary["metrics"]["resident_mib"]["mean"] == pytest.approx(4.0)
    assert summary["metrics"]["gpu_device_percent"]["mean"] == pytest.approx(25.0)
    assert summary["metrics"]["free_mib"]["mean"] == pytest.approx(15.625)
    assert summary["metrics"]["cpu_speed_limit"]["mean"] == pytest.approx(100.0)
    assert manifest["display"] == {
        "pixels": "6016 x 3384",
        "points": "3008 x 1692",
        "refreshHz": 120.0,
    }
    assert manifest["window"] == {
        "process": "Arknights",
        "x": 0,
        "y": 30,
        "width": 1504,
        "height": 1564,
    }
    assert manifest["foregroundAtStart"] == "zed"
    assert manifest["foregroundAtEnd"] == "zed"
    assert manifest["backgroundTop"]["topCpu"][0]["process"] == "Zed"
    assert manifest["backgroundTop"]["topCpu"][0]["meanCpuPercent"] == pytest.approx(
        50.0
    )
    assert len((run_directory / "samples.csv").read_text().splitlines()) == 3


def test_parse_display_information() -> None:
    text = json.dumps(
        {
            "SPDisplaysDataType": [
                {
                    "spdisplays_ndrvs": [
                        {
                            "spdisplays_main": "spdisplays_yes",
                            "_spdisplays_pixels": "6016 x 3384",
                            "_spdisplays_resolution": "3008 x 1692 @ 120.00Hz",
                        }
                    ]
                }
            ]
        }
    )
    assert benchmark.parse_display_information(text) == {
        "pixels": "6016 x 3384",
        "points": "3008 x 1692",
        "refreshHz": 120.0,
    }


def test_parse_window_bounds() -> None:
    assert benchmark.parse_window_bounds("0, 30, 1504, 1564") == {
        "x": 0,
        "y": 30,
        "width": 1504,
        "height": 1564,
    }
    assert benchmark.parse_window_bounds("nope") is None


def write_run(directory: Path, target: str, cpu: float) -> None:
    directory.mkdir()
    (directory / "manifest.json").write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "case": "adverse",
                "note": "fixture",
                "target": target,
                "machine": {"chip": "Apple M4"},
            }
        ),
        encoding="utf-8",
    )
    (directory / "summary.json").write_text(
        json.dumps(
            {
                "sampleCount": 1,
                "metrics": {"cpu_percent": {"mean": cpu}},
            }
        ),
        encoding="utf-8",
    )
    (directory / "samples.csv").write_text(
        "timestamp,elapsed_seconds,cpu_percent,system_cpu_percent,"
        "background_cpu_percent,background_process_count,resident_mib,"
        "process_count,gpu_device_percent,gpu_renderer_percent,gpu_tiler_percent,"
        "free_mib,wired_mib,compressed_mib,cpu_speed_limit,power_source\n"
        f"2026-01-01T00:00:00Z,1.0,{cpu},20.0,5.0,3,100.0,1,20,20,20,"
        "1000.0,2000.0,3000.0,100,AC Power\n",
        encoding="utf-8",
    )


def test_export_writes_a_web_dataset(tmp_path: Path) -> None:
    baseline = tmp_path / "baseline"
    candidate = tmp_path / "candidate"
    write_run(baseline, "arknights-client", 12.0)
    write_run(candidate, "playcover", 8.0)
    output = tmp_path / "web" / "benchmarks" / "adverse.json"

    benchmark.export(baseline, candidate, output=output)

    dataset = json.loads(output.read_text())
    assert dataset["schemaVersion"] == 1
    assert [run["label"] for run in dataset["runs"]] == [
        "Arknights Client",
        "PlayCover",
    ]
    assert dataset["runs"][0]["samples"][0]["cpu_percent"] == 12.0
    assert dataset["runs"][0]["samples"][0]["power_source"] == "AC Power"


def test_export_adds_an_extra_run(tmp_path: Path) -> None:
    baseline = tmp_path / "baseline"
    candidate = tmp_path / "candidate"
    extra = tmp_path / "extra"
    write_run(baseline, "arknights-client", 12.0)
    write_run(candidate, "playcover", 8.0)
    write_run(extra, "arknights-client", 9.0)
    output = tmp_path / "dataset.json"

    benchmark.export(
        baseline,
        candidate,
        output=output,
        extra=extra,
        extra_label="Arknights Client (MetalFX)",
    )

    dataset = json.loads(output.read_text())
    assert [run["label"] for run in dataset["runs"]] == [
        "Arknights Client",
        "PlayCover",
        "Arknights Client (MetalFX)",
    ]
    assert dataset["runs"][2]["samples"][0]["cpu_percent"] == 9.0


def test_export_writes_the_requested_palette_slots(tmp_path: Path) -> None:
    baseline = tmp_path / "baseline"
    candidate = tmp_path / "candidate"
    write_run(baseline, "arknights-client", 12.0)
    write_run(candidate, "playcover", 8.0)
    output = tmp_path / "dataset.json"

    benchmark.export(baseline, candidate, output=output, slots=[0, 2])

    dataset = json.loads(output.read_text())
    assert [run["slot"] for run in dataset["runs"]] == [0, 2]


def test_export_rejects_slot_count_and_duplicates(tmp_path: Path) -> None:
    baseline = tmp_path / "baseline"
    candidate = tmp_path / "candidate"
    write_run(baseline, "arknights-client", 12.0)
    write_run(candidate, "playcover", 8.0)
    output = tmp_path / "dataset.json"

    for slots in ([0], [1, 1], [-1, 0]):
        with pytest.raises(benchmark.ScriptError):
            benchmark.export(baseline, candidate, output=output, slots=slots)


def test_downsample_keeps_the_last_sample() -> None:
    samples = [{"elapsed_seconds": float(index)} for index in range(10)]
    selected = benchmark._downsample(samples, 3)
    assert selected[0] is samples[0]
    assert selected[-1] is samples[-1]
    assert len(selected) <= 4


def test_compare_renders_a_markdown_table(tmp_path: Path) -> None:
    baseline = tmp_path / "baseline"
    candidate = tmp_path / "candidate"
    for directory, cpu in ((baseline, 10.0), (candidate, 8.0)):
        directory.mkdir()
        (directory / "summary.json").write_text(
            json.dumps({"metrics": {"cpu_percent": {"mean": cpu}}}),
            encoding="utf-8",
        )

    table = benchmark.compare(baseline, candidate)
    assert "| CPU, mean (% of one core) | 10.00 | 8.00 | -2.00 (-20.0%) |" in table
