// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import Testing

@testable import ArknightsClient

@MainActor
struct CustomizationControllerTests {
	@Test
	func initialRestorePrefersPersistedCustomArtwork() async throws {
		let fixture = makeCustomizationController()
		let data = try #require(solidImage(.systemPurple).tiffRepresentation)
		try FileManager.default.createDirectory(
			at: fixture.paths.customArtwork.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try data.write(to: fixture.paths.customArtwork)

		await fixture.controller.restoreInitialArtwork(for: .global)

		#expect(fixture.controller.heroArtwork != nil)
		#expect(fixture.controller.activeThemeCacheKey?.hasPrefix("custom.") == true)
	}
	@Test
	func newerArtworkSelectionRejectsAnOlderDelayedRead() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let fixture = makeCustomizationController(dataLoader: { try await loader.next($0) })
		let firstURL = fixture.paths.customArtwork.deletingLastPathComponent()
			.appending(path: "first.tiff")
		let secondURL = fixture.paths.customArtwork.deletingLastPathComponent()
			.appending(path: "second.tiff")
		let firstData = try #require(solidImage(.systemRed).tiffRepresentation)
		let secondData = try #require(solidImage(.systemGreen).tiffRepresentation)

		fixture.controller.applyCustomArtwork(from: firstURL)
		await loader.waitForRequestCount(1)
		fixture.controller.applyCustomArtwork(from: secondURL)
		await loader.waitForRequestCount(2)
		await loader.resolve(1, with: secondData)
		#expect(
			await waitForCondition {
				(try? Data(contentsOf: fixture.paths.customArtwork)) == secondData
			}
		)

		await loader.resolve(0, with: firstData)
		await Task.yield()

