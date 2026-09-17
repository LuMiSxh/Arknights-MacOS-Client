#!/usr/bin/env -S uv run --locked --no-dev
# SPDX-License-Identifier: MPL-2.0

"""Prepare and validate type-safe Swift symbols from the String Catalogs."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

from lib.common import (
    PROJECT_DIR,
    ScriptError,
    output,
    require_directory,
    run,
    run_main,
)
from lib.console import success
from lib.project_config import ProjectConfiguration, load_project_configuration

LICENSE_HEADER = "// SPDX-License-Identifier: MPL-2.0\n\n"
FINGERPRINT_PREFIX = "// Localization catalog fingerprint: "
GENERATOR_SOURCE = Path(__file__).read_bytes()
KEY_PATTERN = re.compile(r"^[a-z][A-Za-z0-9]*(?:\.[a-z][A-Za-z0-9]*)+$")
GENERATED_SYMBOL_PATTERN = re.compile(
    r"Localized string for key “(?P<key>[^”]+)”[\s\S]*?\n\s*"
    r"static (?:var|func) (?P<symbol>[A-Za-z_][A-Za-z0-9_]*)\b"
)
SWIFT_PACKAGE_BUNDLE_DECLARATION = (
    "private nonisolated let resourceBundle = Foundation.Bundle.module"
)
APP_RESOURCE_BUNDLE_DECLARATION = (
    "private nonisolated let resourceBundle = AppResourceBundle.bundle"
)
TOOLCHAIN_SYMBOL_SDK_VERSION = 27


@dataclass(frozen=True)
class LocalizationLayout:
    resource_directory: Path
    generated_directory: Path
    source_language: str
    localizations: tuple[str, ...]
    catalogs: tuple[Path, ...]


def swift_resource_root(bundle: Path) -> Path:
    """Return the resource directory for either SwiftPM bundle layout."""
    nested = bundle / "Contents/Resources"
    return nested if nested.is_dir() else bundle


def discover_layout(configuration: ProjectConfiguration) -> LocalizationLayout:
    resource_directory = configuration.resource_directory
    catalogs = tuple(sorted(resource_directory.glob("*.xcstrings")))
    if not catalogs:
        raise ScriptError("no localization catalogs found")
    target_directory = configuration.target_directory
    excluded = set(configuration.package.excluded_paths)
    processed = set(configuration.package.processed_resource_paths)
    for catalog in catalogs:
        relative = catalog.relative_to(target_directory)
        if relative in excluded:
            raise ScriptError(
                f"Package.swift excludes processed String Catalog: {relative}"
            )
        if relative not in processed:
            raise ScriptError(
                f"Package.swift does not process String Catalog: {relative}"
            )
    return LocalizationLayout(
        resource_directory=resource_directory,
        generated_directory=target_directory / "Shared/Localization",
        source_language=configuration.product.development_region,
        localizations=configuration.product.localizations,
        catalogs=catalogs,
    )


def validate_catalog(catalog_path: Path, layout: LocalizationLayout) -> None:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    if catalog.get("sourceLanguage") != layout.source_language:
        raise ScriptError(
            "catalog source language must match CFBundleDevelopmentRegion: "
            f"{catalog_path.name}"
        )
    strings = catalog.get("strings")
    if not isinstance(strings, dict) or not strings:
        raise ScriptError("localization catalog does not contain any strings")

    for key, entry in strings.items():
        if KEY_PATTERN.fullmatch(key) is None:
            raise ScriptError(f"localization key is not feature-namespaced: {key}")
        if not isinstance(entry, dict) or not entry.get("comment", "").strip():
            raise ScriptError(
                f"localization key is missing a translator comment: {key}"
            )
        localizations = entry.get("localizations", {})
        for language in layout.localizations:
            localization = localizations.get(language)
            if not isinstance(localization, dict):
                raise ScriptError(
                    f"localization key {key} is missing language: {language}"
                )
            string_units = _string_units(localization)
            if not string_units:
                raise ScriptError(
                    f"localization key {key} has no string value for language: {language}"
                )
            for unit in string_units:
                if (
                    unit.get("state") != "translated"
                    or not unit.get("value", "").strip()
                ):
                    raise ScriptError(
                        f"localization key {key} has an incomplete {language} translation"
                    )


def _string_units(value: object) -> list[dict[str, str]]:
    if isinstance(value, dict):
        units: list[dict[str, str]] = []
        string_unit = value.get("stringUnit")
        if isinstance(string_unit, dict):
            units.append(string_unit)
        for nested in value.values():
            units.extend(_string_units(nested))
        return units
    if isinstance(value, list):
        return [unit for nested in value for unit in _string_units(nested)]
    return []


def toolchain_generates_symbols() -> bool:
    """Report whether the active SDK's build system emits the catalog symbols itself.

    The macOS 27 SDK generates a ``GeneratedStringSymbols_<Catalog>.swift`` for every
    String Catalog in the target.  Two build commands would then produce the same object
    file, so this script must stop writing its own symbols there.  Earlier SDKs generate
    nothing, and contributors on macOS 26 keep the symbols this script produces.
    """
    try:
        version = output(["xcrun", "--sdk", "macosx", "--show-sdk-version"])
    except (ScriptError, OSError):
        return False
    major, _, _ = version.partition(".")
    return major.isdigit() and int(major) >= TOOLCHAIN_SYMBOL_SDK_VERSION


def validate_catalog_usage(
    layout: LocalizationLayout,
    *,
    source_directory: Path,
    generated_symbols: dict[str, Path] | None = None,
) -> None:
    """Reject catalog entries whose generated Swift symbol has no production reference.

    ``generated_symbols`` maps a catalog stem to a symbol file outside the target, used
    when the build system owns the symbols and the target therefore holds none.
    """
    source = "\n".join(
        path.read_text(encoding="utf-8")
        for path in source_directory.rglob("*.swift")
        if not path.name.startswith("GeneratedStringSymbols_")
    )
    orphaned: list[str] = []
    for catalog in layout.catalogs:
        strings = json.loads(catalog.read_text(encoding="utf-8")).get("strings", {})
        generated_path = (
            generated_symbols[catalog.stem]
            if generated_symbols is not None
            else layout.generated_directory
            / f"GeneratedStringSymbols_{catalog.stem}.swift"
        )
        generated = generated_path.read_text(encoding="utf-8")
        symbols = {
            match.group("key"): match.group("symbol")
            for match in GENERATED_SYMBOL_PATTERN.finditer(generated)
        }
        missing_symbols = sorted(set(strings) - set(symbols))
        if missing_symbols:
            raise ScriptError(
                "generated localization symbols are incomplete: "
                + ", ".join(missing_symbols)
            )
        orphaned.extend(
            key
            for key, symbol in symbols.items()
            if re.search(rf"\b{re.escape(symbol)}\b", source) is None
            and f'"{key}"' not in source
        )
    if orphaned:
        raise ScriptError(
            "localization keys have no Swift reference: " + ", ".join(sorted(orphaned))
        )


def use_app_resource_bundle(generated_symbols: str) -> str:
    if generated_symbols.count(SWIFT_PACKAGE_BUNDLE_DECLARATION) != 1:
        raise ScriptError("unexpected generated Swift package resource declaration")
    return generated_symbols.replace(
        SWIFT_PACKAGE_BUNDLE_DECLARATION,
        APP_RESOURCE_BUNDLE_DECLARATION,
    )


def catalog_fingerprint(catalog: Path) -> str:
    digest = hashlib.sha256(GENERATOR_SOURCE)
    digest.update(catalog.read_bytes())
    return digest.hexdigest()


def symbols_are_current(path: Path, fingerprint: str) -> bool:
    if not path.is_file():
        return False
    prefix = f"{FINGERPRINT_PREFIX}{fingerprint}"
    try:
        contents = path.read_text(encoding="utf-8")
        return (
            prefix in contents.splitlines()[-4:]
            and APP_RESOURCE_BUNDLE_DECLARATION in contents
        )
    except OSError:
        return False


def generate_catalog(
    catalog: Path,
    output_directory: Path,
) -> tuple[str, Path]:
    catalog_directory = output_directory / catalog.stem
    symbols_directory = catalog_directory / "symbols"
    symbols_directory.mkdir(parents=True)
    run(
        [
            "xcrun",
            "xcstringstool",
            "generate-symbols",
            catalog,
            "--output-directory",
            symbols_directory,
            "--language",
            "swift",
        ],
        cwd=PROJECT_DIR,
    )
    generated_symbols = tuple(symbols_directory.glob("*.swift"))
    if len(generated_symbols) != 1:
        raise ScriptError(f"unexpected generated symbol output for {catalog.name}")
    symbols_path = generated_symbols[0]
    symbols = use_app_resource_bundle(symbols_path.read_text(encoding="utf-8"))
    fingerprint = catalog_fingerprint(catalog)
    symbols_path.write_text(
        LICENSE_HEADER + symbols + "\n" + FINGERPRINT_PREFIX + fingerprint + "\n",
        encoding="utf-8",
    )
    return catalog.stem, symbols_path


def generate_localization(
    layout: LocalizationLayout, output_directory: Path
) -> dict[str, Path]:
    with ThreadPoolExecutor(max_workers=min(4, len(layout.catalogs))) as executor:
        generated = dict(
            executor.map(
                lambda catalog: generate_catalog(catalog, output_directory),
                layout.catalogs,
            )
        )
    return generated


def compile_swift_localizations(
    binary_directory: Path,
    configuration: ProjectConfiguration | None = None,
) -> None:
    """Compile SwiftPM's raw catalogs into the resource bundle's .lproj files.

    SwiftPM either copies raw ``.xcstrings`` resources or, on newer SDKs,
    emits a bundle whose catalogs are already compiled. Foundation's
    localized-string lookup needs compiled ``.strings`` resources before tests
    or app packaging consume the resource bundle.
    """
    configuration = configuration or load_project_configuration()
    bundle = require_directory(
        binary_directory / configuration.swift_resource_bundle_name
    )
    resource_root = swift_resource_root(bundle)
    catalogs = tuple(sorted(resource_root.glob("*.xcstrings")))
    languages = tuple(configuration.product.localizations)
    if not catalogs:
        localizations = tuple(sorted(resource_root.glob("*.lproj/*.strings")))
        discovered = {path.parent.name.removesuffix(".lproj") for path in localizations}
        expected = set(languages)
        if discovered != expected:
            raise ScriptError(
                "Swift resource bundle contains neither raw String Catalogs nor "
                f"all compiled localizations: {bundle}"
            )
        return

    language_arguments = [
        argument for language in languages for argument in ("--language", language)
    ]
    for catalog in catalogs:
        run(
            [
                "xcrun",
                "xcstringstool",
                "compile",
                catalog,
                "--output-directory",
                resource_root,
                *language_arguments,
            ],
            cwd=PROJECT_DIR,
        )

    expected = {
        resource_root / f"{language}.lproj" / f"{catalog.stem}.strings"
        for language in languages
        for catalog in catalogs
    }
    missing = sorted(path for path in expected if not path.is_file())
    if missing:
        raise ScriptError(
            "xcstringstool did not produce all localized Swift resources: "
            + ", ".join(str(path.relative_to(resource_root)) for path in missing)
        )


def prepare_toolchain_symbols(
    layout: LocalizationLayout, configuration: ProjectConfiguration
) -> bool:
    """Clear this script's symbols and validate key usage against a throwaway copy.

    The build system writes its own symbols on this SDK, so anything left in the target
    duplicates them.  Key-usage validation still needs the symbol names, and the generated
    ones only exist inside the build's derived sources, so they are regenerated into a
    temporary directory that never reaches the target.  The build system's symbols resolve
    through ``Bundle.module``, which is why ``build_app.py`` packages the Swift resource
    bundle whole instead of only flattening its localizations.
    """
    obsolete = sorted(layout.generated_directory.glob("GeneratedStringSymbols_*.swift"))
    for path in obsolete:
        path.unlink()
    with tempfile.TemporaryDirectory() as directory:
        validate_catalog_usage(
            layout,
            source_directory=configuration.target_directory,
            generated_symbols=generate_localization(layout, Path(directory)),
        )
    return bool(obsolete)


def prepare_localization(
    *, force: bool = False, configuration: ProjectConfiguration | None = None
) -> bool:
    configuration = configuration or load_project_configuration()
    layout = discover_layout(configuration)
    for catalog in layout.catalogs:
        validate_catalog(catalog, layout)
    if toolchain_generates_symbols():
        return prepare_toolchain_symbols(layout, configuration)

    expected = {
        layout.generated_directory / f"GeneratedStringSymbols_{catalog.stem}.swift": (
            catalog,
            catalog_fingerprint(catalog),
        )
        for catalog in layout.catalogs
    }
    stale = {
        destination: catalog
        for destination, (catalog, fingerprint) in expected.items()
        if force or not symbols_are_current(destination, fingerprint)
    }
    obsolete = set(
        layout.generated_directory.glob("GeneratedStringSymbols_*.swift")
    ) - set(expected)
    if not stale and not obsolete:
        validate_catalog_usage(layout, source_directory=configuration.target_directory)
        return False

    if stale:
        with tempfile.TemporaryDirectory() as directory:
            stale_layout = LocalizationLayout(
                resource_directory=layout.resource_directory,
                generated_directory=layout.generated_directory,
                source_language=layout.source_language,
                localizations=layout.localizations,
                catalogs=tuple(stale.values()),
            )
            generated = generate_localization(stale_layout, Path(directory))
            layout.generated_directory.mkdir(parents=True, exist_ok=True)
            for destination, catalog in stale.items():
                destination.write_bytes(generated[catalog.stem].read_bytes())
    for path in obsolete:
        path.unlink()
    validate_catalog_usage(layout, source_directory=configuration.target_directory)
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("prepare", "format", "compile"))
    parser.add_argument(
        "binary_directory",
        nargs="?",
        type=Path,
        help="SwiftPM binary directory used by the compile mode",
    )
    arguments = parser.parse_args()
    if arguments.mode == "compile":
        if arguments.binary_directory is None:
            parser.error("compile requires a SwiftPM binary directory")
        compile_swift_localizations(arguments.binary_directory)
        success("SwiftPM localization resources compiled")
        return
    changed = prepare_localization(force=arguments.mode == "format")
    if changed:
        success("Localization symbols generated")


if __name__ == "__main__":
    run_main(main)
