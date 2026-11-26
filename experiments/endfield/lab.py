# SPDX-License-Identifier: MPL-2.0

"""Run Arknights: Endfield on the app's ARM Wine runtime inside a separate lab root.

The lab owns its Wine prefix, game folder, logs, and helpers. It reads the runtime and
never writes to the app's data directory. See experiments/endfield/README.md.
"""

import argparse
import contextlib
import filecmp
import hashlib
import json
import os
import plistlib
import re
import shlex
import shutil
import signal
import subprocess
import sys
import threading
import time
import urllib.parse
import urllib.request
import xml.parsers.expat
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path, PureWindowsPath

REPOSITORY_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY_DIR / "scripts"))

import installer  # noqa: E402
from lib.common import PROJECT_DIR, ScriptError, fail, run_main  # noqa: E402
from lib.console import info, success, warning  # noqa: E402
from lib.project_config import RUNTIME_CONFIG  # noqa: E402
from runtime_config import load_runtime_config  # noqa: E402

LAB_ROOT_ENVIRONMENT = "ENDFIELD_LAB_ROOT"
DEFAULT_LAB_ROOT = Path.home() / "Library/Application Support/EndfieldLab"
# Matches AppPaths.bundleIdentifier. project_config would run `swift package dump-package`.
APP_DATA_DIRECTORY = (
    Path.home() / "Library/Application Support/com.lumisxh.arknights-client"
)
RUNTIME_LANE = "arm"
GAME_PROCESS_NAME = "Endfield"
GAME_EXECUTABLE = r"G:\Endfield.exe"
DEFAULT_LAUNCHER_EXECUTABLE = r"C:\Program Files\GRYPHLINK\Launcher.exe"
# Versioned folder: update when the launcher self-updates (or pass --games-exe).
DEFAULT_GAMES_EXECUTABLE = r"C:\Program Files\GRYPHLINK\1.6.0\Games.exe"
FIXED_GAME_ARGUMENTS = ("-launcher_lang=en-us", "-launcher_sub_channel=6")
WINE_DEBUG_PRESETS = {
    "default": "-all,err+all",
    "ace": "err+all,+seh,+module,+loaddll,+ntoskrnl,+process",
    "vulkan": "err+all,+vulkan,+loaddll",
}
PARENTS = ("direct", "launcher", "stepministrator")
# macOS short process names (ps ucomm) of the game. A KosmicKrisp GPU hang at ~22.8 GB
# resident on a 16 GB Mac froze WindowServer; the guard ends the game before that.
GUARDED_PROCESS_NAMES = frozenset({GAME_PROCESS_NAME, f"{GAME_PROCESS_NAME}.exe"})
DEFAULT_MEMORY_LIMIT_GB = 12.0
# The record must survive a hard reboot after a freeze, so each line is fsynced.
RECORD_INTERVAL_SECONDS = 1.0
LOG_SYNC_SECONDS = 1.0
# `command` is needed because Wine names every Unix process after its own binary, so
# the Windows exe name is only visible in the command line, if at all.
PS_ARGV = ["/bin/ps", "-axo", "pid=,rss=,ucomm=,command="]
WINE_PROCESS_NAME_PREFIX = "wine"
PROCESS_TABLE_SIZE = 5
COMMAND_PREVIEW_CHARS = 120
SAMPLE_TIMEOUT_SECONDS = 5
VM_STAT_ARGV = ["/usr/bin/vm_stat"]
SWAP_ARGV = ["/usr/sbin/sysctl", "vm.swapusage"]
PRESSURE_ARGV = ["/usr/bin/memory_pressure", "-Q"]
GPU_ARGV = ["/usr/sbin/ioreg", "-a", "-r", "-c", "IOAccelerator"]
GPU_STATISTIC_KEYS = (
    "Device Utilization %",
    "In use system memory",
    "Alloc system memory",
    "recoveryCount",
)
VM_STAT_PAGES = {
    "Pages free": "freeBytes",
    "Pages occupied by compressor": "compressedBytes",
}
VM_STAT_COUNTERS = {"Swapins": "swapins", "Swapouts": "swapouts"}
SWAP_AMOUNT = re.compile(r"(\w+)\s*=\s*([\d.]+)([KMGT])")
MEMORY_PRESSURE_LEVEL = re.compile(r"memory pressure level:\s*(\w+)")
MEMORY_FREE_PERCENT = re.compile(r"memory free percentage:\s*(\d+)%")
# Host crash reports that can name a freeze. `collect` copies the matching files.
DIAGNOSTIC_REPORTS = (
    ("user", Path.home() / "Library/Logs/DiagnosticReports"),
    ("system", Path("/Library/Logs/DiagnosticReports")),
)
REPORT_NAME_MARKERS = (
    "windowserver",
    "gpuevent",
    "agx",
    "endfield",
    "metal",
    "watchdog",
    "panic",
)
REPORT_SUFFIXES = (".ips", ".spin", ".panic", ".diag", ".crash")
REPORT_TIME_MARGIN_SECONDS = 60
COLLECT_END_MARGIN = timedelta(minutes=2)
LOG_SHOW_TIMEOUT_SECONDS = 600
# WindowServer's own records, kernel GPU errors, and kernel memorystatus. A bare
# "jetsam" match also catches runningboardd assertion dumps, which add noise only.
LOG_SHOW_PREDICATE = (
    '(senderImagePath CONTAINS "WindowServer") '
    'OR (process == "kernel" AND ('
    'eventMessage CONTAINS[c] "IOGPU" '
    'OR eventMessage CONTAINS[c] "AGX" '
    'OR eventMessage CONTAINS[c] "GPU restart" '
    'OR eventMessage CONTAINS[c] "GPU hang" '
    'OR eventMessage CONTAINS[c] "memorystatus" '
    'OR eventMessage CONTAINS[c] "jetsam"'
    ")) "
    'OR eventMessage CONTAINS[c] "gpuEvent"'
)
DXMT_DLL_DIRECTORY = Path("DXMT/x64")
RETINA_KEY = r"HKCU\Software\Wine\Mac Driver"
KOSMICKRISP_ICD = Path("share/vulkan/icd.d/kosmickrisp_mesa_icd.aarch64.json")
# Lab-only MoltenVK (KhronosGroup release, unpacked by hand): KosmicKrisp hangs the M4 GPU
# when the game loads its world.
MOLTENVK_ICD_GLOB = "toolchains/moltenvk-*/icd.d/MoltenVK_icd.json"
# Lives inside the prefix: Wine routes a Unix exe path through start.exe, which hangs in
# imm32 initialization on the ARM runtime. A C:\ path starts the helper directly.
STEPMINISTRATOR = r"C:\stepministrator\stepministrator.exe"
STEPMINISTRATOR_SOURCE = (
    Path(__file__).resolve().parent / "stepministrator/stepministrator.c"
)
# ARM64 build: the x86_64 MinGW build hung under FEX before the Wine loader started.
MINGW_COMPILER = "aarch64-w64-mingw32-clang"
MINGW_TOOLCHAIN_GLOB = "toolchains/llvm-mingw-*/bin"
# GUI subsystem: the console build hung in imm32 initialization on the ARM runtime.
MINGW_FLAGS = (
    "-municode",
    "-mwindows",
    "-O2",
    "-s",
    "-static",
    "-Wall",
    "-Wextra",
    "-Werror",
)

