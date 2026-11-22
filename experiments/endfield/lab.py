# SPDX-License-Identifier: MPL-2.0

"""Run Arknights: Endfield on the app's ARM Wine runtime inside a separate lab root.

The lab owns its Wine prefix, game folder, logs, and helpers. It reads the runtime and
never writes to the app's data directory. See experiments/endfield/README.md.
"""

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path, PureWindowsPath

REPOSITORY_DIR = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPOSITORY_DIR / "scripts"))

import installer  # noqa: E402
from lib.common import PROJECT_DIR, fail, run_main  # noqa: E402
from lib.console import success, warning  # noqa: E402
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
DXMT_DLL_DIRECTORY = Path("DXMT/x64")
KOSMICKRISP_ICD = Path("share/vulkan/icd.d/kosmickrisp_mesa_icd.aarch64.json")
# Lives inside the prefix: Wine routes a Unix exe path through start.exe, which hangs in
# imm32 initialization on the ARM runtime. A C:\ path starts the helper directly.
STEPMINISTRATOR = r"C:\stepministrator\stepministrator.exe"
STEPMINISTRATOR_SOURCE = (
    Path(__file__).resolve().parent / "stepministrator/stepministrator.c"
)
MINGW_COMPILER = "x86_64-w64-mingw32-gcc"
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
HOMEBREW_BIN = "/opt/homebrew/bin"
PREFIX_WINE_OVERRIDES = "winemac.drv=d"
DXMT_OVERRIDES = "d3d10core,d3d11,dxgi=n,b;winemetal=b;dcomp,mscoree,mshtml="
# backend -> (WINEDLLOVERRIDES, game argument that selects the renderer)
BACKENDS: dict[str, tuple[str, str]] = {
    "dxmt-d3d11": (DXMT_OVERRIDES, "-force-d3d11"),
    # Wine's builtin d3d12 (vkd3d) runs on Vulkan, so it also goes through KosmicKrisp.
    "vkd3d-kk": ("dcomp,mscoree,mshtml=", "-force-d3d12"),
    "vulkan-kk": ("dcomp,mscoree,mshtml=", "-force-vulkan"),
}
VULKAN_BACKENDS = {"vkd3d-kk", "vulkan-kk"}


@dataclass(frozen=True, slots=True)
class LaunchPlan:
    argv: list[str]
    cwd: Path
    env: dict[str, str]
    required: list[Path]
    notes: list[str]


def utc_stamp() -> str:
    return datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")


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


