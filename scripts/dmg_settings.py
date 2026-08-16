# SPDX-License-Identifier: MPL-2.0

"""Compact Finder presentation for the release disk image."""

app_bundle = globals()["defines"]["app_bundle"]
app_name = "Arknights Client.app"

format = "UDZO"
files = [app_bundle]
symlinks = {"Applications": "/Applications"}

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
default_view = "icon-view"
arrange_by = None
grid_spacing = 96
icon_size = 112
text_size = 14
label_pos = "bottom"
window_rect = ((100, 100), (560, 320))
icon_locations = {
    app_name: (145, 155),
    "Applications": (415, 155),
}