PREFIX_WINE_OVERRIDES = "winemac.drv=d"
DXMT_OVERRIDES = "d3d10core,d3d11,dxgi=n,b;winemetal=b;dcomp,mscoree,mshtml="
# backend -> (WINEDLLOVERRIDES, game argument that selects the renderer)
BACKENDS: dict[str, tuple[str, str]] = {
    "dxmt-d3d11": (DXMT_OVERRIDES, "-force-d3d11"),
    # Wine's builtin d3d12 (vkd3d) runs on Vulkan, so it also goes through KosmicKrisp.
    "vkd3d-kk": ("dcomp,mscoree,mshtml=", "-force-d3d12"),
    "vulkan-kk": ("dcomp,mscoree,mshtml=", "-force-vulkan"),
    "vulkan-mvk": ("dcomp,mscoree,mshtml=", "-force-vulkan"),
}
VULKAN_BACKENDS = {"vkd3d-kk", "vulkan-kk", "vulkan-mvk"}

DEFAULT_PREFIX_NAME = "prefix"
MF_PREFIX_NAME = "prefix-mf"
# Diagnostic only. Microsoft's binaries are not licensed for this repository.
# Never commit or ship them.
MF_INSTALL_COMMIT = "f8d24e9b600bad038911e8618721c8bfb83872e9"
MF_HOST = "raw.githubusercontent.com"
MF_RAW_URL = f"https://{MF_HOST}/Ultimator14/mf-install/{MF_INSTALL_COMMIT}"
MF_CACHE_DIRECTORY = f"mf-install-{MF_INSTALL_COMMIT[:8]}"
MF_HTTP_TIMEOUT_SECONDS = 60
MF_WINDOWS_DIRECTORY = r"C:\mf-install"
MF_OVERRIDE_KEY = r"HKEY_CURRENT_USER\Software\Wine\DllOverrides"
# Repository path -> SHA-256. Only the x64 system32 DLLs are copied, as Yaagl does.
MF_FILES: dict[str, str] = {
    "system32/colorcnv.dll": "0bab1293a19c960315b89789f7cf4dd39d6cb743d0f4929d03e8f149b6845718",
    "system32/mf.dll": "dbf0458bed308078edd82c81e6d1209e111c5bfa5d64dd068cedfd9e0a6c05ab",
    "system32/mferror.dll": "d9ce54938155a37f260b01d808917bc541383b750cd3a3094ce9308e318a0e2c",
    "system32/mfplat.dll": "025294dd69a421fe4eacaa463f8cb797610d8f3a7a3c61656ae83d0cee07a9bf",
    "system32/mfplay.dll": "a5c579a7ad6d55cbb13c748201b97c286e0e165827b8ed19019c696459f1f13a",
    "system32/mfreadwrite.dll": "665d8a6cdf29f9df2d9014a0eb7dcf1f840b7809a625f0752fdc3830ee952413",
    "system32/msmpeg2adec.dll": "97a9b89b1b50cddf6adff9059dce5935d905796dbcd6db58ea2fa693caaa194a",
    "system32/msmpeg2vdec.dll": "d7d0bc980c658d5e2f2c605075338493eac97b9d7674007a9490846c2dcdf6f3",
    "system32/sqmapi.dll": "17411c6a6c1e699bc4b0c04d782fd9aa09cf577dba41e743f7588904d489cb9f",
    "mf.reg": "078fb5b82e9afcb98a2a61ea5424bf1e297d8da974176a371c41ee0c6d251873",
    "wmf.reg": "296cf8e139c0145fdb86eb6c901b6f45d33d34179c6d05fc4ebc555fb8d85760",
}
MF_DLL_PATHS = tuple(path for path in MF_FILES if path.endswith(".dll"))
MF_REGISTRY_PATHS = tuple(path for path in MF_FILES if path.endswith(".reg"))
MF_REGISTER_DLLS = ("colorcnv.dll", "msmpeg2adec.dll", "msmpeg2vdec.dll")


@dataclass(frozen=True, slots=True)
class LaunchPlan:
    argv: list[str]
    cwd: Path
    env: dict[str, str]
    required: list[Path]
    notes: list[str]


@dataclass(frozen=True, slots=True)
class ProcessSample:
    """One line of `ps -axo pid=,rss=,ucomm=,command=`."""

    pid: int
    resident: int
    name: str
    command: str


@dataclass(frozen=True, slots=True)
class GuardDecision:
    """The memory guard's view of one `ps` sample."""

    limit: int
    resident: int | None
    pids: list[int]

    @property
    def over_limit(self) -> bool:
        return (
            self.limit > 0 and self.resident is not None and self.resident > self.limit
        )

    def as_record(self) -> dict[str, object]:
        return {
            "limitBytes": self.limit,
            "sampled": self.resident is not None,
            "residentBytes": self.resident,
            "pids": self.pids,
            "overLimit": self.over_limit,
        }


def utc_stamp() -> str:
    return datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")


def iso_timestamp() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def lab_root() -> Path:
    override = os.environ.get(LAB_ROOT_ENVIRONMENT)
    return Path(override).expanduser().absolute() if override else DEFAULT_LAB_ROOT


def resolve_runtime(override: Path | None) -> Path:
    if override is None:
        version = (
            load_runtime_config(PROJECT_DIR / RUNTIME_CONFIG)
            .lane(RUNTIME_LANE)
            .runtime.version
        )
        runtime = APP_DATA_DIRECTORY / "Runtimes" / f"{RUNTIME_LANE}-{version}"
    else:
        runtime = override.expanduser().absolute()
    wine = runtime / "bin/wine64"
    if not (wine.is_file() and os.access(wine, os.X_OK)):
        fail(f"runtime has no executable bin/wine64: {runtime}")
    return runtime


def runtime_version(runtime: Path) -> str | None:
    manifest = runtime / "RUNTIME.json"
    if not manifest.is_file():
        return None
    version = json.loads(manifest.read_text(encoding="utf-8")).get("version")
    return version if isinstance(version, str) else None


