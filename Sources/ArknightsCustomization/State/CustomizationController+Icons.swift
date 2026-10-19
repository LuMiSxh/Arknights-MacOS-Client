// SPDX-License-Identifier: MPL-2.0

import AppKit
import ArknightsCore
import Foundation
import UniformTypeIdentifiers

extension CustomizationController {
	package func chooseCustomAppIcon() {
		chooseCustomIcon(
			title: "Choose an app icon",
			apply: applyCustomAppIcon(from:)
		)
	}

	package func chooseCustomGameIcon() {
		chooseCustomIcon(
			title: "Choose a game icon",
			apply: applyCustomGameIcon(from:)
		)
	}

	package func resetGameIcon() {
		invalidateIconOperations()
		do {
			if FileManager.default.fileExists(atPath: paths.customGameIcon.path) {
				try FileManager.default.removeItem(at: paths.customGameIcon)
			}
			try CustomizationImageIO.removeIfPresent(paths.operatorPresetAvatar)
			setHasCustomGameIcon(false)
		} catch {
			lifecycle.show(error)
		}
	}

	// With Dynamic Theme active the themed icon replaces the custom one directly. Clearing the
	// bundle icon first lets the Dock re-read the untinted default over the themed result.
	private func restoreLauncherIcon() -> Bool {
		if usesDynamicTheme(), heroArtwork != nil { return true }
		return launcherIconManager.reset()
	}

	package func resetAppIcon() {
		invalidateIconOperations()
		do {
			if FileManager.default.fileExists(atPath: paths.customAppIcon.path) {
				try FileManager.default.removeItem(at: paths.customAppIcon)
			}
			try CustomizationImageIO.removeIfPresent(paths.operatorPresetAvatar)
			guard restoreLauncherIcon() else { throw CustomizationError.cannotSetAppIcon }
			setHasCustomAppIcon(false)
			preferences.setLastAppliedDynamicIconHue(nil)
			updateThemeColor()
		} catch {
			lifecycle.show(error)
		}
	}

	@discardableResult
	package func loadCustomAppIcon() async -> Bool {
		guard let token = beginIconRestore() else { return false }
		let iconURL = paths.customAppIcon
		setHasCustomGameIcon(FileManager.default.fileExists(atPath: paths.customGameIcon.path))
		do {
			let data = try await dataLoader(iconURL)
			guard ownsIconRestore(token) else { return false }
			guard let image = NSImage(data: data) else {
				log.error("Saved launcher icon is not a valid image")
				setHasCustomAppIcon(false)
				return false
			}
			guard launcherIconManager.apply(image) else {
				log.error("Failed to reapply the saved launcher icon to the app bundle")
				setHasCustomAppIcon(false)
				return false
			}
			guard ownsIconRestore(token) else { return false }
			setHasCustomAppIcon(true)
			return true
		} catch {
			guard ownsIconRestore(token) else { return false }
			setHasCustomAppIcon(false)
			if (error as? CocoaError)?.code == .fileReadNoSuchFile { return false }
			log.error(
				"Failed to load saved launcher icon: \(launcherDiagnosticDescription(for: error))")
			return false
		}
	}

