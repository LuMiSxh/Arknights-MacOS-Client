---
title: Display and performance
description: Rendering, window size, resolution, frame rate, cursor, and Battery Saver
order: 42
---

# Display and performance

## Display

Change these settings in **Settings → Game → Display**. They apply at the next launch.

**Game display** chooses the display the game opens on. The list shows each connected display by name. **Primary display** follows the display with the menu bar. The row appears when more than one display is connected. If the chosen display is disconnected, the game opens on the primary display.

**Rendering** sets how the game reaches a Retina display. It has no effect on other displays.

| Choice       | Behavior                                                                                                                                         |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Retina**   | Draws every display pixel. Sharpest. Needs the most GPU time.                                                                                    |
| **MetalFX**  | Draws one pixel per macOS point. DXMT upscales each frame 2× with MetalFX spatial scaling. Softer text. A runtime without MetalFX uses Standard. |
| **Standard** | Draws one pixel per macOS point. macOS stretches the window. Blurry on Retina displays.                                                          |

**Window size** uses the "Looks like" sizes of **System Settings → Displays**. **Fill screen** fills the usable screen area with the title bar visible. **Compact** picks a smaller 16:9 window. The menu also lists exact sizes.

**Resolution** sets the fullscreen resolution. With MetalFX or Standard rendering, the game draws one pixel per macOS point, then scales up.

- **Native** matches the display pixel for pixel, with the menu bar. Setup picks it. It follows display changes.
- The list also holds the sizes of the official client and sizes in the display shape between 4K and the native resolution.

Lower resolutions scale to fill the screen. They look grainy on larger or differently shaped displays. Sizes larger than the display are hidden.

**Cursor** set to **macOS** shows the macOS cursor instead of the PRTS cursor. The cursor then follows the mouse without delay. It needs runtime support. The launcher sends this choice to the runtime at every launch.

**Settings → Game → Display** shows the exact size the game draws. **Override in-game display settings** is on by default. Keep it on: the launcher converts the window size into the game resolution, so the picture stays sharp. When it is off, the display settings of Arknights decide. They count drawn pixels. Example: with Retina rendering on a 2× display, 2560×1440 opens a 1280×720 window.

## Performance

**Frame rate limit** in **Settings → Game → Performance** caps the frames per second the game draws. Use the slider to choose **30 FPS**, **60 FPS**, or **120 FPS**. Lower values save battery.

**Frame rate limit**, **Game Mode**, and **Metal Performance HUD** apply only when **Override in-game display settings** is on. When it is off, the game keeps its own settings for these options.

## Battery Saver

**Battery Saver** lowers game options at the next launch. Turn it on in **Settings → Game → Performance**.

It turns off **Game Mode**. The game uses the lower of **Battery Saver frame rate limit** and **Frame rate limit**. If **Override in-game display settings** is off, the game uses **Battery Saver frame rate limit** alone.

If **Override in-game display settings** is on, it also changes **Rendering** from **Retina** to **MetalFX** or **Standard**.

Choose **30 FPS** or **60 FPS** for **Battery Saver frame rate limit**. Changes apply at the next launch.