def base_environment(lab: Path, prefix: Path, runtime: Path) -> dict[str, str]:
    # Mirrors WineRuntime.isolatedEnvironment. HOME points into the prefix so Wine never
    # writes to the real home directory.
    home = prefix / "home"
    return {
        "WINEPREFIX": str(prefix),
        "HOME": str(home),
        "WINEHOMEDIR": str(home),
        "WINEPRELOADERAPPNAME": GAME_PROCESS_NAME,
        "WINEMSYNC": "1",
        "DXMT_SHADER_CACHE": "1",
        "DXMT_LOG_LEVEL": "error",
        "DXMT_LOG_PATH": str(lab / "logs"),
        "PATH": f"{runtime / 'bin'}:/usr/bin:/bin",
        "DYLD_FALLBACK_LIBRARY_PATH": str(runtime / "lib"),
        # Runtime patch 0009: borderless fullscreen windows enter a native macOS Space.
        # Override with `--env LMISXH_AKMOCL_FULLSCREEN=0` for windowed tests.
        "LMISXH_AKMOCL_FULLSCREEN": "1",
        # Command-Q quits (default on in the runtime; explicit for the sidecar record).
        "LMISXH_AKMOCL_MENU": "1",
    }


def host_path(windows_path: str, prefix: Path, lab: Path) -> Path:
    """Map a path on the prefix's C: drive or the lab's G: (game folder) drive."""
    windows = PureWindowsPath(windows_path)
    roots = {"C:": prefix / "drive_c", "G:": lab / "game"}
    root = roots.get(windows.drive.upper())
    if root is None:
        fail(f"Windows path must be on drive C: or G:: {windows_path}")
    return root.joinpath(*windows.parts[1:])


def dxmt_dlls(runtime: Path) -> list[Path]:
    dlls = sorted((runtime / DXMT_DLL_DIRECTORY).glob("*.dll"))
    if not dlls:
        fail(
            f"runtime has no DXMT DLLs in {DXMT_DLL_DIRECTORY}: {runtime} "
            "(the dxmt-d3d11 backend needs a runtime that bundles DXMT)"
        )
    return dlls


def set_retina(prefix: Path, runtime: Path, env: dict[str, str], enabled: bool) -> None:
    """Write the Mac driver RetinaMode that the next launch reads."""
    argv = [
        str(runtime / "bin/wine64"),
        "reg",
        "add",
        RETINA_KEY,
        "/v",
        "RetinaMode",
        "/d",
        "y" if enabled else "n",
        "/f",
    ]
    completed = subprocess.run(
        argv,
        env=env | {"WINEDEBUG": "-all"},
        cwd=prefix,
        check=False,
        capture_output=True,
        text=True,
        errors="replace",
        timeout=60,
    )
    if completed.returncode:
        detail = completed.stderr.strip() or completed.stdout.strip()
        fail(f"could not set RetinaMode: {detail}")


def sync_dxmt(prefix: Path, runtime: Path) -> int:
    """Copy the runtime's DXMT DLLs over the prefix copies; return how many changed.

    A prefix keeps the DXMT DLLs of the runtime that created it. Running another
    runtime without this refresh loads stale DLLs against a different `winemetal`,
    which fails deep inside the game as a UnityPlayer load error.
    """
    system32 = prefix / "drive_c/windows/system32"
    changed = 0
    for dll in dxmt_dlls(runtime):
        target = system32 / dll.name
        if target.is_file() and filecmp.cmp(dll, target, shallow=False):
            continue
        system32.mkdir(parents=True, exist_ok=True)
        shutil.copy2(dll, target)
        changed += 1
    return changed


def print_environment(env: dict[str, str]) -> None:
    print("env:")
    for key in sorted(env):
        print(f"  {key}={env[key]}")


def run_logged(argv: list[str], env: dict[str, str], cwd: Path, log: Path) -> int:
    """Run a process, copying its combined output to stdout and to the log file."""
    log.parent.mkdir(parents=True, exist_ok=True)
    with (
        # Line-buffered, so the log can be read while the game runs.
        log.open("w", encoding="utf-8", buffering=1) as file,
        subprocess.Popen(
            argv,
            env=env,
            cwd=cwd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            encoding="utf-8",
            errors="replace",
        ) as process,
    ):
        assert process.stdout is not None
        synced = time.monotonic()
        for line in process.stdout:
            sys.stdout.write(line)
            file.write(line)
            now = time.monotonic()
            if now - synced >= LOG_SYNC_SECONDS:
                # A freeze forces a hard reboot; keep the log tail on disk.
                os.fsync(file.fileno())
                synced = now
        return process.wait()


def run_prefix(args: argparse.Namespace) -> None:
    lab = lab_root()
    runtime = resolve_runtime(args.runtime)
    prefix = lab / args.prefix
    system32 = prefix / "drive_c/windows/system32"
    dosdevices_link = prefix / "dosdevices/g:"
    env = base_environment(lab, prefix, runtime) | {
        "WINEDLLOVERRIDES": PREFIX_WINE_OVERRIDES,
        "WINEDEBUG": WINE_DEBUG_PRESETS["default"],
    }
    argv = [str(runtime / "bin/wine64"), "wineboot.exe", "-u"]
    dlls = dxmt_dlls(runtime)
    if args.dry_run:
        print_environment(env)
        print(f"argv: {shlex.join(argv)}")
        for dll in dlls:
            print(f"copy: {dll} -> {system32 / dll.name}")
        print(f"symlink: {dosdevices_link} -> {lab / 'game'}")
        return
    if prefix.exists():
        if not args.force:
            fail(f"prefix already exists: {prefix} (pass --force to recreate it)")
        shutil.rmtree(prefix)
    (lab / "game").mkdir(parents=True, exist_ok=True)
    log = lab / "logs" / f"{utc_stamp()}-prefix.log"
    code = run_logged(argv, env, lab, log)
    if code:
        fail(f"wineboot exited with {code}; see {log}")
    system32.mkdir(parents=True, exist_ok=True)
    for dll in dlls:
        shutil.copy2(dll, system32 / dll.name)
    dosdevices_link.parent.mkdir(parents=True, exist_ok=True)
    dosdevices_link.symlink_to(lab / "game")
    success(f"prefix ready: {prefix}")


