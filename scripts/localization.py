#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.13"
# dependencies = []
# ///
# SPDX-License-Identifier: MPL-2.0

"""Generate or verify SwiftPM localization resources from the String Catalog."""

from __future__ import annotations

import argparse
import json
import re
import tempfile
from pathlib import Path

from lib.common import PROJECT_DIR, ScriptError, run, run_main, success

RESOURCE_DIRECTORY = PROJECT_DIR / "Sources/ArknightsClient/Resources"
GENERATED_DIRECTORY = PROJECT_DIR / "Sources/ArknightsClient/Shared/Localization"
LOCALIZATIONS = ("en", "de")
LICENSE_HEADER = "// SPDX-License-Identifier: MPL-2.0\n\n"
KEY_PATTERN = re.compile(r"^[a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+$")
SWIFT_PACKAGE_BUNDLE_DECLARATION = (
    "private nonisolated let resourceBundle = Foundation.Bundle.module"
)
APP_RESOURCE_BUNDLE_DECLARATION = (
    "private nonisolated let resourceBundle = AppResourceBundle.bundle"
)


def catalog_paths() -> list[Path]:
    catalogs = sorted(RESOURCE_DIRECTORY.glob("*.xcstrings"))
    if not catalogs:
        raise ScriptError("no localization catalogs found")
    return catalogs


def validate_catalog(catalog_path: Path) -> None:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    if catalog.get("sourceLanguage") != "en":
        raise ScriptError("localization source language must be English")
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
        for language in LOCALIZATIONS:
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


def synchronize_file(source: Path, destination: Path, *, write: bool) -> None:
    expected = source.read_bytes()
    actual = destination.read_bytes() if destination.is_file() else None
    if actual == expected:
        return
    if not write:
        relative = destination.relative_to(PROJECT_DIR)
        raise ScriptError(f"generated localization file is stale: {relative}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(expected)


def remove_stale_files(
    actual_files: set[Path], expected_files: set[Path], *, write: bool
) -> None:
    for stale in sorted(actual_files - expected_files):
        if not write:
            relative = stale.relative_to(PROJECT_DIR)
            raise ScriptError(
                f"obsolete generated localization file remains: {relative}"
            )
        stale.unlink()


def use_app_resource_bundle(generated_symbols: str) -> str:
    if generated_symbols.count(SWIFT_PACKAGE_BUNDLE_DECLARATION) != 1:
        raise ScriptError("unexpected generated Swift package resource declaration")
    return generated_symbols.replace(
        SWIFT_PACKAGE_BUNDLE_DECLARATION,
        APP_RESOURCE_BUNDLE_DECLARATION,
    )


def generate_localization(
    catalogs: list[Path], output_directory: Path
) -> tuple[dict[str, Path], dict[tuple[str, str], Path]]:
    compiled_directory = output_directory / "compiled"
    symbols_directory = output_directory / "symbols"
    symbols_directory.mkdir(parents=True)
    generated: dict[str, Path] = {}
    compiled: dict[tuple[str, str], Path] = {}
    for catalog in catalogs:
        run(
            [
                "xcrun",
                "xcstringstool",
                "compile",
                catalog,
                "--output-directory",
                compiled_directory,
                "--format",
                "stringsAndStringsdict",
            ],
            cwd=PROJECT_DIR,
        )
        before = set(symbols_directory.glob("*.swift"))
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
        new_symbols = set(symbols_directory.glob("*.swift")) - before
        if len(new_symbols) != 1:
            raise ScriptError(f"unexpected generated symbol output for {catalog.name}")
        generated_symbols = new_symbols.pop()
        symbols = use_app_resource_bundle(generated_symbols.read_text(encoding="utf-8"))
        generated_symbols.write_text(LICENSE_HEADER + symbols, encoding="utf-8")
        run(
            [
                "swift",
                "format",
                "format",
                "--configuration",
                PROJECT_DIR / ".swift-format",
                "--in-place",
                generated_symbols,
            ],
            cwd=PROJECT_DIR,
        )
        generated[catalog.stem] = generated_symbols
        for language in LOCALIZATIONS:
            compiled[(catalog.stem, language)] = (
                compiled_directory / f"{language}.lproj/{catalog.stem}.strings"
            )
    return generated, compiled


def synchronize_localization(*, write: bool) -> None:
    catalogs = catalog_paths()
    for catalog in catalogs:
        validate_catalog(catalog)
    with tempfile.TemporaryDirectory() as directory:
        generated, compiled = generate_localization(catalogs, Path(directory))
        expected_symbols = {
            GENERATED_DIRECTORY / f"GeneratedStringSymbols_{catalog_name}.swift"
            for catalog_name in generated
        }
        for catalog_name, source in generated.items():
            destination = (
                GENERATED_DIRECTORY / f"GeneratedStringSymbols_{catalog_name}.swift"
            )
            synchronize_file(source, destination, write=write)
        remove_stale_files(
            set(GENERATED_DIRECTORY.glob("GeneratedStringSymbols_*.swift")),
            expected_symbols,
            write=write,
        )
        for (catalog_name, language), source in compiled.items():
            destination = (
                RESOURCE_DIRECTORY / f"{language}.lproj/{catalog_name}.strings"
            )
            synchronize_file(source, destination, write=write)
        for language in LOCALIZATIONS:
            expected_strings = {
                RESOURCE_DIRECTORY / f"{language}.lproj/{catalog_name}.strings"
                for catalog_name in generated
            }
            remove_stale_files(
                set((RESOURCE_DIRECTORY / f"{language}.lproj").glob("*.strings")),
                expected_strings,
                write=write,
            )


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("check", "format"))
    arguments = parser.parse_args()
    synchronize_localization(write=arguments.mode == "format")
    success(f"localization {arguments.mode} complete")


if __name__ == "__main__":
    run_main(main)
