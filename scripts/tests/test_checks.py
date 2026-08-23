# SPDX-License-Identifier: MPL-2.0

from __future__ import annotations

import checks


def test_handwritten_swift_sources_exclude_generated_catalog_symbols() -> None:
    sources = checks.handwritten_swift_sources()

    assert any(path.name == "L10n.swift" for path in sources)
    assert not any(path.name.startswith("GeneratedStringSymbols_") for path in sources)