def launch_plan(
    args: argparse.Namespace, lab: Path, prefix: Path, runtime: Path
) -> LaunchPlan:
    wine = str(runtime / "bin/wine64")
    game_directory = lab / "game"
    game_executable = host_path(GAME_EXECUTABLE, prefix, lab)
    override, renderer_argument = BACKENDS[args.backend]
    env = base_environment(lab, prefix, runtime) | {
        "WINEDEBUG": args.wine_debug or WINE_DEBUG_PRESETS[args.debug],
        "WINEDLLOVERRIDES": override,
    }
    if args.backend == "vulkan-mvk":
        icds = sorted(lab.glob(MOLTENVK_ICD_GLOB))
        if not icds:
            fail(f"no MoltenVK ICD matches {lab / MOLTENVK_ICD_GLOB}")
        env["VK_DRIVER_FILES"] = str(icds[-1])
    elif args.backend in VULKAN_BACKENDS:
        icd = runtime / KOSMICKRISP_ICD
        if not icd.is_file():
            fail(f"runtime has no KosmicKrisp ICD: {icd}")
        env["VK_DRIVER_FILES"] = str(icd)
    # Only the direct parent picks the renderer. The official launcher passes none.
    game_arguments = [*FIXED_GAME_ARGUMENTS, *args.game_args]
    required = [prefix]
    notes: list[str] = []
    if args.parent == "direct":
        argv = [wine, GAME_EXECUTABLE, renderer_argument, *game_arguments]
        cwd = game_directory
        required.append(game_executable)
    elif args.parent == "launcher":
        launcher = host_path(args.launcher_exe, prefix, lab)
        argv = [wine, args.launcher_exe]
        cwd = launcher.parent
        required.append(launcher)
        notes.append(
            "launcher parent: the launcher starts the game, so game arguments "
            "and the renderer flag are not passed"
        )
    else:
        helper = host_path(STEPMINISTRATOR, prefix, lab)
        argv = [wine, STEPMINISTRATOR, args.games_exe, GAME_EXECUTABLE, *game_arguments]
        # The helper sets the game's working directory itself.
        cwd = helper.parent
        required += [host_path(args.games_exe, prefix, lab), game_executable, helper]
    env |= dict(args.env)
    return LaunchPlan(argv=argv, cwd=cwd, env=env, required=required, notes=notes)


def missing_message(path: Path, helper: Path) -> str:
    hint = " (build it with build-helpers)" if path == helper else ""
    return f"missing: {path}{hint}"


def run_launch(args: argparse.Namespace) -> None:
    lab = lab_root()
    runtime = resolve_runtime(args.runtime)
    prefix = lab / args.prefix
    plan = launch_plan(args, lab, prefix, runtime)
    started_at = utc_stamp()
    run = f"{started_at}-{args.backend}-{args.parent}"
    log = lab / "logs" / f"{run}.log"
    record_path = lab / "logs" / f"{run}-record.jsonl"
    sidecar = log.with_suffix(".json")
    for note in plan.notes:
        warning(note)
    helper = host_path(STEPMINISTRATOR, prefix, lab)
    problems = [
        missing_message(path, helper) for path in plan.required if not path.exists()
    ]
    if args.dry_run:
        print_environment(plan.env)
        print(f"argv: {shlex.join(plan.argv)}")
        print(f"cwd: {plan.cwd}")
        print(f"log: {log}")
        print(f"sidecar: {sidecar}")
        print(f"record: {record_path}")
        if args.backend == "dxmt-d3d11":
            for dll in dxmt_dlls(runtime):
                print(
                    f"dxmt: {dll} -> {prefix / 'drive_c/windows/system32' / dll.name}"
                )
        if args.retina is not None:
            print(f"retina: {'y' if args.retina else 'n'}")
        for problem in problems:
            warning(f"{problem} (a real launch stops here)")
        return
    if problems:
        fail("; ".join(problems))
    if args.backend == "dxmt-d3d11":
        changed = sync_dxmt(prefix, runtime)
        if changed:
            info(f"refreshed {changed} DXMT DLL(s) from {runtime}")
    if args.retina is not None:
        set_retina(prefix, runtime, plan.env, args.retina)
        info(f"retina mode {'on' if args.retina else 'off'}")
    record = {
        "backend": args.backend,
        "prefix": args.prefix,
        "parent": args.parent,
        "startedAt": started_at,
        "runtime": {"path": str(runtime), "version": runtime_version(runtime)},
        "cwd": str(plan.cwd),
        "argv": plan.argv,
        "env": plan.env,
        "record": str(record_path),
        "retina": args.retina,
    }
    log.parent.mkdir(parents=True, exist_ok=True)
    sidecar.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    limit = int(args.memory_limit_gb * 1024**3) if args.memory_limit_gb > 0 else 0
    recorder = RunRecorder(record_path, limit, plan.env, runtime)
    recorder.start()
    try:
        code = run_logged(plan.argv, plan.env, plan.cwd, log)
    finally:
        recorder.close()
    # With the launcher parent, wine returns when the launcher stub exits, while the game
    # may still run. The other parents return only after the game has exited.
    if args.parent != "launcher":
        end_leftovers(plan.env, runtime)
    if code:
        raise SystemExit(code)


def parse_ps_samples(ps_output: str) -> list[ProcessSample]:
    """Return one sample per `ps -axo pid=,rss=,ucomm=,command=` line."""
    samples: list[ProcessSample] = []
    for line in ps_output.splitlines():
        fields = line.split(None, 3)
        if len(fields) == 4:
            samples.append(
                ProcessSample(
                    pid=int(fields[0]),
                    resident=int(fields[1]) * 1024,
                    name=fields[2].strip(),
                    command=fields[3].strip(),
                )
            )
    return samples


def is_wine_process(sample: ProcessSample) -> bool:
    """Return True when Wine owns the Unix process.

    Wine names every Unix process after its own binary, so `Endfield.exe` never
    reaches `ps`. Summing every Wine process covers the game, `Games.exe`,
    `PlatformProcess.exe`, and `wineserver`.
    """
    return sample.name.lower().startswith(WINE_PROCESS_NAME_PREFIX)


def is_game_process(sample: ProcessSample) -> bool:
    """Return True for the game, by name or by the Windows path in its command line."""
    if sample.name in GUARDED_PROCESS_NAMES:
        return True
    if not is_wine_process(sample):
        return False
    command = sample.command.lower()
    return any(exe.lower() in command for exe in GUARDED_PROCESS_NAMES)


def game_usage(ps_output: str) -> tuple[list[int], int]:
    """Return the game PIDs and the resident bytes of the lab's Wine processes."""
    pids: list[int] = []
    resident = 0
    for sample in parse_ps_samples(ps_output):
        if is_wine_process(sample) or sample.name in GUARDED_PROCESS_NAMES:
            resident += sample.resident
        if is_game_process(sample):
            pids.append(sample.pid)
    return pids, resident


