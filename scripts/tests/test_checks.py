# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import build_compatibility
from lib.common import PROJECT_DIR


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
