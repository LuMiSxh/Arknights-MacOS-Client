// SPDX-License-Identifier: MPL-2.0

/// Versions and source commits that the bundled `RUNTIME.json` pins. A field is nil when the file omits it.
struct RuntimePins: Equatable, Sendable {
	var wineVersion: String?
	var wineCommit: String?
	var dxmtVersion: String?
	var dxmtCommit: String?
}

/// What the installed runtime reports about itself. Settings → About shows it.
package struct InstalledRuntimeDetails: Equatable, Sendable {
	package let name: String
	package let wineVersion: String?
	package let wineCommit: String?
	package let dxmtVersion: String?
	package let dxmtCommit: String?
	package let hardwareCursor: Bool
	package let metalFXSpatialUpscaling: Bool
	package let nativeFullscreenSpace: Bool

	init(name: String, pins: RuntimePins, capabilities: RuntimeCapabilities) {
		self.name = name
		wineVersion = pins.wineVersion
		wineCommit = pins.wineCommit
		dxmtVersion = pins.dxmtVersion
		dxmtCommit = pins.dxmtCommit
		hardwareCursor = capabilities.hardwareCursorSupported
		metalFXSpatialUpscaling = capabilities.metalFXSpatialUpscalingSupported
		nativeFullscreenSpace = capabilities.nativeFullscreenSpaceSupported
	}
}