def sample_processes() -> str:
    return subprocess.run(
        PS_ARGV,
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def kill_processes(pids: list[int]) -> None:
    # SIGKILL first: it frees the game's memory at once, even when Wine is stuck.
    for pid in pids:
        with contextlib.suppress(ProcessLookupError):
            os.kill(pid, signal.SIGKILL)


def end_game(pids: list[int], env: dict[str, str], runtime: Path) -> None:
    kill_processes(pids)
    quiet = env | {"WINEDEBUG": "-all"}
    subprocess.run(
        [str(runtime / "bin/wineserver"), "-k"], env=quiet, check=False, timeout=30
    )
    wait_for_wineserver(quiet, runtime)


def sample_stdout(argv: list[str]) -> str | None:
    """Run a cheap host sampler; return None when it fails, so the record shows a gap."""
    try:
        completed = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=SAMPLE_TIMEOUT_SECONDS,
        )
    except OSError, subprocess.TimeoutExpired:
        return None
    return completed.stdout if completed.returncode == 0 else None


def parse_vm_stat(text: str) -> dict[str, int]:
    """Return free and compressed bytes plus swap counters from `vm_stat` output."""
    page_size = 4096
    match = re.search(r"page size of (\d+) bytes", text)
    if match:
        page_size = int(match.group(1))
    values: dict[str, int] = {}
    for line in text.splitlines():
        label, separator, value = line.partition(":")
        if not separator:
            continue
        label = label.strip()
        digits = value.strip().rstrip(".")
        if not digits.isdigit():
            continue
        if label in VM_STAT_PAGES:
            values[VM_STAT_PAGES[label]] = int(digits) * page_size
        elif label in VM_STAT_COUNTERS:
            values[VM_STAT_COUNTERS[label]] = int(digits)
    return values


def parse_swap_usage(text: str) -> dict[str, int]:
    """Return total, used, and free swap bytes from `sysctl vm.swapusage` output."""
    units = {"K": 1024, "M": 1024**2, "G": 1024**3, "T": 1024**4}
    values: dict[str, int] = {}
    for name, amount, unit in SWAP_AMOUNT.findall(text):
        if name in {"total", "used", "free"}:
            values[f"{name}Bytes"] = int(float(amount) * units[unit])
    return values


def parse_memory_pressure(text: str) -> dict[str, int | str]:
    """Return the pressure level, or the free percentage, from `memory_pressure -Q`."""
    level = MEMORY_PRESSURE_LEVEL.search(text)
    if level:
        return {"level": level.group(1)}
    percent = MEMORY_FREE_PERCENT.search(text)
    if percent:
        return {"freePercent": int(percent.group(1))}
    return {}


def parse_gpu_statistics(payload: bytes) -> dict[str, int] | None:
    """Return the GPU counters from `ioreg -a -r -c IOAccelerator` output."""
    try:
        entries = plistlib.loads(payload)
    except ValueError, xml.parsers.expat.ExpatError:
        return None
    if not isinstance(entries, list):
        return None
    for entry in entries:
        statistics = (
            entry.get("PerformanceStatistics") if isinstance(entry, dict) else None
        )
        if isinstance(statistics, dict) and "Device Utilization %" in statistics:
            return {
                key: value
                for key, value in statistics.items()
                if key in GPU_STATISTIC_KEYS and isinstance(value, int)
            }
    return None


def sample_vm_stat() -> dict[str, int] | None:
    text = sample_stdout(VM_STAT_ARGV)
    return parse_vm_stat(text) if text else None


def sample_swap_usage() -> dict[str, int] | None:
    text = sample_stdout(SWAP_ARGV)
    return parse_swap_usage(text) if text else None


def sample_memory_pressure() -> dict[str, int | str] | None:
    text = sample_stdout(PRESSURE_ARGV)
    return parse_memory_pressure(text) if text else None


def sample_gpu_statistics() -> dict[str, int] | None:
    text = sample_stdout(GPU_ARGV)
    return parse_gpu_statistics(text.encode("utf-8")) if text else None


class RunRecorder:
    """Write one JSON line per second with host memory, GPU, and guard state.

    A freeze forces a hard reboot, so every line is flushed and fsynced before the next
    sample. The memory guard reads the same `ps` sample as the record.
    """

    def __init__(
        self, path: Path, limit: int, env: dict[str, str], runtime: Path
    ) -> None:
        self.limit = limit
        self.env = env
        self.runtime = runtime
        self.started = time.monotonic()
        self.stopped = threading.Event()
        self.guard_fired = False
        self.table_written = False
        self.lock = threading.Lock()
        path.parent.mkdir(parents=True, exist_ok=True)
        self.file = path.open("w", encoding="utf-8", buffering=1)

    def start(self) -> None:
        threading.Thread(target=self.run, daemon=True).start()

    def close(self) -> None:
        self.stopped.set()
        with self.lock:
            self.file.close()

    def run(self) -> None:
        while not self.stopped.wait(RECORD_INTERVAL_SECONDS):
            self.sample()

    def sample(self) -> None:
        processes, guard, table = self.processes(sample_stdout(PS_ARGV))
        entry: dict[str, object] = {
            "timestamp": iso_timestamp(),
            "elapsedSeconds": round(time.monotonic() - self.started, 1),
            "processes": processes,
            "vm": sample_vm_stat(),
            "swap": sample_swap_usage(),
            "pressure": sample_memory_pressure(),
            "gpu": sample_gpu_statistics(),
            "guard": guard.as_record(),
        }
        # One table per run shows how `ps` names the game without growing every line.
        if table is not None and not self.table_written:
            entry["processTable"] = table
            self.table_written = True
        self.write(entry)
        if guard.over_limit and not self.guard_fired:
            self.terminate(guard)

    def processes(
        self, ps_output: str | None
    ) -> tuple[dict[str, int] | None, GuardDecision, list[dict[str, object]] | None]:
        if ps_output is None:
            return None, GuardDecision(self.limit, None, []), None
        samples = parse_ps_samples(ps_output)
        processes: dict[str, int] = {}
        pids: list[int] = []
        resident = 0
        for sample in samples:
            if is_wine_process(sample) or sample.name in GUARDED_PROCESS_NAMES:
                processes[sample.name] = processes.get(sample.name, 0) + sample.resident
                resident += sample.resident
            if is_game_process(sample):
                pids.append(sample.pid)
        largest = sorted(samples, key=lambda sample: sample.resident, reverse=True)
        table = [
            {
                "pid": sample.pid,
                "residentBytes": sample.resident,
                "name": sample.name,
                "command": sample.command[:COMMAND_PREVIEW_CHARS],
            }
            for sample in largest[:PROCESS_TABLE_SIZE]
        ]
        return processes, GuardDecision(self.limit, resident, pids), table

    def write(self, entry: dict[str, object]) -> None:
        with self.lock:
            if self.file.closed:
                return
            self.file.write(json.dumps(entry, separators=(",", ":")) + "\n")
            self.file.flush()
            os.fsync(self.file.fileno())

    def terminate(self, guard: GuardDecision) -> None:
        self.guard_fired = True
        assert guard.resident is not None
        message = (
            f"the lab's Wine processes use {guard.resident / 1024**3:.1f} GB, over the "
            f"{self.limit / 1024**3:.1f} GB limit; ending the prefix"
        )
        warning(message)
        self.write(
            {
                "timestamp": iso_timestamp(),
                "event": "guard-kill",
                "message": message,
                "guard": guard.as_record(),
            }
        )
        end_game(guard.pids, self.env, self.runtime)


