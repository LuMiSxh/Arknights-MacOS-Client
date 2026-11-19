# SPDX-License-Identifier: MPL-2.0

import lib.wallpaper_manifest as manifest


def test_new_entries_sort_numerically_and_keep_existing_tags() -> None:
    merged = manifest.merge_entries(
        {"global-10": ["a"], "global-2": ["b"]}, {"global-3": ["c"]}
    )
    assert list(merged) == ["global-2", "global-3", "global-10"]
    assert merged["global-10"] == ["a"]


def test_render_matches_repository_layout_with_wrapped_entry() -> None:
    tags = {
        "global-1": ["amiya", "closer"],
        "global-463": [
            "silverash",
            "gnosis",
            "degenbrecher",
            "cliffheart",
            "pramanix",
            "kjera",
            "kjerag",
            "karlan trade co., ltd",
        ],
    }
    expected = (
        "{\n"
        '  "schemaVersion": 1,\n'
        '  "tags": {\n'
        '    "global-1": ["amiya", "closer"],\n'
        '    "global-463": [\n'
        '      "silverash",\n'
        '      "gnosis",\n'
        '      "degenbrecher",\n'
        '      "cliffheart",\n'
        '      "pramanix",\n'
        '      "kjera",\n'
        '      "kjerag",\n'
        '      "karlan trade co., ltd"\n'
        "    ]\n"
        "  }\n"
        "}\n"
    )
    assert manifest.render_manifest(tags) == expected
