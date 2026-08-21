# Third-party notices

Arknights Client packages a prebuilt compatibility runtime. Exact versions, archive hashes, and build provenance are pinned in [`runtime.json`](../../runtime.json). The app also embeds a small MPL-2.0 wrapper built from `RuntimeSupport/Vuplex`; it does not distribute the Vuplex SDK.

## Runtime components

| Component     | Version or revision                                    | License                                                                                             | Source                                                                                                  |
| ------------- | ------------------------------------------------------ | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| WineCX / Wine | Wine 11.15, `51e3854751e51ed25af4cd3af367f92f421ed0c8` | LGPL-2.1-or-later and bundled third-party terms                                                     | [dappermint/winecx](https://github.com/dappermint/winecx/tree/51e3854751e51ed25af4cd3af367f92f421ed0c8) |
| DXMT          | 0.80                                                   | MIT and bundled third-party terms                                                                   | [3Shain/dxmt](https://github.com/3Shain/dxmt/tree/v0.80)                                                |
| MoltenVK      | 1.4.2                                                  | Apache-2.0 and bundled third-party terms                                                            | [KhronosGroup/MoltenVK](https://github.com/KhronosGroup/MoltenVK/tree/v1.4.2)                           |
| Wine Gecko    | 2.47.4                                                 | MPL/GPL/LGPL terms and Mozilla notices                                                              | [Wine Gecko](https://gitlab.winehq.org/wine/wine-gecko)                                                 |
| GStreamer     | 1.26.3, including base, good, bad, and libav plugins   | Mostly LGPL-2.1-or-later; selected plugins and dependencies are GPL-2.0-or-later or use other terms | [GStreamer](https://github.com/GStreamer/gstreamer/tree/1.26.3)                                         |
| FFmpeg        | 7.1.1                                                  | GPL-3.0-or-later for the bundled configuration                                                      | [FFmpeg 7.1.1](https://github.com/FFmpeg/FFmpeg/tree/n7.1.1)                                            |

The runtime also contains dynamically linked libraries for media, text, networking, compression, and X11 compatibility. Notable media dependencies include x264, x265, FDK-AAC, FAAD2, libdvdcss, libdvdnav, libdvdread, OpenH264, libde265, libaom, dav1d, SVT-AV1, libvpx, LAME, OpenMPT, FLAC, Vorbis, Opus, Theora, Speex, and libsndfile. Their own licenses and patent terms continue to apply.

Canonical texts currently included with development builds are:

- Apache License 2.0
- GNU General Public License 2.0 and 3.0
- GNU Lesser General Public License 2.1 and 3.0
- DXMT 0.80 MIT license
- Fraunhofer FDK-AAC notice

Wine Mono, DXVK, and Apple's Game Porting Toolkit are not copied into the app bundle.
