# SPDX-License-Identifier: MPL-2.0

"""Tests for the freeze recorder parsers in lab.py."""

import plistlib
from datetime import UTC, datetime

import lab

VM_STAT = """\
Mach Virtual Memory Statistics: (page size of 16384 bytes)
Pages free:                                    74209.
Pages active:                                 377762.
Pages occupied by compressor:                  41459.
Swapins:                                        123.
Swapouts:                                       456.
"""


def test_parse_vm_stat_reads_bytes_and_counters():
    assert lab.parse_vm_stat(VM_STAT) == {
        "freeBytes": 74209 * 16384,
        "compressedBytes": 41459 * 16384,
        "swapins": 123,
        "swapouts": 456,
    }


def test_parse_swap_usage_converts_units():
    text = "vm.swapusage: total = 2.00G  used = 512.50M  free = 1536.00M  (encrypted)"
    assert lab.parse_swap_usage(text) == {
        "totalBytes": 2 * 1024**3,
        "usedBytes": 537_395_200,
        "freeBytes": 1_610_612_736,
    }


def test_parse_memory_pressure_prefers_the_level():
    assert lab.parse_memory_pressure("The system has memory pressure level: warn") == {
        "level": "warn"
    }


def test_parse_memory_pressure_accepts_the_free_percentage():
    text = (
        "The system has 17179869184 (1048576 pages with a page size of 16384).\n"
        "System-wide memory free percentage: 81%\n"
    )
    assert lab.parse_memory_pressure(text) == {"freePercent": 81}


def test_parse_gpu_statistics_keeps_the_known_counters():
    payload = plistlib.dumps(
        [
            {
                "PerformanceStatistics": {
                    "Device Utilization %": 13,
                    "In use system memory": 914_685_952,
                    "Alloc system memory": 1_672_839_168,
                    "recoveryCount": 0,
                    "Tiler Utilization %": 13,
                }
            }
        ]
    )
    assert lab.parse_gpu_statistics(payload) == {
        "Device Utilization %": 13,
        "In use system memory": 914_685_952,
        "Alloc system memory": 1_672_839_168,
        "recoveryCount": 0,
    }


def test_parse_gpu_statistics_rejects_malformed_output():
    assert lab.parse_gpu_statistics(b"<plist><array>") is None


def test_parse_ps_samples_reads_pid_rss_name_and_command():
    text = (
        "  101  1024 wine64-preloader wine64-preloader C:\\stepministrator\\stepministrator.exe\n"
        "  102  2048 Endfield.exe G:\\Endfield.exe -launcher_lang=en-us\n"
    )
    samples = lab.parse_ps_samples(text)
    assert [(sample.pid, sample.resident, sample.name) for sample in samples] == [
        (101, 1024 * 1024, "wine64-preloader"),
        (102, 2048 * 1024, "Endfield.exe"),
    ]
    assert samples[1].command == "G:\\Endfield.exe -launcher_lang=en-us"


def test_game_usage_sums_wine_processes_and_finds_the_game():
    text = (
        "  101  1024 wine64-preloader wine64-preloader C:\\stepministrator\\stepministrator.exe\n"
        "  102  2048 wine64-preloader wine64-preloader G:\\Endfield.exe -launcher_lang=en-us\n"
        "  103  4096 wineserver wineserver\n"
        "  200   512 bash bash -c grep Endfield.exe\n"
    )
    assert lab.game_usage(text) == ([102], (1024 + 2048 + 4096) * 1024)


def test_runtime_from_processes_reads_the_binary_path(tmp_path):
    (tmp_path / "bin").mkdir()
    (tmp_path / "bin/wineserver").touch()
    text = f"  42  2048 wineserver {tmp_path}/bin/wineserver -w\n"
    assert lab.runtime_from_processes(text) == tmp_path


def test_runtime_from_processes_ignores_commands_without_a_runtime():
    text = "  42  2048 bash bash -c ls /nonexistent/bin/wine64\n"
    assert lab.runtime_from_processes(text) is None


def test_is_freeze_report_selects_windowserver_and_skips_unrelated():
    assert lab.is_freeze_report(
        "WindowServer_2026-11-26-231701_Mina.userspace_watchdog_timeout.spin"
    )
    assert lab.is_freeze_report("gpuEvent-WindowServer-2026-11-22-193357.ips")
    assert not lab.is_freeze_report("ContextStoreAgent-2026-11-22-084542.ips")


def test_last_record_time_skips_a_partial_tail():
    text = (
        '{"timestamp":"2026-11-26T23:16:57Z"}\n'
        '{"timestamp":"2026-11-26T23:16:58Z"}\n'
        '{"timestamp":"2026-11-26T23:1'
    )
    assert lab.last_record_time(text) == datetime(2026, 11, 26, 23, 16, 58, tzinfo=UTC)
