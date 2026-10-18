// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import ArknightsTestSupport
import Foundation
import Testing

@testable import ArknightsCustomization

@MainActor
struct CustomizationControllerTests {
	enum Race: CaseIterable {
		case artworkSelection
		case passiveArtworkLoad
		case startupArtworkRestore
		case themeExtraction
		case operatorIconRefresh
		case manualIconOverStartupRestore
	}

	@Test(arguments: Race.allCases)
	func newerArtworkSelectionRejectsAnOlderDelayedRead(race: Race) async throws {
		switch race {
		case .artworkSelection: try await artworkSelectionRace()
		case .passiveArtworkLoad: try await passiveArtworkLoadRace()
		case .startupArtworkRestore: try await startupArtworkRestoreRace()
		case .themeExtraction: try await themeExtractionRace()
		case .operatorIconRefresh: try await operatorIconRefreshRace()
		case .manualIconOverStartupRestore: try await manualIconOverStartupRestoreRace()
		}
	}

	private func artworkSelectionRace() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let fixture = try makeCustomizationController(dataLoader: { try await loader.next($0) })
		defer { fixture.temporary.remove() }
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

	private func passiveArtworkLoadRace() async throws {
		let stager = ControlledRequestGate<Void, (Data, URL)>()
		let fixture = try makeCustomizationController(dataStager: {
			try await stager.next(($0, $1))
		})
		defer { fixture.temporary.remove() }
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

	private func startupArtworkRestoreRace() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let stager = ControlledRequestGate<Void, (Data, URL)>()
		let fixture = try makeCustomizationController(
			dataLoader: { try await loader.next($0) },
			dataStager: { try await stager.next(($0, $1)) }
		)
		defer { fixture.temporary.remove() }
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

	private func themeExtractionRace() async throws {
		let extractor = ControlledRequestGate<ExtractedAccent?, NSImage>()
		let fixture = try makeCustomizationController(
			usesDynamicTheme: true,
			accentExtractor: { try? await extractor.next($0) }
		)
		defer { fixture.temporary.remove() }
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

	private func operatorIconRefreshRace() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let fixture = try makeCustomizationController(dataLoader: { try await loader.next($0) })
		defer { fixture.temporary.remove() }
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

	private func manualIconOverStartupRestoreRace() async throws {
		let loader = ControlledRequestGate<Data, URL>()
		let fixture = try makeCustomizationController(dataLoader: { try await loader.next($0) })
		defer { fixture.temporary.remove() }
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

	@Test
	func failedLauncherIconApplicationDoesNotPublishCustomIcon() async throws {
		let fixture = try makeCustomizationController(setBundleIcon: { _ in false })
		defer { fixture.temporary.remove() }
		let data = try #require(solidImage(.systemGreen).tiffRepresentation)
		try FileManager.default.createDirectory(
			at: fixture.paths.customAppIcon.deletingLastPathComponent(),
			withIntermediateDirectories: true
		)
		try data.write(to: fixture.paths.customAppIcon)

		#expect(await !fixture.controller.loadCustomAppIcon())
		#expect(!fixture.controller.hasCustomAppIcon)
	}
}

@MainActor
func makeCustomizationController(
	usesDynamicTheme: Bool = false,
	dataLoader: CustomizationController.DataLoader? = nil,
	dataStager: CustomizationController.DataStager? = nil,
	iconCommitter: CustomizationController.IconCommitter? = nil,
	iconPublicationPreparer: CustomizationController.IconPublicationPreparer? = nil,
	accentExtractor: CustomizationController.AccentExtractor? = nil,
	dynamicIconRenderer: CustomizationController.DynamicIconRenderer? = nil,
	setBundleIcon: @escaping (NSImage?) -> Bool = { _ in true },
	setRunningIcon: @escaping (NSImage?) -> Void = { _ in }
) throws -> (
	controller: CustomizationController,
	paths: AppPaths,
	preferences: LauncherPreferencesStore,
	temporary: TemporaryDirectory
) {
	let temporary = try TemporaryDirectory("CustomizationControllerTests")
	let root = temporary.url
	let paths = AppPaths(
		applicationSupportDirectory: root.appending(path: "Support"),
		cachesDirectory: root.appending(path: "Caches"),
		libraryDirectory: root.appending(path: "Library")
	)
	let defaults = makeIsolatedDefaults("CustomizationControllerTests").defaults
	let lifecycle = LauncherLifecycleStore(log: LauncherLog(fileURL: paths.launcherLogFile))
	let preferences = LauncherPreferencesStore(defaults: defaults)
	let iconManager = LauncherIconManager(
		setBundleIcon: setBundleIcon,
		setRunningIcon: setRunningIcon,
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
		iconCommitter: iconCommitter,
		iconPublicationPreparer: iconPublicationPreparer,
		accentExtractor: accentExtractor,
		dynamicIconRenderer: dynamicIconRenderer
	)
	return (controller, paths, preferences, temporary)
}

@MainActor
func solidImage(_ color: NSColor) -> NSImage {
	let image = NSImage(size: NSSize(width: 64, height: 64))
	image.lockFocus()
	color.setFill()
	NSBezierPath(rect: NSRect(x: 0, y: 0, width: 64, height: 64)).fill()
	image.unlockFocus()
	return image
}