def runtime_from_processes(ps_output: str) -> Path | None:
    """Return the runtime of the running Wine processes, from their command line."""
    for sample in parse_ps_samples(ps_output):
        for marker in ("/bin/wineserver", "/bin/wine64"):
            position = sample.command.find(marker)
            if position <= 0:
                continue
            root = Path(sample.command[:position].strip())
            if (root / "bin/wineserver").is_file():
                return root
    return None


def kill_runtime(override: Path | None, ps_output: str) -> Path | None:
    """Prefer the runtime of the running processes over the pinned default.

    The pinned runtime may not be the one that is running, or may not be installed.
    """
    runtime = runtime_from_processes(ps_output)
    if runtime is not None:
        return runtime
    try:
        return resolve_runtime(override)
    except ScriptError:
        if override is not None:
            raise
        return None


def run_kill(args: argparse.Namespace) -> None:
    lab = lab_root()
    ps_output = sample_processes()
    pids, _ = game_usage(ps_output)
    runtime = kill_runtime(args.runtime, ps_output)
    if runtime is None:
        warning("no runtime found; ending only the matched game processes")
        kill_processes(pids)
        success(f"ended {len(pids)} game process(es)")
        return
    end_game(pids, base_environment(lab, lab / args.prefix, runtime), runtime)
    success(f"ended {len(pids)} game process(es) and the {args.prefix} prefix")


def end_leftovers(env: dict[str, str], runtime: Path) -> None:
    # The game's PlatformProcess.exe outlives the game and keeps the prefix alive.
    quiet = env | {"WINEDEBUG": "-all"}
    subprocess.run(
        [str(runtime / "bin/wine64"), "taskkill", "/f", "/im", "PlatformProcess.exe"],
        env=quiet,
        check=False,
        capture_output=True,
    )
    wait_for_wineserver(quiet, runtime)


def wait_for_wineserver(env: dict[str, str], runtime: Path) -> None:
    try:
        subprocess.run(
            [str(runtime / "bin/wineserver"), "-w"], env=env, check=False, timeout=30
        )
    except subprocess.TimeoutExpired:
        warning("the prefix is still running after 30 s; check for leftover processes")


def run_install(args: argparse.Namespace) -> None:
    try:
        installer.run(lab_root(), plan_only=args.plan, force=args.force)
    except installer.InstallError as error:
        fail(str(error))


def run_build_helpers(args: argparse.Namespace) -> None:
    lab = lab_root()
    toolchains = sorted(lab.glob(MINGW_TOOLCHAIN_GLOB))
    compiler = shutil.which(
        MINGW_COMPILER, path=os.pathsep.join(str(path) for path in toolchains)
    )
    if compiler is None:
        fail(f"{MINGW_COMPILER} not found; unpack llvm-mingw into {lab / 'toolchains'}")
    stepministrator = host_path(STEPMINISTRATOR, lab / args.prefix, lab)
    command = [
        compiler,
        *MINGW_FLAGS,
        "-o",
        str(stepministrator),
        str(STEPMINISTRATOR_SOURCE),
    ]
    if args.dry_run:
        print(shlex.join(command))
        return
    stepministrator.parent.mkdir(parents=True, exist_ok=True)
    # Replace by rename, so a running helper keeps its mapped image.
    staged = stepministrator.with_name(f".{stepministrator.name}.new")
    command[command.index(str(stepministrator))] = str(staged)
    code = subprocess.run(command, check=False).returncode
    if code:
        fail(f"{command[0]} exited with {code}")
    staged.replace(stepministrator)
    success(f"built {stepministrator}")


def require_mf_url(url: str) -> None:
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.hostname != MF_HOST or parts.port is not None:
        fail(f"mf-install downloads must use https://{MF_HOST}: {url}")


class _MfRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        require_mf_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


_MF_OPENER = urllib.request.build_opener(_MfRedirects)


def fetch_mf_bytes(url: str) -> bytes:
    require_mf_url(url)
    try:
        with _MF_OPENER.open(url, timeout=MF_HTTP_TIMEOUT_SECONDS) as response:
            return response.read()
    except OSError as error:
        fail(f"download failed: {url}: {error}")


def mf_cached_path(lab: Path, path: str) -> Path:
    return lab / "downloads" / MF_CACHE_DIRECTORY / Path(path).name


def cache_mf_file(lab: Path, path: str) -> None:
    """Keep one pinned file in the cache, downloading it when the cached copy differs."""
    digest = MF_FILES[path]
    cached = mf_cached_path(lab, path)
    if cached.is_file() and hashlib.sha256(cached.read_bytes()).hexdigest() == digest:
        return
    data = fetch_mf_bytes(f"{MF_RAW_URL}/{path}")
    actual = hashlib.sha256(data).hexdigest()
    if actual != digest:
        fail(f"SHA-256 mismatch for {path}: expected {digest}, got {actual}")
    cached.parent.mkdir(parents=True, exist_ok=True)
    partial = cached.with_name(f"{cached.name}.part")
    partial.write_bytes(data)
    partial.replace(cached)


def cache_mf_files(lab: Path) -> None:
    for path in MF_FILES:
        cache_mf_file(lab, path)


def clone_prefix(source: Path, target: Path) -> None:
    if target.exists():
        shutil.rmtree(target)
    code = subprocess.run(
        ["cp", "-c", "-R", str(source), str(target)], check=False
    ).returncode
    if code:
        fail(f"cp -c exited with {code}")


def point_game_drive(prefix: Path, lab: Path) -> None:
    link = prefix / "dosdevices/g:"
    game = lab / "game"
    if link.is_symlink() and link.readlink() == game:
        return
    link.unlink(missing_ok=True)
    link.symlink_to(game)


def mf_destination(path: str, prefix: Path, lab: Path) -> Path:
    if path in MF_DLL_PATHS:
        return prefix / "drive_c/windows/system32" / Path(path).name
    return host_path(MF_WINDOWS_DIRECTORY, prefix, lab) / Path(path).name


def copy_mf_files(lab: Path, prefix: Path) -> None:
    for path in MF_FILES:
        destination = mf_destination(path, prefix, lab)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(mf_cached_path(lab, path), destination)


