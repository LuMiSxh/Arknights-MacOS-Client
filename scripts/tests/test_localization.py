# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import json
from pathlib import Path

import localization
import pytest
from lib.common import ScriptError


def layout(
    root: Path,
    *,
    localizations: tuple[str, ...] = ("en", "de"),
    catalogs: tuple[Path, ...] = (),
) -> localization.LocalizationLayout:
    return localization.LocalizationLayout(
        resource_directory=root,
        generated_directory=root / "Generated",
        source_language="en",
        localizations=localizations,
        catalogs=catalogs,
    )


def test_generated_symbols_use_the_packaged_app_resource_bundle() -> None:
    generated = (
        "#if SWIFT_PACKAGE\n"
        "private nonisolated let resourceBundle = Foundation.Bundle.module\n"
        "#endif\n"
    )

    result = localization.use_app_resource_bundle(generated)

    assert "AppResourceBundle.bundle" in result
    assert "Foundation.Bundle.module" not in result


def test_rejects_catalog_keys_without_shipping_translations(tmp_path: Path) -> None:
    catalog = tmp_path / "Localizable.xcstrings"
    catalog.write_text(
        json.dumps(
            {
                "sourceLanguage": "en",
                "strings": {
                    "home.settings": {
                        "comment": "Settings button",
                        "localizations": {
                            "en": {
                                "stringUnit": {
                                    "state": "translated",
                                    "value": "Settings",
                                }
                            }
                        },
                    }
                },
            }
        ),
        encoding="utf-8",
    )

    with pytest.raises(ScriptError, match="missing language: de"):
        localization.validate_catalog(catalog, layout(catalog.parent))


def test_shipping_languages_come_from_the_layout(tmp_path: Path) -> None:
    catalog = tmp_path / "Localizable.xcstrings"
    localizations = {
        language: {"stringUnit": {"state": "translated", "value": language}}
        for language in ("en", "de", "fr")
    }
    catalog.write_text(
        json.dumps(
            {
                "sourceLanguage": "en",
                "strings": {
                    "home.settings": {
                        "comment": "Settings button",
                        "localizations": localizations,
                    }
                },
            }
        ),
        encoding="utf-8",
    )

    localization.validate_catalog(
        catalog,
        layout(catalog.parent, localizations=("en", "de", "fr")),
    )


def test_catalog_fingerprint_invalidates_symbols_after_copy_changes(
    tmp_path: Path,
) -> None:
    catalog = tmp_path / "Localizable.xcstrings"
    symbols = tmp_path / "GeneratedStringSymbols_Localizable.swift"
    catalog.write_text("first", encoding="utf-8")
    fingerprint = localization.catalog_fingerprint(catalog)
    symbols.write_text(
        f"{localization.LICENSE_HEADER}"
        f"{localization.APP_RESOURCE_BUNDLE_DECLARATION}\n"
        f"{localization.FINGERPRINT_PREFIX}{fingerprint}\n",
        encoding="utf-8",
    )

    assert localization.symbols_are_current(symbols, fingerprint)

    catalog.write_text("second", encoding="utf-8")
    assert not localization.symbols_are_current(
        symbols, localization.catalog_fingerprint(catalog)
    )