	package func resetOperatorIcons() {
		invalidateIconOperations()
		do {
			for url in [paths.customAppIcon, paths.customGameIcon, paths.operatorPresetAvatar]
			where FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}
			guard restoreLauncherIcon() else { throw CustomizationError.cannotSetAppIcon }
			setHasCustomAppIcon(false)
			setHasCustomGameIcon(false)
			preferences.setLastAppliedDynamicIconHue(nil)
			updateThemeColor()
		} catch {
			lifecycle.show(error)
		}
	}

	func refreshOperatorPresetIconsForTheme(hue: Double?) async {
		await startOperatorPresetIconRefresh(hue: hue).value
	}

	@discardableResult
	func startOperatorPresetIconRefresh(hue: Double?) -> Task<Void, Never> {
		guard !iconMutationInFlight else { return Task {} }
		let operationID = UUID()
		let sourceURL = paths.operatorPresetAvatar
		let dataLoader = self.dataLoader
		return passiveIconRefresh.replace { [weak self, log] token in
			guard let self else { return }
			do {
				let data = try await dataLoader(sourceURL)
				guard self.ownsPassiveIconRefresh(token) else { return }
				let rendered = await AppIconRenderer.renderPresetIcons(from: data, accentHue: hue)
				guard self.ownsPassiveIconRefresh(token) else { return }
				guard let icons = rendered else { throw CustomizationError.cannotEncodeAppIcon }
				let encodedIcons = try await CustomizationImageIO.encodePNGs(of: icons)
				guard self.ownsPassiveIconRefresh(token) else { return }
				let launcherStage = CustomizationImageIO.stagedURL(
					for: self.paths.customAppIcon,
					operationID: operationID
				)
				let gameStage = CustomizationImageIO.stagedURL(
					for: self.paths.customGameIcon,
					operationID: operationID
				)
				defer {
					CustomizationImageIO.discard(launcherStage, log: log)
					CustomizationImageIO.discard(gameStage, log: log)
				}
				try await self.dataStager(encodedIcons.launcher, launcherStage)
				guard self.ownsPassiveIconRefresh(token) else { return }
				try await self.dataStager(encodedIcons.game, gameStage)
				guard self.ownsPassiveIconRefresh(token) else { return }
				let replacements = [
					(staged: launcherStage, destination: self.paths.customAppIcon),
					(staged: gameStage, destination: self.paths.customGameIcon),
				]
				let prepared = try await self.iconPublicationPreparer(
					replacements.map(\.destination),
					operationID,
					log
				)
				guard self.ownsPassiveIconRefresh(token) else {
					prepared.discard(log: log)
					return
				}
				try CustomizationImageIO.publish(
					replacements,
					prepared: prepared,
					using: self.iconCommitter,
					log: log
				)
				guard self.launcherIconManager.apply(icons.launcher) else {
					throw CustomizationError.cannotSetAppIcon
				}
				self.setHasCustomAppIcon(true)
				self.setHasCustomGameIcon(true)
			} catch {
				guard self.ownsPassiveIconRefresh(token) else { return }
				if (error as? CocoaError)?.code == .fileReadNoSuchFile { return }
				log.error(
					"Failed to refresh operator icons for Dynamic Theme: \(launcherDiagnosticDescription(for: error))"
				)
			}
		}
	}

	private func chooseCustomIcon(
		title: String,
		apply: @escaping (URL) -> Void
	) {
		let panel = NSOpenPanel()
		panel.title = title
		panel.prompt = "Choose"
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		apply(selected)
	}

	private func beginIconRestore() -> TaskSlot.Token? {
		guard !iconMutationInFlight else { return nil }
		return iconRestore.begin()
	}

	private func ownsIconRestore(_ token: TaskSlot.Token) -> Bool {
		iconRestore.owns(token) && !iconMutationInFlight && !Task.isCancelled
	}

	private func ownsPassiveIconRefresh(_ token: TaskSlot.Token) -> Bool {
		passiveIconRefresh.owns(token) && !iconMutationInFlight && !Task.isCancelled
	}

	func invalidateIconOperations() {
		iconMutationGeneration &+= 1
		iconMutationInFlight = false
		iconRestore.invalidate()
		passiveIconRefresh.invalidate()
		operatorIconOperationID = UUID()
	}

	package func applyCustomAppIcon(from url: URL) {
		let id = beginIconOperation()
		loadAndApplyCustomIcon(from: url, operationID: id, isAppIcon: true)
	}
	package func applyCustomGameIcon(from url: URL) {
		let id = beginIconOperation()
		loadAndApplyCustomIcon(from: url, operationID: id, isAppIcon: false)
	}
	func applyPresetAvatar(data: Data) async {
		let id = beginIconOperation()
		let generation = iconMutationGeneration
		defer { finishIconMutation(id) }
		let source = paths.operatorPresetAvatar
		do {
			try await CustomizationImageIO.validateOffMainActor(data, source: source)
			let hue = dynamicThemeHue
			let rendered = await AppIconRenderer.renderPresetIcons(from: data, accentHue: hue)
			guard operatorIconOperationID == id, let icons = rendered else {
				throw CustomizationError.cannotEncodeAppIcon
			}
			let encoded = try await CustomizationImageIO.encodePNGs(of: icons)
			guard operatorIconOperationID == id else { return }
			let app = CustomizationImageIO.stagedURL(for: paths.customAppIcon, operationID: id)
			let gameURL = CustomizationImageIO.stagedURL(for: paths.customGameIcon, operationID: id)
			let sourceURL = CustomizationImageIO.stagedURL(for: source, operationID: id)
			defer {
				for url in [app, gameURL, sourceURL] { CustomizationImageIO.discard(url, log: log) }
			}
			try await dataStager(encoded.launcher, app)
			guard operatorIconOperationID == id else { return }
			try await dataStager(encoded.game, gameURL)
			guard operatorIconOperationID == id else { return }
			try await dataStager(data, sourceURL)
			guard operatorIconOperationID == id else { return }
			let replacements = [
				(staged: app, destination: paths.customAppIcon),
				(staged: gameURL, destination: paths.customGameIcon),
				(staged: sourceURL, destination: source),
			]
			let prepared = try await iconPublicationPreparer(
				replacements.map(\.destination),
				id,
				log
			)
			guard operatorIconOperationID == id,
				iconMutationGeneration == generation,
				!Task.isCancelled
			else {
				prepared.discard(log: log)
				return
			}
			try CustomizationImageIO.publish(
				replacements,
				prepared: prepared,
				using: iconCommitter,
				log: log
			)
			guard launcherIconManager.apply(icons.launcher) else {
				throw CustomizationError.cannotSetAppIcon
			}
			setHasCustomAppIcon(true)
			setHasCustomGameIcon(true)
		} catch {
			guard operatorIconOperationID == id, iconMutationGeneration == generation else {
				return
			}
			lifecycle.show(error)
		}
	}
	private func loadAndApplyCustomIcon(from url: URL, operationID id: UUID, isAppIcon: Bool) {
		let load = dataLoader
		Task { [weak self] in
			guard let self else { return }
			defer { self.finishIconMutation(id) }
			do {
				let data = try await load(url)
				guard self.operatorIconOperationID == id else { return }
				let padded = await AppIconRenderer.renderPaddedIcon(from: data)
				guard self.operatorIconOperationID == id else { return }
				guard let padded else {
					self.lifecycle.show(CustomizationError.invalidCustomImage(url))
					return
				}
				try CustomizationImageIO.removeIfPresent(self.paths.operatorPresetAvatar)
				await self.persistCustomIcon(padded, operationID: id, isAppIcon: isAppIcon)
			} catch {
				guard self.operatorIconOperationID == id else { return }
				self.lifecycle.show(error)
			}
		}
	}

	private func persistCustomIcon(
		_ icon: RenderedIcon, operationID id: UUID, isAppIcon: Bool
	) async {
		do {
			let image = icon.image
			let png = try await CustomizationImageIO.encodePNG(of: icon)
			guard operatorIconOperationID == id else { return }
			let destination = isAppIcon ? paths.customAppIcon : paths.customGameIcon
			let staged = CustomizationImageIO.stagedURL(for: destination, operationID: id)
			try await dataStager(png, staged)
			guard operatorIconOperationID == id else {
				CustomizationImageIO.discard(staged, log: log)
				return
			}
			try CustomizationImageIO.commit(staged, to: destination)
			if isAppIcon {
				guard launcherIconManager.apply(image) else {
					throw CustomizationError.cannotSetAppIcon
				}
				setHasCustomAppIcon(true)
			} else {
				setHasCustomGameIcon(true)
			}
		} catch {
			guard operatorIconOperationID == id else { return }
			lifecycle.show(error)
		}
	}
	private func beginIconOperation() -> UUID {
		let id = UUID()
		operatorIconOperationID = id
		passiveIconRefresh.invalidate()
		iconRestore.invalidate()
		iconMutationGeneration &+= 1
		iconMutationInFlight = true
		return id
	}
	private func finishIconMutation(_ id: UUID) {
		guard operatorIconOperationID == id else { return }
		iconMutationInFlight = false
	}
}