def mf_steps(wine: str) -> list[tuple[str, list[str]]]:
    """Return (label, argv) pairs. Each label names that step's log file."""
    overrides = [
        (
            f"override-{Path(path).stem}",
            [wine, "reg", "add", MF_OVERRIDE_KEY, "/v", Path(path).stem]
            + ["/d", "native", "/f"],
        )
        for path in MF_DLL_PATHS
    ]
    imports = [
        (
            f"regedit-{Path(path).name}",
            [wine, "regedit", "/S", str(PureWindowsPath(MF_WINDOWS_DIRECTORY, path))],
        )
        for path in MF_REGISTRY_PATHS
    ]
    registrations = [
        (f"regsvr32-{name}", [wine, "regsvr32", "/s", name])
        for name in MF_REGISTER_DLLS
    ]
    return [*overrides, *imports, *registrations]


def run_mf_steps(
    steps: list[tuple[str, list[str]]],
    env: dict[str, str],
    lab: Path,
    runtime: Path,
    stamp: str,
) -> None:
    for label, argv in steps:
        log = lab / "logs" / f"{stamp}-mf-prefix-{label}.log"
        code = run_logged(argv, env, lab, log)
        if not code:
            continue
        message = f"mf-prefix step {label} exited with {code}; see {log}"
        # The ARM64 regsvr32 may not load these x64 DLLs. Finish the prefix anyway: the
        # log shows the failure, and the decoders then stay unregistered.
        if label.startswith("regsvr32-"):
            warning(
                f"{message}; the decoder is not registered, so the test is inconclusive"
            )
        else:
            fail(message)
    wait_for_wineserver(env, runtime)


def print_mf_plan(
    source: Path,
    target: Path,
    lab: Path,
    env: dict[str, str],
    steps: list[tuple[str, list[str]]],
) -> None:
    print_environment(env)
    for path in MF_FILES:
        print(f"download: {MF_RAW_URL}/{path} -> {mf_cached_path(lab, path)}")
    print(f"clone: cp -c -R {source} {target}")
    print(f"symlink: {target / 'dosdevices/g:'} -> {lab / 'game'}")
    for path in MF_FILES:
        destination = mf_destination(path, target, lab)
        print(f"copy: {mf_cached_path(lab, path)} -> {destination}")
    for label, argv in steps:
        print(f"argv [{label}]: {shlex.join(argv)}")


def run_mf_prefix(args: argparse.Namespace) -> None:
    lab = lab_root()
    runtime = resolve_runtime(args.runtime)
    source = lab / args.source
    target = lab / args.target
    if args.source == args.target:
        fail("--from and --to must name different prefixes")
    if not source.is_dir():
        fail(f"source prefix missing: {source}")
    if target.exists() and not args.force:
        fail(f"target prefix exists: {target} (pass --force to replace it)")
    env = base_environment(lab, target, runtime) | {
        "WINEDEBUG": WINE_DEBUG_PRESETS["default"]
    }
    steps = mf_steps(str(runtime / "bin/wine64"))
    if args.dry_run:
        print_mf_plan(source, target, lab, env, steps)
        return
    cache_mf_files(lab)
    clone_prefix(source, target)
    point_game_drive(target, lab)
    copy_mf_files(lab, target)
    run_mf_steps(steps, env, lab, runtime, utc_stamp())
    success(f"mf-prefix ready: {target}")


def env_pair(value: str) -> tuple[str, str]:
    key, separator, env_value = value.partition("=")
    if not separator or not key:
        raise argparse.ArgumentTypeError(f"expected KEY=VALUE, got {value!r}")
    return key, env_value


def add_runtime_argument(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--runtime",
        type=Path,
        metavar="PATH",
        help="runtime directory; default is the app's installed ARM runtime",
    )


def prefix_name(value: str) -> str:
    """Accept one directory name, so every prefix stays directly under the lab root."""
    if value in {"", ".", ".."} or "/" in value or "\\" in value:
        raise argparse.ArgumentTypeError(f"expected a directory name, got {value!r}")
    return value


def add_prefix_argument(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--prefix",
        type=prefix_name,
        default=DEFAULT_PREFIX_NAME,
        metavar="NAME",
        help="prefix directory under the lab root (default: prefix)",
    )


def resolve_run(lab: Path, run: str) -> Path:
    """Return the sidecar of the one run that matches a stamp or a full run name."""
    logs = lab / "logs"
    matches = [
        path
        for path in sorted(logs.glob("*.json"))
        if path.stem == run or path.stem.startswith(f"{run}-")
    ]
    if not matches:
        fail(f"no run matches {run!r} under {logs}")
    if len(matches) > 1:
        names = ", ".join(path.stem for path in matches)
        fail(f"{run!r} matches several runs: {names}")
    return matches[0]


def run_start(sidecar: Path) -> datetime:
    entry = json.loads(sidecar.read_text(encoding="utf-8"))
    started = entry.get("startedAt") if isinstance(entry, dict) else None
    if not isinstance(started, str):
        fail(f"run sidecar has no startedAt: {sidecar}")
    return datetime.strptime(started, "%Y%m%dT%H%M%SZ").replace(tzinfo=UTC)


def last_record_time(text: str) -> datetime | None:
    """Return the timestamp of the last complete record line.

    A hard reboot can leave a partial last line, so an unparseable tail is skipped.
    """
    for line in reversed(text.splitlines()):
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError:
            continue
        timestamp = entry.get("timestamp") if isinstance(entry, dict) else None
        if isinstance(timestamp, str):
            return datetime.strptime(timestamp, "%Y-%m-%dT%H:%M:%SZ").replace(
                tzinfo=UTC
            )
    return None


def is_freeze_report(name: str) -> bool:
    """Return True for a host report that can explain a freeze."""
    lowered = name.lower()
    return lowered.endswith(REPORT_SUFFIXES) and (
        any(marker in lowered for marker in REPORT_NAME_MARKERS)
        or lowered.endswith((".spin", ".panic"))
    )


def collect_reports(start: datetime, destination: Path) -> tuple[int, list[str]]:
    """Copy readable freeze reports newer than `start`; return the count and sudo hints."""
    copied = 0
    hints: list[str] = []
    threshold = start.timestamp() - REPORT_TIME_MARGIN_SECONDS
    for label, directory in DIAGNOSTIC_REPORTS:
        try:
            entries = sorted(directory.iterdir())
        except FileNotFoundError, PermissionError:
            continue
        for path in entries:
            if not is_freeze_report(path.name):
                continue
            try:
                if not path.is_file() or path.stat().st_mtime < threshold:
                    continue
            except OSError:
                continue
            target = destination / f"{label}-{path.name}"
            try:
                shutil.copy2(path, target)
            except PermissionError:
                hints.append(
                    f"sudo cp -p {shlex.quote(str(path))} {shlex.quote(str(target))}"
                )
            else:
                copied += 1
    return copied, hints


