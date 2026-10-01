// SPDX-License-Identifier: MPL-2.0

import AppKit
import Foundation
import UniformTypeIdentifiers

extension CustomizationController {
	func chooseCustomAppIcon() {
		chooseCustomIcon(
			title: LauncherStrings.pickerLauncherIcon,
			apply: applyCustomAppIcon(from:)
		)
	}

	func chooseCustomGameIcon() {
		chooseCustomIcon(
			title: LauncherStrings.pickerGameIcon,
			apply: applyCustomGameIcon(from:)
		)
	}

	func resetGameIcon() {
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

	/// With Dynamic Theme active the themed icon replaces the custom one directly. Clearing the
	/// bundle icon first lets the Dock re-read the untinted default over the themed result.
	private func restoreLauncherIcon() -> Bool {
		if usesDynamicTheme(), heroArtwork != nil { return true }
		return launcherIconManager.reset()
	}

	func resetAppIcon() {
		invalidateIconOperations()
		do {
			if FileManager.default.fileExists(atPath: paths.customAppIcon.path) {
				try FileManager.default.removeItem(at: paths.customAppIcon)
			}
			try CustomizationImageIO.removeIfPresent(paths.operatorPresetAvatar)
			guard restoreLauncherIcon() else { throw LauncherError.cannotSetAppIcon }
			setHasCustomAppIcon(false)
			preferences.setLastAppliedDynamicIconHue(nil)
			updateThemeColor()
		} catch {
			lifecycle.show(error)
		}
	}

	@discardableResult
	func loadCustomAppIcon() async -> Bool {
		guard let (operationID, generation) = beginIconRestore() else { return false }
		let iconURL = paths.customAppIcon
		guard isCurrentIconRestore(operationID, generation: generation) else { return false }
		setHasCustomGameIcon(FileManager.default.fileExists(atPath: paths.customGameIcon.path))
		do {
			let data = try await dataLoader(iconURL)
			guard isCurrentIconRestore(operationID, generation: generation) else { return false }
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
			guard isCurrentIconRestore(operationID, generation: generation) else { return false }
			setHasCustomAppIcon(true)
			return true
		} catch {
			guard isCurrentIconRestore(operationID, generation: generation) else { return false }
			setHasCustomAppIcon(false)
			if (error as? CocoaError)?.code == .fileReadNoSuchFile { return false }
			log.error(
				"Failed to load saved launcher icon: \(launcherDiagnosticDescription(for: error))")
			return false
		}
	}

	func resetOperatorIcons() {
		invalidateIconOperations()
		do {
			for url in [paths.customAppIcon, paths.customGameIcon, paths.operatorPresetAvatar]
			where FileManager.default.fileExists(atPath: url.path) {
				try FileManager.default.removeItem(at: url)
			}
			guard restoreLauncherIcon() else { throw LauncherError.cannotSetAppIcon }
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
		passiveOperatorIconOperationID = operationID
		let generation = iconMutationGeneration
		let sourceURL = paths.operatorPresetAvatar
		let dataLoader = self.dataLoader
		return Task { [weak self, log] in
			guard let self else { return }
			do {
				let data = try await dataLoader(sourceURL)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
				guard
					let icons = AppIconRenderer.createPresetIconPair(
						from: data,
						accentHue: hue
					),
					let launcherTIFF = icons.launcher.tiffRepresentation,
					let gameTIFF = icons.game.tiffRepresentation
				else { throw LauncherError.cannotEncodeAppIcon }
				async let launcherPNG = CustomizationImageIO.encodePNG(fromTIFF: launcherTIFF)
				async let gamePNG = CustomizationImageIO.encodePNG(fromTIFF: gameTIFF)
				let encodedIcons = try await (launcherPNG, gamePNG)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
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
				try await self.dataStager(encodedIcons.0, launcherStage)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
				try await self.dataStager(encodedIcons.1, gameStage)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
				let replacements = [
					(staged: launcherStage, destination: self.paths.customAppIcon),
					(staged: gameStage, destination: self.paths.customGameIcon),
				]
				let prepared = try await self.iconPublicationPreparer(
					replacements.map(\.destination),
					operationID,
					log
				)
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else {
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
					throw LauncherError.cannotSetAppIcon
				}
				self.setHasCustomAppIcon(true)
				self.setHasCustomGameIcon(true)
			} catch {
				guard self.isCurrentPassiveOperatorIconRefresh(operationID, generation: generation)
				else { return }
				if (error as? CocoaError)?.code == .fileReadNoSuchFile { return }
				log.error(
					"Failed to refresh operator icons for Dynamic Theme: \(launcherDiagnosticDescription(for: error))"
				)
			}
			guard self.passiveOperatorIconOperationID == operationID else { return }
			self.passiveOperatorIconOperationID = nil
		}
	}

	private func chooseCustomIcon(
		title: String,
		apply: @escaping (URL) -> Void
	) {
		let panel = NSOpenPanel()
		panel.title = title
		panel.prompt = LauncherStrings.pickerChoose
		panel.allowedContentTypes = [.image]
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		guard panel.runModal() == .OK, let selected = panel.url else { return }
		apply(selected)
	}

	private func beginIconRestore() -> (UUID, UInt64)? {
		guard !iconMutationInFlight else { return nil }
		let operationID = UUID()
		iconRestoreOperationID = operationID
		return (operationID, iconMutationGeneration)
	}

	private func isCurrentIconRestore(_ operationID: UUID, generation: UInt64) -> Bool {
		iconRestoreOperationID == operationID
			&& iconMutationGeneration == generation
			&& !iconMutationInFlight
			&& !Task.isCancelled
	}

	private func isCurrentPassiveOperatorIconRefresh(
		_ operationID: UUID,
		generation: UInt64
	) -> Bool {
		passiveOperatorIconOperationID == operationID
			&& iconMutationGeneration == generation
			&& !iconMutationInFlight
			&& !Task.isCancelled
	}

	func invalidateIconOperations() {
		iconMutationGeneration &+= 1
		iconMutationInFlight = false
		iconRestoreOperationID = nil
		passiveOperatorIconOperationID = nil
		operatorIconOperationID = UUID()
	}

	func applyCustomAppIcon(from url: URL) {
		let id = beginIconOperation()
		loadAndApplyCustomIcon(from: url, operationID: id, isAppIcon: true)
	}
	func applyCustomGameIcon(from url: URL) {
		let id = beginIconOperation()
		loadAndApplyCustomIcon(from: url, operationID: id, isAppIcon: false)
	}
	func applyPresetAvatar(data: Data) async {
		let id = beginIconOperation()
		let generation = iconMutationGeneration
		defer { finishIconMutation(id) }
		let source = paths.operatorPresetAvatar
		do {
			try await Task.detached(priority: .userInitiated) {
				try CustomizationImageIO.validate(data, source: source)
			}.value
			guard operatorIconOperationID == id,
				let icons = AppIconRenderer.createPresetIconPair(
					from: data, accentHue: dynamicThemeHue),
				let launcherTIFF = icons.launcher.tiffRepresentation,
				let gameTIFF = icons.game.tiffRepresentation
			else { throw LauncherError.cannotEncodeAppIcon }
			async let launcher = CustomizationImageIO.encodePNG(fromTIFF: launcherTIFF)
			async let game = CustomizationImageIO.encodePNG(fromTIFF: gameTIFF)
			let encoded = try await (launcher, game)
			guard operatorIconOperationID == id else { return }
			let app = CustomizationImageIO.stagedURL(for: paths.customAppIcon, operationID: id)
			let gameURL = CustomizationImageIO.stagedURL(for: paths.customGameIcon, operationID: id)
			let sourceURL = CustomizationImageIO.stagedURL(for: source, operationID: id)
			defer {
				for url in [app, gameURL, sourceURL] { CustomizationImageIO.discard(url, log: log) }
			}
			try await dataStager(encoded.0, app)
			guard operatorIconOperationID == id else { return }
			try await dataStager(encoded.1, gameURL)
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
				throw LauncherError.cannotSetAppIcon
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
				guard let raw = NSImage(data: data) else {
					self.lifecycle.show(LauncherError.invalidCustomImage(url))
					return
				}
				try CustomizationImageIO.removeIfPresent(self.paths.operatorPresetAvatar)
				await self.persistCustomIcon(
					AppIconRenderer.padToAppleGrid(image: raw), operationID: id,
					isAppIcon: isAppIcon)
			} catch {
				guard self.operatorIconOperationID == id else { return }
				self.lifecycle.show(error)
			}
		}
	}

	private func persistCustomIcon(_ image: NSImage, operationID id: UUID, isAppIcon: Bool) async {
		do {
			guard let tiff = image.tiffRepresentation else {
				throw LauncherError.cannotEncodeAppIcon
			}
			let png = try await CustomizationImageIO.encodePNG(fromTIFF: tiff)
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
				guard launcherIconManager.apply(image) else { throw LauncherError.cannotSetAppIcon }
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
		passiveOperatorIconOperationID = nil
		iconRestoreOperationID = nil
		iconMutationGeneration &+= 1
		iconMutationInFlight = true
		return id
	}
	private func finishIconMutation(_ id: UUID) {
		guard operatorIconOperationID == id else { return }
		iconMutationInFlight = false
	}
}