def base_environment(lab: Path, runtime: Path) -> dict[str, str]:
    # Mirrors WineRuntime.isolatedEnvironment. HOME points into the prefix so Wine never
    # writes to the real home directory.
    home = lab / "prefix" / "home"
    return {
        "WINEPREFIX": str(lab / "prefix"),
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


def host_path(windows_path: str, lab: Path) -> Path:
    """Map a path on the lab's C: (prefix drive_c) or G: (game folder) drive."""
    windows = PureWindowsPath(windows_path)
    roots = {"C:": lab / "prefix" / "drive_c", "G:": lab / "game"}
    root = roots.get(windows.drive.upper())
    if root is None:
        fail(f"Windows path must be on drive C: or G:: {windows_path}")
    return root.joinpath(*windows.parts[1:])


def dxmt_dlls(runtime: Path) -> list[Path]:
    dlls = sorted((runtime / DXMT_DLL_DIRECTORY).glob("*.dll"))
    if not dlls:
        fail(f"runtime has no DXMT DLLs in {DXMT_DLL_DIRECTORY}: {runtime}")
    return dlls


def print_environment(env: dict[str, str]) -> None:
    print("env:")
    for key in sorted(env):
        print(f"  {key}={env[key]}")


def run_logged(argv: list[str], env: dict[str, str], cwd: Path, log: Path) -> int:
    """Run a process, copying its combined output to stdout and to the log file."""
    log.parent.mkdir(parents=True, exist_ok=True)
    with (
        log.open("w", encoding="utf-8") as file,
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
        for line in process.stdout:
            sys.stdout.write(line)
            file.write(line)
        return process.wait()


def run_prefix(args: argparse.Namespace) -> None:
    lab = lab_root()
    runtime = resolve_runtime(args.runtime)
    prefix = lab / "prefix"
    system32 = prefix / "drive_c/windows/system32"
    dosdevices_link = prefix / "dosdevices/g:"
    env = base_environment(lab, runtime) | {
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


def launch_plan(args: argparse.Namespace, lab: Path, runtime: Path) -> LaunchPlan:
    wine = str(runtime / "bin/wine64")
    game_directory = lab / "game"
    game_executable = host_path(GAME_EXECUTABLE, lab)
    override, renderer_argument = BACKENDS[args.backend]
    env = base_environment(lab, runtime) | {
        "WINEDEBUG": args.wine_debug or WINE_DEBUG_PRESETS[args.debug],
        "WINEDLLOVERRIDES": override,
    }
    if args.backend in VULKAN_BACKENDS:
        icd = runtime / KOSMICKRISP_ICD
        if not icd.is_file():
            fail(f"runtime has no KosmicKrisp ICD: {icd}")
        env["VK_DRIVER_FILES"] = str(icd)
    env |= dict(args.env)
    # Only the direct parent picks the renderer. The official launcher passes none.
    game_arguments = [*FIXED_GAME_ARGUMENTS, *args.game_args]
    required = [lab / "prefix"]
    notes: list[str] = []
    if args.parent == "direct":
        argv = [wine, GAME_EXECUTABLE, renderer_argument, *game_arguments]
        cwd = game_directory
        required.append(game_executable)
    elif args.parent == "launcher":
        launcher = host_path(args.launcher_exe, lab)
        argv = [wine, args.launcher_exe]
        cwd = launcher.parent
        required.append(launcher)
        notes.append(
            "launcher parent: the launcher starts the game, so game arguments "
            "and the renderer flag are not passed"
        )
    else:
        helper = host_path(STEPMINISTRATOR, lab)
        argv = [wine, STEPMINISTRATOR, args.games_exe, GAME_EXECUTABLE, *game_arguments]
        # The helper sets the game's working directory itself.
        cwd = helper.parent
        required += [host_path(args.games_exe, lab), game_executable, helper]
    return LaunchPlan(argv=argv, cwd=cwd, env=env, required=required, notes=notes)


def missing_message(path: Path, lab: Path) -> str:
    hint = (
        " (build it with build-stepministrator)"
        if path == host_path(STEPMINISTRATOR, lab)
        else ""
    )
    return f"missing: {path}{hint}"


def run_launch(args: argparse.Namespace) -> None:
    lab = lab_root()
    runtime = resolve_runtime(args.runtime)
    plan = launch_plan(args, lab, runtime)
    started_at = utc_stamp()
    log = lab / "logs" / f"{started_at}-{args.backend}-{args.parent}.log"
    sidecar = log.with_suffix(".json")
    for note in plan.notes:
        warning(note)
    problems = [
        missing_message(path, lab) for path in plan.required if not path.exists()
    ]
    if args.dry_run:
        print_environment(plan.env)
        print(f"argv: {shlex.join(plan.argv)}")
        print(f"cwd: {plan.cwd}")
        print(f"log: {log}")
        print(f"sidecar: {sidecar}")
        for problem in problems:
            warning(f"{problem} (a real launch stops here)")
        return
    if problems:
        fail("; ".join(problems))
    record = {
        "backend": args.backend,
        "parent": args.parent,
        "startedAt": started_at,
        "runtime": {"path": str(runtime), "version": runtime_version(runtime)},
        "cwd": str(plan.cwd),
        "argv": plan.argv,
        "env": plan.env,
    }
    log.parent.mkdir(parents=True, exist_ok=True)
    sidecar.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    code = run_logged(plan.argv, plan.env, plan.cwd, log)
    # With the launcher parent, wine returns when the launcher stub exits, while the game
    # may still run. The other parents return only after the game has exited.
    if args.parent != "launcher":
        end_leftovers(plan.env, runtime)
    if code:
        raise SystemExit(code)


def end_leftovers(env: dict[str, str], runtime: Path) -> None:
    # The game's PlatformProcess.exe outlives the game and keeps the prefix alive.
    quiet = env | {"WINEDEBUG": "-all"}
    subprocess.run(
        [str(runtime / "bin/wine64"), "taskkill", "/f", "/im", "PlatformProcess.exe"],
        env=quiet,
        check=False,
        capture_output=True,
    )
    try:
        subprocess.run(
            [str(runtime / "bin/wineserver"), "-w"], env=quiet, check=False, timeout=30
        )
    except subprocess.TimeoutExpired:
        warning("the prefix is still running after 30 s; check for leftover processes")


def run_install(args: argparse.Namespace) -> None:
    try:
        installer.run(lab_root(), plan_only=args.plan, force=args.force)
    except installer.InstallError as error:
        fail(str(error))


def run_build_stepministrator(args: argparse.Namespace) -> None:
    compiler = shutil.which(
        MINGW_COMPILER, path=f"{os.environ.get('PATH', '')}{os.pathsep}{HOMEBREW_BIN}"
    )
    if compiler is None:
        fail(f"{MINGW_COMPILER} not found; install MinGW with `brew install mingw-w64`")
    output = host_path(STEPMINISTRATOR, lab_root())
    command = [compiler, *MINGW_FLAGS, "-o", str(output), str(STEPMINISTRATOR_SOURCE)]
    if args.dry_run:
        print(shlex.join(command))
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    code = subprocess.run(command, check=False).returncode
    if code:
        fail(f"{MINGW_COMPILER} exited with {code}")
    success(f"built {output}")


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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Run Arknights: Endfield on the ARM Wine runtime in the lab root."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    prefix = commands.add_parser("prefix", help="create the lab Wine prefix")
    add_runtime_argument(prefix)
    prefix.add_argument(
        "--force", action="store_true", help="delete and recreate an existing prefix"
    )
    prefix.add_argument(
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

    build = commands.add_parser(
        "build-stepministrator", help="compile bin/stepministrator.exe with MinGW"
    )
    build.add_argument(
        "--dry-run", action="store_true", help="print the compiler command only"
    )

    launch = commands.add_parser("launch", help="start the game once")
    launch.add_argument("--backend", required=True, choices=sorted(BACKENDS))
    launch.add_argument("--parent", required=True, choices=PARENTS)
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
        "--dry-run", action="store_true", help="print the env, argv, and log path"
    )
    launch.add_argument(
        "game_args", nargs="*", metavar="GAME_ARG", help="extra game arguments"
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if args.command == "prefix":
        run_prefix(args)
    elif args.command == "install":
        run_install(args)
    elif args.command == "build-stepministrator":
        run_build_stepministrator(args)
    else:
        run_launch(args)


if __name__ == "__main__":
    run_main(main)
