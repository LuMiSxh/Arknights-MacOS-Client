# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import build_compatibility
import checks
from lib.common import PROJECT_DIR


def test_handwritten_swift_sources_exclude_generated_catalog_symbols() -> None:
    sources = checks.handwritten_swift_sources()

    assert any(path.name == "L10n.swift" for path in sources)
    assert not any(path.name.startswith("GeneratedStringSymbols_") for path in sources)


def test_compatibility_manifest_declares_native_sources_once() -> None:
    components = build_compatibility.load_components()
    artifacts = [
        (
            PROJECT_DIR
            / "RuntimeSupport"
            / component["directory"]
            / artifact["source"],
            (component["directory"], artifact["output"]),
        )
        for component in components
        for artifact in component["artifacts"]
    ]
    sources, outputs = zip(*artifacts, strict=True)

    assert sorted(sources) == sorted(
        path
        for suffix in ("*.c", "*.m")
        for path in (PROJECT_DIR / "RuntimeSupport").rglob(suffix)
    )
    assert len(outputs) == len(set(outputs))