		#expect(try Data(contentsOf: fixture.paths.customArtwork) == secondData)
		#expect(
			fixture.controller.activeThemeCacheKey
				== CustomizationController.customThemeCacheKey(for: secondData)
		)
	}
	@Test
	func passiveArtworkLoadCannotCancelAnActiveUserSelection() async throws {
		let stager = ControlledRequestGate<Void, (Data, URL)>()
		let fixture = makeCustomizationController(dataStager: { try await stager.next(($0, $1)) })
		let selectedData = try #require(solidImage(.systemGreen).tiffRepresentation)

		let selection = Task {
			await fixture.controller.applyDirectCustomArtwork(data: selectedData)
		}
		await stager.waitForRequestCount(1)
		let passiveLoad = Task { await fixture.controller.loadCustomArtwork() }
		#expect(await passiveLoad.value == false)
		try await stager.resolveStaged(0)
		await selection.value

		#expect(try Data(contentsOf: fixture.paths.customArtwork) == selectedData)
		#expect(
			fixture.controller.activeThemeCacheKey
				== CustomizationController.customThemeCacheKey(for: selectedData)
		)
	}
	@Test
	func completedCustomMutationWinsWhenStartupRestoreWasSuspended() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let stager = ControlledRequestGate<Void, (Data, URL)>()
		let fixture = makeCustomizationController(
			dataLoader: { try await loader.next($0) },
			dataStager: { try await stager.next(($0, $1)) }
		)
		let customData = try #require(solidImage(.systemGreen).tiffRepresentation)
		let officialData = try #require(solidImage(.systemRed).tiffRepresentation)
		try FileManager.default.createDirectory(
			at: fixture.paths.artworkCache, withIntermediateDirectories: true)
		try officialData.write(to: fixture.paths.artworkCache.appending(path: "official.jpg"))
		try Data("official".utf8).write(
			to: fixture.paths.artworkCache.appending(path: "active-global.txt"))

		let restore = Task { await fixture.controller.restoreInitialArtwork(for: .global) }
		await loader.waitForRequestCount(1)
		let mutation = Task {
			await fixture.controller.applyDirectCustomArtwork(data: customData)
		}
		await stager.waitForRequestCount(1)
		try await stager.resolveStaged(0)
		await mutation.value
		await loader.resolve(0, with: customData)
		await restore.value

		#expect(fixture.controller.hasPersistedCustomArtwork)
		#expect(
			fixture.controller.activeThemeCacheKey
				== CustomizationController.customThemeCacheKey(for: customData)
		)
	}

	@Test
	func failedLauncherIconApplicationDoesNotPublishCustomIcon() async throws {
		let fixture = makeCustomizationController(setBundleIcon: { _ in false })
		let data = try #require(solidImage(.systemGreen).tiffRepresentation)
		try FileManager.default.createDirectory(
			at: fixture.paths.customAppIcon.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try data.write(to: fixture.paths.customAppIcon)

		#expect(await !fixture.controller.loadCustomAppIcon())
		#expect(!fixture.controller.hasCustomAppIcon)
	}

	@Test
	func newerThemeExtractionRejectsAnOlderDelayedResult() async throws {
		let extractor = ControlledRequestGate<ExtractedAccent?, NSImage>()
		let fixture = makeCustomizationController(
			usesDynamicTheme: true,
			accentExtractor: { try? await extractor.next($0) }
		)
		let firstKey = "custom.first"
		let secondKey = "custom.second"

		fixture.controller.setHeroArtwork(solidImage(.systemRed), themeCacheKey: firstKey)
		await extractor.waitForRequestCount(1)
		fixture.controller.setHeroArtwork(solidImage(.systemGreen), themeCacheKey: secondKey)
		await extractor.waitForRequestCount(2)
		await extractor.resolve(
			1, with: ExtractedAccent(hue: 0.7, saturation: 0.8, brightness: 0.9))
		#expect(await waitForCondition { fixture.controller.dynamicThemeHue == 0.7 })

		await extractor.resolve(
			0, with: ExtractedAccent(hue: 0.1, saturation: 0.8, brightness: 0.9))
		await Task.yield()

		#expect(fixture.controller.dynamicThemeHue == 0.7)
		#expect(fixture.preferences.dynamicThemeAccent(for: firstKey) == nil)
		#expect(fixture.preferences.dynamicThemeAccent(for: secondKey)?.hue == 0.7)
	}
	@Test
	func newerOperatorIconRefreshRejectsAnOlderDelayedRead() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let fixture = makeCustomizationController(dataLoader: { try await loader.next($0) })
		let avatarData = try #require(solidImage(.systemPink).tiffRepresentation)
		await fixture.controller.applyPresetAvatar(data: avatarData)

		let first = Task {
			await fixture.controller.refreshOperatorPresetIconsForTheme(hue: 0.1)
		}
		await loader.waitForRequestCount(1)
		let second = Task {
			await fixture.controller.refreshOperatorPresetIconsForTheme(hue: 0.7)
		}
		await loader.waitForRequestCount(2)
		await loader.resolve(1, with: avatarData)
		await second.value
		let expected = try Data(contentsOf: fixture.paths.customAppIcon)

		await loader.resolve(0, with: avatarData)
		await first.value

		#expect(try Data(contentsOf: fixture.paths.customAppIcon) == expected)
	}
	@Test
	func manualAppIconSelectionWinsOverDelayedStartupRestore() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let fixture = makeCustomizationController(dataLoader: { try await loader.next($0) })
		let selected = solidImage(.systemGreen)
		let staleData = try #require(solidImage(.systemRed).tiffRepresentation)
		let selectedURL = fixture.paths.customArtwork.deletingLastPathComponent()
			.appending(path: "selected.png")

		let restore = Task { await fixture.controller.loadCustomAppIcon() }
		await loader.waitForRequestCount(1)
		fixture.controller.applyCustomAppIcon(from: selectedURL)
		await loader.waitForRequestCount(2)
		let selectedData = try #require(selected.tiffRepresentation)
		await loader.resolve(1, with: selectedData)
		#expect(
			await waitForCondition {
				FileManager.default.fileExists(atPath: fixture.paths.customAppIcon.path)
			}
		)
		await loader.resolve(0, with: staleData)
		_ = await restore.value

		#expect(try Data(contentsOf: fixture.paths.customAppIcon) != staleData)
	}
}

@MainActor
private func makeCustomizationController(
	usesDynamicTheme: Bool = false,
	dataLoader: CustomizationController.DataLoader? = nil,
	dataStager: CustomizationController.DataStager? = nil,
	accentExtractor: CustomizationController.AccentExtractor? = nil,
	setBundleIcon: @escaping (NSImage?) -> Bool = { _ in true }
) -> (
	controller: CustomizationController,
	paths: AppPaths,
	preferences: LauncherPreferencesStore
) {
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
	let preferences = LauncherPreferencesStore(defaults: defaults)
	let iconManager = LauncherIconManager(
		setBundleIcon: setBundleIcon,
		setRunningIcon: { _ in },
		defaultIcon: { solidImage(.systemBlue) }
	)
	let controller = CustomizationController(
		lifecycle: lifecycle,
		paths: paths,
		preferences: preferences,
		launcherIconManager: iconManager,
		region: { .global },
		usesDynamicTheme: { usesDynamicTheme },
		dataLoader: dataLoader,
		dataStager: dataStager,
		accentExtractor: accentExtractor
	)
	return (controller, paths, preferences)
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
