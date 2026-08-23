// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct CustomizationControllerTests {
	@Test
	func matchingThemeIdentityKeepsTheVisibleArtworkInstance() {
		let fixture = makeCustomizationController()
		let visible = solidImage(.systemOrange)
		let duplicateDecode = solidImage(.systemOrange)

		fixture.controller.setHeroArtwork(visible, themeCacheKey: "official.global.first")
		fixture.controller.setHeroArtwork(duplicateDecode, themeCacheKey: "official.global.first")

		#expect(fixture.controller.heroArtwork === visible)
		#expect(fixture.controller.activeThemeCacheKey == "official.global.first")
	}

	@Test
	func initialRestorePrefersPersistedCustomArtwork() throws {
		let fixture = makeCustomizationController()
		let data = try #require(solidImage(.systemPurple).tiffRepresentation)
		try FileManager.default.createDirectory(
			at: fixture.paths.customArtwork.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try data.write(to: fixture.paths.customArtwork)

		fixture.controller.restoreInitialArtwork(for: .global)

		#expect(fixture.controller.heroArtwork != nil)
		#expect(fixture.controller.activeThemeCacheKey?.hasPrefix("custom.") == true)
	}

	@Test
	func directGameIconPersistsAndPublishesItsStatus() throws {
		let fixture = makeCustomizationController()

		fixture.controller.applyDirectCustomGameIcon(image: solidImage(.systemTeal))

		#expect(fixture.controller.hasCustomGameIcon)
		#expect(FileManager.default.fileExists(atPath: fixture.paths.customGameIcon.path))
		#expect(
			fixture.lifecycle.activityMessage
				== L10n.string(.Launcher.launcherStatusGameIconUpdated)
		)
	}

	@Test
	func presetAvatarOwnsBothPersistedIconsAndItsSource() throws {
		let fixture = makeCustomizationController()
		let data = try #require(solidImage(.systemPink).tiffRepresentation)

		fixture.controller.applyPresetAvatar(data: data)

		#expect(FileManager.default.fileExists(atPath: fixture.paths.customAppIcon.path))
		#expect(FileManager.default.fileExists(atPath: fixture.paths.customGameIcon.path))
		#expect(FileManager.default.fileExists(atPath: fixture.paths.operatorPresetAvatar.path))
		#expect(fixture.controller.hasCustomAppIcon)
		#expect(fixture.controller.hasCustomGameIcon)
	}

	@Test
	func presetAvatarRefreshRebuildsTheLauncherIconForANewThemeHue() async throws {
		let fixture = makeCustomizationController()
		let data = try #require(solidImage(.systemPink).tiffRepresentation)
		fixture.controller.applyPresetAvatar(data: data)
		let previous = try Data(contentsOf: fixture.paths.customAppIcon)

		await fixture.controller.refreshOperatorPresetIconsForTheme(hue: 0.78)

		#expect(try Data(contentsOf: fixture.paths.customAppIcon) != previous)
	}

	@Test
	func disabledDynamicThemeRestoresStaticColors() {
		let fixture = makeCustomizationController(usesDynamicTheme: false)
		fixture.controller.dynamicThemeHue = 0.7

		fixture.controller.updateThemeColor()

		#expect(fixture.controller.dynamicThemeHue == nil)
		#expect(fixture.controller.accentColor == LauncherVisuals.cyan)
		#expect(fixture.controller.hudTintColor == LauncherVisuals.hudGlassTint)
	}
}

@MainActor
private func makeCustomizationController(
	usesDynamicTheme: Bool = false
) -> (controller: CustomizationController, lifecycle: LauncherLifecycleStore, paths: AppPaths) {
	let root = FileManager.default.temporaryDirectory.appending(
		path: "CustomizationControllerTests.\(UUID().uuidString)",
		directoryHint: .isDirectory
	)
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let defaults = UserDefaults(suiteName: "CustomizationControllerTests.\(UUID().uuidString)")!
	let lifecycle = LauncherLifecycleStore(log: LauncherLog(fileURL: paths.launcherLogFile))
	let iconManager = LauncherIconManager(
		setBundleIcon: { _ in true },
		setRunningIcon: { _ in },
		defaultIcon: { solidImage(.systemBlue) }
	)
	let controller = CustomizationController(
		lifecycle: lifecycle,
		paths: paths,
		preferences: LauncherPreferencesStore(defaults: defaults),
		launcherIconManager: iconManager,
		region: { .global },
		usesDynamicTheme: { usesDynamicTheme }
	)
	return (controller, lifecycle, paths)
}

@MainActor
private func solidImage(_ color: NSColor) -> NSImage {
	let image = NSImage(size: NSSize(width: 64, height: 64))
	image.lockFocus()
	color.setFill()
	NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
	image.unlockFocus()
	return image
}
