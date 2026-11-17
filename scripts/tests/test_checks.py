# SPDX-License-Identifier: MPL-2.0

import build_compatibility


def test_compatibility_manifest_declares_native_sources_once() -> None:
    components = build_compatibility.load_components()
    artifacts = [
        (
            build_compatibility.SUPPORT_ROOT
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
        for path in build_compatibility.SUPPORT_ROOT.rglob(suffix)
    )
    assert len(outputs) == len(set(outputs))