def write_sudo_hints(destination: Path, hints: list[str]) -> None:
    if not hints:
        return
    script = destination / "sudo-copy.sh"
    script.write_text(
        "# Run these lines in your terminal to copy the root-owned reports.\n"
        + "\n".join(hints)
        + "\n",
        encoding="utf-8",
    )
    print(f"root-owned reports: run {script}, or these lines:")
    for hint in hints:
        print(hint)


def log_show_command(start: datetime, end: datetime) -> list[str]:
    """Return `log show` for the freeze window; bare timestamps are local time."""
    return [
        "/usr/bin/log",
        "show",
        "--start",
        start.astimezone().strftime("%Y-%m-%d %H:%M:%S"),
        "--end",
        end.astimezone().strftime("%Y-%m-%d %H:%M:%S"),
        "--info",
        "--style",
        "compact",
        "--predicate",
        LOG_SHOW_PREDICATE,
    ]


def collect_system_log(start: datetime, end: datetime, destination: Path) -> None:
    argv = log_show_command(start, end)
    try:
        completed = subprocess.run(
            argv,
            check=False,
            capture_output=True,
            text=True,
            errors="replace",
            timeout=LOG_SHOW_TIMEOUT_SECONDS,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        warning(f"log show failed: {error}")
        return
    (destination / "log-show.txt").write_text(completed.stdout, encoding="utf-8")
    if completed.stderr.strip():
        (destination / "log-show.err").write_text(completed.stderr, encoding="utf-8")
    if completed.returncode:
        warning(
            f"log show exited with {completed.returncode}; "
            f"see {destination / 'log-show.err'}"
        )


def run_collect(args: argparse.Namespace) -> None:
    lab = lab_root()
    sidecar = resolve_run(lab, args.run)
    start = run_start(sidecar)
    record = lab / "logs" / f"{sidecar.stem}-record.jsonl"
    last = (
        last_record_time(record.read_text(encoding="utf-8"))
        if record.is_file()
        else None
    )
    end = max(last + COLLECT_END_MARGIN, start) if last else datetime.now(UTC)
    destination = lab / "logs" / f"{sidecar.stem}-collect"
    destination.mkdir(parents=True, exist_ok=True)
    copied, hints = collect_reports(start, destination)
    write_sudo_hints(destination, hints)
    collect_system_log(start, end, destination)
    success(f"collected {copied} report(s) and the system log: {destination}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run Arknights: Endfield on the ARM Wine runtime in the lab root."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    prefix = commands.add_parser("prefix", help="create the lab Wine prefix")
    add_prefix_argument(prefix)
    add_runtime_argument(prefix)
    prefix.add_argument(
        "--force", action="store_true", help="delete and recreate an existing prefix"
    )
    prefix.add_argument(
        "--dry-run", action="store_true", help="print the steps without running them"
    )

    mf = commands.add_parser(
        "mf-prefix", help="clone a prefix with Microsoft Media Foundation (diagnostic)"
    )
    mf.add_argument(
        "--from",
        dest="source",
        type=prefix_name,
        default=DEFAULT_PREFIX_NAME,
        metavar="NAME",
        help="prefix to clone (default: prefix)",
    )
    mf.add_argument(
        "--to",
        dest="target",
        type=prefix_name,
        default=MF_PREFIX_NAME,
        metavar="NAME",
        help="new prefix; replaced with --force (default: prefix-mf)",
    )
    add_runtime_argument(mf)
    mf.add_argument(
        "--force", action="store_true", help="replace an existing target prefix"
    )
    mf.add_argument(
        "--dry-run", action="store_true", help="print the steps without running them"
    )

    install = commands.add_parser("install", help="stream the game into <lab>/game")
    install.add_argument(
        "--plan",
        action="store_true",
        help="read the manifest and ZIP central directory only; download no parts",
    )
    install.add_argument(
        "--force", action="store_true", help="skip the free disk space check"
    )

    build = commands.add_parser("build-helpers", help="compile stepministrator.exe")
    build.add_argument(
        "--dry-run", action="store_true", help="print the compiler command only"
    )
    add_prefix_argument(build)

    launch = commands.add_parser("launch", help="start the game once")
    launch.add_argument("--backend", required=True, choices=sorted(BACKENDS))
    launch.add_argument("--parent", required=True, choices=PARENTS)
    add_prefix_argument(launch)
    add_runtime_argument(launch)
    launch.add_argument(
        "--debug",
        choices=sorted(WINE_DEBUG_PRESETS),
        default="default",
        help="WINEDEBUG preset",
    )
    launch.add_argument(
        "--wine-debug", metavar="RAW", help="raw WINEDEBUG value; overrides --debug"
    )
    launch.add_argument(
        "--env",
        action="append",
        default=[],
        type=env_pair,
        metavar="K=V",
        help="extra environment entry; repeat for more",
    )
    launch.add_argument(
        "--launcher-exe",
        default=DEFAULT_LAUNCHER_EXECUTABLE,
        help="Windows path of the official launcher (launcher parent)",
    )
    launch.add_argument(
        "--games-exe",
        default=DEFAULT_GAMES_EXECUTABLE,
        help="Windows path of the official Games.exe (stepministrator parent)",
    )
    launch.add_argument(
        "--memory-limit-gb",
        type=float,
        default=DEFAULT_MEMORY_LIMIT_GB,
        metavar="GB",
        help="end the lab's Wine processes above this summed resident memory; "
        f"0 disables (default: {DEFAULT_MEMORY_LIMIT_GB:g})",
    )
    retina = launch.add_mutually_exclusive_group()
    retina.add_argument(
        "--retina",
        dest="retina",
        action="store_true",
        help="render at the Retina backing scale",
    )
    retina.add_argument(
        "--no-retina",
        dest="retina",
        action="store_false",
        help="render at 1x",
    )
    launch.set_defaults(retina=None)
    launch.add_argument(
        "--dry-run", action="store_true", help="print the env, argv, and log path"
    )
    launch.add_argument(
        "game_args", nargs="*", metavar="GAME_ARG", help="extra game arguments"
    )

    kill = commands.add_parser(
        "kill", help="end the game and every process in the lab prefix"
    )
    add_prefix_argument(kill)
    add_runtime_argument(kill)

    collect = commands.add_parser(
        "collect", help="gather host crash reports and the system log for a run"
    )
    collect.add_argument(
        "run",
        metavar="RUN",
        help="run stamp or name, e.g. 20261126T220110Z-vulkan-mvk-stepministrator",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if args.command == "prefix":
        run_prefix(args)
    elif args.command == "mf-prefix":
        run_mf_prefix(args)
    elif args.command == "install":
        run_install(args)
    elif args.command == "build-helpers":
        run_build_helpers(args)
    elif args.command == "kill":
        run_kill(args)
    elif args.command == "collect":
        run_collect(args)
    else:
        run_launch(args)


if __name__ == "__main__":
    run_main(main)
